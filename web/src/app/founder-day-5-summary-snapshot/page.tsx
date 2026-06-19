import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Day 5 summary snapshot — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Batch = {
  label: string;
  rounds: string;
  ships: number;
  highlights: string[];
  audit_fixes?: number;
};

const BATCHES: Batch[] = [
  {
    label: "Batches 1-11 (r587-r1300)",
    rounds: "r587 → r1300",
    ships: 480,
    highlights: [
      "Growth-loop visibility · tier projection · earnings projection",
      "BMC Web Console v0→v0.19 (35+ routes)",
      "v0.5 Phase 1 chains + P2 cert ladder + P2 #3 referral bounty + P3 #1 AMC tiers",
      "9 audit passes closed pre-r1300",
    ],
    audit_fixes: 4,
  },
  {
    label: "Batch 12 (r1303-r1314)",
    rounds: "r1303 → r1314",
    ships: 12,
    highlights: [
      "v0.5 Phase 5 founder_priority_actions write-layer (r1306, 6 weeks early)",
      "v0.5 Phase 6 public investor share v2 (r1307, 8 weeks early)",
      "v0.5 Phase 7 DPDP grievance auto-routing (r1309, 3 weeks early)",
      "v0.5 Phase 8 spot-audit cron + engineer-rotation enforcement (r1310, 4 weeks early)",
      "founder_incidents infra (r1311) + cron-status surface (r1312)",
    ],
    audit_fixes: 2,
  },
  {
    label: "Batch 13 (r1315-r1322)",
    rounds: "r1315 → r1322",
    ships: 8,
    highlights: [
      "v0.5 Phase 9 morning email digest preview (r1315)",
      "v0.5 Phase 10 GST quarterly filing prep (r1316)",
      "Weekly board pack + AMC churn early-warning + Tier-1 home composite",
      "v0.5 Phase 3 hospital chains bulk import (r1319)",
      "★ 500 SHIPS MILESTONE hit at r1319/r1320 ★",
      "r1322 biggest audit-fix ever: 14 bugs caught (8 non-existent tables/columns + status enum + grievance vocabulary)",
    ],
    audit_fixes: 2,
  },
  {
    label: "Batches 14-17 (r1323-r1359)",
    rounds: "r1323 → r1359",
    ships: 37,
    highlights: [
      "v0.5 Phase 4 dental vertical pilot (r1323, 3 weeks early)",
      "M&A pipeline · payroll bulk authorize · NPS quarterly · compliance ledger",
      "Unit economics · cap table · decision log · sales territory · action items cockpit",
      "Runway & burn · vendor payables · cohort retention · pipeline velocity · postmortem ledger",
      "Board meeting prep · headcount plan · tech-debt ledger · experimentation tracker · v0.6 ROADMAP LANDED (r1354)",
      "Product feedback inbox · partnerships tracker · engineer NPS · compliance vault · monthly narrative",
    ],
    audit_fixes: 3,
  },
  {
    label: "Batches 18-19 (r1360-r1369)",
    rounds: "r1360 → r1369",
    ships: 10,
    highlights: [
      "AMC renewal pipeline (T-90/60/30) · acquisition attribution",
      "Engineer rotation cockpit · supplier onboarding funnel · incident RCA readout",
      "Revenue recognition · customer health score (composite 0-100)",
      "Fleet equipment inventory · team retro archive · vendor contract vault",
    ],
    audit_fixes: 1,
  },
];

const STATS = {
  total_ships: 546,
  v05_phases_done: "8 of 10",
  v05_phases_remaining: "Phase 1 (Cashfree activation — blocked external KYC), Phase 2 (Android v0.5 release)",
  audit_fix_sweeps: 10,
  prod_bugs_caught: 65,
  ultracode_design_batches: 20,
  ultracode_audit_batches: 10,
  prs_merged_day_5: "#1827 → #1851 = ~25 PRs",
  tags_pushed: ["v0.4-day-5-r1322", "v0.4-day-5-r1349", "v0.4-day-5-r1354", "v0.4-day-5-r1359", "v0.4-day-5-r1369"],
};

function Card({ label, value, tone }: { label: string; value: string; tone?: "ok" | "warn" | "info" }) {
  const toneClass = tone === "ok"
    ? "text-[var(--color-ok)]"
    : tone === "warn"
    ? "text-[var(--color-warn)]"
    : tone === "info"
    ? "text-[var(--color-info)]"
    : "text-[var(--color-fg)]";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold ${toneClass}`}>{value}</div>
    </div>
  );
}

export default async function FounderDay5SummaryPage() {
  await requireFounder();
  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Day 5 summary snapshot ★ 546 SHIPS</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Founder Console sprint review · r587 → r1369 · 8 of 10 v0.5 phases shipped · 10 audit-fix sweeps · 65 prod bugs caught pre-deploy · v0.6 roadmap landed
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-5">
        <Card label="Total ships" value={STATS.total_ships.toString()} tone="ok" />
        <Card label="v0.5 phases done" value={STATS.v05_phases_done} tone="ok" />
        <Card label="Audit-fix sweeps" value={STATS.audit_fix_sweeps.toString()} tone="info" />
        <Card label="Prod bugs caught" value={STATS.prod_bugs_caught.toString()} tone="warn" />
        <Card label="Design batches" value={STATS.ultracode_design_batches.toString()} />
        <Card label="Audit batches" value={STATS.ultracode_audit_batches.toString()} />
        <Card label="Day-5 PRs" value={STATS.prs_merged_day_5} />
        <Card label="Tags" value={`${STATS.tags_pushed.length} tags`} />
        <Card label="500 milestone" value="r1319/r1320" tone="ok" />
        <Card label="v0.6 plan" value="r1354" tone="info" />
      </section>

      <section className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-6">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Day 5 thesis</div>
        <p className="mt-2 text-sm">
          Day 5 was the audit-vs-design self-correcting workflow at full throttle. Ship a 5-design batch via parallel ultracode agents · run an adversarial 3-vote refute panel against every claim · fix the confirmed bugs in a SEPARATE audit-fix migration before the next batch ships. Result: 65 confirmed prod bugs caught pre-deploy across 10 sweeps · zero customer-facing 500 errors from this sprint.
        </p>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Batch ledger</h2>
        <div className="space-y-3">
          {BATCHES.map((b) => (
            <article key={b.label} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
              <div className="flex items-baseline justify-between flex-wrap gap-2">
                <h3 className="text-sm font-semibold">{b.label}</h3>
                <div className="flex items-baseline gap-3 text-xs">
                  <span className="font-mono text-[var(--color-muted)]">{b.rounds}</span>
                  <span className="font-semibold text-[var(--color-ok)]">{b.ships} ships</span>
                  {b.audit_fixes ? (
                    <span className="text-[var(--color-info)]">{b.audit_fixes} audit-fix{b.audit_fixes > 1 ? "es" : ""}</span>
                  ) : null}
                </div>
              </div>
              <ul className="mt-3 space-y-1 text-xs text-[var(--color-muted)]">
                {b.highlights.map((h) => (
                  <li key={h}>• {h}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-4">
        <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Remaining v0.5</h2>
        <p className="mt-2 text-sm">{STATS.v05_phases_remaining}</p>
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-4">
        <h2 className="text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Tags this sprint</h2>
        <ul className="mt-2 space-y-1 text-xs font-mono text-[var(--color-muted)]">
          {STATS.tags_pushed.map((t) => (
            <li key={t}>• {t}</li>
          ))}
        </ul>
      </section>
    </div>
  );
}
