import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type OpenBid = {
  id: string;
  chain_name: string;
  chain_tier: string;
  tender_code: string;
  tender_title: string;
  quarter: string;
  fiscal_year: string;
  tender_value_rupees: number;
  our_bid_rupees: number;
  win_probability_pct: number;
  outcome: string;
  submitted_at: string | null;
  decision_at: string | null;
  region: string;
};

type KPIs = {
  total_bids: number;
  open_bids: number;
  total_pipeline_value_rupees: number;
  weighted_pipeline_rupees: number;
  won_value_rupees: number;
  lost_value_rupees: number;
  win_rate_pct: number;
};

type ChainRow = {
  chain_name: string;
  chain_tier: string;
  bids_count: number;
  open_count: number;
  won_count: number;
  lost_count: number;
  pipeline_rupees: number;
  won_rupees: number;
};

type CompetitorRow = {
  lead_competitor: string;
  encounters: number;
  wins_against: number;
  losses_against: number;
  total_competing_value_rupees: number;
  avg_competitor_bid_rupees: number;
};

type QuarterRow = {
  fiscal_year: string;
  quarter: string;
  bids: number;
  pipeline_rupees: number;
  weighted_rupees: number;
  won_rupees: number;
};

type LearningRow = {
  id: string;
  chain_name: string;
  learning_category: string;
  learning_title: string;
  severity: string;
  action_owner: string;
  action_status: string;
  captured_at: string;
  impact_estimate_rupees: number | null;
};

type DecidedRow = {
  id: string;
  chain_name: string;
  tender_code: string;
  tender_title: string;
  outcome: string;
  our_bid_rupees: number;
  competitor_bid_rupees: number | null;
  lead_competitor: string | null;
  margin_pct: number | null;
  decision_at: string | null;
};

type CategoryRow = {
  learning_category: string;
  total_count: number;
  open_count: number;
  critical_count: number;
  total_impact_rupees: number;
};

function formatRupees(n: number | null | undefined): string {
  if (n == null) return '—';
  if (n >= 10000000) return `₹${(n / 10000000).toFixed(2)} Cr`;
  if (n >= 100000) return `₹${(n / 100000).toFixed(2)} L`;
  return `₹${n.toLocaleString('en-IN')}`;
}

function formatDate(s: string | null | undefined): string {
  if (!s) return '—';
  return new Date(s).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [openBidsRes, kpisRes, chainRes, competitorRes, quarterRes, learningRes, decidedRes, categoryRes] = await Promise.all([
    supabase.rpc('list_open_tender_bids_r2703'),
    supabase.rpc('tender_pipeline_kpis_r2703'),
    supabase.rpc('tender_bids_by_chain_r2703'),
    supabase.rpc('tender_competitor_threat_r2703'),
    supabase.rpc('tender_quarterly_breakdown_r2703'),
    supabase.rpc('list_open_tender_learnings_r2703'),
    supabase.rpc('tender_decided_outcomes_r2703'),
    supabase.rpc('tender_learnings_by_category_r2703'),
  ]);

  const openBids = (openBidsRes.data ?? []) as OpenBid[];
  const kpis = ((kpisRes.data ?? [])[0] ?? null) as KPIs | null;
  const chainRows = (chainRes.data ?? []) as ChainRow[];
  const competitorRows = (competitorRes.data ?? []) as CompetitorRow[];
  const quarterRows = (quarterRes.data ?? []) as QuarterRow[];
  const learningRows = (learningRes.data ?? []) as LearningRow[];
  const decidedRows = (decidedRes.data ?? []) as DecidedRow[];
  const categoryRows = (categoryRes.data ?? []) as CategoryRow[];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Hospital Chain Quarterly Tender Bid Tracker</h1>
        <p className="text-sm text-gray-600">
          Chain × tender × bid value × win probability × competitor × outcome × learning.
          Pipeline weighted by probability; learnings feed bid playbook.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Bids</div>
          <div className="text-2xl font-semibold">{kpis?.total_bids ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Open Bids</div>
          <div className="text-2xl font-semibold">{kpis?.open_bids ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Pipeline Value</div>
          <div className="text-2xl font-semibold">{formatRupees(kpis?.total_pipeline_value_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Weighted Pipeline</div>
          <div className="text-2xl font-semibold">{formatRupees(kpis?.weighted_pipeline_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Won Value</div>
          <div className="text-2xl font-semibold text-green-700">{formatRupees(kpis?.won_value_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Lost Value</div>
          <div className="text-2xl font-semibold text-red-700">{formatRupees(kpis?.lost_value_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Win Rate</div>
          <div className="text-2xl font-semibold">{(kpis?.win_rate_pct ?? 0)}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Open Learnings</div>
          <div className="text-2xl font-semibold">{learningRows.length}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Open Tender Bids (Pending & Shortlisted)</h2>
        <DataTable
          rows={openBids}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: OpenBid) => <span>{r.chain_name}</span> },
            { key: 'chain_tier', header: 'Tier', render: (r: OpenBid) => <span className="uppercase text-xs">{r.chain_tier}</span> },
            { key: 'tender_code', header: 'Tender', render: (r: OpenBid) => <span className="font-mono text-xs">{r.tender_code}</span> },
            { key: 'tender_title', header: 'Title', render: (r: OpenBid) => <span>{r.tender_title}</span> },
            { key: 'quarter', header: 'Quarter', render: (r: OpenBid) => <span>{r.fiscal_year} {r.quarter}</span> },
            { key: 'our_bid_rupees', header: 'Our Bid', render: (r: OpenBid) => <span>{formatRupees(r.our_bid_rupees)}</span> },
            { key: 'win_probability_pct', header: 'Win %', render: (r: OpenBid) => <span>{r.win_probability_pct}%</span> },
            { key: 'outcome', header: 'Status', render: (r: OpenBid) => <span className="uppercase text-xs">{r.outcome}</span> },
            { key: 'decision_at', header: 'Decision', render: (r: OpenBid) => <span>{formatDate(r.decision_at)}</span> },
            { key: 'region', header: 'Region', render: (r: OpenBid) => <span>{r.region}</span> },
          ]}
          emptyMessage="No open bids"
          rowKey={(r: OpenBid, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Bids by Chain</h2>
        <DataTable
          rows={chainRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => <span>{r.chain_name}</span> },
            { key: 'chain_tier', header: 'Tier', render: (r: ChainRow) => <span className="uppercase text-xs">{r.chain_tier}</span> },
            { key: 'bids_count', header: 'Bids', render: (r: ChainRow) => <span>{r.bids_count}</span> },
            { key: 'open_count', header: 'Open', render: (r: ChainRow) => <span>{r.open_count}</span> },
            { key: 'won_count', header: 'Won', render: (r: ChainRow) => <span className="text-green-700">{r.won_count}</span> },
            { key: 'lost_count', header: 'Lost', render: (r: ChainRow) => <span className="text-red-700">{r.lost_count}</span> },
            { key: 'pipeline_rupees', header: 'Pipeline', render: (r: ChainRow) => <span>{formatRupees(r.pipeline_rupees)}</span> },
            { key: 'won_rupees', header: 'Won Value', render: (r: ChainRow) => <span>{formatRupees(r.won_rupees)}</span> },
          ]}
          emptyMessage="No chain data"
          rowKey={(r: ChainRow, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Competitor Threat Matrix</h2>
        <DataTable
          rows={competitorRows}
          columns={[
            { key: 'lead_competitor', header: 'Competitor', render: (r: CompetitorRow) => <span>{r.lead_competitor}</span> },
            { key: 'encounters', header: 'Encounters', render: (r: CompetitorRow) => <span>{r.encounters}</span> },
            { key: 'wins_against', header: 'Wins vs', render: (r: CompetitorRow) => <span className="text-green-700">{r.wins_against}</span> },
            { key: 'losses_against', header: 'Losses vs', render: (r: CompetitorRow) => <span className="text-red-700">{r.losses_against}</span> },
            { key: 'total_competing_value_rupees', header: 'Competing Value', render: (r: CompetitorRow) => <span>{formatRupees(r.total_competing_value_rupees)}</span> },
            { key: 'avg_competitor_bid_rupees', header: 'Avg Bid', render: (r: CompetitorRow) => <span>{formatRupees(r.avg_competitor_bid_rupees)}</span> },
          ]}
          emptyMessage="No competitor intel"
          rowKey={(r: CompetitorRow, i: number) => String(r.lead_competitor ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Quarterly Breakdown</h2>
        <DataTable
          rows={quarterRows}
          columns={[
            { key: 'fiscal_year', header: 'FY', render: (r: QuarterRow) => <span>{r.fiscal_year}</span> },
            { key: 'quarter', header: 'Quarter', render: (r: QuarterRow) => <span>{r.quarter}</span> },
            { key: 'bids', header: 'Bids', render: (r: QuarterRow) => <span>{r.bids}</span> },
            { key: 'pipeline_rupees', header: 'Pipeline', render: (r: QuarterRow) => <span>{formatRupees(r.pipeline_rupees)}</span> },
            { key: 'weighted_rupees', header: 'Weighted', render: (r: QuarterRow) => <span>{formatRupees(r.weighted_rupees)}</span> },
            { key: 'won_rupees', header: 'Won', render: (r: QuarterRow) => <span className="text-green-700">{formatRupees(r.won_rupees)}</span> },
          ]}
          emptyMessage="No quarterly data"
          rowKey={(r: QuarterRow, i: number) => `${r.fiscal_year}-${r.quarter}-${i}`}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Decided Outcomes (Won & Lost)</h2>
        <DataTable
          rows={decidedRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: DecidedRow) => <span>{r.chain_name}</span> },
            { key: 'tender_code', header: 'Tender', render: (r: DecidedRow) => <span className="font-mono text-xs">{r.tender_code}</span> },
            { key: 'tender_title', header: 'Title', render: (r: DecidedRow) => <span>{r.tender_title}</span> },
            { key: 'outcome', header: 'Outcome', render: (r: DecidedRow) => (
              <span className={`uppercase text-xs font-semibold ${r.outcome === 'won' ? 'text-green-700' : 'text-red-700'}`}>{r.outcome}</span>
            ) },
            { key: 'our_bid_rupees', header: 'Our Bid', render: (r: DecidedRow) => <span>{formatRupees(r.our_bid_rupees)}</span> },
            { key: 'competitor_bid_rupees', header: 'Their Bid', render: (r: DecidedRow) => <span>{formatRupees(r.competitor_bid_rupees)}</span> },
            { key: 'lead_competitor', header: 'Competitor', render: (r: DecidedRow) => <span>{r.lead_competitor ?? '—'}</span> },
            { key: 'margin_pct', header: 'Margin %', render: (r: DecidedRow) => <span>{r.margin_pct != null ? `${r.margin_pct}%` : '—'}</span> },
            { key: 'decision_at', header: 'Decided', render: (r: DecidedRow) => <span>{formatDate(r.decision_at)}</span> },
          ]}
          emptyMessage="No decided bids"
          rowKey={(r: DecidedRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Open Learnings & Actions</h2>
        <DataTable
          rows={learningRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: LearningRow) => <span>{r.chain_name}</span> },
            { key: 'learning_category', header: 'Category', render: (r: LearningRow) => <span className="text-xs uppercase">{r.learning_category}</span> },
            { key: 'learning_title', header: 'Learning', render: (r: LearningRow) => <span>{r.learning_title}</span> },
            { key: 'severity', header: 'Severity', render: (r: LearningRow) => (
              <span className={`text-xs uppercase font-semibold ${r.severity === 'critical' ? 'text-red-700' : r.severity === 'warning' ? 'text-amber-700' : 'text-gray-700'}`}>{r.severity}</span>
            ) },
            { key: 'action_owner', header: 'Owner', render: (r: LearningRow) => <span>{r.action_owner}</span> },
            { key: 'action_status', header: 'Status', render: (r: LearningRow) => <span className="text-xs uppercase">{r.action_status}</span> },
            { key: 'captured_at', header: 'Captured', render: (r: LearningRow) => <span>{formatDate(r.captured_at)}</span> },
            { key: 'impact_estimate_rupees', header: 'Impact', render: (r: LearningRow) => <span>{formatRupees(r.impact_estimate_rupees)}</span> },
          ]}
          emptyMessage="No open learnings"
          rowKey={(r: LearningRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Learnings by Category</h2>
        <DataTable
          rows={categoryRows}
          columns={[
            { key: 'learning_category', header: 'Category', render: (r: CategoryRow) => <span className="uppercase text-xs">{r.learning_category}</span> },
            { key: 'total_count', header: 'Total', render: (r: CategoryRow) => <span>{r.total_count}</span> },
            { key: 'open_count', header: 'Open', render: (r: CategoryRow) => <span>{r.open_count}</span> },
            { key: 'critical_count', header: 'Critical', render: (r: CategoryRow) => <span className="text-red-700">{r.critical_count}</span> },
            { key: 'total_impact_rupees', header: 'Impact', render: (r: CategoryRow) => <span>{formatRupees(r.total_impact_rupees)}</span> },
          ]}
          emptyMessage="No categories"
          rowKey={(r: CategoryRow, i: number) => String(r.learning_category ?? i)}
        />
      </section>
    </div>
  );
}
