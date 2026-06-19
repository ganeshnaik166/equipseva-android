import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Referrals snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_referrals_all_time: number;
  referrals_registered_today: number;
  referrals_registered_30d: number;
  bounty_eligible_now: number;
  bounty_pending_now: number;
  bounty_revoked_all_time: number;
  payouts_queued_now: number;
  payouts_paid_all_time: number;
  queued_bounty_value_rupees: number;
  paid_bounty_value_rupees: number;
  paid_bounty_value_30d_rupees: number;
  active_referrers_30d: number;
  stuck_referrals_over_60d: number;
  conversion_pct_90d: number;
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

export default async function ReferralsSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referrals_snapshot_summary");
  if (error) throw new Error(`founder_referrals_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referrals snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI growth dashboard · funnel + bounty spend + ROI + stuck · pair with /referrals-index</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total referrals all-time" val={formatNumber(r.total_referrals_all_time)} />
          <Card title="Registered today" val={formatNumber(r.referrals_registered_today)} />
          <Card title="Registered 30d" val={formatNumber(r.referrals_registered_30d)} sub="growth pulse" />
          <Card title="Active referrers 30d" val={formatNumber(r.active_referrers_30d)} sub="distinct senders" />
          <Card title="Bounty eligible now" val={formatNumber(r.bounty_eligible_now)} ok />
          <Card title="Bounty pending now" val={formatNumber(r.bounty_pending_now)} sub="awaiting first paid job" />
          <Card title="Bounty revoked all-time" val={formatNumber(r.bounty_revoked_all_time)} sub="abuse signal" />
          <Card title="Stuck >60d (no payout)" val={formatNumber(r.stuck_referrals_over_60d)} danger={r.stuck_referrals_over_60d > 0} />
          <Card title="Payouts queued now" val={formatNumber(r.payouts_queued_now)} />
          <Card title="Payouts paid all-time" val={formatNumber(r.payouts_paid_all_time)} ok />
          <Card title="Queued bounty value" val={`₹${formatNumber(r.queued_bounty_value_rupees)}`} sub="money owed" />
          <Card title="Paid bounty value all-time" val={`₹${formatNumber(r.paid_bounty_value_rupees)}`} ok />
          <Card title="Paid bounty value 30d" val={`₹${formatNumber(r.paid_bounty_value_30d_rupees)}`} sub="growth CAC pulse" />
          <Card title="Conversion 90d (paid/signed)" val={`${Number(r.conversion_pct_90d).toFixed(1)}%`} sub="signup→paid" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}