import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_contracts: number;
  active_count: number;
  paused_count: number;
  expired_count: number;
  active_mrr_inr: number;
  paused_mrr_inr: number;
  avg_active_mrr_inr: number;
  expiring_30d: number;
  expiring_30d_mrr_inr: number;
  total_pool_balance_inr: number;
  zero_balance_active: number;
  new_amcs_30d: number;
  expired_30d: number;
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

export default async function AmcSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_snapshot_summary");
  if (error) throw new Error(`founder_amc_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">13-KPI single-row dashboard · pair with /amc-index meta-landing for drilldowns</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total contracts" val={formatNumber(r.total_contracts)} />
          <Card title="Active" val={formatNumber(r.active_count)} ok />
          <Card title="Paused" val={formatNumber(r.paused_count)} sub="frozen MRR" />
          <Card title="Expired" val={formatNumber(r.expired_count)} />
          <Card title="Active MRR" val={formatRupees(Number(r.active_mrr_inr))} ok />
          <Card title="Paused MRR" val={formatRupees(Number(r.paused_mrr_inr))} sub="frozen" />
          <Card title="Avg active MRR" val={formatRupees(Number(r.avg_active_mrr_inr))} />
          <Card title="Pool balance grand total" val={formatRupees(Number(r.total_pool_balance_inr))} />
          <Card title="Expiring 30d" val={formatNumber(r.expiring_30d)} sub={formatRupees(Number(r.expiring_30d_mrr_inr))} danger />
          <Card title="Zero pool active AMCs" val={formatNumber(r.zero_balance_active)} sub="hospitals can't book" danger />
          <Card title="New AMCs 30d" val={formatNumber(r.new_amcs_30d)} ok />
          <Card title="Expired 30d" val={formatNumber(r.expired_30d)} danger />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
