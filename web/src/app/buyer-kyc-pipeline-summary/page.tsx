import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Buyer KYC pipeline summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  requests_total: number;
  status_pending: number;
  status_verified: number;
  status_rejected: number;
  pending_0_7d: number;
  pending_7_30d: number;
  pending_over_30d: number;
  oldest_pending_days: number;
  avg_pending_age_days: number;
  avg_review_days_30d: number;
  submitted_today: number;
  reviewed_today: number;
  doc_type_gst_pending: number;
  checkout_gated_profiles: number;
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

export default async function BuyerKycPipelineSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_buyer_kyc_pipeline_summary");
  if (error) throw new Error(`founder_buyer_kyc_pipeline_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Buyer KYC pipeline summary</h1>
        <span className="text-xs text-[var(--color-muted)]">{`14-KPI hospital-buyer KYC queue · pending + aging buckets + 30d review velocity + IST-day intake/review + GST doc-mix + checkout gate`}</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Requests total" val={formatNumber(r.requests_total)} sub="all-time submissions" />
          <Card title="Pending" val={formatNumber(r.status_pending)} danger={r.status_pending > 0} sub="awaiting founder review" />
          <Card title="Verified" val={formatNumber(r.status_verified)} ok={r.status_verified > 0} sub="lifetime cleared" />
          <Card title="Rejected" val={formatNumber(r.status_rejected)} danger={r.status_rejected > 0} sub="needs resubmit" />
          <Card title="Pending 0-7d" val={formatNumber(r.pending_0_7d)} sub="fresh queue" />
          <Card title="Pending 7-30d" val={formatNumber(r.pending_7_30d)} danger={r.pending_7_30d > 0} sub="aging — review now" />
          <Card title={`Pending ${'>'}30d`} val={formatNumber(r.pending_over_30d)} danger={r.pending_over_30d > 0} sub="stale — checkout still blocked" />
          <Card title="Oldest pending (d)" val={formatNumber(r.oldest_pending_days)} danger={r.oldest_pending_days > 30} sub="worst-case wait" />
          <Card title="Avg pending age (d)" val={`${Number(r.avg_pending_age_days).toFixed(2)}d`} danger={r.avg_pending_age_days >= 14} sub="backlog health" />
          <Card title="Avg review days 30d" val={`${Number(r.avg_review_days_30d).toFixed(2)}d`} ok={r.avg_review_days_30d > 0 && r.avg_review_days_30d < 2} danger={r.avg_review_days_30d >= 7} sub="founder turnaround" />
          <Card title="Submitted today" val={formatNumber(r.submitted_today)} sub="IST day intake" />
          <Card title="Reviewed today" val={formatNumber(r.reviewed_today)} ok={r.reviewed_today > 0} sub="IST day throughput" />
          <Card title="GST doc pending" val={formatNumber(r.doc_type_gst_pending)} sub="top doc-type backlog" />
          <Card title="Checkout-gated buyers" val={formatNumber(r.checkout_gated_profiles)} danger={r.checkout_gated_profiles > 0} sub="profiles.buyer_kyc_status not verified" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}