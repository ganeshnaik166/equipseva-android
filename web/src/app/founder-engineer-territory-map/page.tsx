import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string | number };

export const dynamic = 'force-dynamic';

export default async function FounderEngineerTerritoryMapPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let cityRows: any[] = [];
  let engineerRows: any[] = [];
  let gapRows: any[] = [];
  let queueRows: any[] = [];
  let zoneRows: any[] = [];

  try {
    const r = await sb.rpc('founder_territory_map_kpis');
    kpis = r.data?.[0] ?? {};
  } catch {
    kpis = {};
  }
  try {
    const r = await sb.rpc('founder_territory_city_breakdown');
    cityRows = (r.data as any[]) ?? [];
  } catch {
    cityRows = [];
  }
  try {
    const r = await sb.rpc('founder_territory_engineer_assignments');
    engineerRows = (r.data as any[]) ?? [];
  } catch {
    engineerRows = [];
  }
  try {
    const r = await sb.rpc('founder_territory_coverage_gaps');
    gapRows = (r.data as any[]) ?? [];
  } catch {
    gapRows = [];
  }
  try {
    const r = await sb.rpc('founder_territory_rebalance_pending');
    queueRows = (r.data as any[]) ?? [];
  } catch {
    queueRows = [];
  }
  try {
    const r = await sb.rpc('founder_territory_zone_rollup');
    zoneRows = (r.data as any[]) ?? [];
  } catch {
    zoneRows = [];
  }

  const cards: Kpi[] = [
    { label: 'Total engineers', value: kpis.total_engineers ?? '—' },
    { label: 'With territory', value: kpis.engineers_with_territory ?? '—' },
    { label: 'No territory', value: kpis.engineers_no_territory ?? '—' },
    { label: 'Cities covered', value: kpis.total_cities ?? '—' },
    { label: 'Zones', value: kpis.total_zones ?? '—' },
    { label: 'States', value: kpis.total_states ?? '—' },
    { label: 'Active AMCs', value: kpis.active_amc_contracts ?? '—' },
    { label: 'Jobs 30d', value: kpis.open_jobs_30d ?? '—' },
    { label: 'Uncovered cities', value: kpis.uncovered_cities ?? '—' },
    { label: 'Overstaffed cities', value: kpis.overstaffed_cities ?? '—' },
    { label: 'Pending rebalance', value: kpis.pending_rebalance ?? '—' },
    { label: 'Approved 7d', value: kpis.approved_rebalance_7d ?? '—' },
    { label: 'Rejected 7d', value: kpis.rejected_rebalance_7d ?? '—' },
    { label: 'Avg eng/city', value: kpis.avg_engineers_per_city ?? '—' },
    { label: 'Max eng/city', value: kpis.max_engineers_in_city ?? '—' },
    { label: 'Single-eng cities', value: kpis.cities_single_engineer ?? '—' },
  ];

  const cityCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count ?? 0 },
    { key: 'amc_contracts', header: 'AMCs', render: (r: any) => r.amc_contracts ?? 0 },
    { key: 'jobs_30d', header: 'Jobs 30d', render: (r: any) => r.jobs_30d ?? 0 },
    { key: 'demand_score', header: 'Demand', render: (r: any) => r.demand_score ?? '—' },
    { key: 'coverage_status', header: 'Status', render: (r: any) => r.coverage_status ?? '—' },
  ];

  const engCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'cached_tier', header: 'Tier', render: (r: any) => r.cached_tier ?? '—' },
    { key: 'primary_city', header: 'City', render: (r: any) => r.primary_city ?? '—' },
    { key: 'primary_state', header: 'State', render: (r: any) => r.primary_state ?? '—' },
    { key: 'zone_label', header: 'Zone', render: (r: any) => r.zone_label ?? '—' },
    { key: 'coverage_radius_km', header: 'Radius km', render: (r: any) => r.coverage_radius_km ?? '—' },
    { key: 'jobs_30d', header: 'Jobs 30d', render: (r: any) => r.jobs_30d ?? 0 },
  ];

  const gapCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
    { key: 'amc_count', header: 'AMCs', render: (r: any) => r.amc_count ?? 0 },
    { key: 'jobs_30d', header: 'Jobs 30d', render: (r: any) => r.jobs_30d ?? 0 },
    { key: 'engineers_present', header: 'Engineers', render: (r: any) => r.engineers_present ?? 0 },
    { key: 'gap_severity', header: 'Severity', render: (r: any) => r.gap_severity ?? '—' },
  ];

  const queueCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'from_city', header: 'From', render: (r: any) => r.from_city ?? '—' },
    { key: 'to_city', header: 'To', render: (r: any) => r.to_city ?? '—' },
    { key: 'to_zone', header: 'Zone', render: (r: any) => r.to_zone ?? '—' },
    { key: 'reason', header: 'Reason', render: (r: any) => r.reason ?? '—' },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const zoneCols: Column<any>[] = [
    { key: 'zone_label', header: 'Zone', render: (r: any) => r.zone_label ?? '—' },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count ?? 0 },
    { key: 'cities_covered', header: 'Cities', render: (r: any) => r.cities_covered ?? 0 },
    { key: 'states_in_zone', header: 'States', render: (r: any) => r.states_in_zone ?? 0 },
    { key: 'avg_radius_km', header: 'Avg radius', render: (r: any) => r.avg_radius_km ?? '—' },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Territory Map</h1>
        <p className="text-sm text-neutral-600">
          Per-territory engineer ownership, AMC + demand coverage, and rebalance queue.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="rounded-lg border border-neutral-200 p-3 bg-white">
            <div className="text-xs text-neutral-500">{c.label}</div>
            <div className="text-lg font-semibold">{c.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City breakdown</h2>
        <DataTable
          rows={cityRows}
          columns={cityCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer assignments</h2>
        <DataTable
          rows={engineerRows}
          columns={engCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Coverage gaps</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Rebalance queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Zone rollup</h2>
        <DataTable
          rows={zoneRows}
          columns={zoneCols}
          rowKey={(r: any) => r.id}
        />
      </section>
    </main>
  );
}
