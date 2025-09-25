declare module "@google-cloud/bigquery" {
  export class BigQuery {
    constructor(options?: Record<string, unknown>);
    dataset(datasetId: string): {
      table(tableId: string): {
        insert(rows: unknown[] | Record<string, unknown>, options?: Record<string, unknown>): Promise<void>;
      };
    };
  }
}
