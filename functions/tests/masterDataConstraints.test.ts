import {describe, expect, it} from "vitest";

import {
  buildBackfillUpdates,
  validateMasterDataConstraints,
} from "../src/master-data.js";

describe("validateMasterDataConstraints", () => {
  it("accepts a valid menu item payload", () => {
    const errors = validateMasterDataConstraints("menu_items", {
      name: "Pad Thai",
      category: "mains",
      price: 120,
      recipe: [
        {
          ingredientId: "rice-noodle",
          quantity: 1,
        },
      ],
      modifierGroupIds: ["spice-level"],
      kitchenStations: ["wok"],
    });

    expect(errors).toEqual([]);
  });

  it("flags missing required menu item fields", () => {
    const errors = validateMasterDataConstraints("menu_items", {
      category: "mains",
      price: -10,
    });

    expect(errors).not.toHaveLength(0);
    expect(errors.join(" ")).toMatch(/name/i);
  });

  it("rejects invalid ingredient payloads", () => {
    const errors = validateMasterDataConstraints("ingredients", {
      name: "Fish Sauce",
      unit: "ml",
      currentStock: -2,
    });

    expect(errors).not.toHaveLength(0);
    expect(errors.join(" ")).toMatch(/currentStock/i);
  });

  it("rejects modifier group options without names", () => {
    const errors = validateMasterDataConstraints("modifierGroups", {
      groupName: "Protein",
      selectionType: "single",
      options: [{priceChange: 10}],
    });

    expect(errors.join(" ")).toMatch(/optionName/i);
  });
});

describe("buildBackfillUpdates", () => {
  it("normalizes menu item fields", () => {
    const updates = buildBackfillUpdates("menu_items", {
      name: "  Pad Thai  ",
      price: "120",
    });

    expect(updates).toMatchObject({
      name: "Pad Thai",
      nameNormalized: "pad thai",
      price: 120,
      schemaVersion: 1,
    });
  });

  it("normalizes modifier group options", () => {
    const updates = buildBackfillUpdates("modifierGroups", {
      selectionType: "single",
      options: [
        {
          optionName: "  Large  ",
          priceChange: "15",
        },
      ],
    });

    expect(updates.selectionType).toBe("SINGLE");
    expect(updates.options).toEqual([
      {
        optionName: "Large",
        priceChange: 15,
      },
    ]);
    expect(updates.schemaVersion).toBe(1);
  });
});

