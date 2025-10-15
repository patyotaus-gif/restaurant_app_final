import {CallableRequest, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
type BigQueryTable = {
  insert: (
    rows: unknown[],
    options?: {ignoreUnknownValues?: boolean; skipInvalidRows?: boolean}
  ) => Promise<unknown>;
};

type BigQueryDataset = {
  table: (tableId: string) => BigQueryTable;
};

type BigQueryClient = {
  dataset: (datasetId: string) => BigQueryDataset;
};

let bigQueryClientPromise: Promise<BigQueryClient> | undefined;

async function getBigQueryClient(): Promise<BigQueryClient> {
  if (!bigQueryClientPromise) {
    bigQueryClientPromise = import("@google-cloud/bigquery")
      .then((module) => {
        const BigQueryCtor =
          (module as {BigQuery?: new (...args: unknown[]) => BigQueryClient})
            .BigQuery ??
          (module as {default?: new (...args: unknown[]) => BigQueryClient})
            .default;

        if (!BigQueryCtor) {
          throw new Error(
            "The '@google-cloud/bigquery' module does not export a BigQuery constructor."
          );
        }

        return new BigQueryCtor();
      })
      .catch((error) => {
        logger.error(
          "Failed to load BigQuery client. Ensure '@google-cloud/bigquery' is installed.",
          error as Error
        );
        throw error;
      });
  }

  return bigQueryClientPromise;
}

type FrameSummary = {
  average: number;
  p90: number;
  p99: number;
  max: number;
};

type MetricPayload = {
  sessionId: string;
  timestamp: string;
  appVersion?: string | null;
  buildMode: string;
  platform: string;
  frameCount: number;
  build: FrameSummary;
  raster: FrameSummary;
  commit?: string;
  branch?: string;
  isWeb?: boolean;
};

const datasetId = process.env.BUILD_METRICS_DATASET ?? "ops_metrics";
const tableId = process.env.BUILD_METRICS_TABLE ?? "frame_performance";

export const ingestBuildMetric = onCall(
  {region: "asia-southeast1", memory: "128MiB", timeoutSeconds: 10},
  async (request: CallableRequest<MetricPayload>) => {
    const metric = request.data;
    if (!metric) {
      throw new Error("Missing metric payload");
    }
    if (!metric.sessionId || !metric.timestamp || !metric.build || !metric.raster) {
      throw new Error("Metric payload missing required properties");
    }

    const row = {
      session_id: metric.sessionId,
      collected_at: metric.timestamp,
      app_version: metric.appVersion ?? null,
      build_mode: metric.buildMode,
      platform: metric.platform,
      frame_count: metric.frameCount,
      build_average_ms: metric.build.average,
      build_p90_ms: metric.build.p90,
      build_p99_ms: metric.build.p99,
      build_max_ms: metric.build.max,
      raster_average_ms: metric.raster.average,
      raster_p90_ms: metric.raster.p90,
      raster_p99_ms: metric.raster.p99,
      raster_max_ms: metric.raster.max,
      commit: metric.commit ?? null,
      branch: metric.branch ?? null,
      is_web: metric.isWeb ?? false,
      received_at: new Date().toISOString(),
    };

    try {
      const bigquery = await getBigQueryClient();
      await bigquery.dataset(datasetId).table(tableId).insert([row], {
        ignoreUnknownValues: true,
        skipInvalidRows: true,
      });
      logger.info("Build metrics streamed", {sessionId: metric.sessionId});
    } catch (error) {
      logger.error("Failed to insert build metrics", error as Error, row);
      throw error;
    }

    return {status: "ok"};
  }
);
