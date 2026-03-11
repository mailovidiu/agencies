#!/usr/bin/env node

/**
 * One-shot updater for Firestore records used by "What's New" and
 * "Recently updated". It bumps timestamp fields so the record appears first.
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
 *     --collection agencies \
 *     --name "The White House" \
 *     --set contactInfo.website=https://www.whitehouse.gov \
 *     --set description="Updated description text"
 */

const admin = require('firebase-admin');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'u-s-departments-and-age-gnkn5k';
const VALID_COLLECTIONS = new Set(['departments', 'agencies']);
const NAME_FIELDS_BY_COLLECTION = {
  departments: ['name'],
  agencies: ['nume', 'name'],
};

function usage(exitCode = 0) {
  console.log(`
Usage:
  node scripts/bump_whats_new_department.js [--collection <departments|agencies>] [--id <docId> | --name <exactName>] [--set path=value]... [--dry-run]

Options:
  --collection <name>  Optional. Force collection: departments or agencies.
  --id <docId>         Target document ID.
  --name <exactName>   Target by exact name.
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
    collection: null,
    id: null,
    name: null,
    sets: [],
    dryRun: false,
    help: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--collection') {
      result.collection = argv[++i] || null;
      continue;
    }
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
  if (path === 'lastUpdated' || path === 'updatedAt') {
    throw new Error('Do not set timestamp fields manually; they are set automatically');
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

async function detectCollection(db, forcedCollection) {
  if (forcedCollection) {
    if (!VALID_COLLECTIONS.has(forcedCollection)) {
      throw new Error(
        `Invalid --collection "${forcedCollection}". Valid values: departments, agencies`,
      );
    }
    return forcedCollection;
  }

  const [departmentsSnap, agenciesSnap] = await Promise.all([
    db.collection('departments').limit(1).get(),
    db.collection('agencies').limit(1).get(),
  ]);

  const hasDepartments = !departmentsSnap.empty;
  const hasAgencies = !agenciesSnap.empty;

  if (hasDepartments && !hasAgencies) return 'departments';
  if (hasAgencies && !hasDepartments) return 'agencies';
  if (hasDepartments && hasAgencies) {
    throw new Error(
      'Both collections contain data. Use --collection departments|agencies explicitly.',
    );
  }

  throw new Error(
    'No data found in either `departments` or `agencies`. Use --collection if needed.',
  );
}

async function resolveTargetDoc(db, collection, id, name) {
  const ref = db.collection(collection);

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
    return { doc, matchedField: null };
  }

  const nameFields = NAME_FIELDS_BY_COLLECTION[collection] || ['name'];
  const matches = [];
  for (const field of nameFields) {
    const snap = await ref.where(field, '==', name).get();
    for (const doc of snap.docs) {
      matches.push({ doc, field });
    }
  }

  const deduped = [];
  const seen = new Set();
  for (const item of matches) {
    if (!seen.has(item.doc.id)) {
      seen.add(item.doc.id);
      deduped.push(item);
    }
  }

  if (deduped.length === 0) {
    throw new Error(
      `No document found with name="${name}" in ${collection} (fields: ${nameFields.join(', ')})`,
    );
  }
  if (deduped.length > 1) {
    const ids = deduped.map((x) => x.doc.id).join(', ');
    throw new Error(`Name matched multiple documents. Use --id. Matches: ${ids}`);
  }

  return { doc: deduped[0].doc, matchedField: deduped[0].field };
}

function buildTimestampPayload(collection) {
  if (collection === 'departments') {
    return { lastUpdated: FieldValue.serverTimestamp() };
  }

  if (collection === 'agencies') {
    return {
      lastUpdated: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
  }

  return { lastUpdated: FieldValue.serverTimestamp() };
}

function getCurrentTimestampPreview(data) {
  if (!data || typeof data !== 'object') return null;
  return (
    data.lastUpdated ||
    data.updatedAt ||
    data.createdAt ||
    data.dataModificarii ||
    null
  );
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) usage(0);

  const db = initAdmin();
  const collection = await detectCollection(db, args.collection);
  const targetResult = await resolveTargetDoc(db, collection, args.id, args.name);
  const target = targetResult.doc;
  const setEntries = args.sets.map(parseSet);

  const updatePayload = {};
  for (const item of setEntries) {
    updatePayload[item.path] = item.value;
  }
  Object.assign(updatePayload, buildTimestampPayload(collection));

  const current = target.data() || {};
  const currentName = current.name || current.nume || '(no name)';
  const currentTs = getCurrentTimestampPreview(current);

  console.log(`${args.dryRun ? '[DRY RUN]' : '[APPLY]'} Project: ${PROJECT_ID}`);
  console.log(`Target: ${target.id} (${currentName})`);
  console.log(`Collection: ${collection}`);
  if (targetResult.matchedField) {
    console.log(`Matched by field: ${targetResult.matchedField}`);
  }
  console.log(`Current timestamp: ${currentTs ? currentTs.toString() : 'null'}`);
  console.log('Planned fields:');
  for (const item of setEntries) {
    console.log(`- ${item.path} = ${JSON.stringify(item.value)}`);
  }
  for (const key of Object.keys(buildTimestampPayload(collection))) {
    console.log(`- ${key} = <serverTimestamp>`);
  }

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
