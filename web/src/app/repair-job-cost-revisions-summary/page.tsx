import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Repair job cost revisions summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  proposed_now: number;
  approved_all_time: number;
  rejected_all_time: number;
  expired_all_time: number;
  approval_pct_all_time: number;
  proposed_30d: number;
  approved_30d: number;
  rejected_30d: number;
  avg_uplift_pct_approved_30d: number;
  total_uplift_inr_approved_30d: number;
  jobs_with_revision_30d: number;
  top_engineer_proposals_30d: number;
  avg_decide_hours_30d: number;
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

const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN")}`;

export default async function RepairJobCostRevisionsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_repair_job_cost_revisions_summary");
  if (error) throw new Error(`founder_repair_job_cost_revisions_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Repair job cost revisions summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI scope-creep audit &middot; uplift % + hospital decisions + abuse flags &middot; pair with /repair-jobs-snapshot-summary</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total revisions all-time" val={formatNumber(r.total_all_time)} sub="every proposal recorded" />
          <Card title="Proposed now" val={formatNumber(r.proposed_now)} danger={r.proposed_now > 0} sub="awaiting hospital decision" />
          <Card title="Approved all-time" val={formatNumber(r.approved_all_time)} ok sub="hospital said yes" />
          <Card title="Rejected all-time" val={formatNumber(r.rejected_all_time)} sub="hospital said no" />
          <Card title="Expired all-time" val={formatNumber(r.expired_all_time)} sub="24h no-decision" />
          <Card title="Approval % all-time" val={`${Number(r.approval_pct_all_time).toFixed(1)}%`} ok sub="approved / decided" />
          <Card title="Proposed 30d" val={formatNumber(r.proposed_30d)} sub="new requests last 30d" />
          <Card title="Approved 30d" val={formatNumber(r.approved_30d)} ok />
          <Card title="Rejected 30d" val={formatNumber(r.rejected_30d)} />
          <Card title="Avg uplift % (approved 30d)" val={`${Number(r.avg_uplift_pct_approved_30d).toFixed(1)}%`} danger={r.avg_uplift_pct_approved_30d > 50} sub="abuse flag if >50%" />
          <Card title="Total uplift INR (approved 30d)" val={inr(r.total_uplift_inr_approved_30d)} sub="extra GMV captured" />
          <Card title="Jobs w/ revision 30d" val={formatNumber(r.jobs_with_revision_30d)} sub="distinct jobs touched" />
          <Card title="Top engineer proposals 30d" val={formatNumber(r.top_engineer_proposals_30d)} danger={r.top_engineer_proposals_30d >= 5} sub="abuse flag if &ge;5" />
          <Card title="Avg decide hrs 30d" val={Number(r.avg_decide_hours_30d).toFixed(1)} sub="hospital response time" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}