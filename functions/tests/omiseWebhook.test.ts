import {describe, expect, it, vi} from "vitest";

import {
  handleOmiseWebhookEvent,
  OmiseWebhookError,
  type OmiseWebhookEvent,
} from "../src/payments/omiseWebhook.js";
import type {OmiseClient} from "../src/payments/omiseClient.js";

describe("handleOmiseWebhookEvent", () => {
  const createClient = () => {
    const retrieveCharge = vi.fn();
    const client = {
      createSource: vi.fn(),
      createCharge: vi.fn(),
      retrieveCharge: retrieveCharge as unknown as OmiseClient["retrieveCharge"],
      captureCharge: vi.fn(),
      refundCharge: vi.fn(),
    } as unknown as OmiseClient;

    return {client, retrieveCharge};
  };

  it("retrieves the charge again when receiving charge.complete", async () => {
    const {client, retrieveCharge} = createClient();
    retrieveCharge.mockResolvedValue({id: "chrg_test"});

    const event: OmiseWebhookEvent = {
      key: "charge.complete",
      data: {object: "charge", id: " chrg_test "},
    };

    const result = await handleOmiseWebhookEvent(event, client);

    expect(retrieveCharge).toHaveBeenCalledWith("chrg_test");
    expect(result).toEqual({
      handled: true,
      event,
      charge: {id: "chrg_test"},
    });
  });

  it("ignores events other than charge.complete", async () => {
    const {client, retrieveCharge} = createClient();

    const event: OmiseWebhookEvent = {
      key: "charge.failed",
      data: {object: "charge", id: "chrg_test"},
    };

    const result = await handleOmiseWebhookEvent(event, client);

    expect(result).toEqual({handled: false, event});
    expect(retrieveCharge).not.toHaveBeenCalled();
  });

  it("throws when charge.complete payload does not include a charge id", async () => {
    const {client} = createClient();

    await expect(
      handleOmiseWebhookEvent(
        {
          key: "charge.complete",
          data: {object: "charge"},
        },
        client
      )
    ).rejects.toThrow(OmiseWebhookError);
  });
});
