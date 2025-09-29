import {HttpsError} from "firebase-functions/v2/https";

export type MasterDataCollection =
  | "menu_items"
  | "ingredients"
  | "modifierGroups"
  | "stores";

const MASTER_DATA_COLLECTION_SET = new Set<MasterDataCollection>([
  "menu_items",
  "ingredients",
  "modifierGroups",
  "stores",
]);

export const MASTER_DATA_COLLECTIONS = Array.from(MASTER_DATA_COLLECTION_SET);

type MasterDataValidator = (data: Record<string, unknown>) => string[];

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function toOptionalString(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

function toOptionalNumber(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    if (!Number.isNaN(parsed) && Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return undefined;
}

function ensureString(
  data: Record<string, unknown>,
  field: string,
  {required = false, maxLength}: {required?: boolean; maxLength?: number} = {}
): string | undefined {
  const value = data[field];
  if (value == null) {
    if (required) {
      throw new HttpsError(
        "failed-precondition",
        `Missing required field "${field}"`
      );
    }
    return undefined;
  }
  if (typeof value !== "string") {
    throw new HttpsError(
      "failed-precondition",
      `Field "${field}" must be a string`
    );
  }
  const trimmed = value.trim();
  if (required && trimmed.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      `Field "${field}" cannot be empty`
    );
  }
  if (maxLength != null && trimmed.length > maxLength) {
    throw new HttpsError(
      "failed-precondition",
      `Field "${field}" exceeds maximum length of ${maxLength}`
    );
  }
  return trimmed;
}

function ensureNumber(
  data: Record<string, unknown>,
  field: string,
  {
    required = false,
    min,
    max,
  }: {required?: boolean; min?: number; max?: number} = {}
): number | undefined {
  const value = data[field];
  if (value == null) {
    if (required) {
      throw new HttpsError(
        "failed-precondition",
        `Missing required field "${field}"`
      );
    }
    return undefined;
  }
  const coerced = toOptionalNumber(value);
  if (coerced == null) {
    throw new HttpsError(
      "failed-precondition",
      `Field "${field}" must be a finite number`
    );
  }
  if (min != null && coerced < min) {
    throw new HttpsError(
      "failed-precondition",
      `Field "${field}" must be >= ${min}`
    );
  }
  if (max != null && coerced > max) {
    throw new HttpsError(
      "failed-precondition",
      `Field "${field}" must be <= ${max}`
    );
  }
  return coerced;
}

function ensureBoolean(
  data: Record<string, unknown>,
  field: string
): boolean | undefined {
  const value = data[field];
  if (value == null) {
    return undefined;
  }
  if (typeof value !== "boolean") {
    throw new HttpsError(
      "failed-precondition",
      `Field "${field}" must be a boolean`
    );
  }
  return value;
}

function ensureArray(
  data: Record<string, unknown>,
  field: string,
  {required = false}: {required?: boolean} = {}
): unknown[] | undefined {
  const value = data[field];
  if (value == null) {
    if (required) {
      throw new HttpsError(
        "failed-precondition",
        `Missing required field "${field}"`
      );
    }
    return undefined;
  }
  if (!Array.isArray(value)) {
    throw new HttpsError(
      "failed-precondition",
      `Field "${field}" must be an array`
    );
  }
  return value;
}

function isValidTimeZone(timezone: string): boolean {
  try {
    Intl.DateTimeFormat(undefined, {timeZone: timezone});
    return true;
  } catch (error) {
    return false;
  }
}

function validateMenuItem(data: Record<string, unknown>): string[] {
  const errors: string[] = [];
  try {
    const name = ensureString(data, "name", {required: true, maxLength: 120});
    if (name && name !== data["name"]) {
      // no-op, ensureString already trimmed
    }
    ensureString(data, "category", {required: true, maxLength: 60});
    ensureNumber(data, "price", {required: true, min: 0});
    const cost = ensureNumber(data, "costOfGoods", {min: 0});
    if (cost != null) {
      // Optional, but if provided should not exceed price
      const price = toOptionalNumber(data["price"]);
      if (price != null && cost > price) {
        errors.push("costOfGoods cannot exceed price");
      }
    }
    const modifierIds = ensureArray(data, "modifierGroupIds");
    if (modifierIds) {
      modifierIds.forEach((value, index) => {
        if (!isNonEmptyString(value)) {
          errors.push(`modifierGroupIds[${index}] must be a non-empty string`);
        }
      });
    }
    const kitchenStations = ensureArray(data, "kitchenStations");
    if (kitchenStations) {
      kitchenStations.forEach((value, index) => {
        if (!isNonEmptyString(value)) {
          errors.push(`kitchenStations[${index}] must be a non-empty string`);
        }
      });
    }
    ensureBoolean(data, "trackStock");
    const recipe = ensureArray(data, "recipe");
    if (recipe) {
      recipe.forEach((entry, index) => {
        if (typeof entry !== "object" || entry == null) {
          errors.push(`recipe[${index}] must be an object`);
          return;
        }
        const ingredientId = toOptionalString(
          (entry as Record<string, unknown>)["ingredientId"]
        );
        if (!ingredientId) {
          errors.push(`recipe[${index}].ingredientId is required`);
        }
        const quantity = toOptionalNumber(
          (entry as Record<string, unknown>)["quantity"]
        );
        if (quantity == null || quantity <= 0) {
          errors.push(`recipe[${index}].quantity must be greater than 0`);
        }
      });
    }
    const prepTime = toOptionalNumber(data["prepTimeMinutes"]);
    if (prepTime != null && prepTime < 0) {
      errors.push("prepTimeMinutes must be >= 0");
    }
  } catch (error) {
    if (error instanceof HttpsError) {
      errors.push(error.message);
    } else {
      throw error;
    }
  }
  return errors;
}

function validateIngredient(data: Record<string, unknown>): string[] {
  const errors: string[] = [];
  try {
    ensureString(data, "name", {required: true, maxLength: 120});
    ensureString(data, "unit", {required: true, maxLength: 20});
    ensureNumber(data, "currentStock", {required: true, min: 0});
    const targetStock = ensureNumber(data, "targetStock", {min: 0});
    const currentStock = toOptionalNumber(data["currentStock"]);
    if (
      targetStock != null &&
      currentStock != null &&
      targetStock < currentStock
    ) {
      errors.push("targetStock cannot be less than currentStock");
    }
    ensureNumber(data, "costPerUnit", {min: 0});
  } catch (error) {
    if (error instanceof HttpsError) {
      errors.push(error.message);
    } else {
      throw error;
    }
  }
  return errors;
}

function validateModifierGroup(data: Record<string, unknown>): string[] {
  const errors: string[] = [];
  try {
    ensureString(data, "groupName", {required: true, maxLength: 80});
    ensureString(data, "selectionType", {required: true, maxLength: 40});
    const options = ensureArray(data, "options", {required: true});
    if (options) {
      options.forEach((option, index) => {
        if (typeof option !== "object" || option == null) {
          errors.push(`options[${index}] must be an object`);
          return;
        }
        const optionRecord = option as Record<string, unknown>;
        const optionName = toOptionalString(optionRecord["optionName"]);
        if (!optionName || optionName.trim().length === 0) {
          errors.push(`options[${index}].optionName is required`);
        }
        const priceChange = toOptionalNumber(optionRecord["priceChange"]);
        if (priceChange == null) {
          errors.push(`options[${index}].priceChange must be a number`);
        }
      });
    }
  } catch (error) {
    if (error instanceof HttpsError) {
      errors.push(error.message);
    } else {
      throw error;
    }
  }
  return errors;
}

function validateStore(data: Record<string, unknown>): string[] {
  const errors: string[] = [];
  try {
    ensureString(data, "name", {required: true, maxLength: 120});
    const timezone = ensureString(data, "timezone", {required: true});
    if (timezone && !isValidTimeZone(timezone)) {
      errors.push(`Invalid timezone: ${timezone}`);
    }
    ensureString(data, "tenantId", {required: true});
    ensureBoolean(data, "isActive");
    const currencySettings = data["currencySettings"];
    if (currencySettings != null) {
      if (
        typeof currencySettings !== "object" ||
        Array.isArray(currencySettings)
      ) {
        errors.push("currencySettings must be an object");
      } else {
        const currencyRecord = currencySettings as Record<string, unknown>;
        ensureString(currencyRecord, "code", {required: true});
        ensureString(currencyRecord, "symbol", {required: true});
        const decimalDigits = ensureNumber(currencyRecord, "decimalDigits", {
          required: true,
          min: 0,
          max: 4,
        });
        if (decimalDigits != null && !Number.isInteger(decimalDigits)) {
          errors.push("currencySettings.decimalDigits must be an integer");
        }
      }
    } else {
      errors.push("currencySettings is required");
    }
  } catch (error) {
    if (error instanceof HttpsError) {
      errors.push(error.message);
    } else {
      throw error;
    }
  }
  return errors;
}

const VALIDATORS: Record<MasterDataCollection, MasterDataValidator> = {
  menu_items: validateMenuItem,
  ingredients: validateIngredient,
  modifierGroups: validateModifierGroup,
  stores: validateStore,
};

export function isMasterDataCollection(
  value: string
): value is MasterDataCollection {
  return MASTER_DATA_COLLECTION_SET.has(value as MasterDataCollection);
}

export function validateMasterDataConstraints(
  collection: string,
  data: Record<string, unknown>
): string[] {
  if (!isMasterDataCollection(collection)) {
    return [];
  }
  return VALIDATORS[collection](data);
}

export const DEFAULT_BACKFILL_BATCH_SIZE = 50;

export type BackfillUpdates = Record<string, unknown>;

export function buildBackfillUpdates(
  collection: MasterDataCollection,
  data: Record<string, unknown>
): BackfillUpdates {
  const updates: BackfillUpdates = {};
  switch (collection) {
    case "menu_items": {
      const name = toOptionalString(data["name"]);
      if (name) {
        const trimmed = name.trim();
        if (trimmed !== name) {
          updates.name = trimmed;
        }
        const normalized = trimmed.toLowerCase();
        if (data["nameNormalized"] !== normalized) {
          updates.nameNormalized = normalized;
        }
      }
      if (data["price"] != null && typeof data["price"] !== "number") {
        const coerced = toOptionalNumber(data["price"]);
        if (coerced != null) {
          updates.price = coerced;
        }
      }
      const schemaVersion = toOptionalNumber(data["schemaVersion"]);
      if (schemaVersion !== 1) {
        updates.schemaVersion = 1;
      }
      break;
    }
    case "ingredients": {
      const unit = toOptionalString(data["unit"]);
      if (unit) {
        const trimmed = unit.trim();
        if (trimmed !== unit) {
          updates.unit = trimmed;
        }
      }
      (["currentStock", "targetStock", "costPerUnit"] as const).forEach(
        (field) => {
          const value = data[field];
          if (value != null && typeof value !== "number") {
            const coerced = toOptionalNumber(value);
            if (coerced != null) {
              updates[field] = coerced;
            }
          }
        }
      );
      const schemaVersion = toOptionalNumber(data["schemaVersion"]);
      if (schemaVersion !== 1) {
        updates.schemaVersion = 1;
      }
      break;
    }
    case "modifierGroups": {
      const selectionType = toOptionalString(data["selectionType"]);
      if (selectionType) {
        const normalized = selectionType.trim().toUpperCase();
        if (normalized !== data["selectionType"]) {
          updates.selectionType = normalized;
        }
      }
      if (Array.isArray(data["options"])) {
        const options = data["options"] as unknown[];
        const sanitized = options.map((option) => {
          if (typeof option !== "object" || option == null) {
            return option;
          }
          const record = option as Record<string, unknown>;
          const next: Record<string, unknown> = {...record};
          const optionName = toOptionalString(record["optionName"]);
          if (optionName) {
            const trimmed = optionName.trim();
            if (trimmed !== optionName) {
              next.optionName = trimmed;
            }
          }
          const priceChange = record["priceChange"];
          if (priceChange != null && typeof priceChange !== "number") {
            const coerced = toOptionalNumber(priceChange);
            if (coerced != null) {
              next.priceChange = coerced;
            }
          }
          return next;
        });
        if (JSON.stringify(sanitized) !== JSON.stringify(options)) {
          updates.options = sanitized;
        }
      }
      const schemaVersion = toOptionalNumber(data["schemaVersion"]);
      if (schemaVersion !== 1) {
        updates.schemaVersion = 1;
      }
      break;
    }
    case "stores": {
      const name = toOptionalString(data["name"]);
      if (name) {
        const trimmed = name.trim();
        if (trimmed !== name) {
          updates.name = trimmed;
        }
        const normalized = trimmed.toLowerCase();
        if (data["nameNormalized"] !== normalized) {
          updates.nameNormalized = normalized;
        }
      }
      const timezone = toOptionalString(data["timezone"]);
      if (timezone) {
        const trimmed = timezone.trim();
        if (trimmed !== timezone) {
          updates.timezone = trimmed;
        }
      }
      const schemaVersion = toOptionalNumber(data["schemaVersion"]);
      if (schemaVersion !== 1) {
        updates.schemaVersion = 1;
      }
      break;
    }
  }

  return updates;
}

