import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_chains: number;
  total_pool_units: number;
  deployed_units: number;
  avg_utilization_pct: number;
  avg_refill_rate_pct: number;
  chains_grade_a: number;
  chains_grade_d_or_f: number;
  total_revenue_impact_rupees: number;
};

type ChainRow = {
  chain_name: string;
  hospital_chain_code: string;
  asset_classes_covered: number;
  pool_units: number;
  deployed_units: number;
  avg_utilization_pct: number;
  avg_refill_rate_pct: number;
  best_grade: string;
};

type AssetRow = {
  asset_class: string;
  pool_units: number;
  deployed_units: number;
  reserve_units: number;
  avg_utilization_pct: number;
  avg_refill_rate_pct: number;
  chains_using: number;
};

type RefillRow = {
  chain_name: string;
  hospital_chain_code: string;
  asset_class: string;
  fiscal_quarter: string;
  refill_target_units: number;
  refill_actual_units: number;
  refill_gap_units: number;
  refill_rate_pct: number;
  outcome_grade: string;
};

type LeaderRow = {
  chain_name: string;
  hospital_chain_code: string;
  asset_class: string;
  pool_size_units: number;
  deployed_units: number;
  utilization_pct: number;
  outcome_grade: string;
};

type EventRow = {
  event_date: string;
  hospital_chain_code: string;
  asset_class: string;
  asset_serial: string;
  event_type: string;
  utilization_hours: number;
  uptime_pct: number;
  outcome: string;
  revenue_impact_rupees: number;
};

type OutcomeRow = {
  outcome: string;
  event_count: number;
  total_revenue_impact_rupees: number;
  avg_uptime_pct: number;
};

type QuarterRow = {
  fiscal_quarter: string;
  total_pool_units: number;
  total_deployed_units: number;
  avg_utilization_pct: number;
  avg_refill_rate_pct: number;
  records: number;
};

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0.00%';
  return Number(n).toFixed(2) + '%';
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, chainsRes, assetsRes, refillRes, leadersRes, eventsRes, outcomesRes, quartersRes] = await Promise.all([
    supabase.rpc('founder_r2879_kpi_summary'),
    supabase.rpc('founder_r2879_chain_rollup'),
    supabase.rpc('founder_r2879_asset_class_breakdown'),
    supabase.rpc('founder_r2879_refill_watchlist'),
    supabase.rpc('founder_r2879_utilization_leaders'),
    supabase.rpc('founder_r2879_recent_events', { p_limit: 20 }),
    supabase.rpc('founder_r2879_outcome_distribution'),
    supabase.rpc('founder_r2879_quarter_trend'),
  ]);

  const kpi: Kpi = (kpiRes.data && kpiRes.data[0]) || {
    total_chains: 0,
    total_pool_units: 0,
    deployed_units: 0,
    avg_utilization_pct: 0,
    avg_refill_rate_pct: 0,
    chains_grade_a: 0,
    chains_grade_d_or_f: 0,
    total_revenue_impact_rupees: 0,
  };
  const chains: ChainRow[] = chainsRes.data || [];
  const assets: AssetRow[] = assetsRes.data || [];
  const refill: RefillRow[] = refillRes.data || [];
  const leaders: LeaderRow[] = leadersRes.data || [];
  const events: EventRow[] = eventsRes.data || [];
  const outcomes: OutcomeRow[] = outcomesRes.data || [];
  const quarters: QuarterRow[] = quartersRes.data || [];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <p className="text-xs uppercase tracking-widest text-slate-500">Round r2879 · Founder Console</p>
        <h1 className="text-3xl font-semibold text-slate-900">Hospital Chain Quarterly Equipment Fleet Loaner Utilization</h1>
        <p className="text-sm text-slate-600">
          Chain × asset class × loaner pool × utilization × refill rate × outcome — quarter-by-quarter view of where loaner fleets are earning vs. idling.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <KpiCard label="Chains tracked" value={fmtInt(kpi.total_chains)} />
        <KpiCard label="Total pool units" value={fmtInt(kpi.total_pool_units)} />
        <KpiCard label="Deployed units" value={fmtInt(kpi.deployed_units)} />
        <KpiCard label="Avg utilization" value={fmtPct(kpi.avg_utilization_pct)} />
        <KpiCard label="Avg refill rate" value={fmtPct(kpi.avg_refill_rate_pct)} />
        <KpiCard label="Grade A rows" value={fmtInt(kpi.chains_grade_a)} />
        <KpiCard label="Grade D/F rows" value={fmtInt(kpi.chains_grade_d_or_f)} />
        <KpiCard label="Revenue impact" value={fmtRupees(kpi.total_revenue_impact_rupees)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold text-slate-900">Chain rollup</h2>
        <p className="text-sm text-slate-600">Per-chain utilization summary — sorted by highest average deployment.</p>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => <span className="font-medium">{r.chain_name}</span> },
            { key: 'hospital_chain_code', header: 'Code', render: (r: ChainRow) => <span className="font-mono text-xs">{r.hospital_chain_code}</span> },
            { key: 'asset_classes_covered', header: 'Asset classes', render: (r: ChainRow) => fmtInt(r.asset_classes_covered) },
            { key: 'pool_units', header: 'Pool', render: (r: ChainRow) => fmtInt(r.pool_units) },
            { key: 'deployed_units', header: 'Deployed', render: (r: ChainRow) => fmtInt(r.deployed_units) },
            { key: 'avg_utilization_pct', header: 'Util', render: (r: ChainRow) => fmtPct(r.avg_utilization_pct) },
            { key: 'avg_refill_rate_pct', header: 'Refill', render: (r: ChainRow) => fmtPct(r.avg_refill_rate_pct) },
            { key: 'best_grade', header: 'Best grade', render: (r: ChainRow) => r.best_grade },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as ChainRow).hospital_chain_code ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold text-slate-900">Asset class breakdown</h2>
        <p className="text-sm text-slate-600">Aggregate pool and utilization by equipment class across all chains.</p>
        <DataTable
          rows={assets}
          columns={[
            { key: 'asset_class', header: 'Asset class', render: (r: AssetRow) => <span className="font-medium">{r.asset_class}</span> },
            { key: 'pool_units', header: 'Pool', render: (r: AssetRow) => fmtInt(r.pool_units) },
            { key: 'deployed_units', header: 'Deployed', render: (r: AssetRow) => fmtInt(r.deployed_units) },
            { key: 'reserve_units', header: 'Reserve', render: (r: AssetRow) => fmtInt(r.reserve_units) },
            { key: 'avg_utilization_pct', header: 'Util', render: (r: AssetRow) => fmtPct(r.avg_utilization_pct) },
            { key: 'avg_refill_rate_pct', header: 'Refill', render: (r: AssetRow) => fmtPct(r.avg_refill_rate_pct) },
            { key: 'chains_using', header: 'Chains', render: (r: AssetRow) => fmtInt(r.chains_using) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as AssetRow).asset_class ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold text-slate-900">Refill watchlist</h2>
        <p className="text-sm text-slate-600">Rows where refill rate is below 80% — supply chain follow-up required.</p>
        <DataTable
          rows={refill}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: RefillRow) => r.chain_name },
            { key: 'asset_class', header: 'Asset class', render: (r: RefillRow) => r.asset_class },
            { key: 'fiscal_quarter', header: 'Quarter', render: (r: RefillRow) => r.fiscal_quarter },
            { key: 'refill_target_units', header: 'Target', render: (r: RefillRow) => fmtInt(r.refill_target_units) },
            { key: 'refill_actual_units', header: 'Actual', render: (r: RefillRow) => fmtInt(r.refill_actual_units) },
            { key: 'refill_gap_units', header: 'Gap', render: (r: RefillRow) => fmtInt(r.refill_gap_units) },
            { key: 'refill_rate_pct', header: 'Refill %', render: (r: RefillRow) => fmtPct(r.refill_rate_pct) },
            { key: 'outcome_grade', header: 'Grade', render: (r: RefillRow) => r.outcome_grade },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(((r as RefillRow).hospital_chain_code + '-' + (r as RefillRow).asset_class) ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold text-slate-900">Utilization leaders</h2>
        <p className="text-sm text-slate-600">Pools running at 85%+ utilization — candidates for capacity expansion.</p>
        <DataTable
          rows={leaders}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: LeaderRow) => r.chain_name },
            { key: 'asset_class', header: 'Asset class', render: (r: LeaderRow) => r.asset_class },
            { key: 'pool_size_units', header: 'Pool', render: (r: LeaderRow) => fmtInt(r.pool_size_units) },
            { key: 'deployed_units', header: 'Deployed', render: (r: LeaderRow) => fmtInt(r.deployed_units) },
            { key: 'utilization_pct', header: 'Util', render: (r: LeaderRow) => fmtPct(r.utilization_pct) },
            { key: 'outcome_grade', header: 'Grade', render: (r: LeaderRow) => r.outcome_grade },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(((r as LeaderRow).hospital_chain_code + '-' + (r as LeaderRow).asset_class) ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold text-slate-900">Recent fleet events</h2>
        <p className="text-sm text-slate-600">Last 20 deploy / refill / breakdown / swap events across the loaner network.</p>
        <DataTable
          rows={events}
          columns={[
            { key: 'event_date', header: 'Date', render: (r: EventRow) => r.event_date },
            { key: 'hospital_chain_code', header: 'Chain', render: (r: EventRow) => <span className="font-mono text-xs">{r.hospital_chain_code}</span> },
            { key: 'asset_class', header: 'Class', render: (r: EventRow) => r.asset_class },
            { key: 'asset_serial', header: 'Serial', render: (r: EventRow) => <span className="font-mono text-xs">{r.asset_serial}</span> },
            { key: 'event_type', header: 'Event', render: (r: EventRow) => r.event_type },
            { key: 'utilization_hours', header: 'Hours', render: (r: EventRow) => fmtInt(r.utilization_hours) },
            { key: 'uptime_pct', header: 'Uptime', render: (r: EventRow) => fmtPct(r.uptime_pct) },
            { key: 'outcome', header: 'Outcome', render: (r: EventRow) => r.outcome },
            { key: 'revenue_impact_rupees', header: 'Revenue', render: (r: EventRow) => fmtRupees(r.revenue_impact_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(((r as EventRow).asset_serial + '-' + (r as EventRow).event_date) ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold text-slate-900">Outcome distribution</h2>
        <p className="text-sm text-slate-600">How the chain fleet events resolved — revenue impact sorted descending.</p>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => <span className="font-medium">{r.outcome}</span> },
            { key: 'event_count', header: 'Events', render: (r: OutcomeRow) => fmtInt(r.event_count) },
            { key: 'avg_uptime_pct', header: 'Avg uptime', render: (r: OutcomeRow) => fmtPct(r.avg_uptime_pct) },
            { key: 'total_revenue_impact_rupees', header: 'Revenue impact', render: (r: OutcomeRow) => fmtRupees(r.total_revenue_impact_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as OutcomeRow).outcome ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold text-slate-900">Quarter-over-quarter trend</h2>
        <p className="text-sm text-slate-600">Pool growth and utilization plotted across fiscal quarters.</p>
        <DataTable
          rows={quarters}
          columns={[
            { key: 'fiscal_quarter', header: 'Quarter', render: (r: QuarterRow) => r.fiscal_quarter },
            { key: 'total_pool_units', header: 'Pool', render: (r: QuarterRow) => fmtInt(r.total_pool_units) },
            { key: 'total_deployed_units', header: 'Deployed', render: (r: QuarterRow) => fmtInt(r.total_deployed_units) },
            { key: 'avg_utilization_pct', header: 'Util', render: (r: QuarterRow) => fmtPct(r.avg_utilization_pct) },
            { key: 'avg_refill_rate_pct', header: 'Refill', render: (r: QuarterRow) => fmtPct(r.avg_refill_rate_pct) },
            { key: 'records', header: 'Rows', render: (r: QuarterRow) => fmtInt(r.records) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as QuarterRow).fiscal_quarter ?? i)}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <p className="text-xs uppercase tracking-wider text-slate-500">{label}</p>
      <p className="mt-2 text-2xl font-semibold text-slate-900">{value}</p>
    </div>
  );
}
