import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "v0.5 roadmap — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Item = {
  phase: number;
  title: string;
  scope: string;
  blockers: string;
  deliverables: string;
  owner: string;
  target_weeks: string;
  status: "Planned" | "Ready" | "Blocked" | "In progress";
  priority: "P0" | "P1" | "P2" | "P3";
};

const PLAN: Item[] = [
  {
    phase: 1, title: "Cashfree payouts activation",
    scope: "KYC submission → activation approval → first real-money payout via Cashfree v2 API. Unblocks engineer-payout pipeline (currently queued payouts accumulating).",
    blockers: "Cashfree KYC approval (founder action ON cashfree merchant portal). Udyam cert uploaded; awaiting 24-48h activation.",
    deliverables: "Real ₹ payout to first engineer · cashfree webhook → engineer_payouts.status=processed · founder-side dashboard /payouts-snapshot-summary turns green.",
    owner: "Founder · Cashfree merchant team",
    target_weeks: "Week 1",
    status: "Blocked",
    priority: "P0",
  },
  {
    phase: 2, title: "Engineer mobile v0.5 release",
    scope: "Android v0.5 with: founder-action-center notifications, cash-survey self-reporting UI, engineer-attendance GPS check-in/out, payout-method registration with UPI/bank verification.",
    blockers: "Phase 1 (need real payout flow) + 1 round of QA on real device.",
    deliverables: "Play Store internal rollout · 100% of active engineers updated within 7d.",
    owner: "Mobile · QA",
    target_weeks: "Weeks 1-2",
    status: "Planned",
    priority: "P0",
  },
  {
    phase: 3, title: "Hospital chains onboarding accelerator",
    scope: "Bulk-import API for hospital chains (top 50 by AMC LTV proxy). Pre-filled AMC affidavits with chain-signer + chain-specific equipment_categories. /hospital-chains-snapshot-summary tracks acquisition velocity.",
    blockers: "1 sales conversation with each chain to validate flow. Founder-led.",
    deliverables: "5 chains onboarded · 50+ hospitals · ₹5L+ MRR added.",
    owner: "Founder · BD",
    target_weeks: "Weeks 2-4",
    status: "Ready",
    priority: "P0",
  },
  {
    phase: 4, title: "Dental vertical pilot",
    scope: "Dental-clinic AMC + repair vertical — distinct equipment_taxonomy_class (autoclave, X-ray, dental chairs, ultrasonic scalers). Bonded-parts supplier network. 10 dental clinics in Hyderabad as pilot cohort.",
    blockers: "Equipment-category seeding + 2-3 dental-equipment suppliers signed.",
    deliverables: "10 dental clinics live · 5 AMCs signed · /equipment-category-snapshot shows dental ≥ 10% mix.",
    owner: "Founder · vertical lead",
    target_weeks: "Weeks 3-6",
    status: "Planned",
    priority: "P1",
  },
  {
    phase: 5, title: "Founder action center v2 (write actions)",
    scope: "Extend r1303 /founder-action-center with action_log table — founder can ACK, RESOLVE, ESCALATE, IGNORE each item with audit trail. SLA-based escalation triggers if items aged past defined thresholds.",
    blockers: "None.",
    deliverables: "New table founder_action_log + RPC founder_log_action + UI buttons + escalation cron.",
    owner: "Claude · founder review",
    target_weeks: "Weeks 1-2",
    status: "Ready",
    priority: "P1",
  },
  {
    phase: 6, title: "Public investor share v2",
    scope: "Extend r1200-ish public investor share with: live MRR, lifetime GMV chart, regional state map, AMC tier mix. Shareable with token, no founder login. Investor diligence ready.",
    blockers: "1 design review of what to expose vs hide. Founder-led.",
    deliverables: "Public URL /share/investor/[v2-token] · stable, cacheable, no PII.",
    owner: "Claude · founder review",
    target_weeks: "Weeks 2-3",
    status: "Planned",
    priority: "P1",
  },
  {
    phase: 7, title: "DPDP grievance auto-routing",
    scope: "Inbound DPDP grievance → auto-classify (correction/erasure/portability) → route to grievance officer with 30-day timer. Integration with /dpdp-grievance-pulse-summary.",
    blockers: "Designate grievance officer (founder for now).",
    deliverables: "Grievance triage automation + auto-escalation if approaching 30-day SLA breach.",
    owner: "Claude",
    target_weeks: "Weeks 3-5",
    status: "Planned",
    priority: "P2",
  },
  {
    phase: 8, title: "Spot-audit cron + engineer-rotation enforcement",
    scope: "Cron-driven spot-audit invitation rotation (every Nth completed job triggers an invite). Engineer rotation enforcement: if engineer skipped 3 invites, freeze new job assignments until they respond.",
    blockers: "Founder approval of N (every 10th job? every 5th?).",
    deliverables: "Spot-audit invitation rate ≥ 30% of completed jobs · response rate ≥ 60%.",
    owner: "Claude",
    target_weeks: "Weeks 4-6",
    status: "Planned",
    priority: "P2",
  },
  {
    phase: 9, title: "Founder daily morning digest v2",
    scope: "Extend /founder-morning-pulse-v2 into an EMAIL DIGEST delivered to founder at 07:30 IST every day with: top 10 /founder-action-center items, MRR delta, key alerts. Single notification — replaces 10+ Slack notifications.",
    blockers: "Email auth from Supabase Edge fn (likely SendGrid).",
    deliverables: "Email arrives 07:30 IST · open rate ≥ 95% · founder uses it as the morning kickoff.",
    owner: "Claude · cron",
    target_weeks: "Weeks 1-2",
    status: "Planned",
    priority: "P1",
  },
  {
    phase: 10, title: "GST quarterly filing automation",
    scope: "End-quarter cron-driven GST filing prep: generate GSTR-1 + GSTR-3B JSON pre-filled from /gst-invoice-snapshot + /reconciliation-tax-snapshot. Manual sign-off, then push to GSTN.",
    blockers: "CA review + GSTN API credentials.",
    deliverables: "Quarterly filing done in &lt;1hr from console.",
    owner: "Claude · founder CA",
    target_weeks: "Weeks 4-8",
    status: "Planned",
    priority: "P2",
  },
];

const STATUS_TONE: Record<Item["status"], string> = {
  "Planned":     "text-[var(--color-info)]",
  "Ready":       "text-[var(--color-ok)]",
  "Blocked":     "text-[var(--color-danger)]",
  "In progress": "text-[var(--color-warn)]",
};

const PRIORITY_TONE: Record<Item["priority"], string> = {
  P0: "text-[var(--color-danger)]",
  P1: "text-[var(--color-warn)]",
  P2: "text-[var(--color-info)]",
  P3: "text-[var(--color-muted)]",
};

export default async function V05RoadmapPage() {
  await requireFounder();
  const ready = PLAN.filter(p => p.status === "Ready").length;
  const blocked = PLAN.filter(p => p.status === "Blocked").length;
  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">v0.5 roadmap ★ r1304</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">10 phases planned · {ready} ready to start · {blocked} blocked · 8-week target horizon</p>
      </header>

      <section className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-6">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">v0.5 thesis</div>
        <p className="mt-2 text-sm">
          v0.4 built the observability surface (~80 snapshots + 27 metas + audit-paired self-correcting workflow). v0.5 turns
          observability into ACTION: Cashfree real-money payouts (P0), hospital-chain bulk onboarding (P0), dental vertical
          pilot (P1), action-center write transitions (P1), morning email digest (P1), public investor share v2 (P1).
        </p>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Phase plan</h2>
        <div className="space-y-3">
          {PLAN.map((p) => (
            <article key={p.phase} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
              <div className="flex items-baseline justify-between flex-wrap gap-2">
                <h3 className="text-sm font-semibold">
                  Phase {p.phase} · {p.title}
                </h3>
                <div className="flex items-baseline gap-3 text-[10px] uppercase tracking-wider font-semibold">
                  <span className={PRIORITY_TONE[p.priority]}>{p.priority}</span>
                  <span className={STATUS_TONE[p.status]}>{p.status}</span>
                  <span className="text-[var(--color-muted)]">{p.target_weeks}</span>
                </div>
              </div>
              <p className="mt-2 text-sm">{p.scope}</p>
              <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-3 text-xs">
                <div><span className="text-[var(--color-muted)]">Blockers: </span>{p.blockers}</div>
                <div><span className="text-[var(--color-muted)]">Deliverables: </span>{p.deliverables}</div>
                <div><span className="text-[var(--color-muted)]">Owner: </span>{p.owner}</div>
              </div>
            </article>
          ))}
        </div>
      </section>
    </div>
  );
}
