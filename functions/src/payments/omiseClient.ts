import {createRequire} from "node:module";
import type {
  OmiseConfig as OmiseNodeConfig,
  OmiseNodeInstance,
  OmiseRequestOptions as OmiseNodeRequestOptions,
} from "omise";

const require = createRequire(import.meta.url);

const OMISE_API_BASE_URL = "https://api.omise.co";
const OMISE_VAULT_BASE_URL = "https://vault.omise.co";
const OMISE_IDEMPOTENCY_HEADER = "Omise-Idempotency-Key";

export interface OmiseClientConfig {
  publicKey?: string;
  secretKey?: string;
  fetchImpl?: FetchLike;
  omiseVersion?: string;
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
  captureCharge(
    chargeId: string,
    options?: OmiseRequestOptions
  ): Promise<OmiseResponse>;
  refundCharge(
    chargeId: string,
    payload?: OmiseRefundRequest,
    options?: OmiseRequestOptions
  ): Promise<OmiseResponse>;
}

type OmiseFactory = (config: OmiseNodeConfig) => OmiseNodeInstance;
type OmiseCallback<TResult> = (error: unknown, result?: TResult) => void;

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

let factoryOverride: OmiseFactory | null | undefined;
let cachedFactory: OmiseFactory | null | undefined;

export function __setOmiseFactoryForTests(
  factory: OmiseFactory | null | undefined
): void {
  factoryOverride = factory;
  cachedFactory = undefined;
}

export function createOmiseClient(config: OmiseClientConfig): OmiseClient {
  const factory = resolveOmiseFactory();
  if (factory) {
    return createSdkBackedClient(config, factory);
  }
  return createHttpClient(config);
}

function resolveOmiseFactory(): OmiseFactory | null {
  if (factoryOverride !== undefined) {
    return factoryOverride;
  }

  if (cachedFactory === undefined) {
    cachedFactory = loadOmiseFactory();
  }

  return cachedFactory ?? null;
}

function loadOmiseFactory(): OmiseFactory | null {
  try {
    const module = require("omise") as unknown;
    if (typeof module === "function") {
      return module as OmiseFactory;
    }

    if (
      module &&
      typeof module === "object" &&
      typeof (module as {default?: unknown}).default === "function"
    ) {
      return (module as {default: OmiseFactory}).default;
    }
  } catch {
    // The Omise SDK is optional at runtime. When it cannot be loaded,
    // we fall back to an HTTP implementation.
  }

  return null;
}

function createSdkBackedClient(
  config: OmiseClientConfig,
  factory: OmiseFactory
): OmiseClient {
  let omiseInstance: OmiseNodeInstance | undefined;

  function ensureInstance(): OmiseNodeInstance {
    if (!omiseInstance) {
      if (!config.publicKey && !config.secretKey) {
        throw new OmiseConfigurationError(
          "Omise API keys are not configured for this operation."
        );
      }

      const factoryConfig: OmiseNodeConfig = {};
      if (config.publicKey) {
        factoryConfig.publicKey = config.publicKey;
      }
      if (config.secretKey) {
        factoryConfig.secretKey = config.secretKey;
      }
      if (config.omiseVersion) {
        factoryConfig.omiseVersion = config.omiseVersion;
      }

      omiseInstance = factory(factoryConfig);
    }

    return omiseInstance;
  }

  function requirePublicClient(): OmiseNodeInstance {
    if (!config.publicKey) {
      throw new OmiseConfigurationError(
        "Omise public key is not configured for this operation."
      );
    }
    return ensureInstance();
  }

  function requireSecretClient(): OmiseNodeInstance {
    if (!config.secretKey) {
      throw new OmiseConfigurationError(
        "Omise secret key is not configured for this operation."
      );
    }
    return ensureInstance();
  }

  return {
    async createSource(payload, options) {
      const client = requirePublicClient();
      const args: unknown[] = [payload];
      const requestOptions = buildSdkRequestOptions(options);
      if (requestOptions) {
        args.push(requestOptions);
      }

      return callSdkOperation(
        client.sources.create.bind(client.sources),
        args
      );
    },

    async createCharge(payload, options) {
      const client = requireSecretClient();
      const args: unknown[] = [payload];
      const requestOptions = buildSdkRequestOptions(options);
      if (requestOptions) {
        args.push(requestOptions);
      }

      return callSdkOperation(
        client.charges.create.bind(client.charges),
        args
      );
    },

    async retrieveCharge(chargeId, options) {
      const client = requireSecretClient();
      const args: unknown[] = [chargeId];
      const requestOptions = buildSdkRequestOptions(options);
      if (requestOptions) {
        args.push(requestOptions);
      }

      return callSdkOperation(
        client.charges.retrieve.bind(client.charges),
        args
      );
    },

    async captureCharge(chargeId, options) {
      const client = requireSecretClient();
      const args: unknown[] = [chargeId];
      const requestOptions = buildSdkRequestOptions(options);
      if (requestOptions) {
        args.push(requestOptions);
      }

      return callSdkOperation(
        client.charges.capture.bind(client.charges),
        args
      );
    },

    async refundCharge(chargeId, payload, options) {
      const client = requireSecretClient();
      const args: unknown[] = [chargeId];
      const hasPayload = payload !== undefined;
      if (hasPayload) {
        args.push(payload);
      }

      const requestOptions = buildSdkRequestOptions(options);
      if (requestOptions) {
        if (!hasPayload) {
          args.push(undefined);
        }
        args.push(requestOptions);
      }

      return callSdkOperation(
        client.charges.createRefund.bind(client.charges),
        args
      );
    },
  };
}

function buildSdkRequestOptions(
  options?: OmiseRequestOptions
): OmiseNodeRequestOptions | undefined {
  if (!options?.idempotencyKey) {
    return undefined;
  }

  return {
    headers: {
      [OMISE_IDEMPOTENCY_HEADER]: options.idempotencyKey,
    },
  };
}

async function callSdkOperation<TResult extends OmiseResponse>(
  method: (...args: [...unknown[], OmiseCallback<TResult>]) => unknown,
  args: unknown[]
): Promise<TResult> {
  try {
    return await callOmise(method, args);
  } catch (error) {
    throw wrapSdkError(error);
  }
}

function callOmise<TResult extends OmiseResponse>(
  method: (...args: [...unknown[], OmiseCallback<TResult>]) => unknown,
  args: unknown[]
): Promise<TResult> {
  return new Promise<TResult>((resolve, reject) => {
    const callback: OmiseCallback<TResult> = (error, result) => {
      if (error) {
        reject(error);
        return;
      }
      resolve((result ?? ({} as TResult)) as TResult);
    };

    let maybePromise: unknown;
    try {
      maybePromise = method(...args, callback);
    } catch (error) {
      reject(error);
      return;
    }

    if (
      maybePromise &&
      typeof maybePromise === "object" &&
      typeof (maybePromise as Promise<TResult>).then === "function"
    ) {
      (maybePromise as Promise<TResult>).then(resolve).catch(reject);
    }
  });
}

function wrapSdkError(error: unknown): OmiseRequestError {
  if (error instanceof OmiseRequestError) {
    return error;
  }

  const message = resolveSdkErrorMessage(error);
  const status = resolveSdkErrorStatus(error);
  return new OmiseRequestError(message, status, error);
}

function resolveSdkErrorMessage(error: unknown): string {
  if (typeof error === "string" && error.trim()) {
    return error.trim();
  }

  if (typeof error === "object" && error && "message" in error) {
    const message = (error as {message?: unknown}).message;
    if (typeof message === "string" && message.trim()) {
      return message.trim();
    }
  }

  if (typeof error === "object" && error && "code" in error) {
    const code = (error as {code?: unknown}).code;
    if (typeof code === "string" && code.trim()) {
      return code.trim();
    }
  }

  return "Omise request failed.";
}

function resolveSdkErrorStatus(error: unknown): number {
  if (typeof error !== "object" || !error) {
    return 500;
  }

  const record = error as {status?: unknown; statusCode?: unknown; code?: unknown};
  const status = record.status ?? record.statusCode ?? record.code;
  if (typeof status === "number" && Number.isFinite(status)) {
    return status;
  }

  if (typeof status === "string") {
    const parsed = Number.parseInt(status, 10);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return 500;
}

interface RequestConfig {
  url: string;
  apiKey: string;
  body?: unknown;
  method?: string;
  idempotencyKey?: string;
  signal?: AbortSignal;
}

function createHttpClient(config: OmiseClientConfig): OmiseClient {
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
      headers[OMISE_IDEMPOTENCY_HEADER] = idempotencyKey;
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
        resolveHttpErrorMessage(parsedBody) ||
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
      return requestWithSecretKey(
        `/charges/${encodeURIComponent(chargeId)}`,
        undefined,
        {
          ...options,
          method: options?.method ?? "GET",
        }
      );
    },
    captureCharge(chargeId, options) {
      return requestWithSecretKey(
        `/charges/${encodeURIComponent(chargeId)}/capture`,
        undefined,
        options
      );
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
  from(input: string, encoding?: string): {toString(encoding: string): string};
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

function resolveHttpErrorMessage(data: unknown): string | undefined {
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

