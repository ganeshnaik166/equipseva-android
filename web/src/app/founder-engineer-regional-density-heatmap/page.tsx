import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [heatmap, cityRollup, gaps, hiring, regionSplit, saturated, kpis] = await Promise.all([
    sb.rpc('get_engineer_regional_heatmap_r2254'),
    sb.rpc('get_city_density_rollup_r2254'),
    sb.rpc('get_critical_gap_pins_r2254'),
    sb.rpc('get_hiring_targets_pipeline_r2254'),
    sb.rpc('get_region_supply_breakdown_r2254'),
    sb.rpc('get_saturated_zones_r2254'),
    sb.rpc('get_regional_density_kpis_r2254'),
  ]);

  const heatmapRows = (heatmap.data ?? []) as any[];
  const cityRows = (cityRollup.data ?? []) as any[];
  const gapRows = (gaps.data ?? []) as any[];
  const hiringRows = (hiring.data ?? []) as any[];
  const regionRows = (regionSplit.data ?? []) as any[];
  const saturatedRows = (saturated.data ?? []) as any[];
  const kpi = (kpis.data?.[0] ?? {}) as any;

  const heatmapCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city },
    { key: 'pin_code', header: 'PIN', render: (r: any) => r.pin_code },
    { key: 'region', header: 'Region', render: (r: any) => r.region },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
    { key: 'active_engineer_count', header: 'Active', render: (r: any) => r.active_engineer_count },
    { key: 'open_jobs_30d', header: 'Open 30d', render: (r: any) => r.open_jobs_30d },
    { key: 'completed_jobs_30d', header: 'Done 30d', render: (r: any) => r.completed_jobs_30d },
    { key: 'demand_supply_ratio', header: 'D/S ratio', render: (r: any) => r.demand_supply_ratio },
    { key: 'density_tier', header: 'Tier', render: (r: any) => r.density_tier },
    { key: 'hiring_priority', header: 'Hire prio', render: (r: any) => r.hiring_priority },
    { key: 'hospitals_count', header: 'Hospitals', render: (r: any) => r.hospitals_count },
    { key: 'avg_response_time_hours', header: 'Avg resp hrs', render: (r: any) => r.avg_response_time_hours ?? '-' },
  ];

  const cityCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city },
    { key: 'region', header: 'Region', render: (r: any) => r.region },
    { key: 'pin_codes_tracked', header: 'PINs', render: (r: any) => r.pin_codes_tracked },
    { key: 'total_engineers', header: 'Engineers', render: (r: any) => r.total_engineers },
    { key: 'total_active_engineers', header: 'Active', render: (r: any) => r.total_active_engineers },
    { key: 'total_open_jobs_30d', header: 'Open 30d', render: (r: any) => r.total_open_jobs_30d },
    { key: 'total_completed_jobs_30d', header: 'Done 30d', render: (r: any) => r.total_completed_jobs_30d },
    { key: 'city_demand_supply_ratio', header: 'D/S ratio', render: (r: any) => r.city_demand_supply_ratio ?? '-' },
    { key: 'critical_gap_pins', header: 'Crit gaps', render: (r: any) => r.critical_gap_pins },
    { key: 'no_coverage_pins', header: 'Zero cov', render: (r: any) => r.no_coverage_pins },
    { key: 'hospitals_count', header: 'Hospitals', render: (r: any) => r.hospitals_count },
  ];

  const gapCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city },
    { key: 'pin_code', header: 'PIN', render: (r: any) => r.pin_code },
    { key: 'region', header: 'Region', render: (r: any) => r.region },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
    { key: 'open_jobs_30d', header: 'Open 30d', render: (r: any) => r.open_jobs_30d },
    { key: 'demand_supply_ratio', header: 'D/S ratio', render: (r: any) => r.demand_supply_ratio },
    { key: 'density_tier', header: 'Tier', render: (r: any) => r.density_tier },
    { key: 'hospitals_count', header: 'Hospitals', render: (r: any) => r.hospitals_count },
    { key: 'avg_response_time_hours', header: 'Avg resp hrs', render: (r: any) => r.avg_response_time_hours ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const hiringCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city },
    { key: 'pin_code', header: 'PIN', render: (r: any) => r.pin_code },
    { key: 'target_quarter', header: 'Quarter', render: (r: any) => r.target_quarter },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'target_engineer_count', header: 'Target', render: (r: any) => r.target_engineer_count },
    { key: 'current_engineer_count', header: 'Current', render: (r: any) => r.current_engineer_count },
    { key: 'gap_to_fill', header: 'Gap', render: (r: any) => r.gap_to_fill },
    { key: 'monthly_burn_estimate_rupees', header: 'Monthly burn', render: (r: any) => `Rs ${Number(r.monthly_burn_estimate_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'rationale', header: 'Rationale', render: (r: any) => r.rationale ?? '-' },
  ];

  const regionCols: Column<any>[] = [
    { key: 'region', header: 'Region', render: (r: any) => r.region },
    { key: 'pin_codes_tracked', header: 'PINs', render: (r: any) => r.pin_codes_tracked },
    { key: 'total_engineers', header: 'Engineers', render: (r: any) => r.total_engineers },
    { key: 'total_open_jobs_30d', header: 'Open 30d', render: (r: any) => r.total_open_jobs_30d },
    { key: 'region_demand_supply_ratio', header: 'D/S ratio', render: (r: any) => r.region_demand_supply_ratio ?? '-' },
    { key: 'saturated_pins', header: 'Saturated', render: (r: any) => r.saturated_pins },
    { key: 'healthy_pins', header: 'Healthy', render: (r: any) => r.healthy_pins },
    { key: 'thin_pins', header: 'Thin', render: (r: any) => r.thin_pins },
    { key: 'critical_gap_pins', header: 'Crit gaps', render: (r: any) => r.critical_gap_pins },
    { key: 'no_coverage_pins', header: 'Zero cov', render: (r: any) => r.no_coverage_pins },
  ];

  const saturatedCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city },
    { key: 'pin_code', header: 'PIN', render: (r: any) => r.pin_code },
    { key: 'region', header: 'Region', render: (r: any) => r.region },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
    { key: 'open_jobs_30d', header: 'Open 30d', render: (r: any) => r.open_jobs_30d },
    { key: 'demand_supply_ratio', header: 'D/S ratio', render: (r: any) => r.demand_supply_ratio },
    { key: 'avg_response_time_hours', header: 'Avg resp hrs', render: (r: any) => r.avg_response_time_hours ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer regional density heatmap</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Engineer count by city x PIN code with demand vs supply ratio. Flags gaps to fill and ranks hiring priority (p0 first). Demand/supply ratio &gt;= 10 = critical gap; &lt; 3 = healthy.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 32 }}>
        <KpiCard label="PINs tracked" value={kpi.total_pin_codes_tracked ?? 0} />
        <KpiCard label="Cities tracked" value={kpi.total_cities ?? 0} />
        <KpiCard label="Total engineers" value={kpi.total_engineers ?? 0} />
        <KpiCard label="Active engineers" value={kpi.total_active_engineers ?? 0} />
        <KpiCard label="Open jobs 30d" value={kpi.total_open_jobs_30d ?? 0} />
        <KpiCard label="Overall D/S ratio" value={kpi.overall_demand_supply_ratio ?? '-'} />
        <KpiCard label="Critical gap PINs" value={kpi.critical_gap_pins ?? 0} />
        <KpiCard label="Zero coverage PINs" value={kpi.no_coverage_pins ?? 0} />
        <KpiCard label="P0 hiring targets" value={kpi.p0_hiring_targets ?? 0} />
        <KpiCard label="Total gap to fill" value={kpi.total_gap_to_fill ?? 0} />
        <KpiCard label="Monthly burn (Rs)" value={Number(kpi.monthly_burn_estimate_rupees ?? 0).toLocaleString('en-IN')} />
      </div>

      <Section title="Heatmap: PIN code density (p0 priority first)">
        <DataTable columns={heatmapCols} rows={heatmapRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="City-level rollup">
        <DataTable columns={cityCols} rows={cityRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Critical gap PINs (D/S >= 10 or zero coverage)">
        <DataTable columns={gapCols} rows={gapRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Hiring targets pipeline">
        <DataTable columns={hiringCols} rows={hiringRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Region-level supply breakdown">
        <DataTable columns={regionCols} rows={regionRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Saturated zones (oversupply candidates for rotation)">
        <DataTable columns={saturatedCols} rows={saturatedRows} rowKey={(_, i) => String(i)} />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: any }) {
  return (
    <div style={{ background: '#fafafa', border: '1px solid #e5e5e5', borderRadius: 8, padding: 14 }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{String(value)}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </section>
  );
}
