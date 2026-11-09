#!/usr/bin/env node
// Storage backup / restore (photos, videos, documents, site files).
//   node tool/backup_files.mjs backup  <dir>    download every file
//   node tool/backup_files.mjs restore <dir>    upload them again (overwrites)
// Needs SUPABASE_URL and SUPABASE_SECRET_KEY (defaults: web/.env.local).
// The secret key bypasses all rules: run this only on a trusted machine.
import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const localEnv = (() => {
  try {
    return Object.fromEntries(
      readFileSync(join(root, 'web/.env.local'), 'utf8').split('\n').filter((l) => /^[A-Z_]+=/.test(l))
        .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).trim()]),
    );
  } catch {
    return {};
  }
})();
const API = process.env.SUPABASE_URL ?? localEnv.NEXT_PUBLIC_SUPABASE_URL;
const SECRET = process.env.SUPABASE_SECRET_KEY ?? localEnv.SUPABASE_SECRET_KEY;
const headers = { apikey: SECRET, authorization: `Bearer ${SECRET}` };
const [mode, dir] = process.argv.slice(2);
if (!['backup', 'restore'].includes(mode) || !dir || !API || !SECRET) {
  console.error('usage: node tool/backup_files.mjs backup|restore <dir>  (needs SUPABASE_URL, SUPABASE_SECRET_KEY)');
  process.exit(2);
}

async function api(path, init = {}) {
  const response = await fetch(`${API}/storage/v1${path}`, { ...init, headers: { ...headers, ...init.headers } });
  if (!response.ok) throw new Error(`${init.method ?? 'GET'} ${path}: ${response.status} ${await response.text()}`);
  return response;
}

async function listAll(bucket, prefix = '') {
  const files = [];
  for (let offset = 0; ; offset += 1000) {
    const items = await (await api(`/object/list/${bucket}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ prefix, limit: 1000, offset, sortBy: { column: 'name', order: 'asc' } }),
    })).json();
    for (const item of items) {
      const path = prefix ? `${prefix}/${item.name}` : item.name;
      if (item.id === null) files.push(...(await listAll(bucket, path)));
      else files.push({ path, type: item.metadata?.mimetype ?? 'application/octet-stream', size: item.metadata?.size ?? 0 });
    }
    if (items.length < 1000) break;
  }
  return files;
}

if (mode === 'backup') {
  const buckets = await (await api('/bucket')).json();
  const manifest = {};
  let total = 0;
  for (const bucket of buckets) {
    const files = await listAll(bucket.id);
    manifest[bucket.id] = files;
    for (const file of files) {
      const target = join(dir, bucket.id, file.path);
      mkdirSync(dirname(target), { recursive: true });
      const response = await api(`/object/${bucket.id}/${file.path.split('/').map(encodeURIComponent).join('/')}`);
      writeFileSync(target, Buffer.from(await response.arrayBuffer()));
      total++;
    }
    console.log(`${bucket.id}: ${files.length} files`);
  }
  writeFileSync(join(dir, 'manifest.json'), JSON.stringify(manifest, null, 1));
  console.log(`Backed up ${total} files to ${dir}`);
} else {
  const manifest = JSON.parse(readFileSync(join(dir, 'manifest.json'), 'utf8'));
  let total = 0;
  for (const [bucket, files] of Object.entries(manifest)) {
    for (const file of files) {
      await api(`/object/${bucket}/${file.path.split('/').map(encodeURIComponent).join('/')}`, {
        method: 'POST',
        headers: { 'content-type': file.type, 'x-upsert': 'true' },
        body: readFileSync(join(dir, bucket, file.path)),
      });
      total++;
    }
    console.log(`${bucket}: ${files.length} files restored`);
  }
  console.log(`Restored ${total} files from ${dir}`);
}
