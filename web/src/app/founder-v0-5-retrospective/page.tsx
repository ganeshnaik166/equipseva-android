import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "v0.5 retrospective — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Phase = {
  num: number;
  title: string;
  status: "shipped_early" | "shipped" | "blocked" | "planned";
  rounds: string;
  what_worked: string;
  what_didnt: string;
  lessons: string;
};

const PHASES: Phase[] = [
  {
    num: 1,
    title: "Cashfree payouts activation",
    status: "blocked",
    rounds: "—",
    what_worked: "Webhook + reaper + dedup all built ahead of time (r466, r468, r472).",
    what_didnt: "External KYC dependency · Cashfree merchant approval was a single blocker we couldn't unblock with code.",
    lessons: "Build integrations to a working API on day 1 but accept that activation is a separate gate the founder owns. Queue payouts safely while waiting.",
  },
  {
    num: 2,
    title: "Engineer mobile v0.5 release",
    status: "planned",
    rounds: "—",
    what_worked: "Web console first kept all v0.5 features testable without needing an Android cut.",
    what_didnt: "Required real-money payout flow (Phase 1) so it's gated on KYC.",
    lessons: "Decouple Android v0.5 from Cashfree by shipping it with the queued-payout UX (no real money required for QA).",
  },
  {
    num: 3,
    title: "Hospital chains bulk onboarding",
    status: "shipped_early",
    rounds: "r1319 + r1321 fix",
    what_worked: "hospital_chains table from r544 already existed · adapted instead of recreated.",
    what_didnt: "r1319 used CREATE TABLE IF NOT EXISTS which silently kept the old r544 schema · all 5 RPCs would have 500-errored on first call. r1321 ALTERed to add new columns + UNIONed status CHECK.",
    lessons: "ALWAYS grep migrations/ for CREATE TABLE <name> before designing a new table. IF NOT EXISTS is a footgun.",
  },
  {
    num: 4,
    title: "Dental vertical pilot",
    status: "shipped_early",
    rounds: "r1323",
    what_worked: "Cohort-tracking pattern (hyderabad-q3 / bengaluru-q4 / expansion) keeps the ledger tidy. Bonded-parts supplier registry is a clean extension point.",
    what_didnt: "equipment_taxonomy_class existed (r486) but didn't have dental categories · had to embed as constant text[].",
    lessons: "Taxonomy migrations should plan for vertical expansion. Add 5-10 placeholder dental + lab + radiology + dialysis categories now.",
  },
  {
    num: 5,
    title: "Founder action center v2 (write actions)",
    status: "shipped_early",
    rounds: "r1306 (6 weeks early)",
    what_worked: "founder_priority_actions write-layer cleanly slots under r1303 read-layer. ACK/RESOLVE/ESCALATE/IGNORE state machine plus ack_expires_at silence rules feel natural.",
    what_didnt: "Audit caught r1306 ENUM cast mismatch (engineers.verification_status not cast ::text in coalesce). r1308 fix.",
    lessons: "ENUM columns ALWAYS need ::text cast inside coalesce when they hit JSON return shapes.",
  },
  {
    num: 6,
    title: "Public investor share v2",
    status: "shipped_early",
    rounds: "r1307 (8 weeks early)",
    what_worked: "Token-gated public RPC + max_views + view_count + status state machine reused r558 token infrastructure. 13 sanitized KPIs no PII.",
    what_didnt: "Audit caught r1307 CHECK constraint violation: 'served' didn't pass r558 outcome CHECK ('ok','expired','exhausted','revoked','not_found'). Every successful share would have 23514-aborted. r1308 fix with dual-vocabulary (log 'ok', emit 'served' to client).",
    lessons: "Re-using existing tables means re-using their CHECK constraints. Always grep CHECK CONSTRAINT before INSERTing into a known table.",
  },
  {
    num: 7,
    title: "DPDP grievance auto-routing",
    status: "shipped_early",
    rounds: "r1309 + r1313 fix (3 weeks early)",
    what_worked: "Hourly cron + r485 grievance_type vocabulary + officer auto-assignment + escalation at T-5 days before 30-day SLA. /dpdp-routing-summary surfaces 15 KPIs.",
    what_didnt: "Two bugs: (1) dpdp_grievance_officers.grievance_type CHECK didn't match r485 vocabulary · officer lookup ALWAYS returned NULL · by_type counters all 0. (2) cron called founder_action_center which has is_founder() gate. pg_cron has no JWT → cron permanently aborted.",
    lessons: "CHECK constraint vocabulary must be lifted from the SAME source table (don't re-invent). pg_cron + is_founder() = NEVER work · inline the query directly.",
  },
  {
    num: 8,
    title: "Spot-audit cron + engineer-rotation enforcement",
    status: "shipped_early",
    rounds: "r1310 (4 weeks early)",
    what_worked: "Every-10th-job invite cadence + 3-ignored 90d freeze + auto-unfreeze when below threshold. /spot-audit-rotation-summary keeps it visible.",
    what_didnt: "Nothing major — cleanest single-PR ship in batch 12.",
    lessons: "Hardcoded N=10 simplifies. Founder can override via constant later if needed.",
  },
  {
    num: 9,
    title: "Founder daily morning digest v2",
    status: "shipped_early",
    rounds: "r1315 (6 weeks early)",
    what_worked: "Single RPC aggregates top 10 actions + MRR deltas (DoD/WoW/30d) + alerts + milestones + cron health into JSONB. Preview page renders exactly what the 07:30 IST email will contain.",
    what_didnt: "engineer_payouts.status='paid_out' was wrong — real success value is 'processed' per r720. Audit caught. r1322 fix.",
    lessons: "engineer_payouts CHECK only allows ('queued','processing','processed','failed','cancelled'). Memorize this — comes up in every burn / payout query.",
  },
  {
    num: 10,
    title: "GST quarterly filing automation",
    status: "shipped_early",
    rounds: "r1316 + r1322 fix (4 weeks early)",
    what_worked: "founder_gst_filings table tracks draft → reviewed → filed → rejected state with ARN. GSTR-1 + GSTR-3B JSON pre-fills from gst_invoices.",
    what_didnt: "Three column name errors in r1316: invoice_date (should be issued_at), buyer_gstin (should be recipient_gstin), taxable_value_rupees (should be taxable_amount_rupees). All caught by audit · r1322 fix.",
    lessons: "Same table, three wrong column names. plpgsql lazy validation makes this class of bug invisible until first call. Audit-vs-design pattern is the only defense.",
  },
];

const META_LESSONS = [
  "Audit-vs-design + 3-vote refute panel caught 65 confirmed prod bugs across 10 sweeps. Without this pattern, every batch would have shipped 3-15 broken RPCs.",
  "plpgsql lazy validation is the dominant failure mode. CREATE FUNCTION accepts non-existent column/table refs cleanly; first call 500s. Mitigation: every batch SYSTEM_BRIEF lists known table/column gotchas + agents Bash-grep before referencing.",
  "Workflow agents hallucinated 8+ non-existent tables (code_red_events / code_red_incidents / spare_part_disputes / amc_payments / amc_scheduled_visits / amc_disputes / spot_audit_invites / repair_job_disputes). All caught by audit.",
  "Pre-flight Python normalization catches: HTML entity unescape, LANGUAGE sql → plpgsql (security-critical), service_role grants, double-BEGIN, mid-function COMMIT, page_path nesting, wrong round number in filename.",
  "CREATE TABLE IF NOT EXISTS is a footgun. Caught r1319 hospital_chains schema collision. Now: always grep CREATE TABLE for any table name before designing.",
  "pg_cron has NO JWT — SECDEF gated by is_founder() will FAIL when invoked from cron. Inline the query or split into internal helper.",
  "ENUM columns must be cast ::text in coalesce / JSON returns. Caught r1306 (engineers.verification_status) and r1308 (investor_share_view_log.outcome).",
  "Session limit can hit mid-batch (happened twice in Day 5). Build resilience: design batches return-only-via-schema, normalize after, retry on next session.",
];

function StatusBadge({ status }: { status: Phase["status"] }) {
  const map = {
    shipped_early: { label: "✅ SHIPPED EARLY", tone: "text-[var(--color-ok)]" },
    shipped: { label: "✅ SHIPPED", tone: "text-[var(--color-ok)]" },
    blocked: { label: "🚫 BLOCKED", tone: "text-[var(--color-danger)]" },
    planned: { label: "⏳ PLANNED", tone: "text-[var(--color-muted)]" },
  };
  const s = map[status];
  return <span className={`text-[10px] font-semibold uppercase tracking-wider ${s.tone}`}>{s.label}</span>;
}

export default async function FounderV05RetrospectivePage() {
  await requireFounder();
  const shippedEarly = PHASES.filter((p) => p.status === "shipped_early").length;
  const blocked = PHASES.filter((p) => p.status === "blocked").length;
  const planned = PHASES.filter((p) => p.status === "planned").length;
  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-semibold">v0.5 retrospective ★ {shippedEarly} of 10 phases shipped early</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          What worked · what didn{"'"}t · lessons learned · per-phase ship report. Day 5 closed at 547 ships with {shippedEarly} v0.5 phases done ahead of schedule, {blocked} blocked on external dependencies, {planned} planned.
        </p>
      </header>

      <section className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-6">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Day 5 verdict</div>
        <p className="mt-2 text-sm">
          v0.5 was originally a 24-week plan. We shipped 8 of 10 phases in <strong>one day</strong> (Day 5 of the sprint) by running ultracode design batches in parallel with adversarial audit refute panels. The two remaining phases are pure external-dependency blocks: Phase 1 (Cashfree KYC, founder owns) and Phase 2 (Android release, gated on Phase 1). The infrastructure for both is built and tested.
        </p>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Per-phase retrospective</h2>
        <div className="space-y-3">
          {PHASES.map((p) => (
            <article key={p.num} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
              <div className="flex items-baseline justify-between flex-wrap gap-2">
                <h3 className="text-sm font-semibold">Phase {p.num} · {p.title}</h3>
                <div className="flex items-baseline gap-3 text-xs">
                  <span className="font-mono text-[var(--color-muted)]">{p.rounds}</span>
                  <StatusBadge status={p.status} />
                </div>
              </div>
              <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-3 text-xs">
                <div>
                  <div className="text-[var(--color-ok)] font-semibold uppercase tracking-wider text-[10px]">What worked</div>
                  <p className="mt-1 text-[var(--color-muted)]">{p.what_worked}</p>
                </div>
                <div>
                  <div className="text-[var(--color-danger)] font-semibold uppercase tracking-wider text-[10px]">What didn{"'"}t</div>
                  <p className="mt-1 text-[var(--color-muted)]">{p.what_didnt}</p>
                </div>
                <div>
                  <div className="text-[var(--color-info)] font-semibold uppercase tracking-wider text-[10px]">Lessons</div>
                  <p className="mt-1 text-[var(--color-muted)]">{p.lessons}</p>
                </div>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Cross-cutting meta-lessons</h2>
        <ol className="list-decimal space-y-2 pl-6 text-sm text-[var(--color-muted)]">
          {META_LESSONS.map((l, i) => (
            <li key={i}>{l}</li>
          ))}
        </ol>
      </section>
    </div>
  );
}
