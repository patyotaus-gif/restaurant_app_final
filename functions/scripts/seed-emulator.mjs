import process from "node:process";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {readFile} from "node:fs/promises";
import admin from "firebase-admin";

const projectId = process.env.PROJECT_ID ?? "demo-test";
const host = process.env.FIRESTORE_EMULATOR_HOST ?? "localhost:8080";
process.env.GOOGLE_CLOUD_PROJECT = projectId;
process.env.FIRESTORE_EMULATOR_HOST = host;

if (!admin.apps.length) {
  admin.initializeApp({projectId});
}

const firestore = admin.firestore();
firestore.settings({ignoreUndefinedProperties: true});

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const seedPath = path.resolve(__dirname, "../fixtures/seed-data.json");

function shouldReset() {
  const flag = (process.env.RESET ?? "").toLowerCase();
  return flag === "1" || flag === "true" || flag === "yes";
}

async function resetCollection(collectionName) {
  if (!shouldReset()) {
    return;
  }
  const ref = firestore.collection(collectionName);
  await admin.firestore().recursiveDelete(ref);
}

async function seed() {
  const raw = await readFile(seedPath, "utf8");
  const seedFile = JSON.parse(raw);
  for (const collection of seedFile.collections ?? []) {
    const documents = collection.documents ?? [];
    await resetCollection(collection.name);
    for (const document of documents) {
      const ref = firestore.collection(collection.name).doc(document.id);
      await ref.set(document.data, {merge: false});
    }
    console.log(
      `Seeded ${documents.length} docs to ${collection.name} on ${host}`
    );
  }
  console.log("Seeding complete");
}

seed().catch((error) => {
  console.error("Failed to seed emulator fixtures", error);
  process.exitCode = 1;
});
