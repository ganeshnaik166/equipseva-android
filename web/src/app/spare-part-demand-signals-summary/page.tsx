import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spare-part demand signals summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_signals_all_time: number;
  total_unresolved: number;
  total_resolved: number;
  resolved_pct: number;
  critical_unresolved: number;
  urgent_unresolved: number;
  high_priority_unresolved: number;
  distinct_groups_unresolved: number;
  unique_reporters_30d: number;
  signals_30d: number;
  signals_7d: number;
  signals_today: number;
  resolved_supplier_onboard: number;
  resolved_bonded_intake: number;
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

export default async function SparePartDemandSignalsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_part_demand_signals_summary");
  if (error) throw new Error(`founder_spare_part_demand_signals_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare-part demand signals summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI supply-gap radar · search-no-results + RFQ-no-supplier intent · pair with /demand-signals</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total signals all-time" val={formatNumber(r.total_signals_all_time)} sub="every search/RFQ miss" />
          <Card title="Unresolved" val={formatNumber(r.total_unresolved)} danger sub="open supply gaps" />
          <Card title="Resolved" val={formatNumber(r.total_resolved)} ok />
          <Card title="Resolved pct" val={`${Number(r.resolved_pct).toFixed(1)}%`} ok={Number(r.resolved_pct) >= 50} sub="closure rate" />
          <Card title="Critical unresolved" val={formatNumber(r.critical_unresolved)} danger sub="urgency = critical" />
          <Card title="Urgent unresolved" val={formatNumber(r.urgent_unresolved)} sub="urgency = urgent" />
          <Card title="High-priority unresolved" val={formatNumber(r.high_priority_unresolved)} danger sub="founder flagged" />
          <Card title="Distinct groups (open)" val={formatNumber(r.distinct_groups_unresolved)} sub="brand|model|part" />
          <Card title="Unique reporters 30d" val={formatNumber(r.unique_reporters_30d)} sub="market breadth" />
          <Card title="Signals 30d" val={formatNumber(r.signals_30d)} />
          <Card title="Signals 7d" val={formatNumber(r.signals_7d)} />
          <Card title="Signals today" val={formatNumber(r.signals_today)} sub="IST day" />
          <Card title="Resolved · supplier onboarded" val={formatNumber(r.resolved_supplier_onboard)} ok sub="net-new supply" />
          <Card title="Resolved · bonded intake" val={formatNumber(r.resolved_bonded_intake)} ok sub="provenance closed" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
