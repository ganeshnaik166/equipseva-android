import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type LoyaltyRow = {
  id: string;
  engineer_user_id: string;
  loyalty_tier: string;
  tenure_months: number;
  quality_score: number;
  status: string;
  reward_balance_rupees: number;
  last_assessed_at: string | null;
  created_at: string;
};

type RewardRow = {
  id: string;
  loyalty_id: string;
  reward_type: string;
  taken_at: string;
  by_email: string | null;
  amount_rupees: number;
  notes_md: string | null;
};

type TopLoyalRow = {
  id: string;
  engineer_user_id: string;
  loyalty_tier: string;
  tenure_months: number;
  quality_score: number;
  reward_balance_rupees: number;
  status: string;
};

function fmtDate(s: string | null) {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s;
  }
}

function fmtRupees(n: number | null | undefined) {
  if (n == null) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [loyaltiesRes, topRes, rewardsRes] = await Promise.all([
    sb.rpc('list_loyalties_r1996', { p_limit: 100 }),
    sb.rpc('top_loyal_r1996', { p_limit: 20 }),
    sb.rpc('recent_rewards_r1996', { p_limit: 50 }),
  ]);

  const loyalties: LoyaltyRow[] = (loyaltiesRes.data as LoyaltyRow[] | null) ?? [];
  const top: TopLoyalRow[] = (topRes.data as TopLoyalRow[] | null) ?? [];
  const rewards: RewardRow[] = (rewardsRes.data as RewardRow[] | null) ?? [];

  const loyaltyCols: Column<LoyaltyRow>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id).slice(0, 8)}</span> },
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => <span className="uppercase">{r.loyalty_tier}</span> },
    { key: 'tenure_months', header: 'Tenure (mo)', render: (r: any) => String(r.tenure_months ?? 0) },
    { key: 'quality_score', header: 'Quality', render: (r: any) => String(r.quality_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'reward_balance_rupees', header: 'Balance', render: (r: any) => fmtRupees(r.reward_balance_rupees) },
    { key: 'last_assessed_at', header: 'Last Assessed', render: (r: any) => fmtDate(r.last_assessed_at) },
  ];

  const topCols: Column<TopLoyalRow>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id).slice(0, 8)}</span> },
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => <span className="uppercase">{r.loyalty_tier}</span> },
    { key: 'tenure_months', header: 'Tenure (mo)', render: (r: any) => String(r.tenure_months ?? 0) },
    { key: 'quality_score', header: 'Quality', render: (r: any) => String(r.quality_score ?? 0) },
    { key: 'reward_balance_rupees', header: 'Balance', render: (r: any) => fmtRupees(r.reward_balance_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const rewardCols: Column<RewardRow>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'reward_type', header: 'Type', render: (r: any) => r.reward_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.amount_rupees) },
    { key: 'loyalty_id', header: 'Loyalty', render: (r: any) => <span className="font-mono text-xs">{String(r.loyalty_id).slice(0, 8)}</span> },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '—' },
  ];

  const totalActive = loyalties.filter((l) => l.status === 'active').length;
  const totalBalance = loyalties.reduce((acc, l) => acc + Number(l.reward_balance_rupees ?? 0), 0);

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer Loyalty Program Tracker</h1>
        <p className="text-sm text-gray-600">
          Anniversary and quality-based loyalty rewards for engineers. Tiers go from rookie up to platinum.
        </p>
        <div className="flex gap-4 text-sm text-gray-700">
          <div>Total tracked: {loyalties.length}</div>
          <div>Active: {totalActive}</div>
          <div>Outstanding balance: {fmtRupees(totalBalance)}</div>
        </div>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top Loyal Engineers</h2>
        <p className="text-sm text-gray-600">Ranked by quality score and tenure across active loyalty records.</p>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All Loyalty Records</h2>
        <p className="text-sm text-gray-600">Most recently created loyalty rows, up to 100.</p>
        <DataTable rows={loyalties} columns={loyaltyCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent Rewards</h2>
        <p className="text-sm text-gray-600">Last 50 reward log entries across all engineers.</p>
        <DataTable rows={rewards} columns={rewardCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
