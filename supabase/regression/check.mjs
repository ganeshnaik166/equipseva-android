#!/usr/bin/env node
// The ratchet. Reads a snapshot directory (see snapshot/run.mjs + snapshot/scan_rpc_callsites.mjs)
// and fails when the backend surface drifts into one of the shapes that has broken production before.
//
// Checks
//   T2-MISSING      a name a client calls with `.rpc("…")` does not exist in the database at all.
//                   Symptom in the app: PGRST202 and a dead screen.
//   T2-NO-GRANT     it exists, but the role that client runs as has no EXECUTE. This is the class that
//                   shipped SECURITY DEFINER RPCs with no `GRANT EXECUTE TO authenticated` and left web
//                   pages and app features silently 42501 for weeks.
//   T1-ANON-FOUNDER a `founder_*` function is executable by `anon`. Even with an internal is_founder()
//                   gate this is one edit away from an unauthenticated read of founder data.
//   T1-PUBLIC-GRANT EXECUTE is granted to PUBLIC, which is how Supabase's default privileges publish a
//                   freshly created function unless the migration revokes it.
//   T4-NO-SEARCH-PATH  a SECURITY DEFINER function without a pinned search_path (privilege escalation via
//                   a caller-controlled schema).
//   T5-RLS-OFF      a public table with row-level security disabled: readable by every authenticated user
//                   through PostgREST.
//
// Everything is compared against allowlists under `allow/`, one object per line with a `#` reason
// comment required above each block. A finding that is understood and accepted belongs in an allowlist
// with its reason; a finding that is not belongs in a fix.
//
// Usage:
//   node supabase/regression/check.mjs --snapshot <dir> [--json <out.json>]
// Exit codes: 0 clean, 1 findings, 2 usage/IO error.

import { existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(
  process.argv.slice(2).map((a, i, all) => (a.startsWith("--") ? [a.slice(2), all[i + 1] ?? "true"] : []))
    .filter((p) => p.length === 2),
);
const snapDir = resolve(args.snapshot ?? join(here, "baseline"));
for (const f of ["functions.tsv", "tables.tsv", "rpc_callsites.tsv"]) {
  if (!existsSync(join(snapDir, f))) {
    console.error(`missing ${f} in ${snapDir} — run snapshot/run.mjs and snapshot/scan_rpc_callsites.mjs first`);
    process.exit(2);
  }
}

const functions = readTsv(join(snapDir, "functions.tsv"));
const tables = readTsv(join(snapDir, "tables.tsv"));
const callsites = readTsv(join(snapDir, "rpc_callsites.tsv"));

// A signature is "name(arg,arg)"; PostgREST resolves by name + supplied argument names, so for grant
// purposes every overload of a name is a candidate and the client succeeds if ANY of them is callable.
const byName = new Map();
for (const f of functions) {
  const name = f.signature.replace(/\(.*$/, "");
  if (!byName.has(name)) byName.set(name, []);
  byName.get(name).push(f);
}

const allow = {
  missing: readAllow("rpc_missing.txt"),
  noGrant: readAllow("rpc_no_grant.txt"),
  anonFounder: readAllow("anon_founder.txt"),
  publicGrant: readAllow("public_execute.txt"),
  noSearchPath: readAllow("secdef_no_search_path.txt"),
  rlsOff: readAllow("rls_off.txt"),
};

const findings = [];
const seenCall = new Map(); // name|role -> first file:line, for one finding per (name, role)
for (const c of callsites) {
  const key = `${c.function}|${c.caller_role}`;
  if (seenCall.has(key)) continue;
  seenCall.set(key, `${c.file}:${c.line}`);
  const overloads = byName.get(c.function);
  if (!overloads) {
    if (!allow.missing.has(c.function)) {
      findings.push({ check: "T2-MISSING", object: c.function, role: c.caller_role, at: `${c.file}:${c.line}`,
        detail: "called by a client but no function of that name exists" });
    }
    continue;
  }
  const col = c.caller_role === "service_role" ? "exec_service_role"
    : c.caller_role === "anon" ? "exec_anon" : "exec_authenticated";
  if (!overloads.some((o) => o[col] === "true")) {
    if (!allow.noGrant.has(c.function)) {
      findings.push({ check: "T2-NO-GRANT", object: c.function, role: c.caller_role, at: `${c.file}:${c.line}`,
        detail: `no overload grants EXECUTE to ${c.caller_role} (${overloads.length} overload(s))` });
    }
  }
}

for (const f of functions) {
  const name = f.signature.replace(/\(.*$/, "");
  if (f.exec_anon === "true" && name.startsWith("founder_") && !allow.anonFounder.has(name)) {
    findings.push({ check: "T1-ANON-FOUNDER", object: f.signature, detail: "founder-only surface is executable by anon" });
  }
  if (f.exec_public === "true" && !allow.publicGrant.has(name)) {
    findings.push({ check: "T1-PUBLIC-GRANT", object: f.signature, detail: "EXECUTE granted to PUBLIC (Supabase default-ACL trap)" });
  }
  if (f.security_definer === "true" && f.kind === "f" && !/search_path=/.test(f.proconfig) && !allow.noSearchPath.has(name)) {
    findings.push({ check: "T4-NO-SEARCH-PATH", object: f.signature, detail: "SECURITY DEFINER without a pinned search_path" });
  }
}

for (const t of tables) {
  if (t.rls_enabled !== "true" && !allow.rlsOff.has(t.table_name)) {
    findings.push({ check: "T5-RLS-OFF", object: t.table_name, detail: "public table with row-level security disabled" });
  }
}

const byCheck = {};
for (const f of findings) byCheck[f.check] = (byCheck[f.check] ?? 0) + 1;
console.log(`snapshot: ${snapDir}`);
console.log(`functions ${functions.length} · tables ${tables.length} · distinct rpc names called ${byName.size ? new Set(callsites.map((c) => c.function)).size : 0}`);
console.log(`allowlisted: ${Object.entries(allow).map(([k, v]) => `${k}=${v.size}`).join(" ")}`);
if (!findings.length) {
  console.log("PASS — no findings");
} else {
  console.log(`FAIL — ${findings.length} finding(s): ${Object.entries(byCheck).map(([k, v]) => `${k}=${v}`).join(" ")}`);
  const shown = findings.slice(0, 60);
  for (const f of shown) {
    console.log(`  ${f.check}\t${f.object}${f.role ? ` [${f.role}]` : ""}\t${f.detail}${f.at ? `\t${f.at}` : ""}`);
  }
  if (findings.length > shown.length) console.log(`  … ${findings.length - shown.length} more (use --json for the full list)`);
}
if (args.json) writeFileSync(resolve(args.json), JSON.stringify({ counts: byCheck, findings }, null, 2));
process.exit(findings.length ? 1 : 0);

function readTsv(path) {
  const lines = readFileSync(path, "utf8").split(/\r?\n/).filter((l) => l.length);
  const header = lines[0].split("\t");
  return lines.slice(1).map((l) => {
    const cells = l.split("\t");
    return Object.fromEntries(header.map((h, i) => [h, cells[i] ?? ""]));
  });
}

function readAllow(file) {
  const p = join(here, "allow", file);
  if (!existsSync(p)) return new Set();
  return new Set(
    readFileSync(p, "utf8").split(/\r?\n/)
      .map((l) => l.replace(/#.*$/, "").trim())
      .filter((l) => l.length),
  );
}
