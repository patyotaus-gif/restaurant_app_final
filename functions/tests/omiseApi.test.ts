import {beforeEach, describe, expect, it, vi} from "vitest";

import {
  createOmiseChargesApi,
  OmiseApiError,
  type OmiseChargeResult,
} from "../src/payments/omiseApi.js";
import type {OmiseClient, OmiseResponse} from "../src/payments/omiseClient.js";

describe("createOmiseChargesApi", () => {
  let client: OmiseClient;
  let createSource: ReturnType<typeof vi.fn>;
  let createCharge: ReturnType<typeof vi.fn>;
  let captureCharge: ReturnType<typeof vi.fn>;
  let refundCharge: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    createSource = vi.fn();
    createCharge = vi.fn();
    captureCharge = vi.fn();
    refundCharge = vi.fn();

    client = {
      createSource: createSource as unknown as OmiseClient["createSource"],
      createCharge: createCharge as unknown as OmiseClient["createCharge"],
      retrieveCharge: vi.fn(),
      captureCharge: captureCharge as unknown as OmiseClient["captureCharge"],
      refundCharge: refundCharge as unknown as OmiseClient["refundCharge"],
    };
  });

  describe("createCardCharge3ds", () => {
    it("builds a charge payload for 3DS card payments", async () => {
      const chargeResponse: OmiseResponse = {
        id: "chrg_test",
        authorize_uri: "https://example.com/authorize",
      };
      createCharge.mockResolvedValue(chargeResponse);

      const api = createOmiseChargesApi({client});
      const result = await api.createCardCharge3ds(
        {
          amount: 10500,
          currency: "THB",
          cardToken: "tokn_test",
          returnUri: "https://example.com/return",
          description: "Table #12",
          metadata: {orderId: "order-12"},
          capture: false,
          customerId: "cust_test",
        },
        {idempotencyKey: "card-charge"}
      );

      expect(createCharge).toHaveBeenCalledWith(
        {
          amount: 10500,
          currency: "thb",
          card: "tokn_test",
          return_uri: "https://example.com/return",
          description: "Table #12",
          metadata: {orderId: "order-12"},
          capture: false,
          customer: "cust_test",
        },
        {idempotencyKey: "card-charge"}
      );
      expect(result).toEqual<OmiseChargeResult>({charge: chargeResponse});
    });

    it("rejects non-integer amounts", async () => {
      const api = createOmiseChargesApi({client});

      await expect(
        api.createCardCharge3ds({
          amount: 100.5,
          currency: "THB",
          cardToken: "tokn_test",
          returnUri: "https://example.com/return",
        })
      ).rejects.toThrowError(OmiseApiError);
    });
  });

  describe("createPromptPayCharge", () => {
    it("creates a source and charge", async () => {
      const sourceResponse: OmiseResponse = {id: "src_promptpay"};
      const chargeResponse: OmiseResponse = {id: "chrg_promptpay"};
      createSource.mockResolvedValue(sourceResponse);
      createCharge.mockResolvedValue(chargeResponse);

      const api = createOmiseChargesApi({client});
      const result = await api.createPromptPayCharge(
        {
          amount: 2500,
          currency: "THB",
          description: "Takeaway order",
          metadata: {orderId: "order-42"},
          sourceMetadata: {channel: "qr"},
          email: "guest@example.com",
          name: "Guest",
          phoneNumber: "+669999999",
        },
        {
          source: {idempotencyKey: "source"},
          charge: {idempotencyKey: "charge"},
        }
      );

      expect(createSource).toHaveBeenCalledWith(
        {
          type: "promptpay",
          amount: 2500,
          currency: "thb",
          metadata: {channel: "qr"},
          email: "guest@example.com",
          name: "Guest",
          phone_number: "+669999999",
        },
        {idempotencyKey: "source"}
      );
      expect(createCharge).toHaveBeenCalledWith(
        {
          amount: 2500,
          currency: "thb",
          source: "src_promptpay",
          description: "Takeaway order",
          metadata: {orderId: "order-42"},
        },
        {idempotencyKey: "charge"}
      );
      expect(result).toEqual<OmiseChargeResult>({
        charge: chargeResponse,
        source: sourceResponse,
      });
    });

    it("throws when Omise does not return a source identifier", async () => {
      createSource.mockResolvedValue({});

      const api = createOmiseChargesApi({client});

      await expect(
        api.createPromptPayCharge({amount: 1000, currency: "THB"})
      ).rejects.toThrowError(/identifier/i);
    });
  });

  describe("createMobileBankingCharge", () => {
    it("builds requests with a resolved mobile banking type", async () => {
      const sourceResponse: OmiseResponse = {id: "src_mobile"};
      const chargeResponse: OmiseResponse = {id: "chrg_mobile"};
      createSource.mockResolvedValue(sourceResponse);
      createCharge.mockResolvedValue(chargeResponse);

      const api = createOmiseChargesApi({client});
      await api.createMobileBankingCharge(
        {
          amount: 8900,
          currency: "THB",
          bank: "SCB",
          sourceMetadata: {channel: "app"},
          sourceData: {platform_type: "ios"},
        },
        {charge: {idempotencyKey: "mobile"}}
      );

      expect(createSource).toHaveBeenCalledWith(
        {
          type: "mobile_banking_scb",
          amount: 8900,
          currency: "thb",
          metadata: {channel: "app"},
          platform_type: "ios",
        },
        undefined
      );
      expect(createCharge).toHaveBeenCalledWith(
        {
          amount: 8900,
          currency: "thb",
          source: "src_mobile",
        },
        {idempotencyKey: "mobile"}
      );
    });

    it("validates the mobile banking bank identifier", async () => {
      const api = createOmiseChargesApi({client});

      await expect(
        api.createMobileBankingCharge({
          amount: 1000,
          currency: "THB",
          bank: "",
        })
      ).rejects.toThrowError(OmiseApiError);
    });
  });

  describe("captureCharge", () => {
    it("delegates to the Omise client", async () => {
      const captureResponse: OmiseResponse = {id: "chrg_capture"};
      captureCharge.mockResolvedValue(captureResponse);

      const api = createOmiseChargesApi({client});
      await expect(api.captureCharge("chrg_capture", {idempotencyKey: "cap"}))
        .resolves.toEqual(captureResponse);

      expect(captureCharge).toHaveBeenCalledWith("chrg_capture", {
        idempotencyKey: "cap",
      });
    });
  });

  describe("refundCharge", () => {
    it("normalizes the refund payload", async () => {
      const refundResponse: OmiseResponse = {id: "rfnd_test"};
      refundCharge.mockResolvedValue(refundResponse);

      const api = createOmiseChargesApi({client});
      await expect(
        api.refundCharge(
          "chrg_test",
          {
            amount: 5000,
            metadata: {reason: "customer_request", notes: undefined},
          },
          {idempotencyKey: "rfnd"}
        )
      ).resolves.toEqual(refundResponse);

      expect(refundCharge).toHaveBeenCalledWith(
        "chrg_test",
        {
          amount: 5000,
          metadata: {reason: "customer_request"},
        },
        {idempotencyKey: "rfnd"}
      );
    });

    it("rejects invalid refund amounts", async () => {
      const api = createOmiseChargesApi({client});

      await expect(
        api.refundCharge("chrg_test", {amount: -1})
      ).rejects.toThrowError(OmiseApiError);
    });
  });
});

