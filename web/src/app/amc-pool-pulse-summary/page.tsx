import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool pulse summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_pool_balance_inr: number;
  active_amc_count: number;
  avg_balance_per_amc_inr: number;
  zero_balance_amc_count: number;
  zero_balance_blocked_mrr_inr: number;
  credits_30d_inr: number;
  debits_30d_inr: number;
  refunds_30d_inr: number;
  net_flow_30d_inr: number;
  top_up_events_30d: number;
  debit_events_30d: number;
  hospitals_at_zero_balance: number;
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

export default async function AmcPoolPulseSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_pulse_summary");
  if (error) throw new Error(`founder_amc_pool_pulse_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool pulse summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI pool health · balance + flow + zero-balance alerts · pair with /amc-snapshot-summary</span>
      </header>
      {r ? (
        <>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="rounded-lg border-2 border-[var(--color-ok)] bg-[var(--color-surface)] p-6">
              <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Total pool balance (active AMCs)</div>
              <div className="mt-2 text-4xl font-bold tabular-nums">{inr(r.total_pool_balance_inr)}</div>
              <div className="mt-1 text-xs text-[var(--color-muted)]">{formatNumber(r.active_amc_count)} active AMCs · avg {inr(r.avg_balance_per_amc_inr)} per contract</div>
            </div>
            <div className={`rounded-lg border-2 p-6 bg-[var(--color-surface)] ${r.net_flow_30d_inr >= 0 ? "border-[var(--color-ok)]" : "border-[var(--color-danger)]"}`}>
              <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Net flow 30d (credits − debits − refunds)</div>
              <div className="mt-2 text-4xl font-bold tabular-nums">{inr(r.net_flow_30d_inr)}</div>
              <div className="mt-1 text-xs text-[var(--color-muted)]">positive = top-ups outpacing consumption</div>
            </div>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Card title="Zero-balance AMCs" val={formatNumber(r.zero_balance_amc_count)} danger={r.zero_balance_amc_count > 0} sub={inr(r.zero_balance_blocked_mrr_inr)} />
            <Card title="Hospitals at zero" val={formatNumber(r.hospitals_at_zero_balance)} sub="cant book free visits" />
            <Card title="Credits 30d" val={inr(r.credits_30d_inr)} ok sub={`${formatNumber(r.top_up_events_30d)} events`} />
            <Card title="Debits 30d" val={inr(r.debits_30d_inr)} sub={`${formatNumber(r.debit_events_30d)} events`} />
            <Card title="Refunds 30d" val={inr(r.refunds_30d_inr)} danger={r.refunds_30d_inr > 0} />
          </div>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
