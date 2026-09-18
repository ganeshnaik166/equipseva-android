#!/usr/bin/env node
// Truth snapshot runner: executes every snapshot/*.sql through the Supabase CLI
// and writes one sorted, tab-separated file per query.
//
// Why TSV and not JSON: the schema has ~19k public functions and ~3.5k policies.
// One object per line, sorted by its natural key, makes `git diff` against the
// committed baseline read as "which object changed", and keeps review possible.
//
// Usage:
//   node supabase/regression/snapshot/run.mjs --target local  --out supabase/regression/baseline
//   node supabase/regression/snapshot/run.mjs --target prod   --out /tmp/prod-snapshot
//
// `--target local` runs `supabase db query -f` against the running local stack;
// `--target prod` adds `--linked` (read-only queries; needs SUPABASE_ACCESS_TOKEN
// or a prior `supabase login`). Set SUPABASE_BIN to point at a non-PATH CLI.
//
// The CLI returns `{ "rows": [ {...}, ... ] }` and prints a "boundary" warning
// wrapper around untrusted data; only the `rows` array is used.

import { spawnSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(
  process.argv.slice(2).map((a, i, all) => (a.startsWith("--") ? [a.slice(2), all[i + 1] ?? "true"] : []))
    .filter((p) => p.length === 2),
);
const target = args.target ?? "local";
const outDir = resolve(args.out ?? join(here, "..", "baseline"));
const supabase = process.env.SUPABASE_BIN ?? "supabase";
const only = args.only ? new Set(args.only.split(",")) : null;

if (!["local", "prod"].includes(target)) {
  console.error(`--target must be local or prod (got ${target})`);
  process.exit(2);
}
mkdirSync(outDir, { recursive: true });

// Natural sort keys per query: the first N columns of the SELECT are the key.
const KEY_COLUMNS = {
  functions: ["signature"],
  tables: ["table_name"],
  policies: ["table_name", "policy_name"],
};

const files = readdirSync(here).filter((f) => f.endsWith(".sql")).sort();
let failures = 0;
for (const file of files) {
  const name = file.replace(/\.sql$/, "");
  if (only && !only.has(name)) continue;
  const sqlPath = join(here, file);
  const cliArgs = ["db", "query", "-f", sqlPath];
  if (target === "prod") cliArgs.push("--linked");
  const started = Date.now();
  const res = spawnSync(supabase, cliArgs, { encoding: "utf8", maxBuffer: 512 * 1024 * 1024 });
  if (res.status !== 0) {
    failures++;
    console.error(`[${name}] supabase exited ${res.status}: ${(res.stderr || res.stdout || "").slice(0, 400)}`);
    continue;
  }
  const rows = extractRows(res.stdout, name);
  if (rows === null) { failures++; continue; }
  const columns = rows.length ? Object.keys(rows[0]) : [];
  const keys = KEY_COLUMNS[name] ?? columns.slice(0, 1);
  rows.sort((a, b) => compareBy(keys, a, b));
  const header = columns.join("\t");
  const body = rows.map((r) => columns.map((c) => cell(r[c])).join("\t"));
  writeFileSync(join(outDir, `${name}.tsv`), [header, ...body].join("\n") + "\n");
  console.log(`[${name}] ${rows.length} rows -> ${join(outDir, `${name}.tsv`)} (${Date.now() - started} ms)`);
}
process.exit(failures ? 1 : 0);

function extractRows(stdout, name) {
  // The CLI wraps JSON in human text; find the outermost object that has "rows".
  const start = stdout.indexOf("{");
  const end = stdout.lastIndexOf("}");
  if (start < 0 || end < 0) {
    console.error(`[${name}] no JSON in CLI output: ${stdout.slice(0, 200)}`);
    return null;
  }
  try {
    const parsed = JSON.parse(stdout.slice(start, end + 1));
    if (!Array.isArray(parsed.rows)) {
      console.error(`[${name}] CLI JSON has no rows array`);
      return null;
    }
    return parsed.rows;
  } catch (e) {
    console.error(`[${name}] could not parse CLI JSON: ${e.message}`);
    return null;
  }
}

function compareBy(keys, a, b) {
  for (const k of keys) {
    const x = String(a[k] ?? ""), y = String(b[k] ?? "");
    if (x < y) return -1;
    if (x > y) return 1;
  }
  return 0;
}

function cell(v) {
  if (v === null || v === undefined) return "";
  const s = typeof v === "string" ? v : JSON.stringify(v);
  // Tabs/newlines inside policy expressions would break the one-object-per-line contract.
  return s.replace(/\t/g, "\\t").replace(/\r?\n/g, "\\n");
}
