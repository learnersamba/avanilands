#!/usr/bin/env node
// Phase 9 security checks over HTTP (the database rules are in supabase/tests).
//
//   node tool/security_check.mjs                      # local (reads web/.env.local and the seed logins)
//   WEB_URL=https://staging.example.com SUPABASE_URL=… SUPABASE_PUBLISHABLE_KEY=… \
//   ADMIN_EMAIL=… ADMIN_PASSWORD=… VISITOR_EMAIL=… VISITOR_PASSWORD=… node tool/security_check.mjs
//
// Never point it at production with real admin details: it uploads (and then
// deletes) small test files.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const localEnv = (() => {
  try {
    return Object.fromEntries(
      readFileSync(join(root, 'web/.env.local'), 'utf8')
        .split('\n')
        .filter((line) => /^[A-Z_]+=/.test(line))
        .map((line) => [line.slice(0, line.indexOf('=')), line.slice(line.indexOf('=') + 1).trim()]),
    );
  } catch {
    return {};
  }
})();
// Local test logins come from the seed file (never used for other environments).
const seedLogin = (email) => {
  const match = readFileSync(join(root, 'supabase/seed.sql'), 'utf8').match(new RegExp(`${email}\\s*/\\s*(\\S+)`));
  return match?.[1];
};

const WEB = process.env.WEB_URL ?? 'http://localhost:3100';
const API = process.env.SUPABASE_URL ?? localEnv.NEXT_PUBLIC_SUPABASE_URL;
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY ?? localEnv.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const ADMIN = [process.env.ADMIN_EMAIL ?? 'admin@avanilands.test'];
ADMIN.push(process.env.ADMIN_PASSWORD ?? seedLogin(ADMIN[0]));
const VISITOR = [process.env.VISITOR_EMAIL ?? 'visitor@avanilands.test'];
VISITOR.push(process.env.VISITOR_PASSWORD ?? seedLogin(VISITOR[0]));
const production = WEB.startsWith('https://');

let failed = 0;
const check = (ok, label, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail && !ok ? ` — ${detail}` : ''}`);
  if (!ok) failed++;
};

async function signIn([email, password]) {
  const response = await fetch(`${API}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: KEY, 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const json = await response.json();
  if (!json.access_token) throw new Error(`Sign-in failed for ${email}: ${json.msg ?? json.error_description}`);
  return json.access_token;
}

const call = (path, token, init = {}) =>
  fetch(`${API}${path}`, {
    ...init,
    headers: { apikey: KEY, authorization: `Bearer ${token ?? KEY}`, 'content-type': 'application/json', ...init.headers },
  });

/** True when the request was refused or returned nothing. */
async function refusedOrEmpty(response) {
  if (!response.ok) return true;
  const text = await response.text();
  return text === '[]' || text === '' || text === 'null';
}

// ---------------------------------------------------------------------------
console.log(`Website ${WEB}\nSupabase ${API}\n`);

// 1. No server secrets in anything sent to browsers
{
  const secrets = ['SUPABASE_SECRET_KEY', 'REVALIDATE_SECRET', 'TURNSTILE_SECRET_KEY', 'IP_HASH_SALT', 'RESEND_API_KEY']
    .map((name) => [name, localEnv[name]])
    .filter(([, value]) => value && value.length >= 8);
  const files = [];
  const walk = (dir) => {
    for (const name of readdirSync(dir)) {
      const path = join(dir, name);
      if (statSync(path).isDirectory()) walk(path);
      else if (/\.(js|html|json|css|txt|map)$/.test(name)) files.push(path);
    }
  };
  for (const dir of ['web/.next/static', 'admin/build/web']) {
    try {
      walk(join(root, dir));
    } catch {
      console.log(`(skipped ${dir}: not built)`);
    }
  }
  const leaks = [];
  for (const file of files) {
    const text = readFileSync(file, 'utf8');
    for (const [name, value] of secrets) if (text.includes(value)) leaks.push(`${name} in ${file}`);
    if (/sb_secret_[A-Za-z0-9]/.test(text) || /"role"\s*:\s*"service_role"/.test(text)) leaks.push(`secret-looking key in ${file}`);
  }
  check(files.length > 0 && leaks.length === 0, `no server secrets in ${files.length} browser files`, leaks.join(', '));
}

// 2. Security headers on the website
{
  const response = await fetch(`${WEB}/`, { redirect: 'manual' });
  const h = response.headers;
  const csp = h.get('content-security-policy') ?? '';
  check(csp.includes("default-src 'self'") && csp.includes("frame-ancestors 'none'") && csp.includes("object-src 'none'"),
    'Content-Security-Policy is strict', csp);
  check(h.get('x-content-type-options') === 'nosniff', 'X-Content-Type-Options: nosniff');
  check(h.get('x-frame-options') === 'DENY', 'X-Frame-Options: DENY');
  check(Boolean(h.get('referrer-policy')), 'Referrer-Policy set');
  check((h.get('permissions-policy') ?? '').includes('camera=()'), 'Permissions-Policy set');
  check(!h.get('x-powered-by'), 'no X-Powered-By');
  if (production) {
    check((h.get('strict-transport-security') ?? '').includes('max-age='), 'HSTS on HTTPS');
    const http = await fetch(WEB.replace('https://', 'http://'), { redirect: 'manual' });
    check([301, 307, 308].includes(http.status), 'plain HTTP redirects to HTTPS', String(http.status));
  }
}

// 3. Website endpoints
{
  const response = await fetch(`${WEB}/api/revalidate`, { method: 'POST', body: '{"table":"properties"}' });
  check(response.status === 401, 'cache refresh refuses callers without the secret', String(response.status));
  const forged = await fetch(`${WEB}/api/revalidate`, {
    method: 'POST',
    headers: { 'x-revalidate-secret': 'guess' },
    body: '{"table":"properties"}',
  });
  check(forged.status === 401, 'cache refresh refuses a wrong secret', String(forged.status));
}

const adminToken = await signIn(ADMIN);
const visitorToken = await signIn(VISITOR);

// 4. Private data through the API, as a visitor (anon) and a signed-in non-admin
for (const [who, token] of [['anon', null], ['signed-in non-admin', visitorToken]]) {
  for (const table of ['properties', 'enquiries', 'enquiry_notes', 'admin_users', 'audit_logs', 'site_settings',
    'property_documents', 'property_slug_history', 'contact_taps', 'page_views']) {
    check(await refusedOrEmpty(await call(`/rest/v1/${table}?select=*&limit=1`, token)), `${who} cannot read ${table}`);
  }
  for (const [fn, body] of [
    ['dashboard_summary', {}],
    ['submit_enquiry', { p_name: 'Bot', p_phone: '9876543210' }],
    ['log_contact_tap', { p_channel: 'call' }],
    ['update_enquiry_status', { p_enquiry_id: '00000000-0000-0000-0000-000000000000', p_status: 'closed' }],
    ['delete_draft_property', { p_property_id: '10000000-0000-4000-a000-000000000011' }],
    ['track_page_view', { p_client: 'a'.repeat(64), p_path: '/' }],
    ['analytics_report', { p_from: '2026-01-01', p_to: '2026-01-31' }],
    ['cleanup_analytics', {}],
  ]) {
    const response = await call(`/rest/v1/rpc/${fn}`, token, { method: 'POST', body: JSON.stringify(body) });
    check(!response.ok, `${who} cannot call ${fn}`, `${response.status}`);
  }
  const patch = await call('/rest/v1/locations?id=not.is.null', token, {
    method: 'PATCH',
    headers: { prefer: 'return=representation' },
    body: JSON.stringify({ is_active: false }),
  });
  check(await refusedOrEmpty(patch), `${who} cannot change locations`);
  const insert = await call('/rest/v1/property_images', token, {
    method: 'POST',
    body: JSON.stringify({ property_id: '10000000-0000-4000-a000-000000000001', storage_path: 'x' }),
  });
  check(!insert.ok, `${who} cannot add photos`, String(insert.status));
}

// Website statistics endpoint: tells a caller nothing, takes nothing big
{
  const page = await fetch(`${WEB}/api/track`);
  check(page.status === 405, 'page tracker only accepts POST', String(page.status));
  const big = await fetch(`${WEB}/api/track`, { method: 'POST', body: 'x'.repeat(5000) });
  check(big.status === 204, 'page tracker ignores oversized input quietly', String(big.status));
  const crossSite = await fetch(`${WEB}/api/track`, {
    method: 'POST',
    headers: { 'sec-fetch-site': 'cross-site', 'content-type': 'application/json' },
    body: JSON.stringify({ path: '/' }),
  });
  check(crossSite.status === 204, 'page tracker answers other sites without counting', String(crossSite.status));
}

// Expired / forged sign-in tokens
{
  const forged = adminToken.split('.').slice(0, 2).join('.') + '.forged-signature';
  const response = await call('/rest/v1/enquiries?select=id&limit=1', forged);
  check(response.status === 401, 'a forged admin token is refused', String(response.status));
}

// 5. Storage
const upload = (bucket, path, token, body, type) =>
  fetch(`${API}/storage/v1/object/${bucket}/${path}`, {
    method: 'POST',
    headers: { apikey: KEY, authorization: `Bearer ${token ?? KEY}`, 'content-type': type, 'x-upsert': 'true' },
    body,
  });
const remove = (bucket, path) =>
  fetch(`${API}/storage/v1/object/${bucket}`, {
    method: 'DELETE',
    headers: { apikey: KEY, authorization: `Bearer ${adminToken}`, 'content-type': 'application/json' },
    body: JSON.stringify({ prefixes: [path] }),
  });
{
  const webp = Buffer.from('RIFF\x1a\x00\x00\x00WEBPVP8L\x0d\x00\x00\x00\x2f\x00\x00\x00\x10\x07\x10\x11\x11\x88\x88\xfe\x07\x00', 'latin1');
  for (const [who, token] of [['anon', null], ['signed-in non-admin', visitorToken]]) {
    const response = await upload('property-media', 'security-check/visitor.webp', token, webp, 'image/webp');
    check(!response.ok, `${who} cannot upload photos`, String(response.status));
  }
  const page = await upload('property-media', 'security-check/page.html', adminToken, '<script>alert(1)</script>', 'text/html');
  check(!page.ok, 'even admins cannot upload HTML to the photo bucket', String(page.status));
  const exe = await upload('property-documents', 'security-check/tool.exe', adminToken, 'MZ', 'application/x-msdownload');
  check(!exe.ok, 'documents bucket refuses programs', String(exe.status));
  const big = await upload('property-documents', 'security-check/big.pdf', adminToken, Buffer.alloc(21 * 1024 * 1024), 'application/pdf');
  check(!big.ok, 'documents bucket refuses files over 20 MB', String(big.status));
  const fine = await upload('property-media', 'security-check/ok.webp', adminToken, webp, 'image/webp');
  check(fine.ok, 'admins can upload a real photo', String(fine.status));
  await remove('property-media', 'security-check/ok.webp');

  // Private documents: no public URL, no listing for visitors
  const docs = await (await call('/rest/v1/property_documents?select=id,storage_path&is_public=eq.false&limit=1', adminToken)).json();
  if (docs[0]) {
    const direct = await fetch(`${API}/storage/v1/object/public/property-documents/${docs[0].storage_path}`);
    check(!direct.ok, 'private document has no public link', String(direct.status));
    const asVisitor = await fetch(`${API}/storage/v1/object/property-documents/${docs[0].storage_path}`, {
      headers: { apikey: KEY, authorization: `Bearer ${visitorToken}` },
    });
    check(!asVisitor.ok, 'signed-in non-admin cannot download a private document', String(asVisitor.status));
    const viaWebsite = await fetch(`${WEB}/api/documents/${docs[0].id}`, { redirect: 'manual' });
    check(viaWebsite.status === 404, 'website will not hand out a private document', String(viaWebsite.status));
  } else {
    console.log('(no private document to test)');
  }
}

console.log(failed ? `\n${failed} FAILED` : '\nALL PASSED');
process.exit(failed ? 1 : 0);
