import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Repair types snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  jobs_total_90d: number;
  distinct_job_types_90d: number;
  top_job_type: string;
  top_job_type_count_90d: number;
  unspecified_job_type_90d: number;
  amc_kind_jobs_90d: number;
  warranty_kind_jobs_90d: number;
  paid_kind_jobs_90d: number;
  urgency_emergency_90d: number;
  urgency_high_90d: number;
  contracted_revenue_30d_rupees: number;
  avg_completion_hours_by_kind_amc: number;
  avg_completion_hours_by_kind_paid: number;
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

export default async function RepairTypesSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_repair_types_snapshot_summary");
  if (error) throw new Error(`founder_repair_types_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Repair types snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">13-KPI mix-shift pulse · job_type/kind/urgency · 90d window · pair with /jobs-by-equipment-type</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Jobs total 90d" val={formatNumber(r.jobs_total_90d)} />
          <Card title="Distinct job_types 90d" val={formatNumber(r.distinct_job_types_90d)} sub="taxonomy spread" />
          <Card title="Top job_type 90d" val={r.top_job_type} sub={`${formatNumber(r.top_job_type_count_90d)} jobs`} />
          <Card title="Unspecified job_type 90d" val={formatNumber(r.unspecified_job_type_90d)} sub="taxonomy hygiene" danger={r.unspecified_job_type_90d > 0} />
          <Card title="AMC-kind jobs 90d" val={formatNumber(r.amc_kind_jobs_90d)} sub="pool-funded" />
          <Card title="Warranty-kind jobs 90d" val={formatNumber(r.warranty_kind_jobs_90d)} sub="OEM-covered" />
          <Card title="Paid-kind jobs 90d" val={formatNumber(r.paid_kind_jobs_90d)} sub="escrow revenue" ok />
          <Card title="Emergency urgency 90d" val={formatNumber(r.urgency_emergency_90d)} danger={r.urgency_emergency_90d > 0} />
          <Card title="High urgency 90d" val={formatNumber(r.urgency_high_90d)} sub="SLA pressure" />
          <Card title="Contracted revenue 30d" val={formatRupees(r.contracted_revenue_30d_rupees)} ok />
          <Card title="Avg completion AMC (30d, hrs)" val={Number(r.avg_completion_hours_by_kind_amc).toFixed(1)} sub="pool jobs cycle" />
          <Card title="Avg completion paid (30d, hrs)" val={Number(r.avg_completion_hours_by_kind_paid).toFixed(1)} sub="escrow jobs cycle" />
          <Card title="AMC vs paid mix 90d" val={`${formatNumber(r.amc_kind_jobs_90d)} / ${formatNumber(r.paid_kind_jobs_90d)}`} sub="margin driver" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
