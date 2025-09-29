/* eslint-disable require-jsdoc, max-len */
import {
  beforeDocumentWritten,
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
  onDocumentWrittenWithAuthContext,
} from "firebase-functions/v2/firestore";
import {
  HttpsError,
  onCall,
  type CallableRequest,
} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {taskQueue} from "firebase-functions/v2";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import https from "node:https";
import {Storage} from "@google-cloud/storage";
import {
  type AnalyticsCustomerRecord,
  type AnalyticsOrderItem,
  type AnalyticsOrderRecord,
  type AnalyticsRefundRecord,
  type AnalyticsEventType,
  type BigQueryInsert,
  buildEventId,
  stringifyItems,
} from "./analytics-models.js";
import {
  isBigQueryStreamingEnabled,
  streamAnalyticsRow,
} from "./bigquery-streaming.js";
import {
  DEFAULT_BACKFILL_BATCH_SIZE,
  MASTER_DATA_COLLECTIONS,
  buildBackfillUpdates,
  isMasterDataCollection,
  validateMasterDataConstraints,
  type MasterDataCollection,
} from "./master-data.js";
export {ingestBuildMetric} from "./build-metrics.js";

admin.initializeApp();
const db = admin.firestore();
const storage = new Storage();

const BACKUP_BUCKET = process.env.BACKUP_BUCKET;
const ASIA_BANGKOK_OFFSET_MINUTES = 7 * 60;
const AGGREGATE_COLLECTION_HOURLY = "analytics_hourly";
const AGGREGATE_COLLECTION_DAILY = "analytics_daily";
const ANALYTICS_SCHEMA_VERSION = 1;
const PRIVACY_LOG_COLLECTION = "privacyOpsLogs";

type TtlFilter = {
  field: string;
  op: FirebaseFirestore.WhereFilterOp;
  value: unknown;
};

type TtlRule = {
  collection: string;
  field: string;
  ttlHours: number;
  fallbackField?: string;
  filters?: TtlFilter[];
  batchSize?: number;
};

const DEFAULT_TTL_BATCH_SIZE = 200;

const TTL_RULES: TtlRule[] = [
  {
    collection: "opsLogs",
    field: "timestamp",
    ttlHours: 24 * 14,
  },
  {
    collection: "notifications",
    field: "createdAt",
    ttlHours: 24 * 30,
  },
  {
    collection: PRIVACY_LOG_COLLECTION,
    field: "createdAt",
    ttlHours: 24 * 90,
  },
  {
    collection: "analytics_exports",
    field: "completedAt",
    fallbackField: "requestedAt",
    ttlHours: 24 * 14,
    filters: [
      {field: "status", op: "in", value: ["completed", "failed"]},
    ],
  },
];

const MAX_BACKFILL_BATCH_SIZE = 500;

type MasterDataBackfillTaskPayload = {
  collection: MasterDataCollection;
  startAfter?: string;
  batchSize?: number;
};

const masterDataBackfillQueue = taskQueue<MasterDataBackfillTaskPayload>({
  rateLimits: {
    maxConcurrentDispatches: 1,
  },
  retryConfig: {
    maxAttempts: 5,
  },
  id: "masterDataBackfill",
});

const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY;
const SENDGRID_FROM_EMAIL =
  process.env.SENDGRID_FROM_EMAIL ?? "no-reply@restaurant.local";

// --- TIER UPGRADE CONFIGURATION ---
const TIER_THRESHOLDS = {
  PLATINUM: 20000,
  GOLD: 5000,
};

const TIER_POINT_MULTIPLIERS = {
  PLATINUM: 1.5,
  GOLD: 1.2,
  SILVER: 1.0,
};
// ------------------------------------

// --- Helper function to create notifications ---
async function createNotification(
  tenantId: string,
  type: string,
  title: string,
  message: string,
  severity: "info" | "warn" | "critical",
  data: object = {}
) {
  try {
    await db.collection("notifications").add({
      tenantId,
      type,
      title,
      message,
      severity,
      data,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      seenBy: {},
    });
    logger.log(`Notification created: ${title}`);
  } catch (error) {
    logger.error("Failed to create notification:", error);
  }
}

function normalizeBackfillBatchSize(value?: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return DEFAULT_BACKFILL_BATCH_SIZE;
  }
  const coerced = Math.trunc(value);
  if (!Number.isFinite(coerced) || coerced <= 0) {
    return DEFAULT_BACKFILL_BATCH_SIZE;
  }
  return Math.min(coerced, MAX_BACKFILL_BATCH_SIZE);
}

export const enforceMasterDataConstraints = beforeDocumentWritten(
  "{collectionId}/{docId}",
  (event: any) => {
    const {collectionId} = event.params;
    if (!isMasterDataCollection(collectionId)) {
      return;
    }

    const afterData = event.data?.after?.data();
    if (!afterData) {
      return;
    }

    const errors = validateMasterDataConstraints(
      collectionId,
      afterData as Record<string, unknown>
    );

    if (errors.length > 0) {
      throw new HttpsError(
        "failed-precondition",
        `Master data constraint violation: ${errors.join("; ")}`
      );
    }
  }
);

export const startMasterDataBackfill = onCall(async (request) => {
  const data = request.data as {
    collection?: string | string[];
    batchSize?: number;
  };

  const requestedCollections = data.collection;
  const collections =
    requestedCollections == null
      ? MASTER_DATA_COLLECTIONS
      : Array.isArray(requestedCollections)
        ? requestedCollections
        : [requestedCollections];

  if (collections.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "At least one master data collection must be provided."
    );
  }

  const invalidCollections = collections.filter(
    (collectionId) => !isMasterDataCollection(collectionId)
  );
  if (invalidCollections.length > 0) {
    throw new HttpsError(
      "invalid-argument",
      `Unsupported master data collection(s): ${invalidCollections.join(", ")}`
    );
  }

  const batchSize = normalizeBackfillBatchSize(data.batchSize);

  for (const collectionId of collections as MasterDataCollection[]) {
    await masterDataBackfillQueue.enqueue({
      collection: collectionId,
      batchSize,
    });
  }

  logger.log(
    "Queued master data backfill",
    collections,
    {batchSize}
  );

  return {
    enqueuedCollections: collections,
    batchSize,
  };
});

export const processMasterDataBackfill = masterDataBackfillQueue.onDispatch(
  async (payload: MasterDataBackfillTaskPayload) => {
    const {collection, startAfter} = payload;
    const batchSize = normalizeBackfillBatchSize(payload.batchSize);

    if (!isMasterDataCollection(collection)) {
      logger.error(
        "Received backfill task for unsupported collection",
        payload
      );
      return;
    }

    let query = db
      .collection(collection)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(batchSize);

    if (typeof startAfter === "string" && startAfter.length > 0) {
      query = query.startAfter(startAfter);
    }

    const snapshot = await query.get();

    if (snapshot.empty) {
      logger.log(`Master data backfill completed for ${collection}.`);
      return;
    }

    for (const doc of snapshot.docs) {
      const originalData = doc.data() as Record<string, unknown>;
      const updates = buildBackfillUpdates(collection, originalData);
      const merged = {...originalData, ...updates};
      const errors = validateMasterDataConstraints(collection, merged);

      if (errors.length > 0) {
        logger.error(
          `Skipping ${collection}/${doc.id} due to constraint violations`,
          {errors}
        );
        continue;
      }

      if (Object.keys(updates).length === 0) {
        continue;
      }

      await doc.ref.update(updates);
      logger.debug(`Backfilled ${collection}/${doc.id}`, updates);
    }

    if (snapshot.size === batchSize) {
      const nextStartAfter = snapshot.docs[snapshot.docs.length - 1]?.id;
      if (nextStartAfter) {
        await masterDataBackfillQueue.enqueue({
          collection,
          startAfter: nextStartAfter,
          batchSize,
        });
      }
    } else {
      logger.log(
        `Master data backfill processed final batch for ${collection} (${snapshot.size} documents).`
      );
    }
  }
);

function normalizeValue(value: unknown): unknown {
  if (value === null || value === undefined) {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map((entry) => normalizeValue(entry));
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }
  if (typeof value === "object") {
    const normalized: Record<string, unknown> = {};
    Object.entries(value as Record<string, unknown>).forEach(([key, entry]) => {
      normalized[key] = normalizeValue(entry);
    });
    return normalized;
  }
  return value;
}

function extractChangeSummary(
  before: Record<string, unknown> | null,
  after: Record<string, unknown> | null
): Record<string, unknown> {
  if (!before && !after) {
    return {};
  }
  if (!before && after) {
    return {after: normalizeValue(after)};
  }
  if (before && !after) {
    return {before: normalizeValue(before)};
  }

  if (!before || !after) {
    return {};
  }

  const normalizedBefore = normalizeValue(before) as Record<string, unknown>;
  const normalizedAfter = normalizeValue(after) as Record<string, unknown>;
  const keys = new Set([
    ...Object.keys(normalizedBefore),
    ...Object.keys(normalizedAfter),
  ]);

  const changes: Record<string, { before: unknown; after: unknown }> = {};
  keys.forEach((key) => {
    const beforeValue = normalizedBefore[key];
    const afterValue = normalizedAfter[key];
    if (JSON.stringify(beforeValue) !== JSON.stringify(afterValue)) {
      changes[key] = {before: beforeValue, after: afterValue};
    }
  });

  if (Object.keys(changes).length === 0) {
    return {};
  }

  return {changes};
}

function toIsoString(value: unknown): string | undefined {
  if (!value) {
    return undefined;
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }
  if (typeof value === "string") {
    return value;
  }
  return undefined;
}

function toNumber(value: unknown): number {
  const numeric = Number(value ?? 0);
  if (Number.isNaN(numeric)) {
    return 0;
  }
  return numeric;
}

function buildAnalyticsEventType(
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined
): AnalyticsEventType {
  if (!before && after) {
    return "CREATE";
  }
  if (before && !after) {
    return "DELETE";
  }
  return "UPDATE";
}

function extractOrderItems(orderData: Record<string, unknown>): AnalyticsOrderItem[] {
  const rawItems = orderData.items;
  if (!Array.isArray(rawItems)) {
    return [];
  }

  return rawItems
    .map((raw) => {
      if (!raw || typeof raw !== "object") {
        return null;
      }
      const entry = raw as Record<string, unknown>;
      return {
        sku: String(entry.sku ?? entry.id ?? ""),
        name: String(entry.name ?? entry.title ?? ""),
        quantity: toNumber(entry.quantity),
        price: toNumber(entry.price ?? entry.unitPrice ?? entry.amount),
        category: entry.category ? String(entry.category) : undefined,
      } satisfies AnalyticsOrderItem;
    })
    .filter((item) => item !== null)
    .map((item) => item as AnalyticsOrderItem);
}

function buildOrderAnalyticsRecord(
  orderId: string,
  orderData: Record<string, unknown>,
  eventType: AnalyticsEventType,
  eventTimestamp: string
): AnalyticsOrderRecord {
  const items = extractOrderItems(orderData);
  const subtotal = toNumber(orderData.subtotal ?? orderData.total ?? 0);
  const tax = toNumber(orderData.tax ?? orderData.taxAmount ?? 0);
  const discount = toNumber(
    orderData.discount ?? orderData.discountAmount ?? orderData.totalDiscount ?? 0
  );
  const tip = toNumber(orderData.tip ?? orderData.tipAmount ?? 0);
  const total = toNumber(orderData.total ?? orderData.grandTotal ?? subtotal + tax - discount + tip);

  return {
    event_id: buildEventId("orders", orderId, eventTimestamp),
    event_type: eventType,
    event_timestamp: eventTimestamp,
    order_id: orderId,
    tenant_id: String(orderData.tenantId ?? ""),
    store_id: orderData.storeId ? String(orderData.storeId) : undefined,
    customer_id: orderData.customerId ? String(orderData.customerId) : undefined,
    status: orderData.status ? String(orderData.status) : undefined,
    payment_status: orderData.paymentStatus
      ? String(orderData.paymentStatus)
      : undefined,
    payment_method: orderData.paymentMethod
      ? String(orderData.paymentMethod)
      : undefined,
    subtotal,
    tax,
    discount,
    tip,
    total,
    currency: orderData.currency ? String(orderData.currency) : undefined,
    order_created_at: toIsoString(orderData.createdAt),
    order_updated_at: toIsoString(orderData.updatedAt),
    order_closed_at: toIsoString(orderData.closedAt ?? orderData.completedAt),
    loyalty_points_awarded: orderData.loyaltyPointsAwarded
      ? toNumber(orderData.loyaltyPointsAwarded)
      : undefined,
    items_json: stringifyItems(items),
  } satisfies AnalyticsOrderRecord;
}

function buildCustomerAnalyticsRecord(
  customerId: string,
  customerData: Record<string, unknown>,
  eventType: AnalyticsEventType,
  eventTimestamp: string
): AnalyticsCustomerRecord {
  return {
    event_id: buildEventId("customers", customerId, eventTimestamp),
    event_type: eventType,
    event_timestamp: eventTimestamp,
    customer_id: customerId,
    tenant_id: String(customerData.tenantId ?? ""),
    email: customerData.email ? String(customerData.email) : undefined,
    phone_number: customerData.phoneNumber
      ? String(customerData.phoneNumber)
      : undefined,
    loyalty_tier: customerData.tier ? String(customerData.tier) : undefined,
    points_balance: customerData.loyaltyPoints
      ? toNumber(customerData.loyaltyPoints)
      : undefined,
    lifetime_value: customerData.lifetimeSpend
      ? toNumber(customerData.lifetimeSpend)
      : undefined,
    created_at: toIsoString(customerData.createdAt),
    updated_at: toIsoString(customerData.updatedAt),
  } satisfies AnalyticsCustomerRecord;
}

function buildRefundAnalyticsRecord(
  refundId: string,
  refundData: Record<string, unknown>,
  eventType: AnalyticsEventType,
  eventTimestamp: string
): AnalyticsRefundRecord {
  return {
    event_id: buildEventId("refunds", refundId, eventTimestamp),
    event_type: eventType,
    event_timestamp: eventTimestamp,
    refund_id: refundId,
    order_id: refundData.originalOrderId
      ? String(refundData.originalOrderId)
      : undefined,
    tenant_id: String(refundData.tenantId ?? ""),
    amount: toNumber(refundData.totalRefundAmount ?? refundData.amount ?? 0),
    reason: refundData.reason ? String(refundData.reason) : undefined,
    status: refundData.status ? String(refundData.status) : undefined,
    processed_at: toIsoString(refundData.processedAt ?? refundData.createdAt),
  } satisfies AnalyticsRefundRecord;
}

async function streamOrderAnalytics(
  orderId: string,
  orderData: Record<string, unknown>,
  eventType: AnalyticsEventType
) {
  const tenantId = orderData.tenantId;
  if (!tenantId) {
    logger.debug("Skipping order analytics streaming for missing tenant", {orderId});
    return;
  }

  const eventTimestamp = new Date().toISOString();
  const payload = buildOrderAnalyticsRecord(orderId, orderData, eventType, eventTimestamp);
  const insert: BigQueryInsert<AnalyticsOrderRecord> = {
    metadata: {
      source: "firestore.orders",
      schema_version: ANALYTICS_SCHEMA_VERSION,
    },
    payload,
  };

  await streamAnalyticsRow("orders", insert);
}

async function streamCustomerAnalytics(
  customerId: string,
  customerData: Record<string, unknown>,
  eventType: AnalyticsEventType
) {
  const tenantId = customerData.tenantId;
  if (!tenantId) {
    logger.debug("Skipping customer analytics streaming for missing tenant", {
      customerId,
    });
    return;
  }

  const eventTimestamp = new Date().toISOString();
  const payload = buildCustomerAnalyticsRecord(
    customerId,
    customerData,
    eventType,
    eventTimestamp
  );
  const insert: BigQueryInsert<AnalyticsCustomerRecord> = {
    metadata: {
      source: "firestore.customers",
      schema_version: ANALYTICS_SCHEMA_VERSION,
    },
    payload,
  };

  await streamAnalyticsRow("customers", insert);
}

async function streamRefundAnalytics(
  refundId: string,
  refundData: Record<string, unknown>,
  eventType: AnalyticsEventType
) {
  const tenantId = refundData.tenantId;
  if (!tenantId) {
    logger.debug("Skipping refund analytics streaming for missing tenant", {refundId});
    return;
  }

  const eventTimestamp = new Date().toISOString();
  const payload = buildRefundAnalyticsRecord(
    refundId,
    refundData,
    eventType,
    eventTimestamp
  );
  const insert: BigQueryInsert<AnalyticsRefundRecord> = {
    metadata: {
      source: "firestore.refunds",
      schema_version: ANALYTICS_SCHEMA_VERSION,
    },
    payload,
  };

  await streamAnalyticsRow("refunds", insert);
}

type CallableAuthContext = CallableRequest<unknown>["auth"];

function isAdminAuth(auth: CallableAuthContext | undefined): boolean {
  if (!auth?.token) {
    return false;
  }
  const token = auth.token as Record<string, unknown>;
  if (token.admin === true) {
    return true;
  }
  const role = token.role as string | undefined;
  if (role && role.toLowerCase() === "admin") {
    return true;
  }
  const roles = token.roles as unknown;
  if (Array.isArray(roles) && roles.map(String).some((r) => r.toLowerCase() === "admin")) {
    return true;
  }
  return false;
}

function resolveCustomerIdFromRequest(
  request: CallableRequest<Record<string, unknown>>
): { customerId: string; isAdmin: boolean; actorId: string } {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication is required for this operation.");
  }

  const isAdmin = isAdminAuth(auth);
  const token = (auth.token ?? {}) as Record<string, unknown>;
  const requestedCustomerId =
    (request.data?.customerId as string | undefined)?.trim() ||
    (token.customerId as string | undefined) ||
    auth.uid;

  if (!requestedCustomerId) {
    throw new HttpsError(
      "invalid-argument",
      "A customerId must be provided or linked to the authenticated user."
    );
  }

  if (!isAdmin) {
    const allowed = new Set<string>();
    if (auth.uid) {
      allowed.add(auth.uid);
    }
    if (typeof token.customerId === "string") {
      allowed.add(String(token.customerId));
    }
    if (!allowed.has(requestedCustomerId)) {
      throw new HttpsError("permission-denied", "You are not allowed to manage this customer data.");
    }
  }

  return {
    customerId: requestedCustomerId,
    isAdmin,
    actorId: auth.uid ?? "unknown",
  };
}

function normalizeDocument(
  data: admin.firestore.DocumentData | undefined
): Record<string, unknown> | null {
  if (!data) {
    return null;
  }
  const normalized = normalizeValue(data);
  return (normalized && typeof normalized === "object"
    ? (normalized as Record<string, unknown>)
    : null);
}

async function collectCustomerDataset(customerId: string) {
  const [customerDoc, ordersSnap, refundsSnap] = await Promise.all([
    db.collection("customers").doc(customerId).get(),
    db.collection("orders").where("customerId", "==", customerId).get(),
    db.collection("refunds").where("customerId", "==", customerId).get(),
  ]);

  const customer = normalizeDocument(customerDoc.data() ?? undefined);
  const orders = ordersSnap.docs.map((doc) => ({
    id: doc.id,
    data: normalizeDocument(doc.data() ?? undefined),
  }));
  const refunds = refundsSnap.docs.map((doc) => ({
    id: doc.id,
    data: normalizeDocument(doc.data() ?? undefined),
  }));

  return {
    customerId,
    generatedAt: new Date().toISOString(),
    customer,
    orders,
    refunds,
  };
}

async function anonymizeCollection(
  collection: string,
  customerId: string,
  updates: Record<string, unknown>
): Promise<number> {
  const snapshot = await db.collection(collection).where("customerId", "==", customerId).get();
  let processed = 0;
  for (const doc of snapshot.docs) {
    try {
      await doc.ref.update(updates);
      processed += 1;
    } catch (error) {
      logger.error("Failed to anonymize document", {
        collection,
        docId: doc.id,
        error,
      });
    }
  }
  return processed;
}

async function logPrivacyAction(
  action: string,
  actorId: string,
  customerId: string,
  payload: Record<string, unknown>
) {
  try {
    await db.collection(PRIVACY_LOG_COLLECTION).add({
      action,
      actorId,
      customerId,
      payload,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.error("Failed to persist privacy action log", {
      action,
      actorId,
      customerId,
      error,
    });
  }
}

async function performCustomerDeletion(customerId: string) {
  const anonymizedAt = new Date().toISOString();
  const baseAnonymisationUpdates: Record<string, unknown> = {
    customerId: null,
    customer: null,
    customerName: "Deleted Customer",
    customerEmail: null,
    customerPhone: null,
    customerNotes: null,
    customerAddress: null,
    privacyDeletedAt: anonymizedAt,
  };

  const [ordersUpdated, refundsUpdated] = await Promise.all([
    anonymizeCollection("orders", customerId, baseAnonymisationUpdates),
    anonymizeCollection("refunds", customerId, {
      ...baseAnonymisationUpdates,
      refundRecipient: null,
      recipientEmail: null,
    }),
  ]);

  const customerRef = db.collection("customers").doc(customerId);
  const customerDoc = await customerRef.get();
  let customerDeleted = false;
  if (customerDoc.exists) {
    await customerRef.delete();
    customerDeleted = true;
  }

  return {
    customerDeleted,
    ordersUpdated,
    refundsUpdated,
    anonymizedAt,
  };
}

async function backfillCollectionToBigQuery(kind: "orders" | "customers" | "refunds") {
  if (!isBigQueryStreamingEnabled()) {
    logger.info("BigQuery streaming disabled. Skipping backfill.", {kind});
    return 0;
  }

  const snapshot = await db.collection(kind).get();
  let processed = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data() as Record<string, unknown>;
    try {
      if (kind === "orders") {
        await streamOrderAnalytics(doc.id, data, "UPDATE");
      } else if (kind === "customers") {
        await streamCustomerAnalytics(doc.id, data, "UPDATE");
      } else {
        await streamRefundAnalytics(doc.id, data, "UPDATE");
      }
      processed += 1;
    } catch (error) {
      logger.error("Failed to backfill document to BigQuery", {
        kind,
        docId: doc.id,
        error,
      });
    }
  }

  return processed;
}

async function deleteExpiredDocumentsForField(
  rule: TtlRule,
  field: string,
  cutoff: admin.firestore.Timestamp,
): Promise<number> {
  let totalDeleted = 0;
  while (true) {
    let query: FirebaseFirestore.Query = db.collection(rule.collection);
    if (rule.filters) {
      for (const filter of rule.filters) {
        query = query.where(filter.field, filter.op, filter.value);
      }
    }
    query = query
      .where(field, "<", cutoff)
      .orderBy(field, "asc")
      .limit(rule.batchSize ?? DEFAULT_TTL_BATCH_SIZE);

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    totalDeleted += snapshot.size;

    if (snapshot.size < (rule.batchSize ?? DEFAULT_TTL_BATCH_SIZE)) {
      break;
    }
  }
  return totalDeleted;
}

async function cleanupExpiredDocuments(rule: TtlRule): Promise<number> {
  const cutoffDate = new Date(Date.now() - rule.ttlHours * 60 * 60 * 1000);
  const cutoff = admin.firestore.Timestamp.fromDate(cutoffDate);
  let deleted = await deleteExpiredDocumentsForField(rule, rule.field, cutoff);
  if (rule.fallbackField) {
    deleted += await deleteExpiredDocumentsForField(
      rule,
      rule.fallbackField,
      cutoff,
    );
  }
  return deleted;
}

export const streamOrdersToBigQuery = onDocumentWritten("orders/{orderId}",
  async (event) => {
    if (!isBigQueryStreamingEnabled()) {
      return;
    }

    const change = event.data;
    if (!change) {
      return;
    }

    const before = change.before?.data() as Record<string, unknown> | undefined;
    const after = change.after?.data() as Record<string, unknown> | undefined;
    const eventType = buildAnalyticsEventType(before, after);
    const source = eventType === "DELETE" ? before : after;

    if (!source) {
      return;
    }

    try {
      await streamOrderAnalytics(event.params.orderId, source, eventType);
    } catch (error) {
      logger.error("Order BigQuery streaming failed", {
        orderId: event.params.orderId,
        eventType,
        error,
      });
      throw error;
    }
  });

export const streamCustomersToBigQuery = onDocumentWritten("customers/{customerId}",
  async (event) => {
    if (!isBigQueryStreamingEnabled()) {
      return;
    }

    const change = event.data;
    if (!change) {
      return;
    }

    const before = change.before?.data() as Record<string, unknown> | undefined;
    const after = change.after?.data() as Record<string, unknown> | undefined;
    const eventType = buildAnalyticsEventType(before, after);
    const source = eventType === "DELETE" ? before : after;

    if (!source) {
      return;
    }

    try {
      await streamCustomerAnalytics(event.params.customerId, source, eventType);
    } catch (error) {
      logger.error("Customer BigQuery streaming failed", {
        customerId: event.params.customerId,
        eventType,
        error,
      });
      throw error;
    }
  });

export const streamRefundsToBigQuery = onDocumentWritten("refunds/{refundId}",
  async (event) => {
    if (!isBigQueryStreamingEnabled()) {
      return;
    }

    const change = event.data;
    if (!change) {
      return;
    }

    const before = change.before?.data() as Record<string, unknown> | undefined;
    const after = change.after?.data() as Record<string, unknown> | undefined;
    const eventType = buildAnalyticsEventType(before, after);
    const source = eventType === "DELETE" ? before : after;

    if (!source) {
      return;
    }

    try {
      await streamRefundAnalytics(event.params.refundId, source, eventType);
    } catch (error) {
      logger.error("Refund BigQuery streaming failed", {
        refundId: event.params.refundId,
        eventType,
        error,
      });
      throw error;
    }
  });

export const cleanupOperationalCollections = onSchedule(
  {
    schedule: "30 2 * * *",
    timeZone: "Asia/Bangkok",
  },
  async () => {
    const results: Array<{collection: string; deleted: number}> = [];
    for (const rule of TTL_RULES) {
      try {
        const deleted = await cleanupExpiredDocuments(rule);
        if (deleted > 0) {
          results.push({collection: rule.collection, deleted});
        }
      } catch (error) {
        logger.error("Failed to cleanup collection", {
          collection: rule.collection,
          error,
        });
      }
    }
    if (results.length > 0) {
      logger.info("TTL cleanup results", {results});
    } else {
      logger.debug("TTL cleanup completed with no deletions");
    }
  },
);

type AggregationMetrics = {
  orderCount: number;
  grossSales: number;
  totalItems: number;
  totalDiscounts: number;
  totalTax: number;
};

const ALL_TENANTS_KEY = "ALL";

function createEmptyMetrics(): AggregationMetrics {
  return {
    orderCount: 0,
    grossSales: 0,
    totalItems: 0,
    totalDiscounts: 0,
    totalTax: 0,
  };
}

function toLocalDate(date: Date): Date {
  return new Date(date.getTime() + ASIA_BANGKOK_OFFSET_MINUTES * 60000);
}

function toUtcFromLocal(localDate: Date): Date {
  return new Date(localDate.getTime() - ASIA_BANGKOK_OFFSET_MINUTES * 60000);
}

function previousHourRange(now: Date = new Date()): {
  startUtc: Date;
  endUtc: Date;
  startLocal: Date;
  endLocal: Date;
} {
  const localNow = toLocalDate(now);
  localNow.setMinutes(0, 0, 0);
  const endLocal = new Date(localNow.getTime());
  const startLocal = new Date(localNow.getTime());
  startLocal.setHours(startLocal.getHours() - 1);
  return {
    startUtc: toUtcFromLocal(startLocal),
    endUtc: toUtcFromLocal(endLocal),
    startLocal,
    endLocal,
  };
}

function previousDayRange(now: Date = new Date()): {
  startUtc: Date;
  endUtc: Date;
  startLocal: Date;
  endLocal: Date;
} {
  const localNow = toLocalDate(now);
  localNow.setHours(0, 0, 0, 0);
  const endLocal = new Date(localNow.getTime());
  const startLocal = new Date(localNow.getTime());
  startLocal.setDate(startLocal.getDate() - 1);
  return {
    startUtc: toUtcFromLocal(startLocal),
    endUtc: toUtcFromLocal(endLocal),
    startLocal,
    endLocal,
  };
}

function formatLocalDateKey(date: Date): string {
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, "0");
  const day = date.getDate().toString().padStart(2, "0");
  return `${year}${month}${day}`;
}

function formatLocalHourKey(date: Date): string {
  const base = formatLocalDateKey(date);
  const hour = date.getHours().toString().padStart(2, "0");
  return `${base}${hour}`;
}

function roundCurrency(value: number): number {
  return Math.round(value * 100) / 100;
}

function accumulateMetrics(
  metrics: AggregationMetrics,
  orderData: Record<string, unknown>
) {
  const total = Number(orderData.total ?? orderData.grandTotal ?? 0);
  const discount = Number(
    orderData.discount ?? orderData.discountAmount ?? orderData.totalDiscount ?? 0
  );
  const tax = Number(orderData.tax ?? orderData.taxAmount ?? 0);
  let quantity = 0;
  const items = orderData.items;
  if (Array.isArray(items)) {
    for (const raw of items) {
      if (raw && typeof raw === "object") {
        const entry = raw as Record<string, unknown>;
        quantity += Number(entry.quantity ?? 0);
      }
    }
  }

  metrics.orderCount += 1;
  metrics.grossSales += total;
  metrics.totalItems += quantity;
  metrics.totalDiscounts += discount;
  metrics.totalTax += tax;
}

// --- Function to notify when order is ready to serve ---
export const onOrderStatusUpdate = onDocumentUpdated("orders/{orderId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;

    if (before.status === "preparing" && after.status === "serving") {
      const tenantId = after.tenantId as string | undefined;
      if (!tenantId) {
        logger.warn("Order missing tenantId, skipping notification", {
          orderId: event.params.orderId,
        });
        return;
      }
      await createNotification(
        tenantId,
        "ORDER_READY",
        `Order Ready: ${after.orderIdentifier}`,
        "An order is now ready to be served to the customer.",
        "info",
        {orderId: event.params.orderId}
      );
    }
  });

// --- Function to notify on low stock ---
export const onIngredientUpdate = onDocumentUpdated("ingredients/{ingredientId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;

    const threshold = after.lowStockThreshold as number;
    // Notify only when the stock crosses the threshold
    if (after.stockQuantity <= threshold && before.stockQuantity > threshold) {
      const tenantId = after.tenantId as string | undefined;
      if (!tenantId) {
        logger.warn("Ingredient missing tenantId, skipping low stock alert", {
          ingredientId: event.params.ingredientId,
        });
        return;
      }
      await createNotification(
        tenantId,
        "LOW_STOCK",
        `Low Stock Alert: ${after.name}`,
        `Stock for ${after.name} is low (${after.stockQuantity} ${after.unit} remaining).`,
        "warn",
        {ingredientId: event.params.ingredientId}
      );
    }
  });

// --- Function to notify on new refund ---
export const onRefundCreate = onDocumentCreated("refunds/{refundId}",
  async (event) => {
    const refundData = event.data?.data();
    if (!refundData) return;

    const amount = (refundData.totalRefundAmount as number).toFixed(2);
    
    const tenantId = refundData.tenantId as string | undefined;
    if (!tenantId) {
      logger.warn("Refund missing tenantId, skipping notification", {
        refundId: event.params.refundId,
      });
      return;
    }

    await createNotification(
      tenantId,
      "REFUND_PROCESSED",
      `Refund Processed: ฿${amount}`,
      `A refund for order ${refundData.originalOrderId} has been processed.`,
      "critical",
      {refundId: event.params.refundId, orderId: refundData.originalOrderId}
    );
  });

export const processWasteRecord = onDocumentCreated("waste_records/{recordId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.log("No data for waste record, skipping.");
      return;
    }
    const wasteData = snapshot.data();
    const ingredientId = wasteData.ingredientId as string;
    const quantityWasted = wasteData.quantity as number;
    if (!ingredientId || !quantityWasted || quantityWasted <= 0) {
      logger.error("Invalid waste data, skipping stock deduction.", wasteData);
      return;
    }
    const ingredientRef = db.collection("ingredients").doc(ingredientId);
    try {
      await ingredientRef.update({
        stockQuantity: admin.firestore.FieldValue.increment(-quantityWasted),
      });
      logger.log(`Deducted ${quantityWasted} from ingredient ${ingredientId} due to waste record.`);
    } catch (error) {
      logger.error(`Failed to deduct stock for ingredient ${ingredientId}.`, error);
    }
  });

export const onTenantDocumentWrite = onDocumentWrittenWithAuthContext(
  "{collectionId}/{docId}",
  async (event) => {
    const change = event.data;
    if (!change) {
      return;
    }

    const {collectionId, docId} = event.params;
    if (collectionId === "auditLogs") {
      return;
    }

    const beforeData = change.before?.data() as Record<string, unknown> | undefined;
    const afterData = change.after?.data() as Record<string, unknown> | undefined;

    if (!beforeData && !afterData) {
      return;
    }

    let action: "create" | "update" | "delete" = "update";
    if (!beforeData && afterData) {
      action = "create";
    } else if (beforeData && !afterData) {
      action = "delete";
    }

    const tenantId =
      (afterData?.tenantId as string | undefined) ??
      (beforeData?.tenantId as string | undefined) ??
      (collectionId === "featureFlags" ? (docId as string) : undefined);

    if (!tenantId) {
      logger.debug("Skipping audit log for document without tenant", {
        collectionId,
        docId,
      });
      return;
    }

    const storeId =
      (afterData?.storeId as string | undefined) ??
      (beforeData?.storeId as string | undefined) ??
      null;

    const metadata = extractChangeSummary(beforeData ?? null, afterData ?? null);

    const payload: Record<string, unknown> = {
      tenantId,
      type: action,
      description: `${action.toUpperCase()} ${collectionId}/${docId}`,
      actorId: event.authId ?? "system",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      collection: collectionId,
      documentId: docId,
    };

    if (storeId) {
      payload.storeId = storeId;
    }

    if (Object.keys(metadata).length > 0) {
      payload.metadata = metadata;
    }

    await db.collection("auditLogs").add(payload);
  }
);

export const returnStockOnRefund = onDocumentCreated("refunds/{refundId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.log("No data associated with the event, skipping.");
      return;
    }
    const refundData = snapshot.data();
    type RefundedItem = {
      name: string;
      quantity: number;
      price: number;
      menuItemId: string;
    };
    const refundedItems: RefundedItem[] = refundData.refundedItems;
    if (!refundedItems || refundedItems.length === 0) {
      logger.log("No items to refund in this document.");
      return;
    }
    await db.runTransaction(async (transaction) => {
      const menuItemRefs = refundedItems.map((item) =>
        db.collection("menu_items").doc(item.menuItemId)
      );
      const menuItemDocs = await transaction.getAll(...menuItemRefs);

      for (const menuItemDoc of menuItemDocs) {
        if (!menuItemDoc.exists) continue;
        const menuItemData = menuItemDoc.data();
        const refundedItem = refundedItems.find(
          (item) => item.menuItemId === menuItemDoc.id
        );
        if (!refundedItem) continue;
        const recipe: {
          ingredientId: string;
          quantity: number;
        }[] = menuItemData?.recipe ?? [];
        if (recipe.length > 0) {
          for (const recipeIngredient of recipe) {
            const ingredientRef = db
              .collection("ingredients")
              .doc(recipeIngredient.ingredientId);
            const quantityToReturn =
              recipeIngredient.quantity * refundedItem.quantity;
            transaction.update(ingredientRef, {
              stockQuantity: admin.firestore.FieldValue.increment(
                quantityToReturn,
              ),
            });
          }
        } else {
          const ingredientRef = db.collection("ingredients")
            .doc(menuItemDoc.id);
          transaction.update(ingredientRef, {
            stockQuantity: admin.firestore.FieldValue.increment(
              refundedItem.quantity,
            ),
          });
        }
      }
    });
    logger.log(`Stock returned for refund ID: ${snapshot.id}`);
  });

export const processPunchCards = onDocumentUpdated("orders/{orderId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after || before.status === "completed" || after.status !== "completed") {
      return;
    }

    const customerId = after.customerId as string;
    type OrderItem = {id: string; category: string; quantity: number;};
    const items: OrderItem[] = after.items;

    if (!customerId || !items || items.length === 0) {
      return;
    }

    type PunchCardCampaign = {
      id: string;
      applicableCategories: string[];
    };

    try {
      const campaignsSnapshot = await db.collection("punch_card_campaigns")
        .where("isActive", "==", true).get();
      if (campaignsSnapshot.empty) {
        return;
      }
      
      const campaigns: PunchCardCampaign[] = campaignsSnapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          applicableCategories: data.applicableCategories || [],
        } as PunchCardCampaign;
      });

      const customerRef = db.collection("customers").doc(customerId);
      const customerUpdateData: {[key: string]: any} = {};

      for (const item of items) {
        const applicableCampaigns = campaigns.filter(
          (c) => c.applicableCategories.includes(item.category)
        );

        for (const campaign of applicableCampaigns) {
          const fieldToUpdate = `punchCards.${campaign.id}`;
          customerUpdateData[fieldToUpdate] = admin.firestore.FieldValue.increment(item.quantity);
        }
      }

      if (Object.keys(customerUpdateData).length > 0) {
        await customerRef.update(customerUpdateData);
        logger.log(`Updated punch cards for customer ${customerId}.`, customerUpdateData);
      }
    } catch (error) {
      logger.error(`Error processing punch cards for order ${event.params.orderId}:`, error);
    }
  });

// --- THIS IS THE UPDATED FUNCTION ---
export const processCompletedOrder = onDocumentUpdated("orders/{orderId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const orderId = event.params.orderId;

    if (!before || !after || before.status === "completed" || after.status !== "completed") {
      return;
    }

    const orderRef = db.collection("orders").doc(orderId);
    
    // --- NEW: Block to calculate Cost of Goods Sold (COGS) ---
    let totalCostOfGoodsSold = 0;
    const itemsForCosting: {id: string; quantity: number;}[] = after.items;

    if (itemsForCosting && itemsForCosting.length > 0) {
      const productIds = itemsForCosting.map((item) => item.id);
      const productsSnapshot = await db.collection("menu_items")
        .where(admin.firestore.FieldPath.documentId(), "in", productIds)
        .get();
      
      const productCosts: {[key: string]: number} = {};
      productsSnapshot.forEach((doc) => {
        productCosts[doc.id] = doc.data().costPrice || 0;
      });

      for (const item of itemsForCosting) {
        const cost = productCosts[item.id] || 0;
        totalCostOfGoodsSold += cost * item.quantity;
      }
    }
    const grossProfit = after.total - totalCostOfGoodsSold;
    logger.log(`Order ${orderId}: Revenue= ${after.total}, COGS= ${totalCostOfGoodsSold}, Profit= ${grossProfit}`);
    // --- End of NEW Block ---


    const promotionCode = after.promotionCode as string;
    if (promotionCode) {
      const promoQuery = await db.collection("promotions").where("code", "==", promotionCode).limit(1).get();
      if (!promoQuery.empty) {
        const promoDoc = promoQuery.docs[0];
        try {
          await promoDoc.ref.update({
            timesUsed: admin.firestore.FieldValue.increment(1),
          });
          logger.log(`Incremented usage for promotion code: ${promotionCode}`);
        } catch (error) {
          logger.error(`Failed to increment usage for promotion code: ${promotionCode}`, error);
        }
      }
    }

    const customerId = after.customerId;
    const orderTotal = after.total as number;
    const items: {id: string; name: string; quantity: number; category?: string;}[] = after.items;

    if (items && items.length > 0) {
      try {
        await db.runTransaction(async (transaction) => {
          const menuItemRefs = items.map((item) =>
            db.collection("menu_items").doc(item.id)
          );
          const menuItemDocs = await transaction.getAll(...menuItemRefs);
          menuItemDocs.forEach((menuItemDoc, index) => {
            if (menuItemDoc.exists) {
              const item = items[index];
              const recipe = menuItemDoc.data()?.recipe ?? [];
              if (recipe.length > 0) {
                for (const ing of recipe) {
                  const ingRef = db.collection("ingredients").doc(ing.ingredientId);
                  const qtyToDeduct = ing.quantity * item.quantity;
                  transaction.update(ingRef, {
                    stockQuantity: admin.firestore.FieldValue.increment(-qtyToDeduct),
                  });
                }
              } else {
                const ingRef = db.collection("ingredients").doc(item.id);
                transaction.update(ingRef, {
                  stockQuantity: admin.firestore.FieldValue.increment(-item.quantity),
                });
              }
            }
          });
        });
        logger.log(`Stock deducted successfully for order ${orderId}.`);
      } catch (error) {
        logger.error(`Error deducting stock for order ${orderId}:`, error);
      }
    }
    
    if (customerId) {
      const customerRef = db.collection("customers").doc(customerId);

      if (after.discountType === "points" && after.pointsRedeemed > 0) {
        const pointsToDeduct = after.pointsRedeemed as number;
        try {
          await customerRef.update({
            loyaltyPoints: admin.firestore.FieldValue.increment(-pointsToDeduct),
          });
          logger.log(`Deducted ${pointsToDeduct} points from customer ${customerId}.`);
        } catch (error) {
          logger.error(`Failed to deduct points from customer ${customerId}.`, error);
        }
      } else {
        const customerDoc = await customerRef.get();
        if (customerDoc.exists) {
          const customerData = customerDoc.data()!;
          const currentTier = (customerData.tier || "SILVER").toUpperCase();
          const newLifetimeSpend = (customerData.lifetimeSpend || 0) + orderTotal;
          let newTier = "SILVER";
          if (newLifetimeSpend >= TIER_THRESHOLDS.PLATINUM) {
            newTier = "PLATINUM";
          } else if (newLifetimeSpend >= TIER_THRESHOLDS.GOLD) {
            newTier = "GOLD";
          }
          const multiplier = TIER_POINT_MULTIPLIERS[currentTier as keyof typeof TIER_POINT_MULTIPLIERS] || 1.0;
          const pointsPerBaht = 1 / 10;
          const pointsToAward = Math.floor(orderTotal * pointsPerBaht * multiplier);
          try {
            const updates: {[key: string]: any} = {
              lifetimeSpend: admin.firestore.FieldValue.increment(orderTotal),
            };
            if (pointsToAward > 0) {
              updates.loyaltyPoints = admin.firestore.FieldValue.increment(pointsToAward);
            }
            if (newTier.toUpperCase() !== currentTier.toUpperCase()) {
              updates.tier = newTier;
            }
            await customerRef.update(updates);
            logger.log(`Processed order for customer ${customerId}. Awarded: ${pointsToAward}, New Spend: ${newLifetimeSpend}, Tier: ${newTier}`);
            // I'm removing the debug_tier_update field as it's not necessary for the final version
          } catch (error) {
            logger.error(`Failed to update points/tier for customer ${customerId}.`, error);
          }
        }
      }
    }

    // --- NEW: Add the calculated profit to the order document ---
    try {
      await orderRef.update({
        "totalCostOfGoodsSold": totalCostOfGoodsSold,
        "grossProfit": grossProfit,
      });
      logger.log(`Successfully updated order ${orderId} with profit data.`);
    } catch (error) {
      logger.error(`Failed to update order ${orderId} with profit data.`, error);
    }
  });

export const updateStockOnPoReceived = onDocumentUpdated("purchase_orders/{poId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) {
      logger.log("No data found on PO update, exiting.");
      return;
    }

    if (after.status !== "received" || before.status === "received") {
      return;
    }

    logger.log(`PO ${event.params.poId} marked as received. Updating stock...`);

    type PoItem = {
      productId: string;
      productName: string;
      quantity: number;
      cost: number;
    };
    const items: PoItem[] = after.items;

    if (!items || items.length === 0) {
      logger.log("No items in PO.");
      return;
    }

    const batch = db.batch();

    items.forEach((item) => {
      const ingredientRef = db.collection("ingredients").doc(item.productId);
      batch.update(ingredientRef, {
        stockQuantity: admin.firestore.FieldValue.increment(item.quantity),
      });
    });

    try {
      await batch.commit();
      logger.log(`Stock updated successfully for PO ${event.params.poId}.`);
    } catch (error) {
      logger.error(`Error updating stock for PO ${event.params.poId}:`, error);
    }
  });

async function sendEmailViaSendGrid(body: Record<string, unknown>) {
  if (!SENDGRID_API_KEY) {
    throw new HttpsError(
      "failed-precondition",
      "SendGrid API key is not configured."
    );
  }

  const payload = JSON.stringify(body);

  await new Promise<void>((resolve, reject) => {
    const request = https.request(
      {
        hostname: "api.sendgrid.com",
        path: "/v3/mail/send",
        method: "POST",
        headers: {
          "Authorization": `Bearer ${SENDGRID_API_KEY}`,
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload).toString(),
        },
      },
      (response) => {
        const {statusCode} = response;
        if (statusCode && statusCode >= 200 && statusCode < 300) {
          response.on("data", () => undefined);
          response.on("end", resolve);
          return;
        }

        let data = "";
        response.on("data", (chunk) => {
          data += chunk;
        });
        response.on("end", () => {
          reject(
            new HttpsError(
              "unknown",
              `SendGrid request failed with status ${statusCode}: ${data}`
            )
          );
        });
      }
    );

    request.on("error", (error) => {
      reject(new HttpsError("unknown", `SendGrid request error: ${error}`));
    });

    request.write(payload);
    request.end();
  });
}

async function aggregateOrdersForRange(options: {
  range: {
    startUtc: Date;
    endUtc: Date;
    startLocal: Date;
    endLocal: Date;
  };
  windowLabel: string;
  collectionName: string;
  docIdBuilder: (tenantId: string) => string;
}) {
  const {range, windowLabel, collectionName, docIdBuilder} = options;
  try {
    const querySnapshot = await db
      .collection("orders")
      .where("status", "==", "completed")
      .where(
        "completedAt",
        ">=",
        admin.firestore.Timestamp.fromDate(range.startUtc)
      )
      .where(
        "completedAt",
        "<",
        admin.firestore.Timestamp.fromDate(range.endUtc)
      )
      .get();

    if (querySnapshot.empty) {
      logger.log(`No completed orders found for ${windowLabel} aggregation window`, {
        window: windowLabel,
        start: range.startUtc.toISOString(),
        end: range.endUtc.toISOString(),
      });
      return;
    }

    const metricsByTenant = new Map<string, AggregationMetrics>();
    const ensureMetrics = (tenantId: string) => {
      if (!metricsByTenant.has(tenantId)) {
        metricsByTenant.set(tenantId, createEmptyMetrics());
      }
      return metricsByTenant.get(tenantId)!;
    };

    querySnapshot.forEach((doc) => {
      const data = doc.data() as Record<string, unknown>;
      const tenantId = (data.tenantId as string | undefined) ?? "default";
      accumulateMetrics(ensureMetrics(tenantId), data);
      if (tenantId !== ALL_TENANTS_KEY) {
        accumulateMetrics(ensureMetrics(ALL_TENANTS_KEY), data);
      }
    });

    await Promise.all(
      Array.from(metricsByTenant.entries()).map(async ([tenantId, metrics]) => {
        const docRef = db.collection(collectionName).doc(docIdBuilder(tenantId));
        await docRef.set(
          {
            tenantId,
            window: windowLabel,
            periodStart: admin.firestore.Timestamp.fromDate(range.startUtc),
            periodEnd: admin.firestore.Timestamp.fromDate(range.endUtc),
            localPeriodStart: range.startLocal.toISOString(),
            localPeriodEnd: range.endLocal.toISOString(),
            timezone: "Asia/Bangkok",
            orderCount: metrics.orderCount,
            grossSales: roundCurrency(metrics.grossSales),
            totalItems: metrics.totalItems,
            totalDiscounts: roundCurrency(metrics.totalDiscounts),
            totalTax: roundCurrency(metrics.totalTax),
            averageOrderValue:
              metrics.orderCount > 0 ?
                roundCurrency(metrics.grossSales / metrics.orderCount) :
                0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true}
        );
      })
    );

    logger.log(`Aggregated ${metricsByTenant.size} tenant buckets for ${windowLabel} window`, {
      window: windowLabel,
      start: range.startUtc.toISOString(),
      end: range.endUtc.toISOString(),
    });
  } catch (error) {
    logger.error(`Failed to aggregate ${windowLabel} metrics`, error);
    throw error;
  }
}

export const aggregateHourlyOrders = onSchedule(
  {
    schedule: "5 * * * *",
    timeZone: "Asia/Bangkok",
  },
  async () => {
    const range = previousHourRange();
    await aggregateOrdersForRange({
      range,
      windowLabel: "hourly",
      collectionName: AGGREGATE_COLLECTION_HOURLY,
      docIdBuilder: (tenantId) => `${tenantId}_${formatLocalHourKey(range.startLocal)}`,
    });
  }
);

export const aggregateDailyOrders = onSchedule(
  {
    schedule: "15 0 * * *",
    timeZone: "Asia/Bangkok",
  },
  async () => {
    const range = previousDayRange();
    await aggregateOrdersForRange({
      range,
      windowLabel: "daily",
      collectionName: AGGREGATE_COLLECTION_DAILY,
      docIdBuilder: (tenantId) => `${tenantId}_${formatLocalDateKey(range.startLocal)}`,
    });
  }
);

async function exportCollectionToBucket(options: {
  collectionName: string;
  destinationFolder: string;
  executedAt: Date;
}) {
  const {collectionName, destinationFolder, executedAt} = options;
  const bucketName = BACKUP_BUCKET;
  if (!bucketName) {
    throw new Error("BACKUP_BUCKET is not configured.");
  }

  const snapshot = await db.collection(collectionName).get();
  const documents = snapshot.docs.map((doc) => ({
    id: doc.id,
    data: normalizeValue(doc.data()) as Record<string, unknown>,
  }));

  const payload = JSON.stringify(
    {
      collection: collectionName,
      exportedAt: executedAt.toISOString(),
      documentCount: documents.length,
      documents,
    },
    null,
    2
  );

  const bucket = storage.bucket(bucketName);
  const file = bucket.file(`${destinationFolder}/${collectionName}.json`);
  await file.save(payload, {
    resumable: false,
    contentType: "application/json",
  });
}

export const exportDataToGcs = onSchedule(
  {
    schedule: "0 3 * * *",
    timeZone: "Asia/Bangkok",
    timeoutSeconds: 540,
  },
  async () => {
    if (!BACKUP_BUCKET) {
      logger.warn(
        "Skipping exportDataToGcs because BACKUP_BUCKET environment variable is not configured."
      );
      return;
    }

    const executedAt = new Date();
    const localDate = toLocalDate(executedAt);
    const folder =
      `backups/${formatLocalDateKey(localDate)}/` +
      executedAt.toISOString().replace(/[:.]/g, "-");

    const collectionsToExport = [
      "orders",
      "refunds",
      "menu_items",
      "featureFlags",
      "stores",
      "customers",
    ];

    const errors: Error[] = [];
    for (const collectionName of collectionsToExport) {
      try {
        await exportCollectionToBucket({
          collectionName,
          destinationFolder: folder,
          executedAt,
        });
        logger.log(
          `Exported ${collectionName} snapshot to gs://${BACKUP_BUCKET}/${folder}/${collectionName}.json`
        );
      } catch (error) {
        logger.error(`Failed to export collection ${collectionName}`, error);
        errors.push(error as Error);
      }
    }

    if (errors.length > 0) {
      throw errors[0];
    }
  }
);

export const sendReceiptEmail = onCall(async (request) => {
  const data = request.data as {
    email?: string;
    orderId?: string;
    orderIdentifier?: string;
    total?: number;
    receiptUrl?: string;
    store?: { [key: string]: unknown };
    customer?: { [key: string]: unknown };
    pdfBase64?: string;
  };

  const email = data.email;
  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Recipient email is required.");
  }

  const orderIdentifier =
    (data.orderIdentifier as string | undefined) ?? data.orderId ?? "Order";
  const storeName = (data.store?.["name"] as string | undefined) ?? "ร้านค้า";
  const customerName =
    (data.customer?.["customerName"] as string | undefined) ?? "ลูกค้า";
  const total = Number(data.total ?? 0).toFixed(2);
  const receiptUrl = data.receiptUrl ?? "";

  const html = `
    <p>เรียนคุณ ${customerName},</p>
    <p>ขอบคุณที่ใช้บริการ ${storeName}</p>
    <p>ข้อมูลคำสั่งซื้อ: <strong>${orderIdentifier}</strong></p>
    <p>ยอดชำระรวม: <strong>${total} บาท</strong></p>
    <p>คุณสามารถดาวน์โหลดใบเสร็จ/ใบกำกับภาษีได้จากลิงก์ด้านล่าง:</p>
    <p><a href="${receiptUrl}" target="_blank" rel="noopener">เปิดใบเสร็จ</a></p>
    <p>ขอขอบคุณและหวังว่าจะได้ให้บริการอีกครั้ง</p>
  `;

  const body: Record<string, unknown> = {
    personalizations: [
      {
        to: [{email}],
      },
    ],
    from: {
      email: SENDGRID_FROM_EMAIL,
      name: storeName,
    },
    subject: `Receipt for ${orderIdentifier}`,
    content: [
      {
        type: "text/html",
        value: html,
      },
    ],
  };

  if (data.pdfBase64) {
    body.attachments = [
      {
        content: data.pdfBase64,
        filename: `${orderIdentifier}.pdf`,
        type: "application/pdf",
        disposition: "attachment",
      },
    ];
  }

  await sendEmailViaSendGrid(body);

  logger.log(`Receipt email sent to ${email} for order ${orderIdentifier}.`);
  return {success: true};
});

export const exportMyData = onCall(async (request) => {
  const {customerId, isAdmin, actorId} = resolveCustomerIdFromRequest(
    request as CallableRequest<Record<string, unknown>>
  );

  const dataset = await collectCustomerDataset(customerId);
  await logPrivacyAction("EXPORT", actorId, customerId, {
    isAdmin,
    orderCount: dataset.orders.length,
    refundCount: dataset.refunds.length,
    hasProfile: Boolean(dataset.customer),
  });

  return dataset;
});

export const deleteMyData = onCall(async (request) => {
  const {customerId, isAdmin, actorId} = resolveCustomerIdFromRequest(
    request as CallableRequest<Record<string, unknown>>
  );

  const result = await performCustomerDeletion(customerId);
  await logPrivacyAction("DELETE", actorId, customerId, {
    isAdmin,
    ...result,
  });

  return {
    success: true,
    customerId,
    ...result,
  };
});

export const adminToolkit = onCall(async (request) => {
  const auth = request.auth;
  if (!auth || !isAdminAuth(auth)) {
    throw new HttpsError(
      "permission-denied",
      "Admin privileges are required to use the admin toolkit."
    );
  }

  const action = (request.data?.action as string | undefined)?.trim();
  if (!action) {
    throw new HttpsError("invalid-argument", "An admin action must be specified.");
  }

  switch (action) {
    case "exportCustomerData": {
      const customerId = (request.data?.customerId as string | undefined)?.trim();
      if (!customerId) {
        throw new HttpsError(
          "invalid-argument",
          "customerId is required for exportCustomerData action."
        );
      }
      const dataset = await collectCustomerDataset(customerId);
      await logPrivacyAction("ADMIN_EXPORT", auth.uid ?? "unknown", customerId, {
        orderCount: dataset.orders.length,
        refundCount: dataset.refunds.length,
      });
      return dataset;
    }
    case "deleteCustomerData": {
      const customerId = (request.data?.customerId as string | undefined)?.trim();
      if (!customerId) {
        throw new HttpsError(
          "invalid-argument",
          "customerId is required for deleteCustomerData action."
        );
      }
      const result = await performCustomerDeletion(customerId);
      await logPrivacyAction("ADMIN_DELETE", auth.uid ?? "unknown", customerId, result);
      return {
        success: true,
        customerId,
        ...result,
      };
    }
    case "backfillAnalytics": {
      const collection =
        ((request.data?.collection as string | undefined)?.trim() as
          | "orders"
          | "customers"
          | "refunds"
          | undefined) ?? "orders";
      const processed = await backfillCollectionToBigQuery(collection);
      return {
        success: true,
        collection,
        processed,
      };
    }
    default:
      throw new HttpsError(
        "invalid-argument",
        `Unsupported admin toolkit action: ${action}`
      );
  }
});
