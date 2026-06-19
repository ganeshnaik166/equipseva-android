import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC SLA + Warranty snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_breaches_all_time: number;
  open_breaches: number;
  breaches_today: number;
  breaches_30d: number;
  emergency_breaches_30d: number;
  credits_issued_30d_rupees: number;
  credits_owed_open_rupees: number;
  avg_actual_hours_30d: number;
  avg_target_hours_30d: number;
  warranty_jobs_30d: number;
  warranty_jobs_today: number;
  warranty_fee_waived_30d_rupees: number;
  contracts_with_breach_30d: number;
  top_breaching_engineer_breaches: number;
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

export default async function AmcSlaWarrantySnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_sla_warranty_snapshot_summary");
  if (error) throw new Error(`founder_amc_sla_warranty_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC SLA + Warranty snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI SLA pulse · breaches + credits owed + warranty waivers · pair with /amc-snapshot-summary</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total SLA breaches all-time" val={formatNumber(r.total_breaches_all_time)} />
          <Card title="Open breaches" val={formatNumber(r.open_breaches)} danger={r.open_breaches > 0} sub="resolved_at IS NULL" />
          <Card title="Breaches today" val={formatNumber(r.breaches_today)} danger={r.breaches_today > 0} />
          <Card title="Breaches 30d" val={formatNumber(r.breaches_30d)} />
          <Card title="Emergency breaches 30d" val={formatNumber(r.emergency_breaches_30d)} danger={r.emergency_breaches_30d > 0} sub="severity=emergency" />
          <Card title="Credits issued 30d" val={`₹${Number(r.credits_issued_30d_rupees).toLocaleString("en-IN")}`} sub="hospital goodwill paid" />
          <Card title="Credits owed (open)" val={`₹${Number(r.credits_owed_open_rupees).toLocaleString("en-IN")}`} danger={Number(r.credits_owed_open_rupees) > 0} sub="unresolved breach $$$" />
          <Card title="Avg actual hours 30d" val={Number(r.avg_actual_hours_30d).toFixed(1)} sub="time-to-arrive" />
          <Card title="Avg target hours 30d" val={Number(r.avg_target_hours_30d).toFixed(1)} sub="contract SLA target" />
          <Card title="Warranty jobs 30d" val={formatNumber(r.warranty_jobs_30d)} sub="auto-detected re-visits" />
          <Card title="Warranty jobs today" val={formatNumber(r.warranty_jobs_today)} />
          <Card title="Warranty fee waived 30d" val={`₹${Number(r.warranty_fee_waived_30d_rupees).toLocaleString("en-IN")}`} sub="platform absorbed cost" />
          <Card title="Contracts breached 30d" val={formatNumber(r.contracts_with_breach_30d)} sub="distinct AMC contracts" />
          <Card title="Top engineer breaches 30d" val={formatNumber(r.top_breaching_engineer_breaches)} danger={r.top_breaching_engineer_breaches > 0} sub="worst single engineer" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
