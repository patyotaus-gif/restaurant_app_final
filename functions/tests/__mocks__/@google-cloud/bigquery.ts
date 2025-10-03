export class BigQuery {
  dataset() {
    return {
      table: () => ({
        insert: async () => Promise.resolve(),
      }),
    };
  }
}

export default BigQuery;
