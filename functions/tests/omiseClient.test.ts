import {afterEach, describe, expect, it, vi} from "vitest";

import {
  __setOmiseFactoryForTests,
  createOmiseClient,
  OmiseConfigurationError,
  OmiseRequestError,
  type OmiseResponse,
} from "../src/payments/omiseClient.js";
import type {OmiseConfig, OmiseNodeInstance} from "omise";

describe("createOmiseClient with omise-node", () => {
  afterEach(() => {
    __setOmiseFactoryForTests(undefined);
  });

  it("invokes the Omise SDK when available", async () => {
    const sourceResponse: OmiseResponse = {id: "src_test"};
    const chargeResponse: OmiseResponse = {id: "chrg_test"};
    const retrieveResponse: OmiseResponse = {id: "chrg_test"};
    const captureResponse: OmiseResponse = {id: "chrg_capture", captured: true};
    const refundResponse: OmiseResponse = {id: "rfnd_test"};

    const sourcesCreate = vi.fn((...args: unknown[]) => {
      const callback = args.at(-1) as (error: unknown, result?: OmiseResponse) => void;
      callback(null, sourceResponse);
    });
    const chargesCreate = vi.fn((...args: unknown[]) => {
      const callback = args.at(-1) as (error: unknown, result?: OmiseResponse) => void;
      callback(null, chargeResponse);
    });
    const chargesRetrieve = vi.fn((...args: unknown[]) => {
      const callback = args.at(-1) as (error: unknown, result?: OmiseResponse) => void;
      callback(null, retrieveResponse);
    });
    const chargesCapture = vi.fn((...args: unknown[]) => {
      const callback = args.at(-1) as (error: unknown, result?: OmiseResponse) => void;
      callback(null, captureResponse);
    });
    const chargesCreateRefund = vi.fn((...args: unknown[]) => {
      const callback = args.at(-1) as (error: unknown, result?: OmiseResponse) => void;
      callback(null, refundResponse);
    });

    const instance: OmiseNodeInstance = {
      sources: {create: sourcesCreate},
      charges: {
        create: chargesCreate,
        retrieve: chargesRetrieve,
        capture: chargesCapture,
        createRefund: chargesCreateRefund,
      },
    };

    const factoryImpl = vi.fn((config: OmiseConfig) => instance);
    __setOmiseFactoryForTests(
      factoryImpl as unknown as (config: OmiseConfig) => OmiseNodeInstance
    );

    const client = createOmiseClient({
      publicKey: "pkey_test",
      secretKey: "skey_test",
    });

    await expect(
      client.createSource(
        {type: "promptpay", amount: 1000, currency: "THB"},
        {idempotencyKey: "source-1"}
      )
    ).resolves.toEqual(sourceResponse);
    await expect(
      client.createCharge(
        {amount: 1000, currency: "THB"},
        {idempotencyKey: "charge-1"}
      )
    ).resolves.toEqual(chargeResponse);
    await expect(client.retrieveCharge("chrg_test")).resolves.toEqual(retrieveResponse);
    await expect(
      client.captureCharge("chrg_test", {idempotencyKey: "capture-1"})
    ).resolves.toEqual(captureResponse);
    await expect(
      client.refundCharge("chrg_test", undefined, {idempotencyKey: "refund-1"})
    ).resolves.toEqual(refundResponse);

    expect(factoryImpl).toHaveBeenCalledTimes(1);
    expect(factoryImpl).toHaveBeenCalledWith({
      publicKey: "pkey_test",
      secretKey: "skey_test",
    });

    expect(sourcesCreate).toHaveBeenCalledWith(
      {type: "promptpay", amount: 1000, currency: "THB"},
      {headers: {"Omise-Idempotency-Key": "source-1"}},
      expect.any(Function)
    );
    expect(chargesCreate).toHaveBeenCalledWith(
      {amount: 1000, currency: "THB"},
      {headers: {"Omise-Idempotency-Key": "charge-1"}},
      expect.any(Function)
    );
    expect(chargesRetrieve).toHaveBeenCalledWith("chrg_test", expect.any(Function));
    expect(chargesCapture).toHaveBeenCalledWith(
      "chrg_test",
      {headers: {"Omise-Idempotency-Key": "capture-1"}},
      expect.any(Function)
    );
    expect(chargesCreateRefund).toHaveBeenCalledWith(
      "chrg_test",
      undefined,
      {headers: {"Omise-Idempotency-Key": "refund-1"}},
      expect.any(Function)
    );
  });

  it("throws when the Omise SDK cannot be loaded", () => {
    __setOmiseFactoryForTests(null);

    expect(() =>
      createOmiseClient({publicKey: "pkey_test", secretKey: "skey_test"})
    ).toThrowError(OmiseConfigurationError);
  });

  it("throws a configuration error when the secret key is missing", async () => {
    const instance: OmiseNodeInstance = {
      sources: {
        create: vi.fn((...args: unknown[]) => {
          const callback = args.at(-1) as (error: unknown, result?: OmiseResponse) => void;
          callback(null, {});
        }),
      },
      charges: {
        create: vi.fn(),
        retrieve: vi.fn(),
        capture: vi.fn(),
        createRefund: vi.fn(),
      },
    };

    const factoryImpl = vi.fn((config: OmiseConfig) => instance);
    __setOmiseFactoryForTests(
      factoryImpl as unknown as (config: OmiseConfig) => OmiseNodeInstance
    );

    const client = createOmiseClient({publicKey: "pkey_only"});
    await expect(
      client.createCharge({amount: 1000, currency: "THB"})
    ).rejects.toThrow(OmiseConfigurationError);
  });

  it("wraps SDK errors into OmiseRequestError", async () => {
    const sdkError = Object.assign(new Error("request failed"), {statusCode: 422});

    const chargesCreate = vi.fn((...args: unknown[]) => {
      const callback = args.at(-1) as (error: unknown, result?: OmiseResponse) => void;
      callback(sdkError);
    });

    const instance: OmiseNodeInstance = {
      sources: {
        create: vi.fn((...args: unknown[]) => {
          const callback = args.at(-1) as (error: unknown, result?: OmiseResponse) => void;
          callback(null, {});
        }),
      },
      charges: {
        create: chargesCreate,
        retrieve: vi.fn(),
        capture: vi.fn(),
        createRefund: vi.fn(),
      },
    };

    const factoryImpl = vi.fn((config: OmiseConfig) => instance);
    __setOmiseFactoryForTests(
      factoryImpl as unknown as (config: OmiseConfig) => OmiseNodeInstance
    );

    const client = createOmiseClient({
      publicKey: "pkey_test",
      secretKey: "skey_test",
    });

    await expect(
      client.createCharge({amount: 1000, currency: "THB"})
    ).rejects.toMatchObject({
      name: "OmiseRequestError",
      status: 422,
      message: "request failed",
    });
    expect(chargesCreate).toHaveBeenCalled();
  });
});
