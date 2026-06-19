import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Gotchas catalog — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Gotcha = {
  id: string;
  kind: "schema" | "function" | "page" | "workflow" | "pg_cron" | "rls";
  severity: "critical" | "high" | "medium";
  short: string;
  long: string;
  first_caught: string;
  mitigation: string;
};

const GOTCHAS: Gotcha[] = [
  {
    id: "G-001",
    kind: "schema",
    severity: "critical",
    short: "profiles.city DOES NOT exist",
    long: "Removed in earlier security sweep. Use organizations.city via profiles.organization_id JOIN.",
    first_caught: "r1224 (audit wwc5rgoqp, fixed r1237)",
    mitigation: "SYSTEM_BRIEF lists this. Agents Bash-grep before referencing profiles columns.",
  },
  {
    id: "G-002",
    kind: "schema",
    severity: "critical",
    short: "amc_pool_ledger DOES NOT exist",
    long: "Real table name is amc_payment_pool. Audit caught the typo on r1209.",
    first_caught: "r1209 (audit ws4nf361d, fixed r1230)",
    mitigation: "SYSTEM_BRIEF entry. Function would have 500-errored on every call.",
  },
  {
    id: "G-003",
    kind: "schema",
    severity: "critical",
    short: "engineer_payouts.status: NO 'paid' / 'paid_out'",
    long: "CHECK constraint allows ('queued','processing','processed','failed','cancelled'). Real success value is 'processed' per r720. r1315 used 'paid_out' which silently matched zero rows.",
    first_caught: "r1315 (audit wy5uvmh9p, fixed r1322)",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-004",
    kind: "schema",
    severity: "high",
    short: "repair_jobs.kind ∈ ('repair','maintenance') ONLY",
    long: "AMC visits use kind='maintenance'. Warranty tracked via warranty_source_job_id. No 'amc' or 'warranty' kind exists.",
    first_caught: "r1225 (fixed r1237)",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-005",
    kind: "schema",
    severity: "high",
    short: "amc_contracts: amc_tier + monthly_fee_rupees (NOT tier / monthly_fee)",
    long: "Plus start_date + end_date (the original schema). activated_at + deactivated_at added in r1339 ALTER after caught missing.",
    first_caught: "r1315 + r1331 (audit whg8da6kf, fixed r1339)",
    mitigation: "SYSTEM_BRIEF lists all 6 amc_contracts columns.",
  },
  {
    id: "G-006",
    kind: "schema",
    severity: "high",
    short: "repair_jobs.engineer_id FKs engineers.id (NOT profiles.id)",
    long: "engineers table has separate user_id and id. repair_jobs.engineer_id joins engineers.id.",
    first_caught: "multiple early rounds",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-007",
    kind: "schema",
    severity: "high",
    short: "engineers.cached_highest_tier (NOT current_tier)",
    long: "Column was renamed to cached_highest_tier in r578-era. verification_status is an enum — cast ::text in coalesce/JSON.",
    first_caught: "early rounds",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-008",
    kind: "schema",
    severity: "high",
    short: "spare_part_orders.supplier_org_id (NOT supplier_user_id)",
    long: "Supplier is org-level, not user-level. Also: total_amount (NOT amount_rupees) + payment_status (NOT status).",
    first_caught: "early rounds",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-009",
    kind: "schema",
    severity: "medium",
    short: "collusion_flags.signal_kind (NOT severity)",
    long: "Plus created_at (NOT detected_at). Used by founder_action_center critical-items query.",
    first_caught: "r1303 (audit wx41ohful, fixed r1305)",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-010",
    kind: "schema",
    severity: "high",
    short: "amc_sla_breaches.credit_issued_rupees + detected_at",
    long: "NOT credit_amount_rupees · NOT created_at. Used in 3 different RPCs that had to be fixed.",
    first_caught: "r1303 (audit wx41ohful, fixed r1305)",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-011",
    kind: "schema",
    severity: "high",
    short: "dpdp_grievances status: NO 'in_progress'",
    long: "CHECK allows ('open','in_review','resolved','rejected'). r1303 used 'in_progress' which violated CHECK.",
    first_caught: "r1303 (audit wx41ohful, fixed r1305)",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-012",
    kind: "schema",
    severity: "critical",
    short: "gst_invoices: issued_at + recipient_gstin + taxable_amount_rupees",
    long: "NOT invoice_date · NOT buyer_gstin · NOT taxable_value_rupees. r1316 had all three wrong column names. Every founder_gst_quarterly_prep call would have failed.",
    first_caught: "r1316 (audit wsau9r0wz, fixed r1322)",
    mitigation: "SYSTEM_BRIEF lists exact column names.",
  },
  {
    id: "G-013",
    kind: "schema",
    severity: "high",
    short: "spot_audit_invitations + spot_audit_responses are SEPARATE tables",
    long: "rating column lives in spot_audit_responses (NOT invitations). invitation_id FK. invitations.created_at, responses.responded_at. r1317 used non-existent spot_audit_invites with rating column.",
    first_caught: "r1317 (audit wsau9r0wz, fixed r1322)",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-014",
    kind: "schema",
    severity: "critical",
    short: "code_red_requests + code_red_dispatch_events (NOT _events / _incidents)",
    long: "Real tables created in r509. Workflow agents repeatedly hallucinate code_red_events or code_red_incidents which don't exist.",
    first_caught: "r1317 + r1318 (audit wsau9r0wz, fixed r1322)",
    mitigation: "SYSTEM_BRIEF + 2 audit catches.",
  },
  {
    id: "G-015",
    kind: "schema",
    severity: "critical",
    short: "founder_priority_actions has NO status column",
    long: "Only action_taken ∈ ('acked','resolved','escalated','ignored') + ack_expires_at. r1320 filtered WHERE status='open' which 500'd.",
    first_caught: "r1320 (audit wsau9r0wz, fixed r1322)",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-016",
    kind: "schema",
    severity: "high",
    short: "founder_incidents.opened_at + severity p0..p3",
    long: "NOT created_at · NOT 'critical'. Status ∈ ('open','investigating','resolved','wont_fix','dupe'). r1320 used both wrong.",
    first_caught: "r1320 (audit wsau9r0wz, fixed r1322)",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-017",
    kind: "schema",
    severity: "critical",
    short: "repair_job_disputes table DOES NOT EXIST",
    long: "Dispute tracking is via repair_job_escrow.status='in_dispute'. r1325 used the non-existent table.",
    first_caught: "r1325 (audit wsau9r0wz, fixed r1333)",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-018",
    kind: "schema",
    severity: "critical",
    short: "hospital_chains r544 schema collision",
    long: "Table existed since r544 with different columns (name, primary_admin_user_id, status). r1319 used CREATE TABLE IF NOT EXISTS which silently kept old schema — all 5 RPCs would have 500'd.",
    first_caught: "r1319 (PR review, fixed r1321 ALTER)",
    mitigation: "Always grep CREATE TABLE <name> before designing.",
  },
  {
    id: "G-019",
    kind: "function",
    severity: "critical",
    short: "LANGUAGE sql functions skip is_founder gate",
    long: "SQL functions can't RAISE EXCEPTION for control flow. 3 of 6 design agents in batch 10 emitted LANGUAGE sql functions WITHOUT is_founder gate, GRANTed to authenticated. Any logged-in user could have called them.",
    first_caught: "r1269-r1274 batch 10 (security-critical pre-flight catch)",
    mitigation: "Pre-flight Python normalizer converts LANGUAGE sql → plpgsql + injects is_founder gate.",
  },
  {
    id: "G-020",
    kind: "pg_cron",
    severity: "critical",
    short: "pg_cron has no JWT — is_founder() always returns false",
    long: "Any SECDEF function gated by is_founder() will RAISE EXCEPTION 'founder only' when called from pg_cron. r1311 cron called founder_action_center which is gated.",
    first_caught: "r1311 (audit wj3ml8w1k, fixed r1313)",
    mitigation: "Inline the query in the cron RPC bypassing the gate, OR split into an internal helper without is_founder.",
  },
  {
    id: "G-021",
    kind: "function",
    severity: "medium",
    short: "extract(hour from interval) returns 0-23, not total hours",
    long: "extract(HOUR) returns the hour-of-day field of an interval. For total hours use extract(EPOCH ...) / 3600. A 5-day incident reported 3h instead of 123h.",
    first_caught: "r1311 (audit wj3ml8w1k, fixed r1313)",
    mitigation: "SYSTEM_BRIEF + grep for any extract(hour from) in new SQL.",
  },
  {
    id: "G-022",
    kind: "function",
    severity: "critical",
    short: "ENUM columns must be cast ::text in coalesce/JSON returns",
    long: "PostgreSQL won't accept coalesce(enum_col, 'pending') if enum_col is a proper ENUM type. RAISE 42804 type mismatch. Same for jsonb_build_object('status', enum_col).",
    first_caught: "r1306 (audit wlrll9mbp, fixed r1308)",
    mitigation: "SYSTEM_BRIEF.",
  },
  {
    id: "G-023",
    kind: "function",
    severity: "critical",
    short: "Re-using table — re-use its CHECK constraints too",
    long: "r1307 INSERT logged outcome='served' but r558's investor_share_view_log CHECK only allows ('ok','expired','exhausted','revoked','not_found'). Every successful share view would 23514-abort.",
    first_caught: "r1307 (audit wlrll9mbp, fixed r1308)",
    mitigation: "Dual-vocabulary (log canonical CHECK value, emit business value to client). Grep ADD CONSTRAINT before INSERTing.",
  },
  {
    id: "G-024",
    kind: "workflow",
    severity: "high",
    short: "Workflow agents wrote files directly to disk",
    long: "Despite 'return only via schema' instruction, agents in batches 2-3 and 15 wrote migrations + pages directly to disk with colliding timestamps. Caused migration_history INSERT failure (duplicate key).",
    first_caught: "batches 2-3 (renumbered) + batch 15 (r1340 cash_conversion collision)",
    mitigation: "Pre-flight Python: ROUND_TO_TS map + force-rewrite round number in filename + supabase migration repair on collision.",
  },
  {
    id: "G-025",
    kind: "workflow",
    severity: "critical",
    short: "Mid-function COMMIT inside $$...$$ body",
    long: "r1360 agent emitted COMMIT; INSIDE a function body before END;$$;. Postgres would fail at CREATE FUNCTION time.",
    first_caught: "r1360 batch 18",
    mitigation: "Normalizer detects COMMIT lines followed within 5 lines by END;/$$; and drops them.",
  },
  {
    id: "G-026",
    kind: "workflow",
    severity: "high",
    short: "Wrong round number in filename",
    long: "3 of 5 batch-19 agents named their migrations round1360_ or round1365_ when prompted as r1365 / r1366 / r1367. The intended round was in _target.round but the agent's emitted filename ignored it.",
    first_caught: "batch 19",
    mitigation: "Normalizer force-rewrites the round number prefix in filename to match _target.round.",
  },
  {
    id: "G-027",
    kind: "page",
    severity: "high",
    short: "HTML-escaped JSX entities (&gt; &lt; &amp;) in SQL and TSX",
    long: "Workflow agents emit JSON-escaped entities in their schema return. Renders as literal &gt; in JSX (won't parse) or as text in SQL (won't compare).",
    first_caught: "batch 9",
    mitigation: "Pre-flight Python html.unescape() on both SQL and TSX.",
  },
  {
    id: "G-028",
    kind: "page",
    severity: "medium",
    short: "Raw < > in JSX text breaks parser",
    long: "JSX text comparison ops must be wrapped: {\"<\"} {\">=\"}. Raw `< 30` in JSX text breaks build.",
    first_caught: "multiple batches",
    mitigation: "Manual fix per batch (catchable by typecheck) + SYSTEM_BRIEF.",
  },
  {
    id: "G-029",
    kind: "page",
    severity: "medium",
    short: "{\"<\"} won't parse INSIDE attribute strings",
    long: "Attribute strings (sub=\"...\") can't contain JSX expressions. Use Unicode chars ≥ ≤ → · inside attribute strings, JSX wrappers only inside JSX text.",
    first_caught: "r1337 batch 14",
    mitigation: "SYSTEM_BRIEF + manual fix.",
  },
  {
    id: "G-030",
    kind: "page",
    severity: "high",
    short: "'use client' page with non-existent /lib/supabase/client import",
    long: "/lib/supabase/server is the real module. Some workflow agents emit 'use client' + import from /lib/supabase/client which doesn't exist as a server-side module.",
    first_caught: "batch 9",
    mitigation: "Pre-flight Python rewrites /lib/supabase/client → /lib/supabase/server.",
  },
];

const SUMMARY_STATS = {
  total_gotchas: GOTCHAS.length,
  critical: GOTCHAS.filter((g) => g.severity === "critical").length,
  high: GOTCHAS.filter((g) => g.severity === "high").length,
  medium: GOTCHAS.filter((g) => g.severity === "medium").length,
  by_kind: {
    schema: GOTCHAS.filter((g) => g.kind === "schema").length,
    function: GOTCHAS.filter((g) => g.kind === "function").length,
    page: GOTCHAS.filter((g) => g.kind === "page").length,
    workflow: GOTCHAS.filter((g) => g.kind === "workflow").length,
    pg_cron: GOTCHAS.filter((g) => g.kind === "pg_cron").length,
  },
};

function SeverityBadge({ severity }: { severity: Gotcha["severity"] }) {
  const tone =
    severity === "critical" ? "text-[var(--color-danger)]"
    : severity === "high" ? "text-[var(--color-warn)]"
    : "text-[var(--color-info)]";
  return <span className={`text-[10px] font-semibold uppercase tracking-wider ${tone}`}>{severity}</span>;
}

function KindBadge({ kind }: { kind: Gotcha["kind"] }) {
  return <span className="text-[10px] font-mono text-[var(--color-muted)]">[{kind}]</span>;
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
      <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value}</div>
    </div>
  );
}

export default async function FounderGotchasCatalogPage() {
  await requireFounder();
  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Gotchas catalog ★ {SUMMARY_STATS.total_gotchas} known failure modes</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Institutional memory of every schema typo / function pattern / page bug / workflow agent failure mode caught during the v0.5 sprint. Use this when onboarding new agents or new engineers — paste relevant entries into prompts.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-8">
        <Card label="Total" value={SUMMARY_STATS.total_gotchas.toString()} />
        <Card label="Critical" value={SUMMARY_STATS.critical.toString()} />
        <Card label="High" value={SUMMARY_STATS.high.toString()} />
        <Card label="Medium" value={SUMMARY_STATS.medium.toString()} />
        <Card label="Schema" value={SUMMARY_STATS.by_kind.schema.toString()} />
        <Card label="Function" value={SUMMARY_STATS.by_kind.function.toString()} />
        <Card label="Page" value={SUMMARY_STATS.by_kind.page.toString()} />
        <Card label="Workflow" value={SUMMARY_STATS.by_kind.workflow.toString()} />
      </section>

      <section className="space-y-3">
        {GOTCHAS.map((g) => (
          <article key={g.id} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="flex items-baseline justify-between flex-wrap gap-2">
              <div className="flex items-baseline gap-2">
                <span className="font-mono text-xs text-[var(--color-muted)]">{g.id}</span>
                <KindBadge kind={g.kind} />
                <SeverityBadge severity={g.severity} />
                <h3 className="text-sm font-semibold">{g.short}</h3>
              </div>
            </div>
            <p className="mt-2 text-xs text-[var(--color-muted)]">{g.long}</p>
            <div className="mt-2 grid grid-cols-1 gap-1 text-[10px] sm:grid-cols-2">
              <div>
                <span className="text-[var(--color-muted)] uppercase tracking-wider">First caught:</span>{" "}
                <span className="font-mono">{g.first_caught}</span>
              </div>
              <div>
                <span className="text-[var(--color-muted)] uppercase tracking-wider">Mitigation:</span>{" "}
                <span className="text-[var(--color-muted)]">{g.mitigation}</span>
              </div>
            </div>
          </article>
        ))}
      </section>
    </div>
  );
}
