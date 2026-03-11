#!/usr/bin/env node

/**
 * Firestore audit + update planner for `departments` or `agencies`.
 *
 * Default mode is read-only (`--dry-run`).
 * Writes happen only with `--apply`.
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=u-s-departments-and-age-gnkn5k \
 *   GOOGLE_APPLICATION_CREDENTIALS=/abs/path/key.json \
 *   node scripts/firestore_audit_and_plan_updates.js --dry-run
 *
 *   MODEL=departments node scripts/firestore_audit_and_plan_updates.js --targets all --dry-run
 *   MODEL=agencies node scripts/firestore_audit_and_plan_updates.js --targets "Health,FAA" --stale-months 18 --dry-run
 *
 * Notes:
 * - Auto-detects model only when exactly one of `departments` / `agencies` has data.
 * - If both contain data, pass MODEL=departments|agencies (or --model).
 */

const admin = require('firebase-admin');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const fs = require('node:fs');

const DEFAULT_PROJECT_ID = 'u-s-departments-and-age-gnkn5k';
const VALID_MODELS = new Set(['departments', 'agencies']);
const SEVERITY_ORDER = {
  critical: 0,
  high: 1,
  medium: 2,
  low: 3,
};

const DEPARTMENT_CATEGORIES = new Set([
  'health',
  'education',
  'transportation',
  'finance',
  'security',
  'environment',
  'agriculture',
  'socialServices',
  'defense',
  'justice',
  'commerce',
  'labor',
  'energy',
  'housing',
  'veterans',
  'other',
]);

const ACRONYM_STOP_WORDS = new Set([
  'a',
  'an',
  'and',
  'for',
  'in',
  'of',
  'on',
  'the',
  'to',
  'u',
  's',
  'us',
  'united',
  'states',
  'department',
  'agency',
  'office',
  'administration',
]);

function usage(exitCode = 0) {
  console.log(`
Usage:
  node scripts/firestore_audit_and_plan_updates.js [options]

Options:
  --model <departments|agencies>   Optional. Overrides MODEL env.
  --targets <csv|all>              Optional. Name/category tokens (default: all).
  --stale-months <N>               Optional. Default: 12.
  --max-link-checks <N>            Optional. Default: 1200.
  --link-timeout-ms <N>            Optional. Default: 8000.
  --json-out <path>                Optional. Write full report JSON to file.
  --dry-run                        Read-only mode (default).
  --apply                          Apply planned updates.
  --help                           Show help.

Environment:
  FIREBASE_PROJECT_ID             Defaults to ${DEFAULT_PROJECT_ID}
  GOOGLE_APPLICATION_CREDENTIALS  Firebase Admin key path
  MODEL                           Optional fallback for --model

Safety:
  - No writes are done unless --apply is provided.
  - If both models have data and model is not forced, script exits with error.
`);
  process.exit(exitCode);
}

function parseArgs(argv) {
  const out = {
    projectId: process.env.FIREBASE_PROJECT_ID || DEFAULT_PROJECT_ID,
    model: process.env.MODEL || null,
    targetsRaw: 'all',
    staleMonths: 12,
    maxLinkChecks: 1200,
    linkTimeoutMs: 8000,
    jsonOut: null,
    apply: false,
    dryRun: true,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--model') {
      out.model = argv[++i] || null;
      continue;
    }
    if (arg === '--targets') {
      out.targetsRaw = argv[++i] || 'all';
      continue;
    }
    if (arg === '--stale-months') {
      const raw = argv[++i];
      const parsed = Number(raw);
      if (!Number.isFinite(parsed) || parsed < 0) {
        throw new Error(`Invalid --stale-months value: ${raw}`);
      }
      out.staleMonths = parsed;
      continue;
    }
    if (arg === '--max-link-checks') {
      const raw = argv[++i];
      const parsed = Number(raw);
      if (!Number.isFinite(parsed) || parsed < 0) {
        throw new Error(`Invalid --max-link-checks value: ${raw}`);
      }
      out.maxLinkChecks = parsed;
      continue;
    }
    if (arg === '--link-timeout-ms') {
      const raw = argv[++i];
      const parsed = Number(raw);
      if (!Number.isFinite(parsed) || parsed < 1000) {
        throw new Error(`Invalid --link-timeout-ms value: ${raw}`);
      }
      out.linkTimeoutMs = parsed;
      continue;
    }
    if (arg === '--json-out') {
      out.jsonOut = argv[++i] || null;
      if (!out.jsonOut) throw new Error('Missing value for --json-out');
      continue;
    }
    if (arg === '--apply') {
      out.apply = true;
      out.dryRun = false;
      continue;
    }
    if (arg === '--dry-run') {
      out.dryRun = true;
      out.apply = false;
      continue;
    }
    if (arg === '--help' || arg === '-h') {
      usage(0);
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (out.model && !VALID_MODELS.has(out.model)) {
    throw new Error(`Invalid model "${out.model}". Use departments|agencies`);
  }

  return out;
}

function initDb(projectId) {
  if (admin.apps.length === 0) {
    admin.initializeApp({ projectId });
  }
  return getFirestore();
}

async function detectModel(db, forcedModel) {
  if (forcedModel) return forcedModel;

  const [departmentsProbe, agenciesProbe] = await Promise.all([
    db.collection('departments').limit(1).get(),
    db.collection('agencies').limit(1).get(),
  ]);

  const hasDepartments = !departmentsProbe.empty;
  const hasAgencies = !agenciesProbe.empty;

  if (hasDepartments && !hasAgencies) return 'departments';
  if (hasAgencies && !hasDepartments) return 'agencies';

  if (hasDepartments && hasAgencies) {
    throw new Error(
      'Model detection is ambiguous because both `departments` and `agencies` contain data. Pass MODEL=departments|agencies (or --model).',
    );
  }

  throw new Error('No data found in either `departments` or `agencies`.');
}

function parseTargets(raw) {
  if (!raw || raw.trim().toLowerCase() === 'all') {
    return { all: true, tokens: [] };
  }
  const tokens = raw
    .split(',')
    .map((x) => x.trim())
    .filter(Boolean)
    .map((x) => x.toLowerCase());
  if (tokens.length === 0) {
    return { all: true, tokens: [] };
  }
  return { all: false, tokens };
}

function deepGet(obj, path) {
  if (!obj || typeof obj !== 'object') return undefined;
  const parts = path.split('.');
  let cursor = obj;
  for (const p of parts) {
    if (!cursor || typeof cursor !== 'object' || !(p in cursor)) return undefined;
    cursor = cursor[p];
  }
  return cursor;
}

function safeString(value) {
  return typeof value === 'string' ? value : '';
}

function isDocRefLike(value) {
  return !!(value && typeof value.path === 'string');
}

function toTimestampDate(value) {
  if (!value) return null;

  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') {
    try {
      return value.toDate();
    } catch (_) {
      return null;
    }
  }
  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
}

function monthsAgoDate(months) {
  const d = new Date();
  d.setMonth(d.getMonth() - months);
  return d;
}

function normalizeName(value) {
  return safeString(value)
    .toLowerCase()
    .replace(/[\(\)\[\]\{\}\.,'":;!?\-&/]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeNameTight(value) {
  return normalizeName(value).replace(/\s+/g, '');
}

function extractPrimaryName(model, data) {
  if (model === 'departments') {
    return safeString(data.name);
  }
  return safeString(data.nume || data.name || data.agencie_name);
}

function extractCategory(model, data) {
  if (model === 'departments') return safeString(data.category);
  return safeString(data.category);
}

function extractShortName(model, data) {
  if (model === 'departments') return safeString(data.shortName);
  return safeString(data.shortName || data.acronym);
}

function matchesTargets(model, data, targets, categoryRefNamesByPath) {
  if (targets.all) return true;

  const name = extractPrimaryName(model, data).toLowerCase();
  const shortName = extractShortName(model, data).toLowerCase();
  const category = extractCategory(model, data).toLowerCase();
  let categoryFromRef = '';

  if (model === 'agencies' && isDocRefLike(data.categorieRef)) {
    categoryFromRef = safeString(categoryRefNamesByPath.get(data.categorieRef.path)).toLowerCase();
  }

  for (const token of targets.tokens) {
    if (!token) continue;
    if (name === token || name.includes(token) || token.includes(name)) return true;
    if (shortName && (shortName === token || shortName.includes(token))) return true;
    if (category && category === token) return true;
    if (categoryFromRef && categoryFromRef === token) return true;
  }

  return false;
}

function stripHtml(html) {
  return safeString(html)
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

function extractHrefsFromHtml(html) {
  const out = [];
  const src = safeString(html);
  const regex = /href\s*=\s*["']([^"']+)["']/gi;
  let m;
  while ((m = regex.exec(src)) !== null) {
    out.push(m[1]);
  }
  return out;
}

function looksLikeDomain(text) {
  const value = safeString(text).trim();
  if (!value) return false;
  return /^[a-z0-9.-]+\.[a-z]{2,}(\/.*)?$/i.test(value);
}

function normalizeUrl(raw) {
  const original = safeString(raw).trim();
  if (!original) return null;

  if (/^(mailto:|tel:|javascript:|#)/i.test(original)) return null;

  let value = original;
  if (/^http\/\//i.test(value)) value = value.replace(/^http\/\//i, 'http://');
  if (/^https\/\//i.test(value)) value = value.replace(/^https\/\//i, 'https://');
  if (/^www\./i.test(value)) value = `https://${value}`;
  if (!/^https?:\/\//i.test(value) && looksLikeDomain(value)) {
    value = `https://${value}`;
  }

  try {
    const u = new URL(value);
    if (u.protocol !== 'http:' && u.protocol !== 'https:') return null;
    return u.toString();
  } catch (_) {
    return null;
  }
}

function canonicalUrlForComparison(raw) {
  const normalized = normalizeUrl(raw);
  if (!normalized) return null;
  try {
    const u = new URL(normalized);
    const protocol = u.protocol.toLowerCase();
    const host = u.hostname.toLowerCase();
    const port = u.port ? `:${u.port}` : '';
    let path = u.pathname || '';
    if (path === '/') path = '';
    if (path.length > 1 && path.endsWith('/')) path = path.slice(0, -1);
    return `${protocol}//${host}${port}${path}${u.search}`;
  } catch (_) {
    return null;
  }
}

function shouldPlanUrlNormalization(raw, normalized) {
  const rawValue = safeString(raw);
  const trimmed = rawValue.trim();
  if (!trimmed || !normalized) return false;

  const rawCanonical = canonicalUrlForComparison(trimmed);
  const normalizedCanonical = canonicalUrlForComparison(normalized);
  if (!rawCanonical || !normalizedCanonical) return false;

  if (rawCanonical !== normalizedCanonical) return true;

  // Preserve equivalent URLs unless the current value is clearly malformed.
  if (rawValue !== trimmed) return true;
  if (!/^https?:\/\//i.test(trimmed)) return true;
  if (/^https?\/\//i.test(trimmed)) return true;

  return false;
}

function normalizeEmail(raw) {
  return safeString(raw).trim().toLowerCase();
}

function isValidEmail(raw) {
  const value = normalizeEmail(raw);
  if (!value) return false;
  if (value.includes('..')) return false;
  return /^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$/i.test(value);
}

function parsePossiblePhone(raw) {
  const value = safeString(raw).trim();
  if (!value) return null;
  const digits = value.replace(/\D+/g, '');
  if (digits.length === 10) {
    return `+1-${digits.slice(0, 3)}-${digits.slice(3, 6)}-${digits.slice(6)}`;
  }
  if (digits.length === 11 && digits.startsWith('1')) {
    return `+1-${digits.slice(1, 4)}-${digits.slice(4, 7)}-${digits.slice(7)}`;
  }
  if (digits.length >= 7 && digits.length <= 15) {
    return value;
  }
  return null;
}

function isLikelyPhone(raw) {
  if (!safeString(raw).trim()) return false;
  return parsePossiblePhone(raw) !== null;
}

function hostnameFromUrl(rawUrl) {
  const normalized = normalizeUrl(rawUrl);
  if (!normalized) return null;
  try {
    const u = new URL(normalized);
    return u.hostname.toLowerCase().replace(/^www\./, '');
  } catch (_) {
    return null;
  }
}

function emailDomain(rawEmail) {
  const value = normalizeEmail(rawEmail);
  const idx = value.lastIndexOf('@');
  if (idx <= 0) return null;
  return value.slice(idx + 1).toLowerCase();
}

function rootDomain(host) {
  if (!host) return null;
  const parts = host.split('.').filter(Boolean);
  if (parts.length < 2) return host;
  return `${parts[parts.length - 2]}.${parts[parts.length - 1]}`;
}

function domainsLikelyMatch(emailDom, webHost) {
  if (!emailDom || !webHost) return true;
  if (emailDom === webHost) return true;
  if (emailDom.endsWith(`.${webHost}`) || webHost.endsWith(`.${emailDom}`)) return true;
  return rootDomain(emailDom) === rootDomain(webHost);
}

function extractAcronymFromName(name) {
  const m = safeString(name).match(/\(([A-Za-z0-9&.\- ]{2,20})\)\s*$/);
  if (!m) return null;
  return m[1].replace(/[^A-Za-z0-9]/g, '').toUpperCase();
}

function computeAcronym(name) {
  const words = normalizeName(name)
    .split(' ')
    .filter(Boolean)
    .filter((w) => !ACRONYM_STOP_WORDS.has(w));

  const source = words.length > 0 ? words : normalizeName(name).split(' ').filter(Boolean);
  if (source.length === 0) return '';
  return source.map((w) => w[0]).join('').toUpperCase();
}

function diceSimilarity(a, b) {
  const x = normalizeName(a);
  const y = normalizeName(b);
  if (!x || !y) return 0;
  if (x === y) return 1;
  if (x.length < 2 || y.length < 2) return 0;

  const bigrams = (s) => {
    const m = new Map();
    for (let i = 0; i < s.length - 1; i++) {
      const bg = s.slice(i, i + 2);
      m.set(bg, (m.get(bg) || 0) + 1);
    }
    return m;
  };

  const aMap = bigrams(x);
  const bMap = bigrams(y);

  let overlap = 0;
  for (const [bg, countA] of aMap.entries()) {
    const countB = bMap.get(bg) || 0;
    overlap += Math.min(countA, countB);
  }

  return (2 * overlap) / (x.length - 1 + (y.length - 1));
}

function hasContentQualityIssue(text) {
  const value = safeString(text);
  if (!value) return false;
  if (/lorem ipsum/i.test(value)) return true;
  if (/\s{3,}/.test(value)) return true;
  if (/!!+|\?\?+/.test(value)) return true;
  if (/\b(goverment|agencie|deparment|infromation)\b/i.test(value)) return true;
  return false;
}

function addFinding(store, finding) {
  store.push({
    severity: finding.severity,
    code: finding.code,
    collection: finding.collection,
    docId: finding.docId,
    name: finding.name || '(no name)',
    message: finding.message,
    details: finding.details || null,
  });
}

function getDocPath(collection, docId) {
  return `${collection}/${docId}`;
}

function buildDocInfo(model, doc) {
  const data = doc.data();
  return {
    collection: model,
    docId: doc.id,
    name: extractPrimaryName(model, data) || '(missing name)',
    data,
  };
}

function planUpdate(plans, docInfo, path, newValue, reason) {
  if (newValue === undefined) return;
  const current = deepGet(docInfo.data, path);
  if (current === newValue) return;

  const key = getDocPath(docInfo.collection, docInfo.docId);
  if (!plans.has(key)) {
    plans.set(key, {
      collection: docInfo.collection,
      docId: docInfo.docId,
      name: docInfo.name,
      update: {},
      reasons: [],
    });
  }

  const entry = plans.get(key);
  entry.update[path] = newValue;
  if (reason && !entry.reasons.includes(reason)) {
    entry.reasons.push(reason);
  }
}

function getBestTimestamp(data) {
  return (
    toTimestampDate(data.lastUpdated) ||
    toTimestampDate(data.updatedAt) ||
    toTimestampDate(data.dataModificarii) ||
    toTimestampDate(data.createdAt) ||
    toTimestampDate(data.dataPublicarii) ||
    null
  );
}

function collectModelLinks(model, data) {
  const out = [];

  if (model === 'departments') {
    const website = deepGet(data, 'contactInfo.website');
    if (website) out.push({ field: 'contactInfo.website', value: website, source: 'website' });

    const social = deepGet(data, 'contactInfo.socialMedia');
    if (social && typeof social === 'object' && !Array.isArray(social)) {
      for (const [network, url] of Object.entries(social)) {
        out.push({
          field: `contactInfo.socialMedia.${network}`,
          value: url,
          source: 'social',
        });
      }
    }
    return out;
  }

  const agencyLinkFields = ['website', 'facebook', 'youtube', 'contact'];
  for (const field of agencyLinkFields) {
    if (data[field]) {
      out.push({ field, value: data[field], source: field === 'website' ? 'website' : 'social' });
    }
  }

  const body = safeString(data.body);
  if (body) {
    for (const href of extractHrefsFromHtml(body)) {
      out.push({ field: 'body', value: href, source: 'bodyHtml' });
    }
  }

  return out;
}

async function runWithConcurrency(items, limit, worker) {
  const queue = [...items];
  const results = [];
  const runners = Array.from({ length: Math.max(1, limit) }, async () => {
    while (queue.length > 0) {
      const item = queue.shift();
      if (!item) break;
      // eslint-disable-next-line no-await-in-loop
      const result = await worker(item);
      results.push(result);
    }
  });
  await Promise.all(runners);
  return results;
}

async function fetchWithTimeout(url, method, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      method,
      redirect: 'follow',
      signal: controller.signal,
      headers: {
        'user-agent': 'firestore-audit-script/1.0',
      },
    });
    return response;
  } finally {
    clearTimeout(timer);
  }
}

async function checkUrlStatus(url, timeoutMs) {
  try {
    let response;
    try {
      response = await fetchWithTimeout(url, 'HEAD', timeoutMs);
      if ([405, 501].includes(response.status)) {
        response = await fetchWithTimeout(url, 'GET', timeoutMs);
      }
    } catch (_) {
      response = await fetchWithTimeout(url, 'GET', timeoutMs);
    }

    return {
      ok: response.status >= 200 && response.status < 400,
      status: response.status,
      finalUrl: response.url || url,
      error: null,
    };
  } catch (error) {
    return {
      ok: false,
      status: null,
      finalUrl: url,
      error: error && error.message ? error.message : 'request_failed',
    };
  }
}

function summarizePayload(payload) {
  const keys = Object.keys(payload || {});
  return keys.length === 0 ? '{}' : JSON.stringify(payload);
}

function severityForLinkFailure(status) {
  if (status === null) return 'medium';
  if (status >= 500) return 'medium';
  if (status >= 400) return 'high';
  return 'low';
}

async function auditModel(db, model, options) {
  const findings = [];
  const plannedUpdates = new Map();
  const targets = parseTargets(options.targetsRaw);
  const staleCutoff = monthsAgoDate(options.staleMonths);

  const [snap, categoriesSnap, litereSnap, litereCategorieSnap] = await Promise.all([
    db.collection(model).get(),
    model === 'agencies' ? db.collection('categories').get() : Promise.resolve(null),
    model === 'agencies' ? db.collection('litere').get() : Promise.resolve(null),
    model === 'agencies' ? db.collection('litereCategorie').get() : Promise.resolve(null),
  ]);

  const categoryRefNamesByPath = new Map();
  const categoryNameSet = new Set();
  if (categoriesSnap) {
    for (const doc of categoriesSnap.docs) {
      categoryRefNamesByPath.set(doc.ref.path, safeString(doc.get('nume')));
      categoryNameSet.add(safeString(doc.get('nume')).toLowerCase());
    }
  }

  const litereRefByPath = new Set();
  if (litereSnap) {
    for (const doc of litereSnap.docs) {
      litereRefByPath.add(doc.ref.path);
    }
  }

  const litereCategorieRefByPath = new Set();
  if (litereCategorieSnap) {
    for (const doc of litereCategorieSnap.docs) {
      litereCategorieRefByPath.add(doc.ref.path);
    }
  }

  const docs = snap.docs.map((doc) => buildDocInfo(model, doc)).filter((docInfo) =>
    matchesTargets(model, docInfo.data, targets, categoryRefNamesByPath),
  );

  const docIds = new Set(docs.map((d) => d.docId));

  const linksToCheck = [];
  const normalizedNameBuckets = new Map();

  for (const docInfo of docs) {
    const { data } = docInfo;
    const name = docInfo.name;
    const normalizedName = normalizeNameTight(name);
    if (normalizedName) {
      if (!normalizedNameBuckets.has(normalizedName)) normalizedNameBuckets.set(normalizedName, []);
      normalizedNameBuckets.get(normalizedName).push(docInfo);
    }

    if (!name || name === '(missing name)') {
      addFinding(findings, {
        severity: 'high',
        code: 'MISSING_REQUIRED_NAME',
        collection: model,
        docId: docInfo.docId,
        name: docInfo.name,
        message: 'Missing required name/title field.',
      });
    } else if (name !== name.trim()) {
      planUpdate(plannedUpdates, docInfo, model === 'departments' ? 'name' : data.nume ? 'nume' : data.name ? 'name' : 'agencie_name', name.trim(), 'Trimmed surrounding whitespace in name');
    }

    const category = extractCategory(model, data);
    if (model === 'departments') {
      if (!category) {
        addFinding(findings, {
          severity: 'high',
          code: 'MISSING_REQUIRED_CATEGORY',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: 'Missing required category.',
        });
      } else if (!DEPARTMENT_CATEGORIES.has(category)) {
        const match = [...DEPARTMENT_CATEGORIES].find((x) => x.toLowerCase() === category.toLowerCase());
        addFinding(findings, {
          severity: 'high',
          code: 'INVALID_CATEGORY_VALUE',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: `Invalid category value: "${category}".`,
        });
        if (match) {
          planUpdate(plannedUpdates, docInfo, 'category', match, 'Normalized category to canonical enum value');
        }
      }
    } else {
      if (category && categoryNameSet.size > 0 && !categoryNameSet.has(category.toLowerCase())) {
        addFinding(findings, {
          severity: 'high',
          code: 'INVALID_CATEGORY_VALUE',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: `Category "${category}" does not exist in categories collection.`,
        });
      }
      if (isDocRefLike(data.categorieRef) && !categoryRefNamesByPath.has(data.categorieRef.path)) {
        addFinding(findings, {
          severity: 'high',
          code: 'BROKEN_CATEGORY_REFERENCE',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: `categorieRef points to missing document: ${data.categorieRef.path}.`,
        });
      }
      if (isDocRefLike(data.literaRef) && !litereCategorieRefByPath.has(data.literaRef.path)) {
        addFinding(findings, {
          severity: 'high',
          code: 'BROKEN_LETTER_REFERENCE',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: `literaRef points to missing document: ${data.literaRef.path}.`,
        });
      }
      if (isDocRefLike(data.agencieREF) && !litereRefByPath.has(data.agencieREF.path) && !docIds.has(data.agencieREF.id)) {
        addFinding(findings, {
          severity: 'high',
          code: 'ORPHAN_REFERENCE',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: `agencieREF appears orphaned: ${data.agencieREF.path}.`,
        });
      }
    }

    const description =
      model === 'departments'
        ? safeString(data.description)
        : safeString(data.description || data.shortDescription || stripHtml(data.body));

    if (!description.trim()) {
      addFinding(findings, {
        severity: 'high',
        code: 'MISSING_REQUIRED_DESCRIPTION',
        collection: model,
        docId: docInfo.docId,
        name: docInfo.name,
        message: 'Missing required description/body content.',
      });
    } else {
      if (description !== description.trim()) {
        const path = model === 'departments' ? 'description' : data.description ? 'description' : data.shortDescription ? 'shortDescription' : null;
        if (path) {
          planUpdate(plannedUpdates, docInfo, path, description.trim(), 'Trimmed description whitespace');
        }
      }
      if (description.trim().length < 40) {
        addFinding(findings, {
          severity: 'medium',
          code: 'DESCRIPTION_TOO_SHORT',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: `Description appears too short (${description.trim().length} chars).`,
        });
      }
      if (hasContentQualityIssue(description)) {
        addFinding(findings, {
          severity: 'low',
          code: 'CONTENT_QUALITY_WARNING',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: 'Possible typo/content-quality issue detected in description.',
        });
      }
    }

    if (model === 'departments') {
      const requiredDepartmentFields = ['shortName', 'services', 'keywords', 'isActive', 'contactInfo'];
      for (const field of requiredDepartmentFields) {
        const value = data[field];
        if (value === undefined || value === null) {
          addFinding(findings, {
            severity: 'high',
            code: 'MISSING_REQUIRED_FIELD',
            collection: model,
            docId: docInfo.docId,
            name: docInfo.name,
            message: `Missing required field "${field}".`,
          });
        }
      }

      if (Array.isArray(data.services) && data.services.length === 0) {
        addFinding(findings, {
          severity: 'medium',
          code: 'EMPTY_REQUIRED_LIST',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: 'Required list "services" is empty.',
        });
      }
      if (Array.isArray(data.keywords) && data.keywords.length === 0) {
        addFinding(findings, {
          severity: 'medium',
          code: 'EMPTY_REQUIRED_LIST',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: 'Required list "keywords" is empty.',
        });
      }

      const parentId = safeString(data.parentDepartmentId).trim();
      if (parentId && !docIds.has(parentId)) {
        addFinding(findings, {
          severity: 'high',
          code: 'ORPHAN_PARENT_REFERENCE',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: `parentDepartmentId points to missing document: ${parentId}.`,
        });
      }
    }

    const emailPath =
      model === 'departments'
        ? 'contactInfo.email'
        : data.email !== undefined
          ? 'email'
          : deepGet(data, 'contactInfo.email') !== undefined
            ? 'contactInfo.email'
            : null;

    const phonePath =
      model === 'departments'
        ? 'contactInfo.phone'
        : data.phone_number !== undefined
          ? 'phone_number'
          : data.toll_free !== undefined
            ? 'toll_free'
            : deepGet(data, 'contactInfo.phone') !== undefined
              ? 'contactInfo.phone'
              : null;

    const websitePath =
      model === 'departments'
        ? 'contactInfo.website'
        : data.website !== undefined
          ? 'website'
          : deepGet(data, 'contactInfo.website') !== undefined
            ? 'contactInfo.website'
            : null;

    const emailValue = emailPath ? safeString(deepGet(data, emailPath)).trim() : '';
    const phoneValue = phonePath ? safeString(deepGet(data, phonePath)).trim() : '';
    const websiteValue = websitePath ? safeString(deepGet(data, websitePath)).trim() : '';

    if (!websiteValue) {
      addFinding(findings, {
        severity: 'medium',
        code: 'MISSING_CONTACT_FIELD',
        collection: model,
        docId: docInfo.docId,
        name: docInfo.name,
        message: 'Missing/empty website contact field.',
      });
    } else {
      const normalized = normalizeUrl(websiteValue);
      if (!normalized) {
        addFinding(findings, {
          severity: 'high',
          code: 'MALFORMED_WEBSITE',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: `Malformed website URL: "${websiteValue}".`,
        });
      }
    }

    if (!phoneValue) {
      addFinding(findings, {
        severity: 'medium',
        code: 'MISSING_CONTACT_FIELD',
        collection: model,
        docId: docInfo.docId,
        name: docInfo.name,
        message: 'Missing/empty phone contact field.',
      });
    } else if (!isLikelyPhone(phoneValue)) {
      addFinding(findings, {
        severity: 'high',
        code: 'MALFORMED_PHONE',
        collection: model,
        docId: docInfo.docId,
        name: docInfo.name,
        message: `Malformed phone value: "${phoneValue}".`,
      });
    } else {
      const normalizedPhone = parsePossiblePhone(phoneValue);
      if (normalizedPhone && normalizedPhone !== phoneValue) {
        planUpdate(plannedUpdates, docInfo, phonePath, normalizedPhone, 'Normalized phone format');
      }
    }

    if (!emailValue) {
      addFinding(findings, {
        severity: 'medium',
        code: 'MISSING_CONTACT_FIELD',
        collection: model,
        docId: docInfo.docId,
        name: docInfo.name,
        message: 'Missing/empty email contact field.',
      });
    } else if (!isValidEmail(emailValue)) {
      addFinding(findings, {
        severity: 'high',
        code: 'MALFORMED_EMAIL',
        collection: model,
        docId: docInfo.docId,
        name: docInfo.name,
        message: `Malformed email value: "${emailValue}".`,
      });
    } else {
      const normalizedEmail = normalizeEmail(emailValue);
      if (normalizedEmail !== emailValue) {
        planUpdate(plannedUpdates, docInfo, emailPath, normalizedEmail, 'Normalized email casing/whitespace');
      }
    }

    const shortName = extractShortName(model, data);
    if (shortName) {
      const trailingAcronym = extractAcronymFromName(name);
      if (trailingAcronym && trailingAcronym !== shortName.toUpperCase()) {
        addFinding(findings, {
          severity: 'medium',
          code: 'TITLE_ACRONYM_MISMATCH',
          collection: model,
          docId: docInfo.docId,
          name: docInfo.name,
          message: `Title acronym "${trailingAcronym}" does not match shortName "${shortName}".`,
        });
      } else if (!trailingAcronym) {
        const expected = computeAcronym(name);
        if (
          expected &&
          shortName.length > 1 &&
          shortName.length <= 10 &&
          expected !== shortName.toUpperCase()
        ) {
          addFinding(findings, {
            severity: 'low',
            code: 'POSSIBLE_ACRONYM_MISMATCH',
            collection: model,
            docId: docInfo.docId,
            name: docInfo.name,
            message: `Computed acronym "${expected}" differs from shortName "${shortName}".`,
          });
        }
      }
    }

    const websiteHost = hostnameFromUrl(websiteValue);
    const mailDomain = emailDomain(emailValue);
    if (websiteHost && mailDomain && !domainsLikelyMatch(mailDomain, websiteHost)) {
      addFinding(findings, {
        severity: 'medium',
        code: 'CROSS_FIELD_DOMAIN_MISMATCH',
        collection: model,
        docId: docInfo.docId,
        name: docInfo.name,
        message: `Email domain "${mailDomain}" does not match website domain "${websiteHost}".`,
      });
    }

    const ts = getBestTimestamp(data);
    if (ts && ts < staleCutoff) {
      addFinding(findings, {
        severity: 'medium',
        code: 'STALE_RECORD',
        collection: model,
        docId: docInfo.docId,
        name: docInfo.name,
        message: `Record appears stale (timestamp ${ts.toISOString().slice(0, 10)} older than ${options.staleMonths} months).`,
      });
    }

    for (const link of collectModelLinks(model, data)) {
      linksToCheck.push({
        docInfo,
        field: link.field,
        source: link.source,
        raw: safeString(link.value),
      });
    }

    if (hasContentQualityIssue(name)) {
      addFinding(findings, {
        severity: 'low',
        code: 'CONTENT_QUALITY_WARNING',
        collection: model,
        docId: docInfo.docId,
        name: docInfo.name,
        message: 'Possible typo/content-quality issue in name/title.',
      });
    }
  }

  // Exact duplicates
  for (const [normName, list] of normalizedNameBuckets.entries()) {
    if (!normName || list.length < 2) continue;
    for (const docInfo of list) {
      addFinding(findings, {
        severity: 'high',
        code: 'DUPLICATE_NAME_EXACT',
        collection: model,
        docId: docInfo.docId,
        name: docInfo.name,
        message: `Exact duplicate normalized name detected (${list.length} docs share "${normName}").`,
      });
    }
  }

  // Near-duplicate names
  const nearPairs = [];
  const nearDocs = docs.slice(0, 800); // hard cap for N^2 scan safety
  for (let i = 0; i < nearDocs.length; i++) {
    for (let j = i + 1; j < nearDocs.length; j++) {
      const a = nearDocs[i];
      const b = nearDocs[j];
      if (!a.name || !b.name) continue;
      if (normalizeNameTight(a.name) === normalizeNameTight(b.name)) continue;
      const sim = diceSimilarity(a.name, b.name);
      if (sim >= 0.93) {
        nearPairs.push({ a, b, sim });
      }
    }
  }
  for (const pair of nearPairs.slice(0, 60)) {
    addFinding(findings, {
      severity: 'medium',
      code: 'DUPLICATE_NAME_NEAR',
      collection: model,
      docId: pair.a.docId,
      name: pair.a.name,
      message: `Near-duplicate name similarity ${pair.sim.toFixed(2)} with ${pair.b.docId} (${pair.b.name}).`,
    });
    addFinding(findings, {
      severity: 'medium',
      code: 'DUPLICATE_NAME_NEAR',
      collection: model,
      docId: pair.b.docId,
      name: pair.b.name,
      message: `Near-duplicate name similarity ${pair.sim.toFixed(2)} with ${pair.a.docId} (${pair.a.name}).`,
    });
  }

  // Link checks with caching
  const cached = new Map();
  let linkChecksAttempted = 0;
  let linkChecksSkipped = 0;

  const normalizedLinkJobs = [];
  for (const item of linksToCheck) {
    const normalized = normalizeUrl(item.raw);
    if (!normalized) {
      if (item.raw && !/^(mailto:|tel:|javascript:|#)/i.test(item.raw)) {
        addFinding(findings, {
          severity: 'high',
          code: 'MALFORMED_URL',
          collection: item.docInfo.collection,
          docId: item.docInfo.docId,
          name: item.docInfo.name,
          message: `Malformed URL in ${item.field}: "${item.raw}".`,
        });
      }
      continue;
    }

    normalizedLinkJobs.push({ ...item, normalized });

    if (item.field !== 'body' && shouldPlanUrlNormalization(item.raw, normalized)) {
      planUpdate(
        plannedUpdates,
        item.docInfo,
        item.field,
        normalized,
        `Normalized URL in ${item.field}`,
      );
    }
  }

  const uniqueUrls = [];
  for (const job of normalizedLinkJobs) {
    if (!cached.has(job.normalized)) {
      cached.set(job.normalized, null);
      uniqueUrls.push(job.normalized);
    }
  }

  const maxUrls = Math.min(uniqueUrls.length, options.maxLinkChecks);
  const urlsToCheck = uniqueUrls.slice(0, maxUrls);
  linkChecksSkipped = uniqueUrls.length - urlsToCheck.length;

  const checkedResults = await runWithConcurrency(
    urlsToCheck,
    10,
    async (url) => ({ url, result: await checkUrlStatus(url, options.linkTimeoutMs) }),
  );

  for (const { url, result } of checkedResults) {
    cached.set(url, result);
    linkChecksAttempted += 1;
  }

  for (const item of normalizedLinkJobs) {
    const result = cached.get(item.normalized);
    if (!result) continue;
    if (result.ok) continue;

    addFinding(findings, {
      severity: severityForLinkFailure(result.status),
      code: item.source === 'bodyHtml' ? 'BROKEN_BODY_HTML_LINK' : 'BROKEN_LINK',
      collection: item.docInfo.collection,
      docId: item.docInfo.docId,
      name: item.docInfo.name,
      message:
        `Broken ${item.source} link in ${item.field}: ${item.normalized}` +
        (result.status ? ` (HTTP ${result.status})` : ` (${result.error || 'request failed'})`),
    });
  }

  findings.sort((a, b) => {
    const sa = SEVERITY_ORDER[a.severity] ?? 9;
    const sb = SEVERITY_ORDER[b.severity] ?? 9;
    if (sa !== sb) return sa - sb;
    if (a.collection !== b.collection) return a.collection.localeCompare(b.collection);
    if (a.docId !== b.docId) return a.docId.localeCompare(b.docId);
    return a.code.localeCompare(b.code);
  });

  const planned = [...plannedUpdates.values()]
    .map((item) => ({
      ...item,
      update: Object.fromEntries(
        Object.entries(item.update).sort((a, b) => a[0].localeCompare(b[0])),
      ),
    }))
    .filter((item) => Object.keys(item.update).length > 0)
    .sort((a, b) => a.docId.localeCompare(b.docId));

  return {
    model,
    scannedCount: docs.length,
    totalInCollection: snap.size,
    findings,
    planned,
    metrics: {
      linkChecksAttempted,
      linkChecksSkipped,
      uniqueLinks: uniqueUrls.length,
      staleMonths: options.staleMonths,
      targets: targets.all ? 'all' : targets.tokens.join(', '),
    },
  };
}

async function applyUpdates(db, planned) {
  if (planned.length === 0) return { applied: 0 };
  let applied = 0;

  const chunks = [];
  const copy = [...planned];
  while (copy.length > 0) {
    chunks.push(copy.splice(0, 400));
  }

  for (const chunk of chunks) {
    const batch = db.batch();
    for (const item of chunk) {
      const ref = db.collection(item.collection).doc(item.docId);
      const timestampPatch =
        item.collection === 'departments'
          ? { lastUpdated: FieldValue.serverTimestamp() }
          : { lastUpdated: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() };
      batch.update(ref, { ...item.update, ...timestampPatch });
    }
    // eslint-disable-next-line no-await-in-loop
    await batch.commit();
    applied += chunk.length;
  }

  return { applied };
}

function printReport(result, options) {
  const severityCounts = { critical: 0, high: 0, medium: 0, low: 0 };
  for (const f of result.findings) {
    severityCounts[f.severity] = (severityCounts[f.severity] || 0) + 1;
  }

  console.log(
    `${options.dryRun ? '[DRY RUN]' : '[APPLY]'} model=${result.model} project=${options.projectId}`,
  );
  console.log(
    `scanned=${result.scannedCount}/${result.totalInCollection} targets=${result.metrics.targets} stale_months=${result.metrics.staleMonths}`,
  );
  console.log(
    `findings: critical=${severityCounts.critical} high=${severityCounts.high} medium=${severityCounts.medium} low=${severityCounts.low}`,
  );
  console.log(
    `links: unique=${result.metrics.uniqueLinks} checked=${result.metrics.linkChecksAttempted} skipped_due_to_cap=${result.metrics.linkChecksSkipped}`,
  );
  console.log(`planned_writes=${result.planned.length}`);

  if (result.findings.length === 0) {
    console.log('No findings detected.');
  } else {
    console.log('\n=== Findings (ordered by severity) ===');
    for (const f of result.findings) {
      console.log(
        `${f.severity.toUpperCase()} | ${f.code} | ${f.collection}/${f.docId} | ${f.name} | ${f.message}`,
      );
    }
  }

  console.log('\n=== Planned Firestore update payloads ===');
  if (result.planned.length === 0) {
    console.log('(none)');
  } else {
    for (const item of result.planned) {
      console.log(
        `${item.collection}/${item.docId} | ${item.name} | ${summarizePayload(item.update)} | reasons=${item.reasons.join('; ')}`,
      );
    }
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const db = initDb(options.projectId);
  const model = await detectModel(db, options.model);
  const result = await auditModel(db, model, options);
  if (options.jsonOut) {
    fs.writeFileSync(options.jsonOut, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
  }
  printReport(result, options);

  if (options.apply) {
    const { applied } = await applyUpdates(db, result.planned);
    console.log(`\nApplied writes: ${applied}`);
  } else {
    console.log('\nNo writes applied. Re-run with --apply to commit planned updates.');
  }
}

main().catch((error) => {
  console.error(`Failed: ${error && error.message ? error.message : error}`);
  process.exitCode = 1;
});
