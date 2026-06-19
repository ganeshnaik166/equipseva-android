import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "v0.6 roadmap — EquipSeva Founder Console" };
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
    phase: 1, title: "Vertical expansion — dental continuation + lab diagnostics + radiology",
    scope: "Build on v0.5 Phase 4 dental pilot. Extend bonded-parts supplier network to lab diagnostics (analyzers, centrifuges, microscopes) and radiology specialty (portable X-ray, ultrasound, mobile CT). Each vertical gets its own equipment_taxonomy_class + dedicated supplier cohort + specialty AMC pricing tier.",
    blockers: "Dental pilot retention metrics (need 90-day data from v0.5 P4) · founder-led sales for lab + radiology anchor accounts (5 each).",
    deliverables: "lab_diagnostic_pilot_clinics + radiology_pilot_centers tables · 24-KPI summary RPC across 3 verticals · /vertical-expansion-snapshot · per-vertical AMC tier pricing.",
    owner: "Claude · founder + 3 vertical leads",
    target_weeks: "Weeks 1-6",
    status: "Planned",
    priority: "P0",
  },
  {
    phase: 2, title: "Hospital chain bulk-import v2 — pre-filled AMC affidavits + signature workflow",
    scope: "Extends v0.5 Phase 3 hospital-chain bulk import with auto-generated AMC affidavit PDFs (per-chain pre-filled with chain-signer name, equipment_categories, monthly_fee_rupees, start_date/end_date). DocuSign-compatible signature workflow. Status tracking: drafted → sent → signed → activated.",
    blockers: "DocuSign API credentials + Anvil/PDFKit for PDF generation · Indian Stamp Act compliance check for digital signatures on AMC affidavits.",
    deliverables: "amc_affidavit_drafts + amc_affidavit_signatures tables · generate_amc_affidavit_pdf Edge Function · /hospital-chain-affidavit-pipeline page · DocuSign webhook handler.",
    owner: "Claude · founder + legal counsel review",
    target_weeks: "Weeks 2-5",
    status: "Planned",
    priority: "P0",
  },
  {
    phase: 3, title: "Engineer app v0.6 — offline-first + peer-to-peer parts marketplace + training mode",
    scope: "Android v0.6 with: offline-first job queue (Room-cached, sync on reconnect), peer-to-peer parts marketplace (engineer A sells surplus to engineer B with platform escrow), training mode (guided walkthroughs for new engineers on first 5 jobs, supervisor sign-off required).",
    blockers: "v0.5 Phase 2 engineer mobile v0.5 must ship first · Phase 1 Cashfree real payouts needed for P2P marketplace escrow.",
    deliverables: "Room offline cache · engineer_p2p_parts_listings table · training_mode_completions table · Play Store rollout to 100% of active engineers.",
    owner: "Mobile · QA · supervisor lead",
    target_weeks: "Weeks 3-8",
    status: "Planned",
    priority: "P1",
  },
  {
    phase: 4, title: "AI-assisted triage — Code Red ML routing + GPU equipment risk scoring",
    scope: "Train classifier on historical repair_jobs + code_red_requests to predict (a) optimal engineer for incoming code-red (latency + skill match + tier), (b) per-equipment 30-day failure risk score driving proactive AMC upsell. Self-hosted on Vercel AI SDK + small open model.",
    blockers: "Need ≥10k labeled historical repair jobs (currently ~2k) — gates training cohort to v0.6 Q3+ · GPU/model hosting cost evaluation.",
    deliverables: "code_red_ml_predictions + equipment_risk_scores tables · cron updates risk scores daily · /code-red-ml-vs-rule-based-bakeoff page · proactive AMC upsell campaign hooked to risk score.",
    owner: "Claude · founder + data lead",
    target_weeks: "Weeks 6-14",
    status: "Planned",
    priority: "P1",
  },
  {
    phase: 5, title: "Cashfree real-money payouts at scale",
    scope: "POST v0.5 Phase 1 Cashfree activation. Scale from 1 payout/week to 500+/week. Add multi-payout-method (UPI · IMPS · NEFT fallback chain), payout retry policy with exponential backoff, founder-side daily reconciliation report comparing Cashfree settled vs engineer_payouts.status=processed.",
    blockers: "v0.5 Phase 1 must be Live (real-money flowing) · Cashfree API rate-limit headroom (verify before scale).",
    deliverables: "engineer_payout_methods table · payout_retry_log table · /payouts-at-scale-snapshot · daily reconciliation cron + founder email at 09:00 IST.",
    owner: "Claude · founder + Cashfree TAM",
    target_weeks: "Weeks 4-8",
    status: "Planned",
    priority: "P0",
  },
  {
    phase: 6, title: "State-level franchise model — 3-state pilot with local franchisee",
    scope: "Pilot franchise model in Karnataka + Maharashtra + Tamil Nadu — local franchisee owns engineer recruiting + hospital sales in their state, EquipSeva keeps platform + tech + payments + central support. Revenue split: 60 franchisee / 40 platform on AMC; 70/30 on repair-job take.",
    blockers: "Founder legal: franchise agreement template (CA + lawyer review) · franchisee KYC + Udyam registration per franchisee · need 1 anchor franchisee per state.",
    deliverables: "franchise_partners table · franchise_revenue_splits ledger · per-state cohort snapshots (/franchise-karnataka-snapshot · /franchise-maharashtra-snapshot · /franchise-tamilnadu-snapshot) · franchisee-onboarding wizard.",
    owner: "Founder-led · Claude builds infra",
    target_weeks: "Weeks 8-16",
    status: "Planned",
    priority: "P1",
  },
  {
    phase: 7, title: "Hospital portal v2 — self-service AMC purchase + tier downgrades/upgrades",
    scope: "Hospitals can log into /hospital/[id]/portal and: purchase AMC tier directly (Razorpay link), upgrade/downgrade existing AMC mid-contract with prorated billing, view all repair jobs + invoices + escrow status, export GST invoices for their accountant. Removes founder/sales from 80% of AMC transactions.",
    blockers: "v0.5 Phase 1 Cashfree live (for refunds on downgrade) · hospital auth (passwordless via SMS OTP).",
    deliverables: "hospital_portal_sessions table · self-service AMC tier transition RPC · proration ledger · /hospital-portal-conversion-funnel page · /hospital/[id]/portal/* routes.",
    owner: "Claude · founder owns hospital UX review",
    target_weeks: "Weeks 5-10",
    status: "Planned",
    priority: "P1",
  },
  {
    phase: 8, title: "Investor data room — DocSend-style document tracking + access analytics",
    scope: "Extends v0.5 Phase 6 public investor share. Token-gated data room where investors get scoped access to: pitch deck · audited financials · cap table · customer references · founder bio. Per-document view tracking (time-on-page, sections scrolled, downloads). Founder gets digest: who viewed what + for how long.",
    blockers: "PDF render pipeline · per-document watermarking with investor token.",
    deliverables: "investor_data_room_documents + investor_document_views tables · /share/data-room/[token] route · /investor-data-room-analytics founder page · per-investor digest cron.",
    owner: "Claude",
    target_weeks: "Weeks 6-9",
    status: "Planned",
    priority: "P2",
  },
  {
    phase: 9, title: "Public market intelligence — competitor pricing scrape + market share dashboard",
    scope: "Weekly cron scrapes competitor AMC pricing (TrustMaeq, Skanray service contracts, OEM AMC) from public sources. Maintains pricing_intelligence table. /market-share-dashboard estimates EquipSeva share by city/equipment-category vs public TAM data (CDSCO registrations as proxy).",
    blockers: "Robots.txt + ToS review per competitor source · Bright Data or ScraperAPI budget.",
    deliverables: "competitor_pricing_snapshots + market_share_estimates tables · weekly scrape cron · /market-intelligence-snapshot + /market-share-dashboard pages · founder email on pricing changes.",
    owner: "Claude · founder reviews scraping scope",
    target_weeks: "Weeks 10-14",
    status: "Planned",
    priority: "P2",
  },
  {
    phase: 10, title: "International expansion — 1 Asian market pilot (Sri Lanka / Bangladesh / Nepal)",
    scope: "Replicate v0.4+v0.5 stack into 1 neighboring Asian market — pilot decision matrix scores Sri Lanka (highest GDP/capita · English-friendly) · Bangladesh (largest TAM · Bengali required) · Nepal (smallest TAM · easy to dominate). Multi-currency support, local payment rails (bKash for BD · eSewa for NP), local regulatory (BSDA-equivalent CDSCO).",
    blockers: "Cross-border money movement (RBI LRS approval) · local entity setup (4-12 weeks per country) · founder bandwidth — only 1 market in v0.6.",
    deliverables: "Multi-tenant org schema additions (org.country) · multi-currency money columns · local payment-method integration (1 of bKash/eSewa) · /intl-pilot-{country}-snapshot.",
    owner: "Founder-led · Claude builds infra after country picked",
    target_weeks: "Weeks 12-24",
    status: "Planned",
    priority: "P3",
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

export default async function V06RoadmapPage() {
  await requireFounder();
  const ready = PLAN.filter(p => p.status === "Ready").length;
  const blocked = PLAN.filter(p => p.status === "Blocked").length;
  const planned = PLAN.filter(p => p.status === "Planned").length;
  const p0 = PLAN.filter(p => p.priority === "P0").length;
  const p1 = PLAN.filter(p => p.priority === "P1").length;
  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">v0.6 roadmap — POST-v0.5 expansion plan</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          10 phases planned · {planned} planned · {ready} ready · {blocked} blocked · {p0} P0 · {p1} P1 · target window Weeks 1-24
        </p>
      </header>

      <section className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-6">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">v0.6 thesis</div>
        <p className="mt-2 text-sm">
          v0.4 built observability (~80 snapshots + audit-paired self-correcting workflow). v0.5 turned observability into
          action (Cashfree payouts, hospital-chain bulk onboarding, dental pilot, action-center writes, public investor share v2).
          v0.6 EXPANDS THE SURFACE: more verticals (lab + radiology on top of dental), self-service for hospitals (portal v2)
          and engineers (offline-first + P2P marketplace), franchise-model state expansion (3-state pilot), AI-assisted triage
          (ML on top of rule-based code-red routing), and first international beachhead (1 Asian market). Goal at end of v0.6:
          3 verticals live, 3-state franchise pilot, 1 international pilot, 500+ payouts/week.
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

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <h2 className="text-sm font-semibold mb-2 uppercase tracking-wider text-[var(--color-muted)]">Sequencing notes</h2>
        <ul className="text-xs space-y-1 list-disc list-inside">
          <li><span className="text-[var(--color-muted)]">Hard dependency: </span>Phase 5 (Cashfree at scale) needs v0.5 Phase 1 LIVE first. Phase 3 P2P marketplace needs Phase 5. Phase 7 hospital portal refund flow needs Phase 5.</li>
          <li><span className="text-[var(--color-muted)]">Founder bottleneck: </span>Phases 2 (legal), 6 (franchise legal + sales), 10 (entity setup + country pick) are founder-time-bound, not engineering-bound.</li>
          <li><span className="text-[var(--color-muted)]">Data dependency: </span>Phase 4 ML triage gated on ≥10k labeled jobs — currently ~2k. Realistic ship in v0.6 Q3 if repair-job volume accelerates via Phase 2 hospital affidavits and Phase 1 vertical expansion.</li>
          <li><span className="text-[var(--color-muted)]">Quick wins first: </span>Phases 1 + 2 + 5 + 7 should anchor first 8 weeks (revenue-direct). Phases 8 + 9 are operator quality-of-life. Phase 10 starts founder discovery in Week 12.</li>
        </ul>
      </section>
    </div>
  );
}
