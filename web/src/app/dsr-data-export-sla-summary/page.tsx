import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "DSR data-export SLA summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  open_dsr_now: number;
  breached_sla_open: number;
  approaching_24h_open: number;
  filed_today: number;
  filed_7d: number;
  filed_30d: number;
  resolved_today: number;
  resolved_7d: number;
  resolved_30d: number;
  avg_resolution_hours_30d: number;
  p90_resolution_hours_30d: number;
  oldest_open_age_hours: number;
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

export default async function DsrDataExportSlaSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_dsr_data_export_sla_summary");
  if (error) throw new Error(`founder_dsr_data_export_sla_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">DSR data-export SLA summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI DPDP panel · DSR queue + SLA breach + completion latency · pair with /dpdp-grievances</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Open DSR now" val={formatNumber(r.open_dsr_now)} sub="awaiting fulfilment" />
          <Card title="SLA breached (open)" val={formatNumber(r.breached_sla_open)} danger={r.breached_sla_open > 0} sub="past deadline" />
          <Card title="Approaching SLA <24h" val={formatNumber(r.approaching_24h_open)} danger={r.approaching_24h_open > 0} sub="open + due within 24h" />
          <Card title="Filed today" val={formatNumber(r.filed_today)} sub="IST day" />
          <Card title="Filed 7d" val={formatNumber(r.filed_7d)} />
          <Card title="Filed 30d" val={formatNumber(r.filed_30d)} />
          <Card title="Resolved today" val={formatNumber(r.resolved_today)} ok={r.resolved_today > 0} />
          <Card title="Resolved 7d" val={formatNumber(r.resolved_7d)} ok />
          <Card title="Resolved 30d" val={formatNumber(r.resolved_30d)} ok />
          <Card title="Avg resolution (30d, hours)" val={Number(r.avg_resolution_hours_30d).toFixed(1)} />
          <Card title="P90 resolution (30d, hours)" val={Number(r.p90_resolution_hours_30d).toFixed(1)} sub="tail latency" />
          <Card title="Oldest open age (hours)" val={Number(r.oldest_open_age_hours).toFixed(1)} danger={r.oldest_open_age_hours > 24} sub="DPDP audit risk" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
