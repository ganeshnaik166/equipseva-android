import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Buyer KYC verifications summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  decisions_lifetime: number;
  approval_rate_pct: number;
  rejection_rate_pct: number;
  decisions_30d: number;
  approval_rate_30d_pct: number;
  median_decision_hours: number;
  p95_decision_hours: number;
  decisions_under_24h_30d_pct: number;
  manual_review_backlog: number;
  backlog_breach_48h: number;
  doc_type_gst_share_pct: number;
  doc_type_shop_reg_share_pct: number;
  doc_type_drug_license_share_pct: number;
  doc_type_medical_id_share_pct: number;
  distinct_reviewers_30d: number;
  rejections_with_reason_pct: number;
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

export default async function BuyerKycVerificationsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_buyer_kyc_verifications_summary");
  if (error) throw new Error(`founder_buyer_kyc_verifications_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Buyer KYC verifications summary</h1>
        <span className="text-xs text-[var(--color-muted)]">{`16-KPI verification outcomes · lifetime + 30d approval rate · median/p95 time-to-decision · 48h backlog breach · doc-type mix · reviewer activity`}</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Decisions lifetime" val={formatNumber(r.decisions_lifetime)} sub="verified + rejected" />
          <Card title="Approval rate" val={`${Number(r.approval_rate_pct).toFixed(2)}%`} ok={r.approval_rate_pct >= 70} danger={r.approval_rate_pct > 0 && r.approval_rate_pct < 50} sub="lifetime verified share" />
          <Card title="Rejection rate" val={`${Number(r.rejection_rate_pct).toFixed(2)}%`} danger={r.rejection_rate_pct >= 30} sub="lifetime rejected share" />
          <Card title="Decisions 30d" val={formatNumber(r.decisions_30d)} sub="reviewed last 30 days" />
          <Card title="Approval rate 30d" val={`${Number(r.approval_rate_30d_pct).toFixed(2)}%`} ok={r.approval_rate_30d_pct >= 70} danger={r.approval_rate_30d_pct > 0 && r.approval_rate_30d_pct < 50} sub="recent verified share" />
          <Card title="Median decision (h)" val={`${Number(r.median_decision_hours).toFixed(2)}h`} ok={r.median_decision_hours > 0 && r.median_decision_hours < 24} danger={r.median_decision_hours >= 72} sub="p50 submitted to reviewed" />
          <Card title="P95 decision (h)" val={`${Number(r.p95_decision_hours).toFixed(2)}h`} danger={r.p95_decision_hours >= 168} sub="tail latency" />
          <Card title="Decisions under 24h 30d" val={`${Number(r.decisions_under_24h_30d_pct).toFixed(2)}%`} ok={r.decisions_under_24h_30d_pct >= 80} danger={r.decisions_under_24h_30d_pct > 0 && r.decisions_under_24h_30d_pct < 50} sub="founder SLA" />
          <Card title="Manual review backlog" val={formatNumber(r.manual_review_backlog)} danger={r.manual_review_backlog > 0} sub="pending awaiting decision" />
          <Card title="Backlog breach 48h" val={formatNumber(r.backlog_breach_48h)} danger={r.backlog_breach_48h > 0} sub="pending older than 48h" />
          <Card title="GST doc share" val={`${Number(r.doc_type_gst_share_pct).toFixed(2)}%`} sub="of decided docs" />
          <Card title="Shop reg doc share" val={`${Number(r.doc_type_shop_reg_share_pct).toFixed(2)}%`} sub="of decided docs" />
          <Card title="Drug license share" val={`${Number(r.doc_type_drug_license_share_pct).toFixed(2)}%`} sub="of decided docs" />
          <Card title="Medical ID share" val={`${Number(r.doc_type_medical_id_share_pct).toFixed(2)}%`} sub="of decided docs" />
          <Card title="Distinct reviewers 30d" val={formatNumber(r.distinct_reviewers_30d)} sub="founder accounts deciding" />
          <Card title="Rejections with reason" val={`${Number(r.rejections_with_reason_pct).toFixed(2)}%`} ok={r.rejections_with_reason_pct >= 90} danger={r.rejections_with_reason_pct > 0 && r.rejections_with_reason_pct < 70} sub="audit completeness" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}