import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_tenders: number;
  total_won: number;
  total_lost: number;
  win_rate_pct: number | null;
  total_bid_value_lakhs: number;
  won_value_lakhs: number;
};

type ChainRow = {
  chain_name: string;
  bids: number;
  wins: number;
  losses: number;
  win_rate_pct: number | null;
  total_value_lakhs: number;
};

type LossRow = {
  loss_reason: string;
  lost_count: number;
  lost_value_lakhs: number;
};

type TrendRow = {
  fiscal_year: string;
  quarter: string;
  bids: number;
  wins: number;
  win_rate_pct: number | null;
  total_value_lakhs: number;
};

type TenderRow = {
  id: string;
  chain_name: string;
  tender_ref: string;
  tender_authority: string;
  outcome: string;
  bid_value_lakhs: number;
  bid_submitted_on: string;
  loss_reason: string | null;
  strategy_adjustment: string | null;
};

type StrategyRow = {
  id: string;
  chain_name: string;
  quarter: string;
  fiscal_year: string;
  target_wins: number;
  target_value_lakhs: number;
  pricing_strategy: string;
  next_quarter_focus: string | null;
  owner_email: string | null;
  status: string;
};

type AuthorityRow = {
  tender_authority: string;
  bids: number;
  wins: number;
  win_rate_pct: number | null;
  total_value_lakhs: number;
};

type AdjustmentRow = {
  chain_name: string;
  tender_ref: string;
  outcome: string;
  loss_reason: string | null;
  strategy_adjustment: string | null;
  bid_value_lakhs: number;
};

function fmtPct(v: number | null | undefined) {
  if (v === null || v === undefined) return '—';
  return `${Number(v).toFixed(1)}%`;
}

function fmtLakhs(v: number | null | undefined) {
  if (v === null || v === undefined) return '—';
  return `₹${Number(v).toLocaleString('en-IN', { maximumFractionDigits: 2 })} L`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, chainRes, lossRes, trendRes, topRes, stratRes, authRes, adjRes] = await Promise.all([
    supabase.rpc('founder_r2735_tender_kpis'),
    supabase.rpc('founder_r2735_win_rate_by_chain'),
    supabase.rpc('founder_r2735_loss_reason_breakdown'),
    supabase.rpc('founder_r2735_quarterly_trend'),
    supabase.rpc('founder_r2735_top_tenders'),
    supabase.rpc('founder_r2735_chain_strategy'),
    supabase.rpc('founder_r2735_authority_performance'),
    supabase.rpc('founder_r2735_strategy_adjustments'),
  ]);

  const kpis: Kpi = (kpisRes.data?.[0] as Kpi) ?? {
    total_tenders: 0,
    total_won: 0,
    total_lost: 0,
    win_rate_pct: null,
    total_bid_value_lakhs: 0,
    won_value_lakhs: 0,
  };
  const chains: ChainRow[] = (chainRes.data as ChainRow[]) ?? [];
  const losses: LossRow[] = (lossRes.data as LossRow[]) ?? [];
  const trends: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const tenders: TenderRow[] = (topRes.data as TenderRow[]) ?? [];
  const strategies: StrategyRow[] = (stratRes.data as StrategyRow[]) ?? [];
  const authorities: AuthorityRow[] = (authRes.data as AuthorityRow[]) ?? [];
  const adjustments: AdjustmentRow[] = (adjRes.data as AdjustmentRow[]) ?? [];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="border-b pb-4">
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Government Tender Win Rate</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track chain × govt tender bids, wins, loss reasons & strategy adjustments per quarter
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Tender KPIs</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Total bids</div>
            <div className="text-xl font-bold">{kpis.total_tenders}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Won</div>
            <div className="text-xl font-bold text-green-700">{kpis.total_won}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Lost</div>
            <div className="text-xl font-bold text-red-700">{kpis.total_lost}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Win rate</div>
            <div className="text-xl font-bold">{fmtPct(kpis.win_rate_pct)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Total bid value</div>
            <div className="text-xl font-bold">{fmtLakhs(kpis.total_bid_value_lakhs)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Won value</div>
            <div className="text-xl font-bold text-green-700">{fmtLakhs(kpis.won_value_lakhs)}</div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Win rate by chain</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => <span className="font-medium">{r.chain_name}</span> },
            { key: 'bids', header: 'Bids', render: (r: ChainRow) => <span>{r.bids}</span> },
            { key: 'wins', header: 'Wins', render: (r: ChainRow) => <span className="text-green-700">{r.wins}</span> },
            { key: 'losses', header: 'Losses', render: (r: ChainRow) => <span className="text-red-700">{r.losses}</span> },
            { key: 'win_rate_pct', header: 'Win %', render: (r: ChainRow) => <span>{fmtPct(r.win_rate_pct)}</span> },
            { key: 'total_value_lakhs', header: 'Value', render: (r: ChainRow) => <span>{fmtLakhs(r.total_value_lakhs)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Loss reason breakdown</h2>
        <DataTable
          rows={losses}
          columns={[
            { key: 'loss_reason', header: 'Reason', render: (r: LossRow) => <span className="font-mono text-sm">{r.loss_reason}</span> },
            { key: 'lost_count', header: 'Count', render: (r: LossRow) => <span>{r.lost_count}</span> },
            { key: 'lost_value_lakhs', header: 'Value lost', render: (r: LossRow) => <span>{fmtLakhs(r.lost_value_lakhs)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: LossRow, i: number) => String(r.loss_reason ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Quarterly trend</h2>
        <DataTable
          rows={trends}
          columns={[
            { key: 'fiscal_year', header: 'FY', render: (r: TrendRow) => <span>{r.fiscal_year}</span> },
            { key: 'quarter', header: 'Quarter', render: (r: TrendRow) => <span>{r.quarter}</span> },
            { key: 'bids', header: 'Bids', render: (r: TrendRow) => <span>{r.bids}</span> },
            { key: 'wins', header: 'Wins', render: (r: TrendRow) => <span>{r.wins}</span> },
            { key: 'win_rate_pct', header: 'Win %', render: (r: TrendRow) => <span>{fmtPct(r.win_rate_pct)}</span> },
            { key: 'total_value_lakhs', header: 'Value', render: (r: TrendRow) => <span>{fmtLakhs(r.total_value_lakhs)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: TrendRow, i: number) => `${r.fiscal_year}-${r.quarter}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top tenders by bid value</h2>
        <DataTable
          rows={tenders}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: TenderRow) => <span className="font-medium">{r.chain_name}</span> },
            { key: 'tender_ref', header: 'Tender ref', render: (r: TenderRow) => <span className="font-mono text-xs">{r.tender_ref}</span> },
            { key: 'tender_authority', header: 'Authority', render: (r: TenderRow) => <span>{r.tender_authority}</span> },
            { key: 'outcome', header: 'Outcome', render: (r: TenderRow) => <span className={r.outcome === 'won' ? 'text-green-700 font-medium' : r.outcome === 'lost' ? 'text-red-700' : 'text-gray-600'}>{r.outcome}</span> },
            { key: 'bid_value_lakhs', header: 'Bid', render: (r: TenderRow) => <span>{fmtLakhs(r.bid_value_lakhs)}</span> },
            { key: 'bid_submitted_on', header: 'Submitted', render: (r: TenderRow) => <span className="text-xs">{r.bid_submitted_on}</span> },
            { key: 'loss_reason', header: 'Loss reason', render: (r: TenderRow) => <span className="text-xs">{r.loss_reason ?? '—'}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: TenderRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Chain strategy for next quarter</h2>
        <DataTable
          rows={strategies}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: StrategyRow) => <span className="font-medium">{r.chain_name}</span> },
            { key: 'quarter', header: 'Q', render: (r: StrategyRow) => <span>{r.quarter} {r.fiscal_year}</span> },
            { key: 'target_wins', header: 'Target wins', render: (r: StrategyRow) => <span>{r.target_wins}</span> },
            { key: 'target_value_lakhs', header: 'Target value', render: (r: StrategyRow) => <span>{fmtLakhs(r.target_value_lakhs)}</span> },
            { key: 'pricing_strategy', header: 'Pricing', render: (r: StrategyRow) => <span className="font-mono text-xs">{r.pricing_strategy}</span> },
            { key: 'next_quarter_focus', header: 'Focus', render: (r: StrategyRow) => <span className="text-sm">{r.next_quarter_focus ?? '—'}</span> },
            { key: 'owner_email', header: 'Owner', render: (r: StrategyRow) => <span className="text-xs">{r.owner_email ?? '—'}</span> },
            { key: 'status', header: 'Status', render: (r: StrategyRow) => <span>{r.status}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: StrategyRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Authority performance</h2>
        <DataTable
          rows={authorities}
          columns={[
            { key: 'tender_authority', header: 'Authority', render: (r: AuthorityRow) => <span>{r.tender_authority}</span> },
            { key: 'bids', header: 'Bids', render: (r: AuthorityRow) => <span>{r.bids}</span> },
            { key: 'wins', header: 'Wins', render: (r: AuthorityRow) => <span>{r.wins}</span> },
            { key: 'win_rate_pct', header: 'Win %', render: (r: AuthorityRow) => <span>{fmtPct(r.win_rate_pct)}</span> },
            { key: 'total_value_lakhs', header: 'Value', render: (r: AuthorityRow) => <span>{fmtLakhs(r.total_value_lakhs)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: AuthorityRow, i: number) => String(r.tender_authority ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Strategy adjustments captured</h2>
        <DataTable
          rows={adjustments}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: AdjustmentRow) => <span className="font-medium">{r.chain_name}</span> },
            { key: 'tender_ref', header: 'Tender', render: (r: AdjustmentRow) => <span className="font-mono text-xs">{r.tender_ref}</span> },
            { key: 'outcome', header: 'Outcome', render: (r: AdjustmentRow) => <span>{r.outcome}</span> },
            { key: 'loss_reason', header: 'Reason', render: (r: AdjustmentRow) => <span className="text-xs">{r.loss_reason ?? '—'}</span> },
            { key: 'strategy_adjustment', header: 'Adjustment', render: (r: AdjustmentRow) => <span className="text-sm">{r.strategy_adjustment ?? '—'}</span> },
            { key: 'bid_value_lakhs', header: 'Value', render: (r: AdjustmentRow) => <span>{fmtLakhs(r.bid_value_lakhs)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: AdjustmentRow, i: number) => `${r.tender_ref}-${i}`}
        />
      </section>
    </div>
  );
}
