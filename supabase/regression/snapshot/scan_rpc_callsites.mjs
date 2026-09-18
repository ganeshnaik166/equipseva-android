#!/usr/bin/env node
// Scans the three client code bases for PostgREST RPC call sites and writes a
// sorted TSV of (function, caller_role, file, line) so the grants ratchet can
// prove every name a client calls (a) exists and (b) is executable by the role
// that client runs as. A renamed or never-granted RPC is otherwise invisible
// until a user hits 42501 / PGRST202 in production.
//
// Syntax variants covered (verified against the repo):
//   Kotlin  : .rpc("name" …)            .rpc(function = "name" …)
//             .rpc(\n   function = "name"   (multi-line; the name is on the next line)
//   TS/TSX  : .rpc("name" …)            .rpc('name' …)
// Roles: app/src/main (Kotlin) and web/src call as `authenticated`; edge functions
// under supabase/functions use the service-role client.
//
// Usage: node supabase/regression/snapshot/scan_rpc_callsites.mjs --repo <root> --out <dir>

import { readdirSync, readFileSync, statSync, writeFileSync, mkdirSync } from "node:fs";
import { join, relative, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(
  process.argv.slice(2).map((a, i, all) => (a.startsWith("--") ? [a.slice(2), all[i + 1] ?? "true"] : []))
    .filter((p) => p.length === 2),
);
const repo = resolve(args.repo ?? join(here, "..", "..", ".."));
const outDir = resolve(args.out ?? join(here, "..", "baseline"));
mkdirSync(outDir, { recursive: true });

const TREES = [
  { root: "app/src/main", role: "authenticated", exts: [".kt"] },
  { root: "web/src", role: "authenticated", exts: [".ts", ".tsx"] },
  { root: "supabase/functions", role: "service_role", exts: [".ts"] },
];

// `.rpc(` followed (possibly across a newline) by an optional `function =` and a quoted name.
const CALL = /\.rpc\(\s*(?:function\s*=\s*)?["']([a-zA-Z_][a-zA-Z0-9_]*)["']/g;

const rows = [];
for (const tree of TREES) {
  const base = join(repo, tree.root);
  for (const file of walk(base, tree.exts)) {
    const text = readFileSync(file, "utf8");
    let m;
    while ((m = CALL.exec(text)) !== null) {
      const line = text.slice(0, m.index).split("\n").length;
      rows.push({ function: m[1], caller_role: tree.role, file: relative(repo, file).replace(/\\/g, "/"), line });
    }
  }
}
rows.sort((a, b) => a.function.localeCompare(b.function) || a.file.localeCompare(b.file) || a.line - b.line);
const out = join(outDir, "rpc_callsites.tsv");
writeFileSync(out, ["function\tcaller_role\tfile\tline", ...rows.map((r) => `${r.function}\t${r.caller_role}\t${r.file}\t${r.line}`)].join("\n") + "\n");
const distinct = new Set(rows.map((r) => r.function)).size;
console.log(`${rows.length} call sites, ${distinct} distinct functions -> ${out}`);

function* walk(dir, exts) {
  let entries;
  try { entries = readdirSync(dir); } catch { return; }
  for (const name of entries) {
    if (name === "node_modules" || name === ".next" || name === "build") continue;
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) yield* walk(p, exts);
    else if (exts.some((e) => name.endsWith(e))) yield p;
  }
}
