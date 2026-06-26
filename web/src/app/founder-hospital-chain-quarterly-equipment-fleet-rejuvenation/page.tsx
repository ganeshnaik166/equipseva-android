import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_units: number;
  total_refurb: number;
  total_retire: number;
  total_replace: number;
  total_refurb_cost: number;
  total_replace_cost: number;
  total_expected_revenue: number;
  escalate_cohorts: number;
};

type Cohort = {
  chain_code: string;
  chain_name: string;
  cohort_label: string;
  asset_category: string;
  units_total: number;
  avg_age_years: number;
  verdict: string;
  expected_revenue_lakhs: number;
};

type Verdict = {
  verdict: string;
  cohort_count: number;
  units_sum: number;
  cost_sum: number;
  revenue_sum: number;
};

type ChainRow = {
  chain_code: string;
  chain_name: string;
  cohorts: number;
  units_total: number;
  refurb_cost: number;
  replace_cost: number;
  expected_revenue: number;
};

type RunRow = {
  chain_code: string;
  run_quarter: string;
  run_date: string;
  units_actioned: number;
  cost_committed_lakhs: number;
  revenue_actual_lakhs: number;
  refurb_success_pct: number;
  status: string;
  notes: string;
};

type RoiRow = {
  chain_code: string;
  cohort_label: string;
  total_cost: number;
  expected_revenue: number;
  roi_multiple: number;
  verdict: string;
};

type CategoryRow = {
  asset_category: string;
  cohorts: number;
  units_total: number;
  avg_age: number;
  expected_revenue: number;
};

type RunHealthRow = {
  status: string;
  run_count: number;
  units_sum: number;
  cost_sum: number;
  revenue_sum: number;
  avg_success: number;
};

function fmt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, cohortsRes, verdictsRes, chainsRes, runsRes, roiRes, catsRes, healthRes] = await Promise.all([
    supabase.rpc('rpc_r2839_kpis'),
    supabase.rpc('rpc_r2839_cohort_overview'),
    supabase.rpc('rpc_r2839_verdict_breakdown'),
    supabase.rpc('rpc_r2839_chain_rollup'),
    supabase.rpc('rpc_r2839_recent_runs'),
    supabase.rpc('rpc_r2839_roi_ranking'),
    supabase.rpc('rpc_r2839_category_mix'),
    supabase.rpc('rpc_r2839_run_health'),
  ]);

  const kpis: Kpis = (kpisRes.data?.[0] ?? {
    total_units: 0,
    total_refurb: 0,
    total_retire: 0,
    total_replace: 0,
    total_refurb_cost: 0,
    total_replace_cost: 0,
    total_expected_revenue: 0,
    escalate_cohorts: 0,
  }) as Kpis;

  const cohorts: Cohort[] = (cohortsRes.data ?? []) as Cohort[];
  const verdicts: Verdict[] = (verdictsRes.data ?? []) as Verdict[];
  const chains: ChainRow[] = (chainsRes.data ?? []) as ChainRow[];
  const runs: RunRow[] = (runsRes.data ?? []) as RunRow[];
  const roi: RoiRow[] = (roiRes.data ?? []) as RoiRow[];
  const cats: CategoryRow[] = (catsRes.data ?? []) as CategoryRow[];
  const health: RunHealthRow[] = (healthRes.data ?? []) as RunHealthRow[];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Equipment Fleet Rejuvenation</h1>
        <p className="text-sm text-gray-600">
          Chain × asset cohort × refurb × retire × replace × revenue × verdict roll-up.
          Cohorts flagged as "escalate_review" need founder sign-off before quarter close.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Units in Scope</div>
          <div className="text-2xl font-semibold">{fmt(kpis.total_units)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Refurb / Retire / Replace</div>
          <div className="text-2xl font-semibold">
            {fmt(kpis.total_refurb)} / {fmt(kpis.total_retire)} / {fmt(kpis.total_replace)}
          </div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Refurb + Replace Cost (Lakhs)</div>
          <div className="text-2xl font-semibold">
            {fmt(Number(kpis.total_refurb_cost) + Number(kpis.total_replace_cost))}
          </div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Expected Revenue (Lakhs)</div>
          <div className="text-2xl font-semibold">{fmt(kpis.total_expected_revenue)}</div>
          <div className="text-xs text-gray-500 mt-1">{fmt(kpis.escalate_cohorts)} cohort(s) flagged escalate</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Cohort Overview</h2>
        <DataTable
          rows={cohorts}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Cohort) => r.chain_name },
            { key: 'cohort_label', header: 'Cohort', render: (r: Cohort) => r.cohort_label },
            { key: 'asset_category', header: 'Category', render: (r: Cohort) => r.asset_category },
            { key: 'units_total', header: 'Units', render: (r: Cohort) => fmt(r.units_total) },
            { key: 'avg_age_years', header: 'Avg Age (yrs)', render: (r: Cohort) => fmt(r.avg_age_years) },
            { key: 'verdict', header: 'Verdict', render: (r: Cohort) => r.verdict },
            { key: 'expected_revenue_lakhs', header: 'Exp Rev (L)', render: (r: Cohort) => fmt(r.expected_revenue_lakhs) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Cohort, i: number) => String(`${r.chain_code}-${r.cohort_label}-${i}`)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Verdict Breakdown</h2>
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: Verdict) => r.verdict },
            { key: 'cohort_count', header: 'Cohorts', render: (r: Verdict) => fmt(r.cohort_count) },
            { key: 'units_sum', header: 'Units', render: (r: Verdict) => fmt(r.units_sum) },
            { key: 'cost_sum', header: 'Cost (L)', render: (r: Verdict) => fmt(r.cost_sum) },
            { key: 'revenue_sum', header: 'Revenue (L)', render: (r: Verdict) => fmt(r.revenue_sum) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Verdict, i: number) => String(`${r.verdict}-${i}`)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Chain Roll-up</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'cohorts', header: 'Cohorts', render: (r: ChainRow) => fmt(r.cohorts) },
            { key: 'units_total', header: 'Units', render: (r: ChainRow) => fmt(r.units_total) },
            { key: 'refurb_cost', header: 'Refurb Cost (L)', render: (r: ChainRow) => fmt(r.refurb_cost) },
            { key: 'replace_cost', header: 'Replace Cost (L)', render: (r: ChainRow) => fmt(r.replace_cost) },
            { key: 'expected_revenue', header: 'Exp Rev (L)', render: (r: ChainRow) => fmt(r.expected_revenue) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(`${r.chain_code}-${i}`)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">ROI Ranking (revenue ÷ cost)</h2>
        <DataTable
          rows={roi}
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: RoiRow) => r.chain_code },
            { key: 'cohort_label', header: 'Cohort', render: (r: RoiRow) => r.cohort_label },
            { key: 'total_cost', header: 'Cost (L)', render: (r: RoiRow) => fmt(r.total_cost) },
            { key: 'expected_revenue', header: 'Exp Rev (L)', render: (r: RoiRow) => fmt(r.expected_revenue) },
            { key: 'roi_multiple', header: 'ROI x', render: (r: RoiRow) => fmt(r.roi_multiple) },
            { key: 'verdict', header: 'Verdict', render: (r: RoiRow) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: RoiRow, i: number) => String(`${r.chain_code}-${r.cohort_label}-${i}`)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Category Mix</h2>
        <DataTable
          rows={cats}
          columns={[
            { key: 'asset_category', header: 'Category', render: (r: CategoryRow) => r.asset_category },
            { key: 'cohorts', header: 'Cohorts', render: (r: CategoryRow) => fmt(r.cohorts) },
            { key: 'units_total', header: 'Units', render: (r: CategoryRow) => fmt(r.units_total) },
            { key: 'avg_age', header: 'Avg Age (yrs)', render: (r: CategoryRow) => fmt(r.avg_age) },
            { key: 'expected_revenue', header: 'Exp Rev (L)', render: (r: CategoryRow) => fmt(r.expected_revenue) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CategoryRow, i: number) => String(`${r.asset_category}-${i}`)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Rejuvenation Runs</h2>
        <DataTable
          rows={runs}
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: RunRow) => r.chain_code },
            { key: 'run_quarter', header: 'Quarter', render: (r: RunRow) => r.run_quarter },
            { key: 'run_date', header: 'Date', render: (r: RunRow) => r.run_date },
            { key: 'units_actioned', header: 'Units', render: (r: RunRow) => fmt(r.units_actioned) },
            { key: 'cost_committed_lakhs', header: 'Cost (L)', render: (r: RunRow) => fmt(r.cost_committed_lakhs) },
            { key: 'revenue_actual_lakhs', header: 'Revenue (L)', render: (r: RunRow) => fmt(r.revenue_actual_lakhs) },
            { key: 'refurb_success_pct', header: 'Refurb % OK', render: (r: RunRow) => fmt(r.refurb_success_pct) },
            { key: 'status', header: 'Status', render: (r: RunRow) => r.status },
            { key: 'notes', header: 'Notes', render: (r: RunRow) => r.notes },
          ]}
          emptyMessage="No data"
          rowKey={(r: RunRow, i: number) => String(`${r.chain_code}-${r.run_date}-${i}`)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Run Health by Status</h2>
        <DataTable
          rows={health}
          columns={[
            { key: 'status', header: 'Status', render: (r: RunHealthRow) => r.status },
            { key: 'run_count', header: 'Runs', render: (r: RunHealthRow) => fmt(r.run_count) },
            { key: 'units_sum', header: 'Units', render: (r: RunHealthRow) => fmt(r.units_sum) },
            { key: 'cost_sum', header: 'Cost (L)', render: (r: RunHealthRow) => fmt(r.cost_sum) },
            { key: 'revenue_sum', header: 'Revenue (L)', render: (r: RunHealthRow) => fmt(r.revenue_sum) },
            { key: 'avg_success', header: 'Avg Success %', render: (r: RunHealthRow) => fmt(r.avg_success) },
          ]}
          emptyMessage="No data"
          rowKey={(r: RunHealthRow, i: number) => String(`${r.status}-${i}`)}
        />
      </section>
    </div>
  );
}
