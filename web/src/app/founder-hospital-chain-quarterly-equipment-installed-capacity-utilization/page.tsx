import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_chains: number;
  total_installed_units: number;
  avg_utilization_pct: number;
  total_unrealized_revenue_rupees: number;
  open_opportunities: number;
};

type Snapshot = {
  id: string;
  chain_name: string;
  fiscal_quarter: string;
  asset_category: string;
  installed_units: number;
  theoretical_hours_per_quarter: number;
  actual_hours_logged: number;
  utilization_pct: number;
  downtime_hours: number;
  revenue_per_hour_rupees: number;
};

type ChainRollup = {
  chain_name: string;
  asset_categories: number;
  total_units: number;
  avg_utilization_pct: number;
  total_downtime_hours: number;
};

type AssetRollup = {
  asset_category: string;
  chains_count: number;
  total_units: number;
  avg_utilization_pct: number;
  total_actual_hours: number;
};

type Opportunity = {
  id: string;
  chain_name: string;
  asset_category: string;
  headroom_pct: number;
  unrealized_revenue_rupees: number;
  recommended_action: string;
  priority: string;
  expected_uplift_pct: number;
  status: string;
};

type Underutilized = {
  chain_name: string;
  asset_category: string;
  utilization_pct: number;
  installed_units: number;
  headroom_pct: number;
};

type ActionRow = {
  recommended_action: string;
  opportunities: number;
  total_unrealized_revenue: number;
  avg_expected_uplift_pct: number;
};

function fmtNum(n: number | null | undefined): string {
  if (n == null) return '0';
  return new Intl.NumberFormat('en-IN').format(Number(n));
}

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '0';
  return '₹' + new Intl.NumberFormat('en-IN').format(Number(n));
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return '0%';
  return Number(n).toFixed(1) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, snapsRes, chainRes, assetRes, oppsRes, underRes, actRes] = await Promise.all([
    supabase.rpc('founder_r2807_kpi_summary'),
    supabase.rpc('founder_r2807_list_snapshots'),
    supabase.rpc('founder_r2807_chain_rollup'),
    supabase.rpc('founder_r2807_asset_rollup'),
    supabase.rpc('founder_r2807_list_opportunities'),
    supabase.rpc('founder_r2807_top_underutilized'),
    supabase.rpc('founder_r2807_action_distribution'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_chains: 0,
    total_installed_units: 0,
    avg_utilization_pct: 0,
    total_unrealized_revenue_rupees: 0,
    open_opportunities: 0,
  }) as Kpi;

  const snaps: Snapshot[] = (snapsRes.data ?? []) as Snapshot[];
  const chains: ChainRollup[] = (chainRes.data ?? []) as ChainRollup[];
  const assets: AssetRollup[] = (assetRes.data ?? []) as AssetRollup[];
  const opps: Opportunity[] = (oppsRes.data ?? []) as Opportunity[];
  const under: Underutilized[] = (underRes.data ?? []) as Underutilized[];
  const actions: ActionRow[] = (actRes.data ?? []) as ActionRow[];

  const snapCols = [
    { key: 'chain_name', header: 'Chain', render: (r: Snapshot) => r.chain_name },
    { key: 'fiscal_quarter', header: 'Quarter', render: (r: Snapshot) => r.fiscal_quarter },
    { key: 'asset_category', header: 'Asset', render: (r: Snapshot) => r.asset_category },
    { key: 'installed_units', header: 'Units', render: (r: Snapshot) => fmtNum(r.installed_units) },
    { key: 'theoretical_hours_per_quarter', header: 'Theo Hrs', render: (r: Snapshot) => fmtNum(r.theoretical_hours_per_quarter) },
    { key: 'actual_hours_logged', header: 'Actual Hrs', render: (r: Snapshot) => fmtNum(r.actual_hours_logged) },
    { key: 'utilization_pct', header: 'Util %', render: (r: Snapshot) => fmtPct(r.utilization_pct) },
    { key: 'downtime_hours', header: 'Downtime', render: (r: Snapshot) => fmtNum(r.downtime_hours) },
    { key: 'revenue_per_hour_rupees', header: 'Rev/Hr', render: (r: Snapshot) => fmtRupees(r.revenue_per_hour_rupees) },
  ];

  const chainCols = [
    { key: 'chain_name', header: 'Chain', render: (r: ChainRollup) => r.chain_name },
    { key: 'asset_categories', header: 'Asset Cats', render: (r: ChainRollup) => fmtNum(r.asset_categories) },
    { key: 'total_units', header: 'Total Units', render: (r: ChainRollup) => fmtNum(r.total_units) },
    { key: 'avg_utilization_pct', header: 'Avg Util', render: (r: ChainRollup) => fmtPct(r.avg_utilization_pct) },
    { key: 'total_downtime_hours', header: 'Downtime', render: (r: ChainRollup) => fmtNum(r.total_downtime_hours) },
  ];

  const assetCols = [
    { key: 'asset_category', header: 'Asset', render: (r: AssetRollup) => r.asset_category },
    { key: 'chains_count', header: 'Chains', render: (r: AssetRollup) => fmtNum(r.chains_count) },
    { key: 'total_units', header: 'Units', render: (r: AssetRollup) => fmtNum(r.total_units) },
    { key: 'avg_utilization_pct', header: 'Avg Util', render: (r: AssetRollup) => fmtPct(r.avg_utilization_pct) },
    { key: 'total_actual_hours', header: 'Actual Hrs', render: (r: AssetRollup) => fmtNum(r.total_actual_hours) },
  ];

  const oppCols = [
    { key: 'chain_name', header: 'Chain', render: (r: Opportunity) => r.chain_name },
    { key: 'asset_category', header: 'Asset', render: (r: Opportunity) => r.asset_category },
    { key: 'headroom_pct', header: 'Headroom', render: (r: Opportunity) => fmtPct(r.headroom_pct) },
    { key: 'unrealized_revenue_rupees', header: 'Unrealized', render: (r: Opportunity) => fmtRupees(r.unrealized_revenue_rupees) },
    { key: 'recommended_action', header: 'Action', render: (r: Opportunity) => r.recommended_action },
    { key: 'priority', header: 'Priority', render: (r: Opportunity) => r.priority },
    { key: 'expected_uplift_pct', header: 'Uplift', render: (r: Opportunity) => fmtPct(r.expected_uplift_pct) },
    { key: 'status', header: 'Status', render: (r: Opportunity) => r.status },
  ];

  const underCols = [
    { key: 'chain_name', header: 'Chain', render: (r: Underutilized) => r.chain_name },
    { key: 'asset_category', header: 'Asset', render: (r: Underutilized) => r.asset_category },
    { key: 'utilization_pct', header: 'Util %', render: (r: Underutilized) => fmtPct(r.utilization_pct) },
    { key: 'installed_units', header: 'Units', render: (r: Underutilized) => fmtNum(r.installed_units) },
    { key: 'headroom_pct', header: 'Headroom', render: (r: Underutilized) => fmtPct(r.headroom_pct) },
  ];

  const actCols = [
    { key: 'recommended_action', header: 'Action', render: (r: ActionRow) => r.recommended_action },
    { key: 'opportunities', header: 'Count', render: (r: ActionRow) => fmtNum(r.opportunities) },
    { key: 'total_unrealized_revenue', header: 'Unrealized', render: (r: ActionRow) => fmtRupees(r.total_unrealized_revenue) },
    { key: 'avg_expected_uplift_pct', header: 'Avg Uplift', render: (r: ActionRow) => fmtPct(r.avg_expected_uplift_pct) },
  ];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Chain Quarterly Capacity Utilization</h1>
        <p className="text-sm text-gray-600">
          Chain × asset × theoretical capacity × actual × utilization &amp; growth headroom. Targets utilization &gt;= 80%.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Chains</div>
          <div className="text-xl font-semibold">{fmtNum(kpi.total_chains)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Installed Units</div>
          <div className="text-xl font-semibold">{fmtNum(kpi.total_installed_units)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Avg Utilization</div>
          <div className="text-xl font-semibold">{fmtPct(kpi.avg_utilization_pct)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Unrealized Revenue</div>
          <div className="text-xl font-semibold">{fmtRupees(kpi.total_unrealized_revenue_rupees)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Open Opportunities</div>
          <div className="text-xl font-semibold">{fmtNum(kpi.open_opportunities)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Snapshots (chain × asset)</h2>
        <DataTable rows={snaps} columns={snapCols} emptyMessage="No data" rowKey={(r, i) => String((r as Snapshot).id ?? i)} />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Chain Rollup</h2>
          <DataTable rows={chains} columns={chainCols} emptyMessage="No data" rowKey={(r, i) => String((r as ChainRollup).chain_name ?? i)} />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Asset Category Rollup</h2>
          <DataTable rows={assets} columns={assetCols} emptyMessage="No data" rowKey={(r, i) => String((r as AssetRollup).asset_category ?? i)} />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Growth Headroom Opportunities</h2>
        <DataTable rows={opps} columns={oppCols} emptyMessage="No data" rowKey={(r, i) => String((r as Opportunity).id ?? i)} />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Top Underutilized (util &lt; 80%)</h2>
          <DataTable rows={under} columns={underCols} emptyMessage="No data" rowKey={(r, i) => String(i)} />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Recommended Action Distribution</h2>
          <DataTable rows={actions} columns={actCols} emptyMessage="No data" rowKey={(r, i) => String((r as ActionRow).recommended_action ?? i)} />
        </div>
      </section>
    </div>
  );
}
