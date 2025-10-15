declare module "omise" {
  export interface OmiseConfig {
    publicKey?: string;
    secretKey?: string;
    omiseVersion?: string;
  }

  export interface OmiseRequestOptions {
    headers?: Record<string, string>;
  }

  export type OmiseCallback<TResult> = (
    error: unknown,
    result?: TResult
  ) => void;

  export interface OmiseSourceService {
    create(
      payload: Record<string, unknown>,
      options: OmiseRequestOptions,
      callback: OmiseCallback<Record<string, unknown>>
    ): void;
    create(
      payload: Record<string, unknown>,
      callback: OmiseCallback<Record<string, unknown>>
    ): void;
  }

  export interface OmiseChargeService {
    create(
      payload: Record<string, unknown>,
      options: OmiseRequestOptions,
      callback: OmiseCallback<Record<string, unknown>>
    ): void;
    create(
      payload: Record<string, unknown>,
      callback: OmiseCallback<Record<string, unknown>>
    ): void;
    retrieve(
      chargeId: string,
      options: OmiseRequestOptions,
      callback: OmiseCallback<Record<string, unknown>>
    ): void;
    retrieve(
      chargeId: string,
      callback: OmiseCallback<Record<string, unknown>>
    ): void;
    capture(
      chargeId: string,
      options: OmiseRequestOptions,
      callback: OmiseCallback<Record<string, unknown>>
    ): void;
    capture(
      chargeId: string,
      callback: OmiseCallback<Record<string, unknown>>
    ): void;
    createRefund(
      chargeId: string,
      payload: Record<string, unknown> | undefined,
      options: OmiseRequestOptions,
      callback: OmiseCallback<Record<string, unknown>>
    ): void;
    createRefund(
      chargeId: string,
      payload: Record<string, unknown> | undefined,
      callback: OmiseCallback<Record<string, unknown>>
    ): void;
    createRefund(
      chargeId: string,
      callback: OmiseCallback<Record<string, unknown>>
    ): void;
  }

  export interface OmiseNodeInstance {
    sources: OmiseSourceService;
    charges: OmiseChargeService;
  }

  const createOmise: (config: OmiseConfig) => OmiseNodeInstance;
  export default createOmise;
}
