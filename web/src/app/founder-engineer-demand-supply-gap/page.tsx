import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

async function loadAll() {
  const sb = await getSupabaseServerClient();
  let kpis: any = {};
  let snapshots: any[] = [];
  let starved: any[] = [];
  let overServed: any[] = [];
  let recs: any[] = [];
  let liveCity: any[] = [];
  let closedRecs: any[] = [];

  try {
    const { data } = await sb.rpc('founder_eds_overview_kpis');
    kpis = data ?? {};
  } catch { kpis = {}; }
  try {
    const { data } = await sb.rpc('founder_eds_recent_snapshots');
    snapshots = data ?? [];
  } catch { snapshots = []; }
  try {
    const { data } = await sb.rpc('founder_eds_starved_markets');
    starved = data ?? [];
  } catch { starved = []; }
  try {
    const { data } = await sb.rpc('founder_eds_over_served_zones');
    overServed = data ?? [];
  } catch { overServed = []; }
  try {
    const { data } = await sb.rpc('founder_eds_open_recommendations');
    recs = data ?? [];
  } catch { recs = []; }
  try {
    const { data } = await sb.rpc('founder_eds_live_demand_by_city');
    liveCity = data ?? [];
  } catch { liveCity = []; }
  try {
    const { data } = await sb.rpc('founder_eds_closed_recommendations_30d');
    closedRecs = data ?? [];
  } catch { closedRecs = []; }

  return { kpis, snapshots, starved, overServed, recs, liveCity, closedRecs };
}

export default async function Page() {
  await requireFounder();
  const { kpis, snapshots, starved, overServed, recs, liveCity, closedRecs } = await loadAll();

  const kpiList: Kpi[] = [
    { label: 'Cities tracked', value: kpis.total_cities_tracked ?? 0 },
    { label: 'Categories tracked', value: kpis.total_categories_tracked ?? 0 },
    { label: 'Starved markets (7d)', value: kpis.starved_markets ?? 0 },
    { label: 'Over-served zones (7d)', value: kpis.over_served_zones ?? 0 },
    { label: 'Balanced zones (7d)', value: kpis.balanced_zones ?? 0 },
    { label: 'Open hire recs', value: kpis.open_hire_recs ?? 0 },
    { label: 'Open transfer recs', value: kpis.open_transfer_recs ?? 0 },
    { label: 'Open freeze recs', value: kpis.open_freeze_recs ?? 0 },
    { label: 'Urgent recs', value: kpis.urgent_recs ?? 0 },
    { label: 'Closed recs (30d)', value: kpis.closed_recs_30d ?? 0 },
    { label: 'Jobs (30d)', value: kpis.jobs_last_30d ?? 0 },
    { label: 'Unfilled jobs (30d)', value: kpis.unfilled_jobs_last_30d ?? 0 },
    { label: 'Total engineers', value: kpis.total_engineers ?? 0 },
    { label: 'Engineers w/ recent job', value: kpis.engineers_with_recent_job ?? 0 },
    { label: 'Avg gap score (7d)', value: String(kpis.avg_gap_score ?? 0) },
    { label: 'Snapshots total', value: kpis.snapshots_total ?? 0 },
  ];

  const snapCols: Column<any>[] = [
    { key: 'captured_at', header: 'When', render: (r: any) => new Date(r.captured_at).toLocaleString() },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'demand_jobs', header: 'Demand', render: (r: any) => r.demand_jobs ?? 0 },
    { key: 'supply_engineers', header: 'Supply', render: (r: any) => r.supply_engineers ?? 0 },
    { key: 'gap_score', header: 'Gap', render: (r: any) => String(r.gap_score ?? 0) },
    { key: 'classification', header: 'Class', render: (r: any) => r.classification ?? '—' },
  ];

  const starvedCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'demand_jobs', header: 'Demand', render: (r: any) => r.demand_jobs ?? 0 },
    { key: 'supply_engineers', header: 'Supply', render: (r: any) => r.supply_engineers ?? 0 },
    { key: 'gap_score', header: 'Gap', render: (r: any) => String(r.gap_score ?? 0) },
    { key: 'captured_at', header: 'When', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const overCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'demand_jobs', header: 'Demand', render: (r: any) => r.demand_jobs ?? 0 },
    { key: 'supply_engineers', header: 'Supply', render: (r: any) => r.supply_engineers ?? 0 },
    { key: 'gap_score', header: 'Gap', render: (r: any) => String(r.gap_score ?? 0) },
    { key: 'captured_at', header: 'When', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const recCols: Column<any>[] = [
    { key: 'created_at', header: 'Opened', render: (r: any) => new Date(r.created_at).toLocaleString() },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'recommendation_kind', header: 'Kind', render: (r: any) => r.recommendation_kind ?? '—' },
    { key: 'headcount_delta', header: 'Delta', render: (r: any) => r.headcount_delta ?? 0 },
    { key: 'urgency', header: 'Urgency', render: (r: any) => r.urgency ?? '—' },
    { key: 'rationale', header: 'Rationale', render: (r: any) => r.rationale ?? '—' },
  ];

  const liveCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'jobs_30d', header: 'Jobs (30d)', render: (r: any) => r.jobs_30d ?? 0 },
    { key: 'unfilled', header: 'Unfilled', render: (r: any) => r.unfilled ?? 0 },
    { key: 'engineers_in_org_city', header: 'Engineers', render: (r: any) => r.engineers_in_org_city ?? 0 },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 8 }}>Engineer Demand-Supply Gap Analyzer</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>Per-city / per-equipment-category demand vs supply. Surfaces starved markets, over-served zones, and hire/transfer recommendations.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        {kpiList.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{String(k.value)}</div>
          </div>
        ))}
      </section>

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '16px 0 8px' }}>Starved markets (last 14d)</h2>
      <DataTable rows={starved} columns={starvedCols} rowKey={(r: any) => r.city + r.equipment_category + r.captured_at} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Over-served zones (last 14d)</h2>
      <DataTable rows={overServed} columns={overCols} rowKey={(r: any) => r.city + r.equipment_category + r.captured_at} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Open hire/transfer recommendations</h2>
      <DataTable rows={recs} columns={recCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Live demand by city (last 30d jobs)</h2>
      <DataTable rows={liveCity} columns={liveCols} rowKey={(r: any) => r.city} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Recent snapshots</h2>
      <DataTable rows={snapshots} columns={snapCols} rowKey={(r: any) => r.id} />

      {closedRecs.length > 0 ? (
        <>
          <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Closed recommendations (30d)</h2>
          <ul>
            {closedRecs.map((r: any) => (
              <li key={r.id}>{r.city} / {r.equipment_category} — {r.recommendation_kind} ({r.urgency}) closed {new Date(r.closed_at).toLocaleDateString()}</li>
            ))}
          </ul>
        </>
      ) : null}
    </main>
  );
}
