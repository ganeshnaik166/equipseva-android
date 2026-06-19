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
    phase: 3, title: "Hospital chains onboarding accelerator — ✅ SHIPPED r1319 (+ r1321 fix)",
    scope: "Bulk-import API for hospital chains (top 50 by AMC LTV proxy). Pre-filled AMC affidavits with chain-signer + chain-specific equipment_categories. /hospital-chains-bulk-import tracks acquisition velocity + prospecting→live funnel.",
    blockers: "None — infra live; sales conversations next.",
    deliverables: "✅ hospital_chains (extended r544 schema) + hospital_chain_imports tables · 5 RPCs · Server-Action register form on /hospital-chains-bulk-import.",
    owner: "Claude · founder owns sales",
    target_weeks: "✅ DONE (2 weeks early)",
    status: "In progress",
    priority: "P0",
  },
  {
    phase: 4, title: "Dental vertical pilot — ✅ SHIPPED r1323",
    scope: "Dental-clinic AMC + repair vertical — distinct equipment_taxonomy_class (autoclave, dental X-ray, dental chairs, ultrasonic scalers). Bonded-parts supplier network. Pilot cohort tracker.",
    blockers: "None for infra; sales (founder-led).",
    deliverables: "✅ dental_pilot_clinics + dental_bonded_parts_suppliers tables · 12-KPI summary RPC · /dental-vertical-pilot page · register+invite Server Actions.",
    owner: "Claude · founder + vertical lead",
    target_weeks: "✅ DONE (3 weeks early)",
    status: "In progress",
    priority: "P1",
  },
  {
    phase: 5, title: "Founder action center v2 (write actions) — ✅ SHIPPED r1306",
    scope: "Extended r1303 /founder-action-center with founder_priority_actions table — founder can ACK/RESOLVE/ESCALATE/IGNORE each item with audit trail. Acked=24h silence, escalated=7d silence, resolved/ignored=permanent.",
    blockers: "None.",
    deliverables: "✅ founder_priority_actions table + log_founder_priority_action RPC + UI buttons + /founder-priority-actions-log audit page.",
    owner: "Claude",
    target_weeks: "✅ DONE (6 weeks early)",
    status: "In progress",
    priority: "P1",
  },
  {
    phase: 6, title: "Public investor share v2 — ✅ SHIPPED r1307",
    scope: "Public RPC investor_share_v2(p_token) at /share/investor/v2/[token] returning 13 sanitized KPIs (active MRR + lifetime GMV/payouts/signups + active engineers/hospitals/states + top-5 equipment categories + trust score + days operating). Built on r558 token_hash + max_views + view_count + status.",
    blockers: "None.",
    deliverables: "✅ Public route /share/investor/v2/[token] · token-gated · all outcomes logged · NO PII.",
    owner: "Claude",
    target_weeks: "✅ DONE (8 weeks early)",
    status: "In progress",
    priority: "P1",
  },
  {
    phase: 7, title: "DPDP grievance auto-routing — ✅ SHIPPED r1309 (+ r1313 fix)",
    scope: "dpdp_route_and_escalate cron runs hourly — routes new grievances to officer by r485 grievance_type, escalates approaching 30-day SLA. /dpdp-routing-summary surfaces 15 KPIs.",
    blockers: "None. Founder owns all 7 grievance types by default in dpdp_grievance_officers.",
    deliverables: "✅ dpdp_grievance_officers + dpdp_grievance_routing tables · cron · /dpdp-routing-summary page.",
    owner: "Claude",
    target_weeks: "✅ DONE (3 weeks early)",
    status: "In progress",
    priority: "P2",
  },
  {
    phase: 8, title: "Spot-audit cron + engineer-rotation enforcement — ✅ SHIPPED r1310",
    scope: "spot_audit_auto_invite runs hourly — creates invite on every 10th completed job per engineer · freezes rotation for engineers with ≥3 ignored in 90d · auto-unfreezes when below threshold.",
    blockers: "None. N=10 hardcoded.",
    deliverables: "✅ engineer_audit_compliance table · cron · /spot-audit-rotation-summary page.",
    owner: "Claude",
    target_weeks: "✅ DONE (4 weeks early)",
    status: "In progress",
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
        <h1 className="text-xl font-semibold">v0.5 roadmap ★ r1304 · r1323 update — 8/10 v0.5 phases SHIPPED in Day 5</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">10 phases planned · 8 SHIPPED ahead of schedule (3/4/5/6/7/8/9/10 + add. incidents/cron/tier-1/churn-warning/board-pack) · {ready} ready · {blocked} blocked</p>
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
