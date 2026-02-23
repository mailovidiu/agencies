#!/usr/bin/env node

/**
 * One-shot updater for the `departments` collection that always bumps
 * `lastUpdated` to server time so the record appears first in "What's New".
 *
 * Usage examples:
 *   # Bump only by document ID
 *   FIREBASE_PROJECT_ID=u-s-departments-and-age-gnkn5k \
 *   GOOGLE_APPLICATION_CREDENTIALS=/abs/path/key.json \
 *   node scripts/bump_whats_new_department.js --id 1759999942873_0005 --dry-run
 *
 *   # Update fields + bump timestamp by exact name
 *   FIREBASE_PROJECT_ID=u-s-departments-and-age-gnkn5k \
 *   GOOGLE_APPLICATION_CREDENTIALS=/abs/path/key.json \
 *   node scripts/bump_whats_new_department.js \
 *     --name "The White House" \
 *     --set contactInfo.website=https://www.whitehouse.gov \
 *     --set description="Updated description text"
 */

const admin = require('firebase-admin');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'u-s-departments-and-age-gnkn5k';
const COLLECTION = 'departments';

function usage(exitCode = 0) {
  console.log(`
Usage:
  node scripts/bump_whats_new_department.js [--id <docId> | --name <exactName>] [--set path=value]... [--dry-run]

Options:
  --id <docId>         Target document ID in departments collection.
  --name <exactName>   Target by exact 'name' field. Must match exactly one doc.
  --set path=value     Field updates to apply (repeatable). Example: contactInfo.phone=+1-202-456-1111
  --dry-run            Print planned update without writing.
  --help               Show this help.

Environment:
  FIREBASE_PROJECT_ID             Defaults to u-s-departments-and-age-gnkn5k
  GOOGLE_APPLICATION_CREDENTIALS  Path to Firebase Admin service-account JSON
`);
  process.exit(exitCode);
}

function parseArgs(argv) {
  const result = {
    id: null,
    name: null,
    sets: [],
    dryRun: false,
    help: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--id') {
      result.id = argv[++i] || null;
      continue;
    }
    if (arg === '--name') {
      result.name = argv[++i] || null;
      continue;
    }
    if (arg === '--set') {
      const raw = argv[++i] || '';
      result.sets.push(raw);
      continue;
    }
    if (arg === '--dry-run') {
      result.dryRun = true;
      continue;
    }
    if (arg === '--help' || arg === '-h') {
      result.help = true;
      continue;
    }
    console.error(`Unknown argument: ${arg}`);
    usage(1);
  }

  return result;
}

function parseSet(raw) {
  const idx = raw.indexOf('=');
  if (idx <= 0) {
    throw new Error(`Invalid --set "${raw}". Expected path=value`);
  }
  const path = raw.slice(0, idx).trim();
  const valueRaw = raw.slice(idx + 1);

  if (!path) {
    throw new Error(`Invalid --set "${raw}". Empty field path`);
  }
  if (path === 'lastUpdated') {
    throw new Error('Do not set lastUpdated manually; it is set automatically');
  }

  return { path, value: coerceValue(valueRaw) };
}

function coerceValue(raw) {
  if (raw === 'true') return true;
  if (raw === 'false') return false;
  if (raw === 'null') return null;
  if (raw !== '' && !Number.isNaN(Number(raw))) return Number(raw);
  return raw;
}

function initAdmin() {
  if (admin.apps.length === 0) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  return getFirestore();
}

async function resolveTargetDoc(db, id, name) {
  const ref = db.collection(COLLECTION);

  if (id && name) {
    throw new Error('Use either --id or --name, not both');
  }
  if (!id && !name) {
    throw new Error('Missing target. Use --id <docId> or --name <exactName>');
  }

  if (id) {
    const doc = await ref.doc(id).get();
    if (!doc.exists) {
      throw new Error(`Document not found by id: ${id}`);
    }
    return doc;
  }

  const byName = await ref.where('name', '==', name).get();
  if (byName.empty) {
    throw new Error(`No document found with name="${name}"`);
  }
  if (byName.docs.length > 1) {
    const ids = byName.docs.map((d) => d.id).join(', ');
    throw new Error(`Name matched multiple documents. Use --id. Matches: ${ids}`);
  }
  return byName.docs[0];
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) usage(0);

  const db = initAdmin();
  const target = await resolveTargetDoc(db, args.id, args.name);
  const setEntries = args.sets.map(parseSet);

  const updatePayload = {};
  for (const item of setEntries) {
    updatePayload[item.path] = item.value;
  }
  updatePayload.lastUpdated = FieldValue.serverTimestamp();

  const current = target.data() || {};
  const currentName = current.name || '(no name)';
  const currentLastUpdated = current.lastUpdated || null;

  console.log(`${args.dryRun ? '[DRY RUN]' : '[APPLY]'} Project: ${PROJECT_ID}`);
  console.log(`Target: ${target.id} (${currentName})`);
  console.log(`Collection: ${COLLECTION}`);
  console.log(`Current lastUpdated: ${currentLastUpdated ? currentLastUpdated.toString() : 'null'}`);
  console.log('Planned fields:');
  for (const item of setEntries) {
    console.log(`- ${item.path} = ${JSON.stringify(item.value)}`);
  }
  console.log('- lastUpdated = <serverTimestamp>');

  if (args.dryRun) {
    console.log('No changes written.');
    return;
  }

  await target.ref.update(updatePayload);
  console.log('Update applied successfully.');
}

main().catch((error) => {
  console.error(`Failed: ${error.message || error}`);
  process.exitCode = 1;
});
