import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerMultiSiteRolloutTrackerPage() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? '';

  const [kpis, overview, stalled, issues, velocity, cities] = await Promise.all([
    supabase.rpc('r2336_top_kpis'),
    supabase.rpc('r2336_rollout_overview'),
    supabase.rpc('r2336_stalled_sites'),
    supabase.rpc('r2336_issue_sites'),
    supabase.rpc('r2336_rollout_velocity'),
    supabase.rpc('r2336_city_distribution'),
  ]);

  const k = kpis.data?.[0] ?? null;

  const overviewCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'master_contract_ref', header: 'Contract', render: (r) => r.master_contract_ref },
    { key: 'total_sites_planned', header: 'Planned', render: (r) => r.total_sites_planned },
    { key: 'sites_signed', header: 'Signed', render: (r) => r.sites_signed },
    { key: 'sites_onboarded', header: 'Onboarded', render: (r) => r.sites_onboarded },
    { key: 'sites_active', header: 'Active', render: (r) => r.sites_active },
    { key: 'sites_with_issues', header: 'Issues', render: (r) => r.sites_with_issues },
    { key: 'pct_active', header: '% Active', render: (r) => (r.pct_active ?? 0) + '%' },
    { key: 'contract_value_rupees', header: 'Value (Rs)', render: (r) => Number(r.contract_value_rupees).toLocaleString('en-IN') },
  ];

  const stalledCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'site_name', header: 'Site', render: (r) => r.site_name },
    { key: 'site_city', header: 'City', render: (r) => r.site_city },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'days_stalled', header: 'Days Stalled', render: (r) => r.days_stalled },
  ];

  const issueCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'site_name', header: 'Site', render: (r) => r.site_name },
    { key: 'site_city', header: 'City', render: (r) => r.site_city },
    { key: 'last_issue_note', header: 'Issue', render: (r) => r.last_issue_note ?? '-' },
    { key: 'equipment_count', header: 'Equip', render: (r) => r.equipment_count },
  ];

  const velocityCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'activated_30d', header: 'Activated 30d', render: (r) => r.activated_30d },
    { key: 'activated_90d', header: 'Activated 90d', render: (r) => r.activated_90d },
    { key: 'remaining_to_activate', header: 'Remaining', render: (r) => r.remaining_to_activate },
  ];

  const cityCols: Column<any>[] = [
    { key: 'site_city', header: 'City', render: (r) => r.site_city },
    { key: 'total_sites', header: 'Total', render: (r) => r.total_sites },
    { key: 'active_sites', header: 'Active', render: (r) => r.active_sites },
    { key: 'issue_sites', header: 'Issues', render: (r) => r.issue_sites },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Customer Multi-Site Rollout Tracker</h1>
        <p className="text-sm text-gray-600">Signed in as {email}. Per-site status across chain contracts.</p>
      </header>

      {k && (
        <section className="grid grid-cols-2 md:grid-cols-6 gap-4">
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Chains</div><div className="text-xl font-semibold">{k.total_chains}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Sites Planned</div><div className="text-xl font-semibold">{k.total_sites_planned}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Sites Active</div><div className="text-xl font-semibold">{k.total_sites_active}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">With Issues</div><div className="text-xl font-semibold">{k.total_sites_with_issues}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Contract Value (Rs)</div><div className="text-xl font-semibold">{Number(k.total_contract_value_rupees).toLocaleString('en-IN')}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">% Complete</div><div className="text-xl font-semibold">{k.pct_completion ?? 0}%</div></div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Rollout Overview</h2>
        <DataTable
          rows={overview.data ?? []}
          columns={overviewCols}
          rowKey={(r: any) => r.id}
          emptyMessage="No multi-site rollouts tracked."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stalled Sites (signed &gt;= 30 days, not onboarded)</h2>
        <DataTable
          rows={stalled.data ?? []}
          columns={stalledCols}
          rowKey={(r: any) => r.chain_name + '|' + r.site_name}
          emptyMessage="No stalled sites."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Sites With Issues</h2>
        <DataTable
          rows={issues.data ?? []}
          columns={issueCols}
          rowKey={(r: any) => r.chain_name + '|' + r.site_name}
          emptyMessage="No sites flagged with issues."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Rollout Velocity</h2>
        <DataTable
          rows={velocity.data ?? []}
          columns={velocityCols}
          rowKey={(r: any) => r.chain_name}
          emptyMessage="No velocity data."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Distribution</h2>
        <DataTable
          rows={cities.data ?? []}
          columns={cityCols}
          rowKey={(r: any) => r.site_city}
          emptyMessage="No city data."
        />
      </section>
    </div>
  );
}
