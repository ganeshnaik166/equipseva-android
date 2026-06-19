import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRupees, formatPct, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Founder compliance ledger — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Ledger = {
  cdsco_pending_representations: number;
  cdsco_resolved_representations: number;
  gst_quarters_filed: number;
  gst_lifetime_outward_taxable_rupees: number;
  gst_last_filing_at: string | null;
  nabh_hospitals_certified: number;
  dpdp_total_grievances: number;
  dpdp_resolved_within_sla_pct: number;
  dpdp_top_officer: string;
  udyam_registered: boolean;
  udyam_urn: string;
  razorpay_last_capture_at: string | null;
  razorpay_lifetime_captures_rupees: number;
  cashfree_last_payout_at: string | null;
  cashfree_lifetime_payouts_rupees: number;
  audit_log_30d_count: number;
  audit_log_lifetime_count: number;
  pending_kyc_engineers: number;
  open_dispute_count: number;
  open_code_red_count: number;
  overall_compliance_score: number;
  generated_at: string;
};

function scoreBand(score: number): { label: string; tone: string; bg: string } {
  if (score >= 80) return { label: "Healthy",   tone: "text-[var(--color-ok)]",     bg: "border-[var(--color-ok)]" };
  if (score >= 60) return { label: "Watch",     tone: "text-[var(--color-warn)]",   bg: "border-[var(--color-warn)]" };
  return              { label: "At risk",   tone: "text-[var(--color-danger)]", bg: "border-[var(--color-danger)]" };
}

function Card({ title, value, sub, tone }: { title: string; value: string; sub?: string; tone?: string }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-lg font-semibold ${tone ?? ""}`}>{value}</div>
      {sub ? <div className="mt-1 text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function Section({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">{label}</h2>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">{children}</div>
    </section>
  );
}

export default async function FounderComplianceLedgerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_compliance_ledger_consolidated");
  if (error) throw new Error(`founder_compliance_ledger_consolidated: ${error.message}`);
  const l = (data?.[0] ?? null) as Ledger | null;

  if (!l) {
    return (
      <div className="space-y-4">
        <h1 className="text-xl font-semibold">Founder compliance ledger ★ r1327</h1>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-sm text-[var(--color-muted)]">
          No ledger data yet — the aggregator returned no rows. Check that founder_compliance_ledger_consolidated() is deployed.
        </div>
      </div>
    );
  }

  const band = scoreBand(l.overall_compliance_score);

  return (
    <div className="space-y-8">
      <header>
        <h1 className="text-xl font-semibold">Founder compliance ledger ★ r1327</h1>
        <p className="mt-1 text-xs text-[var(--color-muted)]">
          Consolidated regulatory health across GST · DPDP · Razorpay · Cashfree · KYC · disputes · Code Red · audit.
          Use as the diligence-ready compliance freeze for board meetings & investor share v2.
          Snapshot at {formatRelativeTime(l.generated_at)}.
        </p>
      </header>

      <section className={`rounded-lg border-2 ${band.bg} bg-[var(--color-surface)] p-6`}>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div className="sm:col-span-1">
            <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">Overall compliance score</div>
            <div className={`mt-2 text-5xl font-bold ${band.tone}`}>{l.overall_compliance_score.toFixed(1)}</div>
            <div className={`mt-1 text-sm font-semibold ${band.tone}`}>{band.label} · /100</div>
          </div>
          <div className="sm:col-span-2 text-xs text-[var(--color-muted)] leading-relaxed">
            Weighted index across five regulatory dimensions: GST filings (30%) · DPDP SLA (30%) · KYC throughput (20%) ·
            Razorpay capture liveness (10%) · Cashfree payout liveness (10%). Bands: {"≥"}80 healthy · {"≥"}60 watch · {"<"}60 at risk.
            This is the same number that feeds the public investor share v2 compliance band — keep it ≥80 before any
            board send.
          </div>
        </div>
      </section>

      <Section label="Tax · GST">
        <Card title="Quarters filed (lifetime)"      value={formatNumber(l.gst_quarters_filed)}                  sub="founder_gst_filings.status=filed" />
        <Card title="Lifetime outward taxable"        value={formatRupees(l.gst_lifetime_outward_taxable_rupees)} sub="gst_invoices.status=issued" />
        <Card title="Last filing"                     value={formatRelativeTime(l.gst_last_filing_at)}             sub="max(filed_at)" />
        <Card title="Audit log 30d ops"               value={formatNumber(l.audit_log_30d_count)}                  sub="founder_action_log 30d" />
      </Section>

      <Section label="Privacy · DPDP">
        <Card title="Total grievances (lifetime)"     value={formatNumber(l.dpdp_total_grievances)}                sub="dpdp_grievances" />
        <Card title="Resolved within SLA"             value={formatPct(l.dpdp_resolved_within_sla_pct)}            sub="resolved_at <= deadline_at" tone={l.dpdp_resolved_within_sla_pct >= 90 ? "text-[var(--color-ok)]" : l.dpdp_resolved_within_sla_pct >= 70 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]"} />
        <Card title="Top grievance officer"           value={l.dpdp_top_officer}                                   sub="active officer with most routed cases" />
        <Card title="DPDP open disputes (escrow)"     value={formatNumber(l.open_dispute_count)}                   sub="repair_job_escrow.dispute_opened_at" tone={l.open_dispute_count > 0 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]"} />
      </Section>

      <Section label="Regulatory · CDSCO + NABH + Udyam">
        <Card title="CDSCO pending representations"   value={formatNumber(l.cdsco_pending_representations)}        sub="ledger reserved for v0.6" />
        <Card title="CDSCO resolved representations"  value={formatNumber(l.cdsco_resolved_representations)}       sub="ledger reserved for v0.6" />
        <Card title="NABH hospitals certified"        value={formatNumber(l.nabh_hospitals_certified)}             sub="ledger reserved for v0.6" />
        <Card title="Udyam registration"              value={l.udyam_registered ? "Registered" : "Pending"}        sub={l.udyam_urn} tone={l.udyam_registered ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]"} />
      </Section>

      <Section label="Payments · Razorpay (incoming)">
        <Card title="Last successful capture"         value={formatRelativeTime(l.razorpay_last_capture_at)}       sub="razorpay_webhook_events payment.captured" tone={l.razorpay_last_capture_at ? "text-[var(--color-ok)]" : "text-[var(--color-muted)]"} />
        <Card title="Lifetime captured"               value={formatRupees(l.razorpay_lifetime_captures_rupees)}    sub="sum(amount_paise)/100" />
        <Card title="Open Code Red"                   value={formatNumber(l.open_code_red_count)}                  sub="code_red_requests.status=open" tone={l.open_code_red_count > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-ok)]"} />
        <Card title="Pending KYC engineers"           value={formatNumber(l.pending_kyc_engineers)}                sub="engineers.verification_status=pending" tone={l.pending_kyc_engineers > 50 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]"} />
      </Section>

      <Section label="Payouts · Cashfree (outgoing)">
        <Card title="Last successful payout"          value={formatRelativeTime(l.cashfree_last_payout_at)}        sub="engineer_payouts.status=processed" tone={l.cashfree_last_payout_at ? "text-[var(--color-ok)]" : "text-[var(--color-muted)]"} />
        <Card title="Lifetime payouts to engineers"   value={formatRupees(l.cashfree_lifetime_payouts_rupees)}     sub="sum(amount_paise)/100" />
        <Card title="Audit log lifetime"              value={formatNumber(l.audit_log_lifetime_count)}             sub="founder_action_log all-time" />
        <Card title="Open disputes (cash held)"       value={formatNumber(l.open_dispute_count)}                   sub="escrow held until resolution" />
      </Section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">How to read this</h2>
        <ul className="mt-3 space-y-2 text-xs text-[var(--color-muted)]">
          <li>• <span className="text-[var(--color-fg)]">Tax/GST</span> — every filed quarter unlocks 7.5 score points. 4/4 filed = full 30 points.</li>
          <li>• <span className="text-[var(--color-fg)]">Privacy/DPDP</span> — % of resolved grievances closed before 30-day deadline. 100% SLA = full 30 points.</li>
          <li>• <span className="text-[var(--color-fg)]">KYC throughput</span> — fraction of active engineers already verified. Target {">"}90% verified.</li>
          <li>• <span className="text-[var(--color-fg)]">Razorpay liveness</span> — last successful capture within 7d signals healthy incoming-cash plumbing.</li>
          <li>• <span className="text-[var(--color-fg)]">Cashfree liveness</span> — last successful payout within 14d signals healthy outgoing-cash plumbing.</li>
          <li>• <span className="text-[var(--color-fg)]">CDSCO & NABH</span> — placeholders until a representation/certification ledger ships in v0.6.</li>
        </ul>
      </section>
    </div>
  );
}
