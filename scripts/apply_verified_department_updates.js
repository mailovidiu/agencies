#!/usr/bin/env node

/**
 * One-shot script: apply verified department contact updates.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/service-account.json \
 *   FIREBASE_PROJECT_ID=u-s-departments-and-age-gnkn5k \
 *   node scripts/apply_verified_department_updates.js
 *
 * Optional:
 *   --dry-run   Print planned updates without writing to Firestore.
 *   DATA_MODEL=departments|agencies   Force model instead of auto-detect.
 *
 * Notes:
 * - Requires `firebase-admin` in your Node environment.
 * - Uses Application Default Credentials (recommended with GOOGLE_APPLICATION_CREDENTIALS).
 * - Auto-detects data model:
 *   1) `departments` collection (name/contactInfo schema)
 *   2) `agencies` collection (nume/body HTML schema)
 */

const admin = require('firebase-admin');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID =
  process.env.FIREBASE_PROJECT_ID || 'u-s-departments-and-age-gnkn5k';
const DRY_RUN = process.argv.includes('--dry-run');
const FORCED_MODEL = process.env.DATA_MODEL;

// Verified fixes for `departments` model, matched by `name`.
const DEPARTMENTS_UPDATES = [
  {
    name: 'National Health Information Center',
    update: {
      'contactInfo.website': 'https://www.womenshealth.gov',
    },
  },
  {
    name: 'Joint Congressional Committee on Inaugural Ceremonies',
    update: {
      'contactInfo.phone': '+1-202-224-0400',
    },
  },
  {
    name: 'Joint Program Executive Office for Chemical, Biological, Radiological and Nuclear Defense',
    update: {
      'contactInfo.phone': '+1-410-436-9000',
      'contactInfo.email': 'usarmy.apg.mbx.cpe-cbrnd-public-affairs@army.mil',
    },
  },
  {
    name: 'National Reconnaissance Office',
    update: {
      'contactInfo.phone': '+1-703-808-5050',
      'contactInfo.email': 'publicaffairs@nro.mil',
    },
  },
];

// Verified fixes for `agencies` model, matched by `nume`.
const AGENCIES_UPDATES = [
  {
    nume: 'National Health Information Center (NHIC)',
  },
  {
    nume: 'Joint Congressional Committee on Inaugural Ceremonies (JCCIC)',
  },
  {
    nume: 'Joint Program Executive Office for Chemical, Biological, Radiological and Nuclear Defense (JPEO-CBRND)',
  },
  {
    nume: 'National Reconnaissance Office (NRO)',
  },
];

function initializeFirebaseAdmin() {
  if (admin.apps.length === 0) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  return getFirestore();
}

function replacePhoneBlock(body, telValue, displayValue) {
  const regex =
    /(<h2>\s*Phone Number\s*<\/h2>\s*<p>\s*<a href="tel:)[^"]*("[^>]*>)[^<]*(<\/a>\s*<\/p>)/i;
  if (!regex.test(body)) {
    return { body, changed: false, note: 'Phone Number block not found' };
  }
  const updated = body.replace(regex, `$1${telValue}$2${displayValue}$3`);
  return {
    body: updated,
    changed: updated !== body,
    note: updated !== body ? `Phone Number set to ${displayValue}` : null,
  };
}

function ensureEmailSection(body, email) {
  if (body.toLowerCase().includes(email.toLowerCase())) {
    return { body, changed: false, note: null };
  }

  const section =
    `\n<div>\n    <h2>Email</h2>\n    <p><a href="mailto:${email}">${email}</a></p>\n</div>`;

  const contactDivRegex = /<div>\s*<h2>\s*Contact\s*<\/h2>[\s\S]*?<\/div>/i;
  if (contactDivRegex.test(body)) {
    const updated = body.replace(contactDivRegex, (match) => `${match}${section}`);
    return {
      body: updated,
      changed: true,
      note: `Email section inserted (${email})`,
    };
  }

  return {
    body: `${body}${section}`,
    changed: true,
    note: `Email section appended (${email})`,
  };
}

function updateNhicWebsite(body) {
  const regex =
    /(<h2>\s*Website\s*<\/h2>\s*<a href=")[^"]*("[^>]*>\s*National Health Information Center\s*<\/a>)/i;
  if (!regex.test(body)) {
    return { body, changed: false, note: 'Website block not found for NHIC' };
  }
  const updated = body.replace(regex, '$1https://www.womenshealth.gov$2');
  return {
    body: updated,
    changed: updated !== body,
    note:
      updated !== body
        ? 'Website set to https://www.womenshealth.gov'
        : null,
  };
}

function mutateAgencyBody(nume, body) {
  let updated = body;
  const notes = [];

  if (nume === 'National Health Information Center (NHIC)') {
    const websiteResult = updateNhicWebsite(updated);
    updated = websiteResult.body;
    if (websiteResult.note) notes.push(websiteResult.note);
  }

  if (nume === 'Joint Congressional Committee on Inaugural Ceremonies (JCCIC)') {
    const phoneResult = replacePhoneBlock(updated, '12022240400', '1-202-224-0400');
    updated = phoneResult.body;
    if (phoneResult.note) notes.push(phoneResult.note);
  }

  if (
    nume ===
    'Joint Program Executive Office for Chemical, Biological, Radiological and Nuclear Defense (JPEO-CBRND)'
  ) {
    const phoneResult = replacePhoneBlock(updated, '1-410-436-9000', '1-410-436-9000');
    updated = phoneResult.body;
    if (phoneResult.note) notes.push(phoneResult.note);

    const emailResult = ensureEmailSection(
      updated,
      'usarmy.apg.mbx.cpe-cbrnd-public-affairs@army.mil',
    );
    updated = emailResult.body;
    if (emailResult.note) notes.push(emailResult.note);
  }

  if (nume === 'National Reconnaissance Office (NRO)') {
    const phoneResult = replacePhoneBlock(updated, '17038085050', '1-703-808-5050');
    updated = phoneResult.body;
    if (phoneResult.note) notes.push(phoneResult.note);

    const emailResult = ensureEmailSection(updated, 'publicaffairs@nro.mil');
    updated = emailResult.body;
    if (emailResult.note) notes.push(emailResult.note);
  }

  return {
    body: updated,
    changed: updated !== body,
    notes,
  };
}

async function resolveUniqueDocs(collectionRef, field, values) {
  const resolved = [];
  const missing = [];
  const ambiguous = [];

  for (const value of values) {
    const snap = await collectionRef.where(field, '==', value).get();
    if (snap.empty) {
      missing.push(value);
      continue;
    }
    if (snap.docs.length > 1) {
      ambiguous.push({
        value,
        docIds: snap.docs.map((doc) => doc.id),
      });
      continue;
    }
    resolved.push({
      value,
      doc: snap.docs[0],
    });
  }

  return { resolved, missing, ambiguous };
}

async function runDepartmentsModel(db) {
  const collection = db.collection('departments');
  const { resolved, missing, ambiguous } = await resolveUniqueDocs(
    collection,
    'name',
    DEPARTMENTS_UPDATES.map((x) => x.name),
  );

  if (missing.length > 0) {
    throw new Error(
      `Aborting: ${missing.length} target name(s) not found: ${missing.join(', ')}`,
    );
  }

  if (ambiguous.length > 0) {
    const details = ambiguous
      .map((x) => `${x.value} -> [${x.docIds.join(', ')}]`)
      .join('; ');
    throw new Error(
      `Aborting: ambiguous matches for ${ambiguous.length} target name(s): ${details}`,
    );
  }

  const plan = resolved.map((entry) => {
    const target = DEPARTMENTS_UPDATES.find((x) => x.name === entry.value);
    return {
      docRef: entry.doc.ref,
      docId: entry.doc.id,
      label: entry.value,
      update: target.update,
    };
  });

  console.log(
    `${DRY_RUN ? '[DRY RUN]' : '[APPLY]'} Project: ${PROJECT_ID}, collection: departments`,
  );
  console.log(`Planned updates: ${plan.length}`);
  for (const item of plan) {
    console.log(`- ${item.docId} (${item.label}): ${JSON.stringify(item.update)}`);
  }

  if (DRY_RUN) {
    console.log('No changes written.');
    return;
  }

  const batch = db.batch();
  for (const item of plan) {
    batch.update(item.docRef, {
      ...item.update,
      lastUpdated: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  console.log(`Done. Applied ${plan.length} update(s).`);
}

async function runAgenciesModel(db) {
  const collection = db.collection('agencies');
  const { resolved, missing, ambiguous } = await resolveUniqueDocs(
    collection,
    'nume',
    AGENCIES_UPDATES.map((x) => x.nume),
  );

  if (missing.length > 0) {
    throw new Error(
      `Aborting: ${missing.length} target agency name(s) not found: ${missing.join(', ')}`,
    );
  }

  if (ambiguous.length > 0) {
    const details = ambiguous
      .map((x) => `${x.value} -> [${x.docIds.join(', ')}]`)
      .join('; ');
    throw new Error(
      `Aborting: ambiguous matches for ${ambiguous.length} agency name(s): ${details}`,
    );
  }

  const plan = resolved.map((entry) => {
    const original = String(entry.doc.get('body') || '');
    const result = mutateAgencyBody(entry.value, original);
    return {
      docRef: entry.doc.ref,
      docId: entry.doc.id,
      label: entry.value,
      changed: result.changed,
      notes: result.notes,
      body: result.body,
    };
  });

  console.log(
    `${DRY_RUN ? '[DRY RUN]' : '[APPLY]'} Project: ${PROJECT_ID}, collection: agencies`,
  );
  console.log(`Targets scanned: ${plan.length}`);
  for (const item of plan) {
    const status = item.changed ? 'CHANGED' : 'UNCHANGED';
    const note = item.notes.length ? ` | ${item.notes.join('; ')}` : '';
    console.log(`- ${item.docId} (${item.label}): ${status}${note}`);
  }

  const changed = plan.filter((x) => x.changed);
  console.log(`Planned writes: ${changed.length}`);

  if (DRY_RUN) {
    console.log('No changes written.');
    return;
  }

  if (changed.length === 0) {
    console.log('No updates required.');
    return;
  }

  const batch = db.batch();
  for (const item of changed) {
    batch.update(item.docRef, { body: item.body });
  }
  await batch.commit();
  console.log(`Done. Applied ${changed.length} update(s).`);
}

async function detectModel(db) {
  if (FORCED_MODEL === 'departments' || FORCED_MODEL === 'agencies') {
    return FORCED_MODEL;
  }

  const departmentsProbe = await db.collection('departments').limit(1).get();
  if (!departmentsProbe.empty) {
    return 'departments';
  }

  const agenciesProbe = await db.collection('agencies').limit(1).get();
  if (!agenciesProbe.empty) {
    return 'agencies';
  }

  return null;
}

async function main() {
  const db = initializeFirebaseAdmin();
  const model = await detectModel(db);

  if (!model) {
    throw new Error(
      'Unable to detect data model. Neither `departments` nor `agencies` contains documents.',
    );
  }

  if (model === 'departments') {
    await runDepartmentsModel(db);
    return;
  }

  if (model === 'agencies') {
    await runAgenciesModel(db);
    return;
  }

  throw new Error(`Unsupported model: ${model}`);
}

main().catch((error) => {
  console.error('Failed to apply updates:', error.message || error);
  process.exitCode = 1;
});
