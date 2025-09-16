import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// --- TIER UPGRADE CONFIGURATION ---
const TIER_THRESHOLDS = {
  PLATINUM: 20000,
  GOLD: 5000,
};

const TIER_POINT_MULTIPLIERS = {
  PLATINUM: 1.5,
  GOLD: 1.2,
  SILVER: 1.0,
};
// ------------------------------------

// --- Helper function to create notifications ---
async function createNotification(
  type: string,
  title: string,
  message: string,
  severity: "info" | "warn" | "critical",
  data: object = {}
) {
  try {
    await db.collection("notifications").add({
      type,
      title,
      message,
      severity,
      data,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      seenBy: {},
    });
    logger.log(`Notification created: ${title}`);
  } catch (error) {
    logger.error("Failed to create notification:", error);
  }
}

// --- Function to notify when order is ready to serve ---
export const onOrderStatusUpdate = onDocumentUpdated("orders/{orderId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;

    if (before.status === "preparing" && after.status === "serving") {
      await createNotification(
        "ORDER_READY",
        `Order Ready: ${after.orderIdentifier}`,
        "An order is now ready to be served to the customer.",
        "info",
        {orderId: event.params.orderId}
      );
    }
  });

// --- Function to notify on low stock ---
export const onIngredientUpdate = onDocumentUpdated("ingredients/{ingredientId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;
    
    const threshold = after.lowStockThreshold as number;
    // Notify only when the stock crosses the threshold
    if (after.stockQuantity <= threshold && before.stockQuantity > threshold) {
        await createNotification(
        "LOW_STOCK",
        `Low Stock Alert: ${after.name}`,
        `Stock for ${after.name} is low (${after.stockQuantity} ${after.unit} remaining).`,
        "warn",
        {ingredientId: event.params.ingredientId}
      );
    }
  });

// --- Function to notify on new refund ---
export const onRefundCreate = onDocumentCreated("refunds/{refundId}",
  async (event) => {
    const refundData = event.data?.data();
    if (!refundData) return;

    const amount = (refundData.totalRefundAmount as number).toFixed(2);
    
    await createNotification(
      "REFUND_PROCESSED",
      `Refund Processed: ฿${amount}`,
      `A refund for order ${refundData.originalOrderId} has been processed.`,
      "critical",
      {refundId: event.params.refundId, orderId: refundData.originalOrderId}
    );
  });

export const processWasteRecord = onDocumentCreated("waste_records/{recordId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.log("No data for waste record, skipping.");
      return;
    }
    const wasteData = snapshot.data();
    const ingredientId = wasteData.ingredientId as string;
    const quantityWasted = wasteData.quantity as number;
    if (!ingredientId || !quantityWasted || quantityWasted <= 0) {
      logger.error("Invalid waste data, skipping stock deduction.", wasteData);
      return;
    }
    const ingredientRef = db.collection("ingredients").doc(ingredientId);
    try {
      await ingredientRef.update({
        stockQuantity: admin.firestore.FieldValue.increment(-quantityWasted),
      });
      logger.log(`Deducted ${quantityWasted} from ingredient ${ingredientId} due to waste record.`);
    } catch (error) {
      logger.error(`Failed to deduct stock for ingredient ${ingredientId}.`, error);
    }
  });


export const returnStockOnRefund = onDocumentCreated("refunds/{refundId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.log("No data associated with the event, skipping.");
      return;
    }
    const refundData = snapshot.data();
    type RefundedItem = {
      name: string;
      quantity: number;
      price: number;
      menuItemId: string;
    };
    const refundedItems: RefundedItem[] = refundData.refundedItems;
    if (!refundedItems || refundedItems.length === 0) {
      logger.log("No items to refund in this document.");
      return;
    }
    await db.runTransaction(async (transaction) => {
      const menuItemRefs = refundedItems.map((item) =>
        db.collection("menu_items").doc(item.menuItemId)
      );
      const menuItemDocs = await transaction.getAll(...menuItemRefs);

      for (const menuItemDoc of menuItemDocs) {
        if (!menuItemDoc.exists) continue;
        const menuItemData = menuItemDoc.data();
        const refundedItem = refundedItems.find(
          (item) => item.menuItemId === menuItemDoc.id
        );
        if (!refundedItem) continue;
        const recipe: {
          ingredientId: string;
          quantity: number;
        }[] = menuItemData?.recipe ?? [];
        if (recipe.length > 0) {
          for (const recipeIngredient of recipe) {
            const ingredientRef = db
              .collection("ingredients")
              .doc(recipeIngredient.ingredientId);
            const quantityToReturn =
              recipeIngredient.quantity * refundedItem.quantity;
            transaction.update(ingredientRef, {
              stockQuantity: admin.firestore.FieldValue.increment(
                quantityToReturn,
              ),
            });
          }
        } else {
          const ingredientRef = db.collection("ingredients")
            .doc(menuItemDoc.id);
          transaction.update(ingredientRef, {
            stockQuantity: admin.firestore.FieldValue.increment(
              refundedItem.quantity,
            ),
          });
        }
      }
    });
    logger.log(`Stock returned for refund ID: ${snapshot.id}`);
  });

export const processPunchCards = onDocumentUpdated("orders/{orderId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after || before.status === "completed" || after.status !== "completed") {
      return;
    }

    const customerId = after.customerId as string;
    type OrderItem = {id: string; category: string; quantity: number;};
    const items: OrderItem[] = after.items;

    if (!customerId || !items || items.length === 0) {
      return;
    }

    type PunchCardCampaign = {
      id: string;
      applicableCategories: string[];
    };

    try {
      const campaignsSnapshot = await db.collection("punch_card_campaigns")
        .where("isActive", "==", true).get();
      if (campaignsSnapshot.empty) {
        return;
      }
      
      const campaigns: PunchCardCampaign[] = campaignsSnapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          applicableCategories: data.applicableCategories || [],
        } as PunchCardCampaign;
      });

      const customerRef = db.collection("customers").doc(customerId);
      const customerUpdateData: {[key: string]: any} = {};

      for (const item of items) {
        const applicableCampaigns = campaigns.filter(
          (c) => c.applicableCategories.includes(item.category)
        );

        for (const campaign of applicableCampaigns) {
          const fieldToUpdate = `punchCards.${campaign.id}`;
          customerUpdateData[fieldToUpdate] = admin.firestore.FieldValue.increment(item.quantity);
        }
      }

      if (Object.keys(customerUpdateData).length > 0) {
        await customerRef.update(customerUpdateData);
        logger.log(`Updated punch cards for customer ${customerId}.`, customerUpdateData);
      }
    } catch (error) {
      logger.error(`Error processing punch cards for order ${event.params.orderId}:`, error);
    }
  });

// --- THIS IS THE UPDATED FUNCTION ---
export const processCompletedOrder = onDocumentUpdated("orders/{orderId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const orderId = event.params.orderId;

    if (!before || !after || before.status === "completed" || after.status !== "completed") {
      return;
    }

    const orderRef = db.collection("orders").doc(orderId);
    
    // --- NEW: Block to calculate Cost of Goods Sold (COGS) ---
    let totalCostOfGoodsSold = 0;
    const itemsForCosting: {id: string; quantity: number;}[] = after.items;

    if (itemsForCosting && itemsForCosting.length > 0) {
      const productIds = itemsForCosting.map((item) => item.id);
      const productsSnapshot = await db.collection("menu_items")
        .where(admin.firestore.FieldPath.documentId(), "in", productIds)
        .get();
      
      const productCosts: {[key: string]: number} = {};
      productsSnapshot.forEach((doc) => {
        productCosts[doc.id] = doc.data().costPrice || 0;
      });

      for (const item of itemsForCosting) {
        const cost = productCosts[item.id] || 0;
        totalCostOfGoodsSold += cost * item.quantity;
      }
    }
    const grossProfit = after.total - totalCostOfGoodsSold;
    logger.log(`Order ${orderId}: Revenue= ${after.total}, COGS= ${totalCostOfGoodsSold}, Profit= ${grossProfit}`);
    // --- End of NEW Block ---


    const promotionCode = after.promotionCode as string;
    if (promotionCode) {
      const promoQuery = await db.collection("promotions").where("code", "==", promotionCode).limit(1).get();
      if (!promoQuery.empty) {
        const promoDoc = promoQuery.docs[0];
        try {
          await promoDoc.ref.update({
            timesUsed: admin.firestore.FieldValue.increment(1),
          });
          logger.log(`Incremented usage for promotion code: ${promotionCode}`);
        } catch (error) {
          logger.error(`Failed to increment usage for promotion code: ${promotionCode}`, error);
        }
      }
    }

    const customerId = after.customerId;
    const orderTotal = after.total as number;
    const items: {id: string; name: string; quantity: number; category?: string;}[] = after.items;

    if (items && items.length > 0) {
      try {
        await db.runTransaction(async (transaction) => {
          const menuItemRefs = items.map((item) =>
            db.collection("menu_items").doc(item.id)
          );
          const menuItemDocs = await transaction.getAll(...menuItemRefs);
          menuItemDocs.forEach((menuItemDoc, index) => {
            if (menuItemDoc.exists) {
              const item = items[index];
              const recipe = menuItemDoc.data()?.recipe ?? [];
              if (recipe.length > 0) {
                for (const ing of recipe) {
                  const ingRef = db.collection("ingredients").doc(ing.ingredientId);
                  const qtyToDeduct = ing.quantity * item.quantity;
                  transaction.update(ingRef, {
                    stockQuantity: admin.firestore.FieldValue.increment(-qtyToDeduct),
                  });
                }
              } else {
                const ingRef = db.collection("ingredients").doc(item.id);
                  transaction.update(ingRef, {
                  stockQuantity: admin.firestore.FieldValue.increment(-item.quantity),
                });
              }
            }
          });
        });
        logger.log(`Stock deducted successfully for order ${orderId}.`);
      } catch (error) {
        logger.error(`Error deducting stock for order ${orderId}:`, error);
      }
    }
    
    if (customerId) {
      const customerRef = db.collection("customers").doc(customerId);

      if (after.discountType === "points" && after.pointsRedeemed > 0) {
        const pointsToDeduct = after.pointsRedeemed as number;
        try {
          await customerRef.update({
            loyaltyPoints: admin.firestore.FieldValue.increment(-pointsToDeduct),
          });
          logger.log(`Deducted ${pointsToDeduct} points from customer ${customerId}.`);
        } catch (error) {
          logger.error(`Failed to deduct points from customer ${customerId}.`, error);
        }
      } else {
        const customerDoc = await customerRef.get();
        if (customerDoc.exists) {
          const customerData = customerDoc.data()!;
          const currentTier = (customerData.tier || "SILVER").toUpperCase();
          const newLifetimeSpend = (customerData.lifetimeSpend || 0) + orderTotal;
          let newTier = "SILVER";
          if (newLifetimeSpend >= TIER_THRESHOLDS.PLATINUM) {
            newTier = "PLATINUM";
          } else if (newLifetimeSpend >= TIER_THRESHOLDS.GOLD) {
            newTier = "GOLD";
          }
          const multiplier = TIER_POINT_MULTIPLIERS[currentTier as keyof typeof TIER_POINT_MULTIPLIERS] || 1.0;
          const pointsPerBaht = 1 / 10;
          const pointsToAward = Math.floor(orderTotal * pointsPerBaht * multiplier);
          try {
            const updates: {[key: string]: any} = {
              lifetimeSpend: admin.firestore.FieldValue.increment(orderTotal),
            };
            if (pointsToAward > 0) {
              updates.loyaltyPoints = admin.firestore.FieldValue.increment(pointsToAward);
            }
            if (newTier.toUpperCase() !== currentTier.toUpperCase()) {
              updates.tier = newTier;
            }
            await customerRef.update(updates);
            logger.log(`Processed order for customer ${customerId}. Awarded: ${pointsToAward}, New Spend: ${newLifetimeSpend}, Tier: ${newTier}`);
            // I'm removing the debug_tier_update field as it's not necessary for the final version
          } catch (error) {
            logger.error(`Failed to update points/tier for customer ${customerId}.`, error);
          }
        }
      }
    }

    // --- NEW: Add the calculated profit to the order document ---
    try {
      await orderRef.update({
        "totalCostOfGoodsSold": totalCostOfGoodsSold,
        "grossProfit": grossProfit,
      });
      logger.log(`Successfully updated order ${orderId} with profit data.`);
    } catch (error) {
      logger.error(`Failed to update order ${orderId} with profit data.`, error);
    }
  });

export const updateStockOnPoReceived = onDocumentUpdated("purchase_orders/{poId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) {
      logger.log("No data found on PO update, exiting.");
      return;
    }

    if (after.status !== "received" || before.status === "received") {
      return; 
    }

    logger.log(`PO ${event.params.poId} marked as received. Updating stock...`);

    type PoItem = {
      productId: string;
      productName: string;
      quantity: number;
      cost: number;
    };
    const items: PoItem[] = after.items;

    if (!items || items.length === 0) {
      logger.log("No items in PO.");
      return;
    }

    const batch = db.batch();

    items.forEach((item) => {
      const ingredientRef = db.collection("ingredients").doc(item.productId);
      batch.update(ingredientRef, {
        stockQuantity: admin.firestore.FieldValue.increment(item.quantity),
      });
    });

    try {
      await batch.commit();
      logger.log(`Stock updated successfully for PO ${event.params.poId}.`);
    } catch (error) {
      logger.error(`Error updating stock for PO ${event.params.poId}:`, error);
    }
  });