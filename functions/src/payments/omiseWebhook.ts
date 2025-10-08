import type {OmiseClient, OmiseResponse} from "./omiseClient.js";

export interface OmiseWebhookEvent {
  key?: string;
  data?: OmiseWebhookCharge | null;
  [key: string]: unknown;
}

export interface OmiseWebhookCharge {
  object?: string;
  id?: string;
  [key: string]: unknown;
}

export interface OmiseWebhookResult {
  handled: boolean;
  event: OmiseWebhookEvent;
  charge?: OmiseResponse;
}

export class OmiseWebhookError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "OmiseWebhookError";
  }
}

export async function handleOmiseWebhookEvent(
  event: OmiseWebhookEvent | null | undefined,
  client: Pick<OmiseClient, "retrieveCharge">
): Promise<OmiseWebhookResult> {
  if (!event || typeof event !== "object") {
    throw new OmiseWebhookError("Omise webhook payload must be an object.");
  }

  if (event.key !== "charge.complete") {
    return {handled: false, event};
  }

  const charge = event.data;
  if (!charge || typeof charge !== "object") {
    throw new OmiseWebhookError(
      "Omise charge.complete webhook payload is missing charge data."
    );
  }

  if (charge.object !== undefined && charge.object !== "charge") {
    throw new OmiseWebhookError(
      "Omise charge.complete webhook payload did not include a charge object."
    );
  }

  const chargeId = charge.id;
  if (typeof chargeId !== "string" || chargeId.trim() === "") {
    throw new OmiseWebhookError(
      "Omise charge.complete webhook payload did not include a charge id."
    );
  }

  const normalizedChargeId = chargeId.trim();
  const retrievedCharge = await client.retrieveCharge(normalizedChargeId);

  return {
    handled: true,
    event,
    charge: retrievedCharge,
  };
}
