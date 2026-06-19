import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Workflow failure modes catalog — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type FailureMode = {
  class: string;
  example: string;
  caught_by: "audit-workflow" | "pre-flight Python" | "build/typecheck" | "first runtime call";
  first_seen_batch: string;
  fix_strategy: string;
  severity: "critical" | "high" | "medium" | "low";
};

const FAILURES: FailureMode[] = [
  {
    class: "Column doesn't exist",
    example: "profiles.city (removed in earlier sweep); engineer_payouts.amount_inr (real: amount_rupees)",
    caught_by: "audit-workflow",
    first_seen_batch: "Pre-r1163 (sweep audit caught 23 bugs)",
    fix_strategy: "Adversarial audit workflow per design batch; design brief lists known-bad column names",
    severity: "critical",
  },
  {
    class: "Table doesn't exist",
    example: "amc_pool_ledger (real: amc_payment_pool)",
    caught_by: "audit-workflow",
    first_seen_batch: "Batch 3 (r1209)",
    fix_strategy: "Audit verifies every CREATE TABLE existence; design brief lists known-bad table names",
    severity: "critical",
  },
  {
    class: "FK semantics drift",
    example: "repair_jobs.engineer_id is FK to engineers.id, not profiles.id — silent false matches",
    caught_by: "audit-workflow",
    first_seen_batch: "Pre-r1163",
    fix_strategy: "Design brief explicitly states the FK target for ambiguous foreign keys",
    severity: "high",
  },
  {
    class: "CHECK enum value invalid",
    example: "repair_jobs.kind = 'amc' (real CHECK allows only repair/maintenance)",
    caught_by: "audit-workflow",
    first_seen_batch: "Batch 5 (r1225)",
    fix_strategy: "Audit cross-references CHECK constraints; design brief lists enum values",
    severity: "high",
  },
  {
    class: "Dead-literal in WHERE",
    example: "status IN ('processed','paid') where 'paid' never appears in the CHECK enum",
    caught_by: "audit-workflow",
    first_seen_batch: "Batch 3 (r1208, r1211)",
    fix_strategy: "Audit flags filter values that can never match; cleanup migration",
    severity: "low",
  },
  {
    class: "LANGUAGE sql + no is_founder gate",
    example: "Function generated as LANGUAGE sql with REVOKE...FROM authenticated; GRANT...TO authenticated; — any logged-in user can call",
    caught_by: "pre-flight Python",
    first_seen_batch: "Batch 10 (r1269, r1272, r1274)",
    fix_strategy: "Python regex converts LANGUAGE sql to plpgsql + injects IF NOT public.is_founder() block",
    severity: "critical",
  },
  {
    class: "REVOKE/GRANT direction wrong",
    example: "REVOKE FROM PUBLIC, anon, authenticated; then GRANT TO authenticated — functionally OK but semantically wrong",
    caught_by: "pre-flight Python",
    first_seen_batch: "Batch 6+10",
    fix_strategy: "Python regex normalizes to standard pattern",
    severity: "low",
  },
  {
    class: "GRANT to service_role instead of authenticated",
    example: "Workflow agent over-conservative; founder page would 401",
    caught_by: "pre-flight Python",
    first_seen_batch: "Batch 6 (r1231)",
    fix_strategy: "Python regex swaps service_role → authenticated (is_founder gate in body remains)",
    severity: "high",
  },
  {
    class: "Missing BEGIN; or COMMIT;",
    example: "Workflow agent skips transaction wrapper",
    caught_by: "pre-flight Python",
    first_seen_batch: "Batch 7 (r1238)",
    fix_strategy: "Python ensures BEGIN; prepended + COMMIT; appended",
    severity: "medium",
  },
  {
    class: "Missing DROP FUNCTION IF EXISTS",
    example: "Re-deploys with signature changes silently fail",
    caught_by: "pre-flight Python",
    first_seen_batch: "Batch 7",
    fix_strategy: "Python injects DROP IF EXISTS before CREATE OR REPLACE",
    severity: "medium",
  },
  {
    class: "Missing STABLE qualifier",
    example: "Postgres can't optimize; minor perf",
    caught_by: "pre-flight Python",
    first_seen_batch: "Batch 7",
    fix_strategy: "Python injects STABLE after LANGUAGE plpgsql",
    severity: "low",
  },
  {
    class: "Duplicate STABLE keyword (regex artifact)",
    example: "After convert-from-sql conversion, two STABLE lines",
    caught_by: "build/typecheck (supabase db push parse error)",
    first_seen_batch: "Batch 10",
    fix_strategy: "Python regex collapses adjacent STABLE",
    severity: "low",
  },
  {
    class: "HTML-escaped JSX in page.tsx",
    example: "`&amp;&amp;` instead of `&&`; `&lt;div&gt;` instead of `<div>` in JS code",
    caught_by: "pre-flight Python (build would fail too)",
    first_seen_batch: "Batch 9 (r1262)",
    fix_strategy: "Python un-escape pass; surgical to JSX text contexts where appropriate",
    severity: "high",
  },
  {
    class: "'use client' + non-existent client import",
    example: "import { createClient } from '@/lib/supabase/client' — module doesn't exist",
    caught_by: "build/typecheck",
    first_seen_batch: "Batch 9 (r1262 risk-score)",
    fix_strategy: "Manual rewrite as server-component matching standard template",
    severity: "high",
  },
  {
    class: "Raw `>=` / `<=` in JSX text",
    example: "`<p>SLA &ge; 60 min</p>` works; `<p>SLA >= 60 min</p>` fails JSX parser",
    caught_by: "build/typecheck",
    first_seen_batch: "Batch 7 (r1240)",
    fix_strategy: "Manual replace with HTML entities",
    severity: "medium",
  },
  {
    class: "Direct file writes despite no-write instruction",
    example: "Workflow agents create migration + page.tsx on disk with potentially-colliding timestamps",
    caught_by: "git status sweep",
    first_seen_batch: "Batches 2-3 (workflows wxq6jth6i + wlx035lgv)",
    fix_strategy: "Renumber timestamps in Python; supabase migration repair --status reverted for orphans",
    severity: "medium",
  },
  {
    class: "Duplicate domain scout (overlap with prior batch)",
    example: "Batch 12 picked spot_audit_responses + duplicate_account_flags already shipped",
    caught_by: "manual dedup at extraction",
    first_seen_batch: "Batch 12",
    fix_strategy: "Strengthen scout brief with full covered-domains list; skip duplicates at extract",
    severity: "low",
  },
  {
    class: "Double-suffix slug (e.g. /X-snapshot-snapshot-summary)",
    example: "Domain key ends in -snapshot + template appends -summary",
    caught_by: "pre-flight Python",
    first_seen_batch: "Batches 2-3",
    fix_strategy: "Python normalize: keep -snapshot, drop appended -summary if redundant",
    severity: "low",
  },
];

const SEVERITY_TONE: Record<FailureMode["severity"], string> = {
  critical: "text-[var(--color-danger)]",
  high:     "text-[var(--color-warn)]",
  medium:   "text-[var(--color-info)]",
  low:      "text-[var(--color-muted)]",
};

const counts = {
  critical: FAILURES.filter(f => f.severity === "critical").length,
  high:     FAILURES.filter(f => f.severity === "high").length,
  medium:   FAILURES.filter(f => f.severity === "medium").length,
  low:      FAILURES.filter(f => f.severity === "low").length,
  audit:    FAILURES.filter(f => f.caught_by === "audit-workflow").length,
  python:   FAILURES.filter(f => f.caught_by === "pre-flight Python").length,
  build:    FAILURES.filter(f => f.caught_by === "build/typecheck").length,
};

export default async function WorkflowFailureModesCatalogPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Workflow failure modes catalog ★ r1302</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">{FAILURES.length} distinct failure modes observed across 12 design batches · all caught pre-deploy</p>
      </header>

      <section className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <div className="rounded-lg border-2 border-[var(--color-danger)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Critical</div>
          <div className="mt-1 text-2xl font-semibold tabular-nums">{counts.critical}</div>
        </div>
        <div className="rounded-lg border-2 border-[var(--color-warn)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">High</div>
          <div className="mt-1 text-2xl font-semibold tabular-nums">{counts.high}</div>
        </div>
        <div className="rounded-lg border-2 border-[var(--color-info)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Medium</div>
          <div className="mt-1 text-2xl font-semibold tabular-nums">{counts.medium}</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Low</div>
          <div className="mt-1 text-2xl font-semibold tabular-nums">{counts.low}</div>
        </div>
      </section>

      <section className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Caught by audit workflow</div>
          <div className="mt-1 text-xl font-semibold tabular-nums">{counts.audit}</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Caught by pre-flight Python</div>
          <div className="mt-1 text-xl font-semibold tabular-nums">{counts.python}</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Caught by build/typecheck</div>
          <div className="mt-1 text-xl font-semibold tabular-nums">{counts.build}</div>
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Failure mode catalog</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                <th className="py-2 pr-3">Class</th>
                <th className="py-2 pr-3">Example</th>
                <th className="py-2 pr-3">Severity</th>
                <th className="py-2 pr-3">Caught by</th>
                <th className="py-2 pr-3">First seen</th>
                <th className="py-2">Fix strategy</th>
              </tr>
            </thead>
            <tbody>
              {FAILURES.map((f, i) => (
                <tr key={i} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 font-semibold">{f.class}</td>
                  <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{f.example}</td>
                  <td className={`py-2 pr-3 ${SEVERITY_TONE[f.severity]} uppercase tracking-wider text-[10px] font-medium`}>{f.severity}</td>
                  <td className="py-2 pr-3 text-xs">{f.caught_by}</td>
                  <td className="py-2 pr-3 text-xs font-mono">{f.first_seen_batch}</td>
                  <td className="py-2 text-xs">{f.fix_strategy}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
