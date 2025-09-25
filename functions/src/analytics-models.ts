export type AnalyticsEventType = "CREATE" | "UPDATE" | "DELETE";

export interface AnalyticsOrderItem extends Record<string, unknown> {
  sku: string;
  name: string;
  quantity: number;
  price: number;
  category?: string;
}

export interface AnalyticsOrderRecord extends Record<string, unknown> {
  event_id: string;
  event_type: AnalyticsEventType;
  event_timestamp: string;
  order_id: string;
  tenant_id: string;
  store_id?: string;
  customer_id?: string;
  status?: string;
  payment_status?: string;
  payment_method?: string;
  subtotal: number;
  tax: number;
  discount: number;
  tip: number;
  total: number;
  currency?: string;
  order_created_at?: string;
  order_updated_at?: string;
  order_closed_at?: string;
  loyalty_points_awarded?: number;
  items_json: string;
}

export interface AnalyticsCustomerRecord extends Record<string, unknown> {
  event_id: string;
  event_type: AnalyticsEventType;
  event_timestamp: string;
  customer_id: string;
  tenant_id: string;
  email?: string;
  phone_number?: string;
  loyalty_tier?: string;
  points_balance?: number;
  lifetime_value?: number;
  created_at?: string;
  updated_at?: string;
}

export interface AnalyticsRefundRecord extends Record<string, unknown> {
  event_id: string;
  event_type: AnalyticsEventType;
  event_timestamp: string;
  refund_id: string;
  order_id?: string;
  tenant_id: string;
  amount: number;
  reason?: string;
  status?: string;
  processed_at?: string;
}

export interface BigQueryRowMetadata {
  source: string;
  schema_version: number;
}

export interface BigQueryInsert<T extends Record<string, unknown>>
  extends Record<string, unknown> {
  metadata: BigQueryRowMetadata;
  payload: T;
}

export function buildEventId(collection: string, documentId: string, suffix?: string): string {
  const parts = [collection, documentId];
  if (suffix) {
    parts.push(suffix);
  }
  return parts.join("-");
}

export function stringifyItems(items: AnalyticsOrderItem[]): string {
  try {
    return JSON.stringify(items);
  } catch (error) {
    return JSON.stringify([]);
  }
}
