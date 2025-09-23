import admin from "firebase-admin";
import {describe, it, beforeAll, afterAll, expect, vi} from "vitest";

function wait(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitFor<T>(
  assertion: () => Promise<T>,
  {timeout = 10000, interval = 250}: {timeout?: number; interval?: number} = {}
): Promise<T> {
  const start = Date.now();
  let lastError: unknown;
  while (Date.now() - start < timeout) {
    try {
      return await assertion();
    } catch (error) {
      lastError = error;
    }
    await wait(interval);
  }
  throw lastError ?? new Error("Condition not met before timeout");
}

let emulatorAvailable = false;

describe("returnStockOnRefund", () => {
  beforeAll(async() => {
    process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
    process.env.FUNCTIONS_EMULATOR = "true";
    if (admin.apps.length === 0) {
      admin.initializeApp({projectId: "demo-test"});
    }

    try {
      await Promise.race([
        admin.firestore().listCollections(),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error("Timed out connecting to emulator")), 1500),
        ),
      ]);
      emulatorAvailable = true;
    } catch (error) {
      vi.skip(
        `Firestore emulator not reachable at ${process.env.FIRESTORE_EMULATOR_HOST}. Run \`npm run test:emulator\` for integration coverage.`,
      );
    }
  });

  afterAll(async () => {
    const initializedApps = admin.apps.filter(
      (app): app is admin.app.App => app != null,
    );
    await Promise.all(initializedApps.map((app) => app.delete()));
  });

  it("restores ingredient stock based on refunded menu items", async () => {
    if (!emulatorAvailable) {
      return;
    }
    
    const db = admin.firestore();
    const tenantId = `tenant-${Date.now()}`;

    const ingredientRef = db.collection("ingredients").doc();
    await ingredientRef.set({
      tenantId,
      name: "Flour",
      stockQuantity: 10,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const menuItemRef = db.collection("menu_items").doc();
    await menuItemRef.set({
      tenantId,
      name: "Bread",
      recipe: [
        {
          ingredientId: ingredientRef.id,
          quantity: 0.5,
        },
      ],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const refundRef = db.collection("refunds").doc();
    await refundRef.set({
      tenantId,
      refundedItems: [
        {
          menuItemId: menuItemRef.id,
          name: "Bread",
          quantity: 4,
          price: 120,
        },
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const finalQuantity = await waitFor(async () => {
      const snapshot = await ingredientRef.get();
      const data = snapshot.data();
      const quantity = data?.stockQuantity as number | undefined;
      if (quantity == null || Math.abs(quantity - 12) > 0.0001) {
        throw new Error(`Expected ingredient stock to be 12, got ${quantity}`);
      }
      return quantity;
    });

    expect(finalQuantity).toBeCloseTo(12);
  }, 20000);
});