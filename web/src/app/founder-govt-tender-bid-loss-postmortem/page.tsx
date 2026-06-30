import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type PortfolioSummary = {
  total_lost_bids: number;
  total_bid_value_lost_rupees: number;
  total_winning_value_rupees: number;
  avg_price_gap_percent: number;
  open_postmortems: number;
  founder_signed_count: number;
  catastrophic_count: number;
};

type DisqRow = {
  disqualification_reason: string;
  loss_count: number;
  value_lost_rupees: number;
  avg_price_gap_percent: number;
};

type CategoryRow = {
  tender_category: string;
  loss_count: number;
  value_lost_rupees: number;
  catastrophic_count: number;
};

type WinnerTierRow = {
  winning_bidder_tier: string;
  wins_against_us: number;
  total_winning_value_rupees: number;
  avg_price_gap_percent: number;
};

type ReplayDecisionRow = {
  replay_decision: string;
  postmortem_count: number;
  unlock_potential_rupees: number;
};

type ActionPortfolioRow = {
  action_category: string;
  action_count: number;
  completed_count: number;
  blocked_count: number;
  total_estimated_cost_rupees: number;
  total_unlock_value_rupees: number;
};

type TopLossRow = {
  tender_reference_no: string;
  tender_title: string;
  issuing_authority: string;
  bid_value_rupees: number;
  price_gap_percent: number;
  disqualification_reason: string;
  replay_decision: string;
  postmortem_status: string;
};

type OwnerRow = {
  responsible_owner: string;
  open_actions: number;
  blocked_actions: number;
  completed_actions: number;
  unlock_value_pending_rupees: number;
};

function inr(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function FounderGovtTenderBidLossPostmortemPage() {
  const supabase = await getSupabaseServerClient();

  const [
    summaryRes,
    disqRes,
    categoryRes,
    winnerRes,
    replayRes,
    actionPortfolioRes,
    topLossesRes,
    ownerRes,
  ] = await Promise.all([
    supabase.rpc('fn_r3099_postmortem_portfolio_summary'),
    supabase.rpc('fn_r3099_losses_by_disqualification'),
    supabase.rpc('fn_r3099_losses_by_category'),
    supabase.rpc('fn_r3099_winning_bidder_tier_breakdown'),
    supabase.rpc('fn_r3099_replay_decision_distribution'),
    supabase.rpc('fn_r3099_replay_action_portfolio'),
    supabase.rpc('fn_r3099_top_losses_by_value'),
    supabase.rpc('fn_r3099_owner_workload_rollup'),
  ]);

  const summary: PortfolioSummary[] = (summaryRes.data ?? []) as PortfolioSummary[];
  const disq: DisqRow[] = (disqRes.data ?? []) as DisqRow[];
  const category: CategoryRow[] = (categoryRes.data ?? []) as CategoryRow[];
  const winners: WinnerTierRow[] = (winnerRes.data ?? []) as WinnerTierRow[];
  const replay: ReplayDecisionRow[] = (replayRes.data ?? []) as ReplayDecisionRow[];
  const actionPortfolio: ActionPortfolioRow[] = (actionPortfolioRes.data ?? []) as ActionPortfolioRow[];
  const topLosses: TopLossRow[] = (topLossesRes.data ?? []) as TopLossRow[];
  const owners: OwnerRow[] = (ownerRes.data ?? []) as OwnerRow[];

  const summaryCols: Column<PortfolioSummary>[] = [
    { key: 'total_lost_bids', header: 'Lost Bids' },
    { key: 'total_bid_value_lost_rupees', header: 'Bid Value Lost', render: (r) => inr(r.total_bid_value_lost_rupees) },
    { key: 'total_winning_value_rupees', header: 'L1 Winner Value', render: (r) => inr(r.total_winning_value_rupees) },
    { key: 'avg_price_gap_percent', header: 'Avg Price Gap %' },
    { key: 'open_postmortems', header: 'Open' },
    { key: 'founder_signed_count', header: 'Founder Signed' },
    { key: 'catastrophic_count', header: 'Catastrophic' },
  ];

  const disqCols: Column<DisqRow>[] = [
    { key: 'disqualification_reason', header: 'Disqualification Reason' },
    { key: 'loss_count', header: 'Losses' },
    { key: 'value_lost_rupees', header: 'Value Lost', render: (r) => inr(r.value_lost_rupees) },
    { key: 'avg_price_gap_percent', header: 'Avg Price Gap %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'tender_category', header: 'Tender Category' },
    { key: 'loss_count', header: 'Losses' },
    { key: 'value_lost_rupees', header: 'Value Lost', render: (r) => inr(r.value_lost_rupees) },
    { key: 'catastrophic_count', header: 'Catastrophic' },
  ];

  const winnerCols: Column<WinnerTierRow>[] = [
    { key: 'winning_bidder_tier', header: 'Winning Bidder Tier' },
    { key: 'wins_against_us', header: 'Wins vs Us' },
    { key: 'total_winning_value_rupees', header: 'Winning Value', render: (r) => inr(r.total_winning_value_rupees) },
    { key: 'avg_price_gap_percent', header: 'Avg Price Gap %' },
  ];

  const replayCols: Column<ReplayDecisionRow>[] = [
    { key: 'replay_decision', header: 'Replay Decision' },
    { key: 'postmortem_count', header: 'Postmortems' },
    { key: 'unlock_potential_rupees', header: 'Unlock Potential', render: (r) => inr(r.unlock_potential_rupees) },
  ];

  const actionCols: Column<ActionPortfolioRow>[] = [
    { key: 'action_category', header: 'Action Category' },
    { key: 'action_count', header: 'Total' },
    { key: 'completed_count', header: 'Done' },
    { key: 'blocked_count', header: 'Blocked' },
    { key: 'total_estimated_cost_rupees', header: 'Est Cost', render: (r) => inr(r.total_estimated_cost_rupees) },
    { key: 'total_unlock_value_rupees', header: 'Unlock Value', render: (r) => inr(r.total_unlock_value_rupees) },
  ];

  const topLossesCols: Column<TopLossRow>[] = [
    { key: 'tender_reference_no', header: 'Tender Ref' },
    { key: 'tender_title', header: 'Title' },
    { key: 'issuing_authority', header: 'Authority' },
    { key: 'bid_value_rupees', header: 'Bid Value', render: (r) => inr(r.bid_value_rupees) },
    { key: 'price_gap_percent', header: 'Price Gap %' },
    { key: 'disqualification_reason', header: 'Disq Reason' },
    { key: 'replay_decision', header: 'Replay' },
    { key: 'postmortem_status', header: 'Status' },
  ];

  const ownerCols: Column<OwnerRow>[] = [
    { key: 'responsible_owner', header: 'Owner' },
    { key: 'open_actions', header: 'Open' },
    { key: 'blocked_actions', header: 'Blocked' },
    { key: 'completed_actions', header: 'Done' },
    { key: 'unlock_value_pending_rupees', header: 'Unlock Pending', render: (r) => inr(r.unlock_value_pending_rupees) },
  ];

  return (
    <div className="mx-auto max-w-7xl px-6 py-8 space-y-10">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Govt Tender Bid Loss Post-Mortem Tracker</h1>
        <p className="text-sm text-neutral-600">
          Lost government tender bids analysis — tender × eligibility gap × price gap × winning bidder × disqualification reason × lessons-learned × replay playbook.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">Portfolio Summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No post-mortems recorded yet."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Losses by Disqualification Reason</h2>
        <DataTable
          rows={disq}
          columns={disqCols}
          emptyMessage="No disqualification rollup."
          rowKey={(r, i) => String(r.disqualification_reason ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Losses by Tender Category</h2>
        <DataTable
          rows={category}
          columns={categoryCols}
          emptyMessage="No category rollup."
          rowKey={(r, i) => String(r.tender_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Winning Bidder Tier Breakdown</h2>
        <DataTable
          rows={winners}
          columns={winnerCols}
          emptyMessage="No winner tier rollup."
          rowKey={(r, i) => String(r.winning_bidder_tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Replay Decision Distribution</h2>
        <DataTable
          rows={replay}
          columns={replayCols}
          emptyMessage="No replay decisions logged."
          rowKey={(r, i) => String(r.replay_decision ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Replay Action Portfolio</h2>
        <DataTable
          rows={actionPortfolio}
          columns={actionCols}
          emptyMessage="No replay actions defined."
          rowKey={(r, i) => String(r.action_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Top Losses by Value</h2>
        <DataTable
          rows={topLosses}
          columns={topLossesCols}
          emptyMessage="No high-value losses recorded."
          rowKey={(r, i) => String(r.tender_reference_no ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Owner Workload Rollup</h2>
        <DataTable
          rows={owners}
          columns={ownerCols}
          emptyMessage="No owner workload tracked."
          rowKey={(r, i) => String(r.responsible_owner ?? i)}
        />
      </section>
    </div>
  );
}
