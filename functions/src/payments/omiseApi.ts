import {
  createOmiseClient,
  type OmiseChargeRequest,
  type OmiseClient,
  type OmiseClientConfig,
  type OmiseRefundRequest,
  type OmiseRequestOptions,
  type OmiseResponse,
  type OmiseSourceRequest,
} from "./omiseClient.js";

export interface OmiseCard3dsChargeParams extends BaseChargeParams {
  cardToken: string;
  returnUri: string;
}

export interface OmisePromptPayChargeParams extends SourceChargeParams {
  sourceMetadata?: Record<string, unknown>;
  sourceData?: Record<string, unknown>;
}

export interface OmiseMobileBankingChargeParams extends SourceChargeParams {
  bank?: string;
  sourceType?: string;
  sourceMetadata?: Record<string, unknown>;
  sourceData?: Record<string, unknown>;
}

export interface OmiseRefundChargeParams {
  amount?: number;
  metadata?: Record<string, unknown>;
}

export interface OmiseChargeResult {
  charge: OmiseResponse;
  source?: OmiseResponse;
}

export interface OmiseSourceChargeOptions {
  source?: OmiseRequestOptions;
  charge?: OmiseRequestOptions;
}

export interface OmiseChargesApi {
  createCardCharge3ds(
    params: OmiseCard3dsChargeParams,
    options?: OmiseRequestOptions
  ): Promise<OmiseChargeResult>;
  createPromptPayCharge(
    params: OmisePromptPayChargeParams,
    options?: OmiseSourceChargeOptions
  ): Promise<OmiseChargeResult>;
  createMobileBankingCharge(
    params: OmiseMobileBankingChargeParams,
    options?: OmiseSourceChargeOptions
  ): Promise<OmiseChargeResult>;
  captureCharge(
    chargeId: string,
    options?: OmiseRequestOptions
  ): Promise<OmiseResponse>;
  refundCharge(
    chargeId: string,
    payload?: OmiseRefundChargeParams,
    options?: OmiseRequestOptions
  ): Promise<OmiseResponse>;
}

export class OmiseApiError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "OmiseApiError";
  }
}

type OmiseChargesInit = OmiseClientConfig | {client: OmiseClient};

export function createOmiseChargesApi(
  config: OmiseChargesInit
): OmiseChargesApi {
  const client = hasClient(config)
    ? config.client
    : createOmiseClient(config);

  return {
    async createCardCharge3ds(params, options) {
      const amount = ensurePositiveInteger(params.amount, "amount");
      const currency = normalizeCurrency(params.currency);
      const cardToken = ensureNonEmptyString(params.cardToken, "cardToken");
      const returnUri = ensureNonEmptyString(params.returnUri, "returnUri");

      const chargePayload = buildChargePayload(
        params,
        amount,
        currency,
        {
          card: cardToken,
          return_uri: returnUri,
        }
      );

      const charge = await client.createCharge(chargePayload, options);
      return {charge};
    },

    async createPromptPayCharge(params, options) {
      const amount = ensurePositiveInteger(params.amount, "amount");
      const currency = normalizeCurrency(params.currency);

      const sourcePayload = buildSourcePayload(
        params,
        amount,
        currency,
        "promptpay",
        params.sourceMetadata,
        params.sourceData
      );

      const source = await client.createSource(sourcePayload, options?.source);
      const sourceId = extractIdentifier(source, "source");

      const chargePayload = buildChargePayload(
        params,
        amount,
        currency,
        {
          source: sourceId,
        }
      );

      const charge = await client.createCharge(chargePayload, options?.charge);
      return {charge, source};
    },

    async createMobileBankingCharge(params, options) {
      const amount = ensurePositiveInteger(params.amount, "amount");
      const currency = normalizeCurrency(params.currency);
      const sourceType = resolveMobileBankingType(params);

      const sourcePayload = buildSourcePayload(
        params,
        amount,
        currency,
        sourceType,
        params.sourceMetadata,
        params.sourceData
      );

      const source = await client.createSource(sourcePayload, options?.source);
      const sourceId = extractIdentifier(source, "source");

      const chargePayload = buildChargePayload(
        params,
        amount,
        currency,
        {
          source: sourceId,
        }
      );

      const charge = await client.createCharge(chargePayload, options?.charge);
      return {charge, source};
    },

    captureCharge(chargeId, options) {
      const id = ensureNonEmptyString(chargeId, "chargeId");
      return client.captureCharge(id, options);
    },

    refundCharge(chargeId, payload, options) {
      const id = ensureNonEmptyString(chargeId, "chargeId");
      const normalized = normalizeRefundPayload(payload);
      return client.refundCharge(id, normalized, options);
    },
  };
}

function hasClient(config: OmiseChargesInit): config is {client: OmiseClient} {
  return (config as {client?: OmiseClient}).client !== undefined;
}

interface BaseChargeParams {
  amount: number;
  currency: string;
  description?: string;
  metadata?: Record<string, unknown>;
  capture?: boolean;
  customerId?: string;
}

interface SourceChargeParams extends BaseChargeParams {
  email?: string;
  name?: string;
  phoneNumber?: string;
}

function buildChargePayload(
  params: BaseChargeParams,
  amount: number,
  currency: string,
  extra: Record<string, unknown>
): OmiseChargeRequest {
  const payload: Record<string, unknown> = {
    amount,
    currency,
    ...extra,
  };

  const description = coerceOptionalString(params.description);
  if (description) {
    payload.description = description;
  }

  const metadata = sanitizeRecord(params.metadata);
  if (metadata) {
    payload.metadata = metadata;
  }

  if (params.capture !== undefined) {
    payload.capture = params.capture;
  }

  const customer = coerceOptionalString(params.customerId);
  if (customer) {
    payload.customer = customer;
  }

  return payload as OmiseChargeRequest;
}

function buildSourcePayload(
  params: SourceChargeParams,
  amount: number,
  currency: string,
  type: string,
  metadata?: Record<string, unknown>,
  additionalData?: Record<string, unknown>
): OmiseSourceRequest {
  const payload: Record<string, unknown> = {
    type,
    amount,
    currency,
  };

  const normalizedMetadata = sanitizeRecord(metadata);
  if (normalizedMetadata) {
    payload.metadata = normalizedMetadata;
  }

  const email = coerceOptionalString(params.email);
  if (email) {
    payload.email = email;
  }

  const name = coerceOptionalString(params.name);
  if (name) {
    payload.name = name;
  }

  const phoneNumber = coerceOptionalString(params.phoneNumber);
  if (phoneNumber) {
    payload.phone_number = phoneNumber;
  }

  if (additionalData) {
    for (const [key, value] of Object.entries(additionalData)) {
      if (value === undefined || isReservedSourceKey(key)) {
        continue;
      }
      payload[key] = value;
    }
  }

  return payload as OmiseSourceRequest;
}

function normalizeRefundPayload(
  payload?: OmiseRefundChargeParams
): OmiseRefundRequest | undefined {
  if (!payload) {
    return undefined;
  }

  const normalized: Record<string, unknown> = {};

  if (payload.amount !== undefined) {
    normalized.amount = ensurePositiveInteger(payload.amount, "amount");
  }

  const metadata = sanitizeRecord(payload.metadata);
  if (metadata) {
    normalized.metadata = metadata;
  }

  return normalized as OmiseRefundRequest;
}

function ensurePositiveInteger(value: number, field: string): number {
  if (!Number.isFinite(value)) {
    throw new OmiseApiError(`${field} must be a finite number.`);
  }
  if (!Number.isInteger(value)) {
    throw new OmiseApiError(
      `${field} must be an integer representing the smallest currency unit.`
    );
  }
  if (value <= 0) {
    throw new OmiseApiError(`${field} must be greater than zero.`);
  }
  return value;
}

function ensureNonEmptyString(value: unknown, field: string): string {
  if (typeof value !== "string") {
    throw new OmiseApiError(`${field} must be a string.`);
  }
  const trimmed = value.trim();
  if (!trimmed) {
    throw new OmiseApiError(`${field} must not be empty.`);
  }
  return trimmed;
}

function normalizeCurrency(value: string): string {
  const normalized = ensureNonEmptyString(value, "currency").toLowerCase();
  if (!/^[a-z]{3}$/.test(normalized)) {
    throw new OmiseApiError("currency must be a three-letter ISO code.");
  }
  return normalized;
}

function resolveMobileBankingType(
  params: OmiseMobileBankingChargeParams
): string {
  if (params.sourceType) {
    return ensureIdentifier(params.sourceType, "sourceType");
  }
  if (!params.bank) {
    throw new OmiseApiError(
      "bank is required when sourceType is not provided for mobile banking charges."
    );
  }
  const bank = ensureIdentifier(params.bank, "bank");
  return `mobile_banking_${bank}`;
}

function ensureIdentifier(value: string, field: string): string {
  const normalized = ensureNonEmptyString(value, field).toLowerCase();
  if (!/^[a-z0-9_]+$/.test(normalized)) {
    throw new OmiseApiError(
      `${field} may only contain lowercase letters, numbers, or underscores.`
    );
  }
  return normalized;
}

function coerceOptionalString(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

function sanitizeRecord(
  data?: Record<string, unknown>
): Record<string, unknown> | undefined {
  if (!data) {
    return undefined;
  }
  const entries = Object.entries(data).filter(([, value]) => value !== undefined);
  if (entries.length === 0) {
    return undefined;
  }
  return Object.fromEntries(entries);
}

function extractIdentifier(response: OmiseResponse, label: string): string {
  const id = response?.["id"];
  if (typeof id !== "string" || id.trim() === "") {
    throw new OmiseApiError(`Omise ${label} did not return an identifier.`);
  }
  return id;
}

function isReservedSourceKey(key: string): boolean {
  switch (key) {
    case "type":
    case "amount":
    case "currency":
    case "metadata":
    case "email":
    case "name":
    case "phone_number":
      return true;
    default:
      return false;
  }
}

