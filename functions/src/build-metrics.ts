import {CallableRequest, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {BigQuery} from "@google-cloud/bigquery";

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

const bigquery = new BigQuery();
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
