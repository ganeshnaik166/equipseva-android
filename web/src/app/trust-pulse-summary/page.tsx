import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Trust pulse summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  disputes_open: number;
  disputes_resolution_pct_30d: number;
  spot_audits_responded_30d: number;
  spot_audit_avg_rating_30d: number;
  spot_audit_pass_pct_30d: number;
  code_red_resolved_30d: number;
  code_red_sla_breach_pct_30d: number;
  escrow_refund_pct_30d: number;
  payouts_failed_pct_30d: number;
  amc_paused_now: number;
  amc_expired_30d: number;
  engineer_kyc_pending_over_7d: number;
  hospitals_signup_no_job: number;
  overall_trust_score: number;
};

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

const pct = (n: number) => `${Number(n).toFixed(1)}%`;

export default async function TrustPulseSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_trust_pulse_summary");
  if (error) throw new Error(`founder_trust_pulse_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Trust pulse summary</h1>
        <span className="text-xs text-[var(--color-muted)]">Composite trust score · disputes + audits + Code Red + refunds + payouts + AMC + KYC backlog</span>
      </header>
      {r ? (
        <>
          <div className={`rounded-lg border-2 p-6 ${r.overall_trust_score >= 90 ? "border-[var(--color-ok)]" : r.overall_trust_score >= 75 ? "border-[var(--color-warn)]" : "border-[var(--color-danger)]"} bg-[var(--color-surface)]`}>
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Overall trust score 30d (composite of 5 pass-rates)</div>
            <div className="mt-2 text-4xl font-bold tabular-nums">{pct(r.overall_trust_score)}</div>
            <div className="mt-1 text-xs text-[var(--color-muted)]">≥90% green · 75-90% amber · &lt;75% red · weight = (disputes-resolved + audit-pass + (100-Code-Red-breach) + (100-refund) + (100-payout-fail)) ÷ 5</div>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Card title="Disputes open" val={formatNumber(r.disputes_open)} danger={r.disputes_open > 0} />
            <Card title="Dispute resolution 30d" val={pct(r.disputes_resolution_pct_30d)} ok={r.disputes_resolution_pct_30d >= 80} danger={r.disputes_resolution_pct_30d < 50} />
            <Card title="Spot audits 30d" val={formatNumber(r.spot_audits_responded_30d)} sub={`avg ${Number(r.spot_audit_avg_rating_30d).toFixed(1)} ★`} />
            <Card title="Audit pass % 30d" val={pct(r.spot_audit_pass_pct_30d)} ok={r.spot_audit_pass_pct_30d >= 80} danger={r.spot_audit_pass_pct_30d < 60} sub="rating ≥4" />
            <Card title="Code Red resolved 30d" val={formatNumber(r.code_red_resolved_30d)} ok />
            <Card title="Code Red SLA breach 30d" val={pct(r.code_red_sla_breach_pct_30d)} danger={r.code_red_sla_breach_pct_30d > 10} />
            <Card title="Escrow refund % 30d" val={pct(r.escrow_refund_pct_30d)} danger={r.escrow_refund_pct_30d > 5} />
            <Card title="Payouts failed % 30d" val={pct(r.payouts_failed_pct_30d)} danger={r.payouts_failed_pct_30d > 5} />
            <Card title="AMC paused now" val={formatNumber(r.amc_paused_now)} sub="frozen MRR" />
            <Card title="AMC expired 30d" val={formatNumber(r.amc_expired_30d)} />
            <Card title="Engineer KYC pending >7d" val={formatNumber(r.engineer_kyc_pending_over_7d)} danger={r.engineer_kyc_pending_over_7d > 0} />
            <Card title="Hospitals never posted" val={formatNumber(r.hospitals_signup_no_job)} sub="activation gap" />
          </div>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
