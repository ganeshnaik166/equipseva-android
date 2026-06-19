import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Money in flight summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  escrow_held_inr: number;
  escrow_held_cnt: number;
  escrow_in_dispute_inr: number;
  payouts_queued_inr: number;
  payouts_queued_cnt: number;
  payouts_processing_inr: number;
  spare_parts_paid_unshipped_inr: number;
  spare_parts_paid_unshipped_cnt: number;
  amc_pool_total_balance_inr: number;
  referral_bounty_queued_inr: number;
  disputes_open_at_stake_inr: number;
  total_in_flight_inr: number;
  released_today_inr: number;
  refunded_today_inr: number;
  paid_payouts_today_inr: number;
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

export default async function MoneyInFlightSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_money_in_flight_summary");
  if (error) throw new Error(`founder_money_in_flight_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Money in flight summary</h1>
        <span className="text-xs text-[var(--color-muted)]">Cross-domain cash position · escrow + payouts + spare parts + AMC pool + bounty + disputes</span>
      </header>
      {r ? (
        <>
          <div className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-6">
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Total money in flight (held + queued + pool)</div>
            <div className="mt-2 text-4xl font-bold tabular-nums">{inr(r.total_in_flight_inr)}</div>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Card title="Escrow held" val={inr(r.escrow_held_inr)} sub={`${formatNumber(r.escrow_held_cnt)} contracts`} />
            <Card title="Escrow in dispute" val={inr(r.escrow_in_dispute_inr)} danger={r.escrow_in_dispute_inr > 0} />
            <Card title="Payouts queued" val={inr(r.payouts_queued_inr)} sub={`${formatNumber(r.payouts_queued_cnt)} engineers`} />
            <Card title="Payouts processing" val={inr(r.payouts_processing_inr)} sub="in motion" />
            <Card title="Spare parts paid (unshipped)" val={inr(r.spare_parts_paid_unshipped_inr)} sub={`${formatNumber(r.spare_parts_paid_unshipped_cnt)} orders`} danger={r.spare_parts_paid_unshipped_inr > 0} />
            <Card title="AMC pool balance (total)" val={inr(r.amc_pool_total_balance_inr)} ok sub="across active AMCs" />
            <Card title="Referral bounty queued" val={inr(r.referral_bounty_queued_inr)} sub="growth-loop spend" />
            <Card title="Disputes open at stake" val={inr(r.disputes_open_at_stake_inr)} danger={r.disputes_open_at_stake_inr > 0} />
          </div>
          <div className="mt-6">
            <h2 className="text-sm font-semibold mb-3">Today&apos;s outflows (IST)</h2>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
              <Card title="Escrow released today" val={inr(r.released_today_inr)} ok />
              <Card title="Escrow refunded today" val={inr(r.refunded_today_inr)} danger={r.refunded_today_inr > 0} />
              <Card title="Payouts paid today" val={inr(r.paid_payouts_today_inr)} ok />
            </div>
          </div>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
