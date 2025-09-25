import * as logger from "firebase-functions/logger";
import {BigQueryInsert} from "./analytics-models";

const BIGQUERY_DATASET = process.env.BIGQUERY_DATASET ?? "restaurant_analytics";

const TABLE_MAPPING: Record<string, string> = {
  orders: process.env.BIGQUERY_TABLE_ANALYTICS_ORDERS ?? "orders_stream",
  customers: process.env.BIGQUERY_TABLE_ANALYTICS_CUSTOMERS ?? "customers_stream",
  refunds: process.env.BIGQUERY_TABLE_ANALYTICS_REFUNDS ?? "refunds_stream",
};

type BigQueryClient = {
  dataset(datasetId: string): {
    table(tableId: string): {
      insert(
        rows: Record<string, unknown>[] | Record<string, unknown>,
        options?: Record<string, unknown>
      ): Promise<void>;
    };
  };
};

let cachedClient: BigQueryClient | null = null;

function getBigQueryClient(): BigQueryClient | null {
  if (cachedClient !== null) {
    return cachedClient;
  }

  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const {BigQuery} = require("@google-cloud/bigquery") as {
      BigQuery: new (options?: Record<string, unknown>) => BigQueryClient;
    };
    cachedClient = new BigQuery();
    logger.debug("BigQuery client initialised");
  } catch (error) {
    logger.warn(
      "BigQuery module not available. Streaming will be skipped until dependency is installed.",
      error
    );
    cachedClient = null;
  }

  return cachedClient;
}

function resolveTableName(kind: keyof typeof TABLE_MAPPING): string {
  return TABLE_MAPPING[kind];
}

export async function streamAnalyticsRow<T extends Record<string, unknown>>(
  kind: keyof typeof TABLE_MAPPING,
  row: BigQueryInsert<T>
): Promise<void> {
  const client = getBigQueryClient();
  if (!client) {
    logger.info(
      `Skipping BigQuery streaming for ${kind} because client is not configured.`,
      {kind}
    );
    return;
  }

  const datasetId = BIGQUERY_DATASET;
  const tableId = resolveTableName(kind);
  try {
    await client.dataset(datasetId).table(tableId).insert([row]);
    logger.debug("Streamed row to BigQuery", {datasetId, tableId});
  } catch (error) {
    logger.error("Failed to stream row to BigQuery", {
      datasetId,
      tableId,
      error,
    });
    throw error;
  }
}

export function isBigQueryStreamingEnabled(): boolean {
  return getBigQueryClient() !== null;
}
