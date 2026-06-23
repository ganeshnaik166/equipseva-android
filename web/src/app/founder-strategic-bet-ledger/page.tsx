import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PortfolioRow = {
  total_bets: number;
  bets_in_flight: number;
  bets_won: number;
  bets_lost: number;
  bets_partial: number;
  bets_killed: number;
  total_capital_committed_rupees: number;
  total_expected_revenue_rupees: number;
  total_actual_revenue_rupees: number;
  win_rate_pct: number;
  capital_efficiency_x: number;
};

function fmtRupees(v: number | null | undefined): string {
  if (!v) return '₹0';
  return '₹' + Number(v).toLocaleString('en-IN');
}

export default async function FounderStrategicBetLedgerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    portfolioRes,
    byCategoryRes,
    listRes,
    topWinsRes,
    topLossesRes,
    milestonesRes,
    attributionRes,
  ] = await Promise.all([
    supabase.rpc('founder_strategic_bets_r2349_portfolio'),
    supabase.rpc('founder_strategic_bets_r2349_by_category'),
    supabase.rpc('founder_strategic_bets_r2349_list', { p_limit: 100 }),
    supabase.rpc('founder_strategic_bets_r2349_top_wins'),
    supabase.rpc('founder_strategic_bets_r2349_top_losses'),
    supabase.rpc('founder_strategic_bets_r2349_milestones_at_risk'),
    supabase.rpc('founder_strategic_bets_r2349_growth_attribution'),
  ]);

  const portfolio: PortfolioRow | null = (portfolioRes.data?.[0] as PortfolioRow) ?? null;
  const byCategory = byCategoryRes.data ?? [];
  const bets = listRes.data ?? [];
  const topWins = topWinsRes.data ?? [];
  const topLosses = topLossesRes.data ?? [];
  const milestones = milestonesRes.data ?? [];
  const attribution = attributionRes.data ?? [];

  const betColumns: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r: any) => <span className="font-medium">{r.bet_name}</span> },
    { key: 'bet_category', header: 'Category', render: (r: any) => <span className="capitalize">{String(r.bet_category).replace(/_/g, ' ')}</span> },
    { key: 'status', header: 'Status', render: (r: any) => (
      <span className={
        r.status === 'won' ? 'text-green-700 font-semibold' :
        r.status === 'lost' || r.status === 'killed' ? 'text-red-700' :
        r.status === 'partial' ? 'text-amber-700' :
        'text-blue-700'
      }>{r.status}</span>
    ) },
    { key: 'risk_level', header: 'Risk', render: (r: any) => (
      <span className={r.risk_level === 'bet_the_farm' ? 'text-red-800 font-bold' : r.risk_level === 'high' ? 'text-orange-700' : 'text-slate-700'}>{r.risk_level}</span>
    ) },
    { key: 'capital_committed_rupees', header: 'Capital', render: (r: any) => fmtRupees(r.capital_committed_rupees) },
    { key: 'expected_revenue_lift_rupees', header: 'Expected', render: (r: any) => fmtRupees(r.expected_revenue_lift_rupees) },
    { key: 'actual_revenue_lift_rupees', header: 'Actual', render: (r: any) => (
      <span className={r.actual_revenue_lift_rupees >= r.expected_revenue_lift_rupees ? 'text-green-700' : 'text-slate-700'}>{fmtRupees(r.actual_revenue_lift_rupees)}</span>
    ) },
    { key: 'confidence_pct', header: 'Conf%', render: (r: any) => r.confidence_pct + '%' },
    { key: 'growth_attribution_pct', header: 'Growth%', render: (r: any) => (r.growth_attribution_pct ?? 0) + '%' },
    { key: 'placed_at', header: 'Placed', render: (r: any) => r.placed_at ? new Date(r.placed_at).toLocaleDateString('en-IN') : '—' },
    { key: 'placed_by_email', header: 'By', render: (r: any) => r.placed_by_email ?? '—' },
  ];

  const categoryColumns: Column<any>[] = [
    { key: 'bet_category', header: 'Category', render: (r: any) => <span className="capitalize font-medium">{String(r.bet_category).replace(/_/g, ' ')}</span> },
    { key: 'total_bets', header: 'Bets', render: (r: any) => r.total_bets },
    { key: 'bets_won', header: 'Won', render: (r: any) => <span className="text-green-700">{r.bets_won}</span> },
    { key: 'bets_lost', header: 'Lost', render: (r: any) => <span className="text-red-700">{r.bets_lost}</span> },
    { key: 'win_rate_pct', header: 'Win %', render: (r: any) => r.win_rate_pct + '%' },
    { key: 'capital_committed_rupees', header: 'Capital', render: (r: any) => fmtRupees(r.capital_committed_rupees) },
    { key: 'actual_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.actual_revenue_rupees) },
  ];

  const winColumns: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r: any) => <span className="font-medium">{r.bet_name}</span> },
    { key: 'bet_category', header: 'Cat', render: (r: any) => <span className="capitalize">{String(r.bet_category).replace(/_/g, ' ')}</span> },
    { key: 'capital_committed_rupees', header: 'Capital', render: (r: any) => fmtRupees(r.capital_committed_rupees) },
    { key: 'actual_revenue_lift_rupees', header: 'Revenue', render: (r: any) => <span className="text-green-700 font-semibold">{fmtRupees(r.actual_revenue_lift_rupees)}</span> },
    { key: 'return_multiple', header: 'Return', render: (r: any) => <span className="font-bold">{r.return_multiple}x</span> },
    { key: 'growth_attribution_pct', header: 'Growth%', render: (r: any) => (r.growth_attribution_pct ?? 0) + '%' },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString('en-IN') : '—' },
  ];

  const lossColumns: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r: any) => <span className="font-medium">{r.bet_name}</span> },
    { key: 'bet_category', header: 'Cat', render: (r: any) => <span className="capitalize">{String(r.bet_category).replace(/_/g, ' ')}</span> },
    { key: 'capital_committed_rupees', header: 'Capital', render: (r: any) => fmtRupees(r.capital_committed_rupees) },
    { key: 'net_loss_rupees', header: 'Net Loss', render: (r: any) => <span className="text-red-700 font-semibold">{fmtRupees(r.net_loss_rupees)}</span> },
    { key: 'lessons_learned', header: 'Lessons', render: (r: any) => <span className="text-xs text-slate-600">{r.lessons_learned ?? '—'}</span> },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString('en-IN') : '—' },
  ];

  const milestoneColumns: Column<any>[] = [
    { key: 'bet_name', header: 'Bet', render: (r: any) => <span className="font-medium">{r.bet_name}</span> },
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => r.milestone_label },
    { key: 'target_date', header: 'Target', render: (r: any) => new Date(r.target_date).toLocaleDateString('en-IN') },
    { key: 'days_overdue', header: 'Overdue', render: (r: any) => (
      <span className={r.days_overdue > 0 ? 'text-red-700 font-bold' : 'text-slate-600'}>
        {r.days_overdue > 0 ? r.days_overdue + 'd' : 'on track'}
      </span>
    ) },
    { key: 'metric_target_value', header: 'Target', render: (r: any) => r.metric_target_value != null ? `${r.metric_target_value} ${r.metric_unit ?? ''}` : '—' },
    { key: 'metric_actual_value', header: 'Actual', render: (r: any) => r.metric_actual_value != null ? `${r.metric_actual_value} ${r.metric_unit ?? ''}` : '—' },
  ];

  const attributionColumns: Column<any>[] = [
    { key: 'bet_category', header: 'Category', render: (r: any) => <span className="capitalize font-medium">{String(r.bet_category).replace(/_/g, ' ')}</span> },
    { key: 'bet_count', header: 'Bets', render: (r: any) => r.bet_count },
    { key: 'total_attribution_pct', header: 'Attribution', render: (r: any) => r.total_attribution_pct + '%' },
    { key: 'total_revenue_attributed_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.total_revenue_attributed_rupees) },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-3xl font-bold tracking-tight">Strategic Bet Ledger</h1>
        <p className="text-sm text-slate-600 mt-1">
          Every strategic bet placed — geo expansion, vertical, hire — with hypothesis, outcome & growth attribution.
        </p>
      </header>

      {portfolio && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="rounded-lg border bg-white p-4">
            <div className="text-xs uppercase text-slate-500">Total Bets</div>
            <div className="text-2xl font-bold">{portfolio.total_bets}</div>
            <div className="text-xs text-slate-500 mt-1">{portfolio.bets_in_flight} in flight</div>
          </div>
          <div className="rounded-lg border bg-white p-4">
            <div className="text-xs uppercase text-slate-500">Win Rate</div>
            <div className="text-2xl font-bold text-green-700">{portfolio.win_rate_pct}%</div>
            <div className="text-xs text-slate-500 mt-1">{portfolio.bets_won}W / {portfolio.bets_lost}L / {portfolio.bets_partial}P</div>
          </div>
          <div className="rounded-lg border bg-white p-4">
            <div className="text-xs uppercase text-slate-500">Capital Committed</div>
            <div className="text-2xl font-bold">{fmtRupees(portfolio.total_capital_committed_rupees)}</div>
            <div className="text-xs text-slate-500 mt-1">across all bets</div>
          </div>
          <div className="rounded-lg border bg-white p-4">
            <div className="text-xs uppercase text-slate-500">Capital Efficiency</div>
            <div className="text-2xl font-bold">{portfolio.capital_efficiency_x}x</div>
            <div className="text-xs text-slate-500 mt-1">
              {fmtRupees(portfolio.total_actual_revenue_rupees)} actual vs {fmtRupees(portfolio.total_expected_revenue_rupees)} expected
            </div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-xl font-semibold mb-3">By Category</h2>
        <DataTable
          rows={byCategory}
          columns={categoryColumns}
          emptyMessage="No bets placed yet."
          rowKey={(r: any) => r.bet_category}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Growth Attribution</h2>
        <DataTable
          rows={attribution}
          columns={attributionColumns}
          emptyMessage="No revenue attributed yet."
          rowKey={(r: any) => r.bet_category}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Milestones At Risk (next 14d & overdue)</h2>
        <DataTable
          rows={milestones}
          columns={milestoneColumns}
          emptyMessage="No milestones at risk."
          rowKey={(r: any) => r.milestone_id}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Top Wins</h2>
        <DataTable
          rows={topWins}
          columns={winColumns}
          emptyMessage="No wins booked yet."
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Top Losses</h2>
        <DataTable
          rows={topLosses}
          columns={lossColumns}
          emptyMessage="No losses recorded."
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">All Bets</h2>
        <DataTable
          rows={bets}
          columns={betColumns}
          emptyMessage="No bets placed."
          rowKey={(r: any) => r.id}
        />
      </section>
    </div>
  );
}
