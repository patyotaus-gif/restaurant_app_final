const OMISE_API_BASE_URL = "https://api.omise.co";
const OMISE_VAULT_BASE_URL = "https://vault.omise.co";

export interface OmiseClientConfig {
  publicKey?: string;
  secretKey?: string;
  fetchImpl?: FetchLike;
}

export interface OmiseRequestOptions {
  method?: string;
  idempotencyKey?: string;
  signal?: AbortSignal;
}

export interface OmiseSourceRequest {
  type: string;
  amount: number;
  currency: string;
  metadata?: Record<string, unknown>;
  email?: string;
  name?: string;
  [key: string]: unknown;
}

export interface OmiseChargeRequest {
  amount: number;
  currency: string;
  source?: string;
  customer?: string;
  description?: string;
  metadata?: Record<string, unknown>;
  capture?: boolean;
  [key: string]: unknown;
}

export interface OmiseRefundRequest {
  amount?: number;
  metadata?: Record<string, unknown>;
  [key: string]: unknown;
}

export type OmiseResponse = Record<string, unknown>;

export class OmiseConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "OmiseConfigurationError";
  }
}

export class OmiseRequestError extends Error {
  readonly status: number;
  readonly details: unknown;

  constructor(message: string, status: number, details: unknown) {
    super(message);
    this.name = "OmiseRequestError";
    this.status = status;
    this.details = details;
  }
}

type FetchLike = (
  input: string,
  init?: {
    method?: string;
    headers?: Record<string, string>;
    body?: string;
    signal?: AbortSignal;
  }
) => Promise<{
  ok: boolean;
  status: number;
  statusText: string;
  text(): Promise<string>;
}>;

interface RequestConfig {
  url: string;
  apiKey: string;
  body?: unknown;
  method?: string;
  idempotencyKey?: string;
  signal?: AbortSignal;
}

export interface OmiseClient {
  createSource(
    payload: OmiseSourceRequest,
    options?: OmiseRequestOptions
  ): Promise<OmiseResponse>;
  createCharge(
    payload: OmiseChargeRequest,
    options?: OmiseRequestOptions
  ): Promise<OmiseResponse>;
  retrieveCharge(
    chargeId: string,
    options?: OmiseRequestOptions
  ): Promise<OmiseResponse>;
  refundCharge(
    chargeId: string,
    payload?: OmiseRefundRequest,
    options?: OmiseRequestOptions
  ): Promise<OmiseResponse>;
}

export function createOmiseClient(config: OmiseClientConfig): OmiseClient {
  const fetcher = resolveFetch(config.fetchImpl);

  async function performRequest<T extends OmiseResponse>(
    requestConfig: RequestConfig
  ): Promise<T> {
    const {url, apiKey, body, method = "POST", idempotencyKey, signal} =
      requestConfig;

    const headers: Record<string, string> = {
      Authorization: `Basic ${encodeBasicAuth(apiKey)}`,
    };

    let serializedBody: string | undefined;
    if (body !== undefined) {
      serializedBody = JSON.stringify(body);
      headers["Content-Type"] = "application/json; charset=utf-8";
    }

    if (idempotencyKey) {
      headers["Omise-Idempotency-Key"] = idempotencyKey;
    }

    const response = await fetcher(url, {
      method,
      headers,
      body: serializedBody,
      signal,
    });

    const rawBody = await response.text();
    const parsedBody = parseResponseBody(rawBody);

    if (!response.ok) {
      const message =
        resolveErrorMessage(parsedBody) ||
        `Omise request failed with status ${response.status}`;
      throw new OmiseRequestError(message, response.status, parsedBody);
    }

    return (parsedBody as T) ?? ({} as T);
  }

  function requestWithPublicKey<T extends OmiseResponse>(
    path: string,
    payload: unknown,
    options?: OmiseRequestOptions
  ): Promise<T> {
    const publicKey = config.publicKey;
    if (!publicKey) {
      throw new OmiseConfigurationError(
        "Omise public key is not configured for this operation."
      );
    }

    return performRequest<T>({
      url: `${OMISE_VAULT_BASE_URL}${path}`,
      apiKey: publicKey,
      body: payload,
      method: options?.method,
      idempotencyKey: options?.idempotencyKey,
      signal: options?.signal,
    });
  }

  function requestWithSecretKey<T extends OmiseResponse>(
    path: string,
    payload?: unknown,
    options?: OmiseRequestOptions
  ): Promise<T> {
    const secretKey = config.secretKey;
    if (!secretKey) {
      throw new OmiseConfigurationError(
        "Omise secret key is not configured for this operation."
      );
    }

    return performRequest<T>({
      url: `${OMISE_API_BASE_URL}${path}`,
      apiKey: secretKey,
      body: payload,
      method: options?.method,
      idempotencyKey: options?.idempotencyKey,
      signal: options?.signal,
    });
  }

  return {
    createSource(payload, options) {
      return requestWithPublicKey("/sources", payload, options);
    },
    createCharge(payload, options) {
      return requestWithSecretKey("/charges", payload, options);
    },
    retrieveCharge(chargeId, options) {
      return requestWithSecretKey(`/charges/${encodeURIComponent(chargeId)}`, undefined, {
        ...options,
        method: options?.method ?? "GET",
      });
    },
    refundCharge(chargeId, payload, options) {
      return requestWithSecretKey(
        `/charges/${encodeURIComponent(chargeId)}/refunds`,
        payload,
        options
      );
    },
  };
}

function resolveFetch(fetchImpl?: FetchLike): FetchLike {
  if (fetchImpl) {
    return fetchImpl;
  }

  const globalFetch = (globalThis as {fetch?: FetchLike}).fetch;
  if (!globalFetch) {
    throw new OmiseConfigurationError(
      "Fetch API is not available. Provide a custom fetch implementation."
    );
  }
  return globalFetch;
}

interface BufferLike {
  from(input: string, encoding?: string): { toString(encoding: string): string };
}

function encodeBasicAuth(key: string): string {
  const globalBuffer = (globalThis as {Buffer?: BufferLike}).Buffer;
  if (globalBuffer) {
    return globalBuffer.from(`${key}:`, "utf8").toString("base64");
  }

  const btoaFn = (globalThis as {btoa?: (input: string) => string}).btoa;
  if (typeof btoaFn === "function") {
    return btoaFn(`${key}:`);
  }

  throw new OmiseConfigurationError(
    "Unable to encode Omise credentials because no base64 encoder is available."
  );
}

function parseResponseBody(rawBody: string): OmiseResponse | null {
  if (!rawBody) {
    return null;
  }

  try {
    const parsed = JSON.parse(rawBody);
    return isRecord(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function resolveErrorMessage(data: unknown): string | undefined {
  if (!data || typeof data !== "object") {
    return undefined;
  }

  const record = data as Record<string, unknown>;
  const message = record["message"];
  if (typeof message === "string" && message.trim()) {
    return message.trim();
  }

  const error = record["error"];
  if (typeof error === "string" && error.trim()) {
    return error.trim();
  }

  if (isRecord(error)) {
    const errorMessage = error["message"];
    if (typeof errorMessage === "string" && errorMessage.trim()) {
      return errorMessage.trim();
    }

    const code = error["code"];
    if (typeof code === "string" && code.trim()) {
      return code.trim();
    }
  }

  return undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

