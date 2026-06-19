import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer availability summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  verified_engineers: number;
  reachable_1h: number;
  reachable_24h: number;
  reachable_7d: number;
  reachable_24h_pct: number;
  open_repair_jobs: number;
  open_code_reds: number;
  unassigned_code_reds: number;
  bids_last_1h: number;
  bids_last_24h: number;
  supply_to_open_demand: number;
  hot_supply_share_pct: number;
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

export default async function EngineerAvailabilitySummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_availability_summary");
  if (error) throw new Error(`founder_engineer_availability_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  const supplyOk = r ? Number(r.supply_to_open_demand) >= 1 : false;
  const redAlert = r ? Number(r.unassigned_code_reds) > 0 : false;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer availability summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI live supply pulse · bid-recency proxy for online presence · pair with /code-red-feed + /repair-jobs-open</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Verified engineers" val={formatNumber(r.verified_engineers)} sub="supply base" />
          <Card title="Reachable last 1h" val={formatNumber(r.reachable_1h)} ok={r.reachable_1h > 0} sub="hot supply (bid in last hr)" />
          <Card title="Reachable last 24h" val={formatNumber(r.reachable_24h)} sub="warm supply" />
          <Card title="Reachable last 7d" val={formatNumber(r.reachable_7d)} sub="weekly active supply" />
          <Card title="Reachable 24h %" val={`${Number(r.reachable_24h_pct).toFixed(1)}%`} danger={Number(r.reachable_24h_pct) < 10} sub="of verified base" />
          <Card title="Hot supply share %" val={`${Number(r.hot_supply_share_pct).toFixed(1)}%`} sub="reachable 1h / verified" />
          <Card title="Open repair jobs" val={formatNumber(r.open_repair_jobs)} sub="awaiting bidder/assign" />
          <Card title="Open code reds" val={formatNumber(r.open_code_reds)} danger={r.open_code_reds > 0} sub="status = open" />
          <Card title="Unassigned code reds" val={formatNumber(r.unassigned_code_reds)} danger={redAlert} sub="no engineer accepted yet" />
          <Card title="Bids last 1h" val={formatNumber(r.bids_last_1h)} sub="raw activity" />
          <Card title="Bids last 24h" val={formatNumber(r.bids_last_24h)} />
          <Card title="Supply ÷ open demand" val={Number(r.supply_to_open_demand).toFixed(2)} ok={supplyOk} danger={!supplyOk && (r.open_repair_jobs + r.open_code_reds) > 0} sub="reachable-24h per open req" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
