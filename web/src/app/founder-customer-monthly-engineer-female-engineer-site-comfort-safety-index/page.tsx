import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type HospitalIndex = { hospital_code: string; hospital_name: string; city: string; avg_comfort: number; avg_safety: number; avg_composite: number; total_visits: number; red_flag_engineers: number };
type EngineerSummary = { engineer_code: string; engineer_name: string; visits_total: number; avg_comfort: number; avg_safety: number; avg_composite: number; sites_red: number };
type RedFlag = { hospital_code: string; hospital_name: string; city: string; engineer_name: string; composite_index: number; restroom_access: string; escort_provided: boolean; incidents_reported: number };
type Incident = { incident_type: string; total_count: number; p1_count: number; p2_count: number; p3_count: number; p4_count: number; unresolved: number };
type Restroom = { restroom_access: string; site_count: number; avg_comfort: number; share_pct: number };
type Open = { hospital_code: string; engineer_code: string; incident_type: string; severity: string; description: string; reported_at: string };
type Kpi = { total_sites: number; total_visits: number; avg_composite: number; red_sites: number; dedicated_restroom_pct: number; escort_provided_pct: number; open_p1_p2: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [hi, es, rf, ib, rm, oi, kp] = await Promise.all([
    sb.rpc('founder_r2952_hospital_index'),
    sb.rpc('founder_r2952_engineer_summary'),
    sb.rpc('founder_r2952_red_flag_sites'),
    sb.rpc('founder_r2952_incident_breakdown'),
    sb.rpc('founder_r2952_restroom_access_mix'),
    sb.rpc('founder_r2952_open_incidents'),
    sb.rpc('founder_r2952_kpis'),
  ]);

  const hospitals = (hi.data ?? []) as HospitalIndex[];
  const engineers = (es.data ?? []) as EngineerSummary[];
  const reds = (rf.data ?? []) as RedFlag[];
  const incidents = (ib.data ?? []) as Incident[];
  const restrooms = (rm.data ?? []) as Restroom[];
  const opens = (oi.data ?? []) as Open[];
  const kpis = ((kp.data ?? []) as Kpi[])[0];

  const hospitalCols: Column<HospitalIndex>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Avg Comfort', accessor: (r) => r.avg_comfort },
    { header: 'Avg Safety', accessor: (r) => r.avg_safety },
    { header: 'Composite', accessor: (r) => r.avg_composite },
    { header: 'Visits', accessor: (r) => r.total_visits },
    { header: 'Red Engineers', accessor: (r) => r.red_flag_engineers },
  ];
  const engineerCols: Column<EngineerSummary>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Code', accessor: (r) => r.engineer_code },
    { header: 'Visits', accessor: (r) => r.visits_total },
    { header: 'Comfort', accessor: (r) => r.avg_comfort },
    { header: 'Safety', accessor: (r) => r.avg_safety },
    { header: 'Composite', accessor: (r) => r.avg_composite },
    { header: 'Red Sites', accessor: (r) => r.sites_red },
  ];
  const redCols: Column<RedFlag>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Composite', accessor: (r) => r.composite_index },
    { header: 'Restroom', accessor: (r) => r.restroom_access },
    { header: 'Escort', accessor: (r) => (r.escort_provided ? 'yes' : 'no') },
    { header: 'Incidents', accessor: (r) => r.incidents_reported },
  ];
  const incidentCols: Column<Incident>[] = [
    { header: 'Type', accessor: (r) => r.incident_type },
    { header: 'Total', accessor: (r) => r.total_count },
    { header: 'P1', accessor: (r) => r.p1_count },
    { header: 'P2', accessor: (r) => r.p2_count },
    { header: 'P3', accessor: (r) => r.p3_count },
    { header: 'P4', accessor: (r) => r.p4_count },
    { header: 'Unresolved', accessor: (r) => r.unresolved },
  ];
  const restroomCols: Column<Restroom>[] = [
    { header: 'Access', accessor: (r) => r.restroom_access },
    { header: 'Sites', accessor: (r) => r.site_count },
    { header: 'Avg Comfort', accessor: (r) => r.avg_comfort },
    { header: 'Share %', accessor: (r) => r.share_pct },
  ];
  const openCols: Column<Open>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_code },
    { header: 'Engineer', accessor: (r) => r.engineer_code },
    { header: 'Type', accessor: (r) => r.incident_type },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Description', accessor: (r) => r.description },
    { header: 'Reported', accessor: (r) => new Date(r.reported_at).toLocaleString() },
  ];

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-semibold">Female-Engineer Site Comfort &amp; Safety Index — r2952</h1>
      <p className="text-sm text-gray-600">Customer monthly engineer comfort &amp; safety composite across hospital sites. Composite &gt;= 80 is target.</p>

      {kpis && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Total sites</div><div className="text-xl font-semibold">{kpis.total_sites}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Total visits</div><div className="text-xl font-semibold">{kpis.total_visits}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Avg composite</div><div className="text-xl font-semibold">{kpis.avg_composite}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Red sites</div><div className="text-xl font-semibold">{kpis.red_sites}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Dedicated restroom %</div><div className="text-xl font-semibold">{kpis.dedicated_restroom_pct}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Escort provided %</div><div className="text-xl font-semibold">{kpis.escort_provided_pct}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Open P1/P2</div><div className="text-xl font-semibold">{kpis.open_p1_p2}</div></div>
        </div>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospital Index (lowest composite first)</h2>
        <DataTable rows={hospitals} columns={hospitalCols} emptyMessage="No hospitals" rowKey={(r, i) => String((r as { hospital_code?: string }).hospital_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Summary</h2>
        <DataTable rows={engineers} columns={engineerCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as { engineer_code?: string }).engineer_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Red Flag Sites</h2>
        <DataTable rows={reds} columns={redCols} emptyMessage="No red flags" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Incident Breakdown by Type</h2>
        <DataTable rows={incidents} columns={incidentCols} emptyMessage="No incidents" rowKey={(r, i) => String((r as { incident_type?: string }).incident_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Restroom Access Mix</h2>
        <DataTable rows={restrooms} columns={restroomCols} emptyMessage="No data" rowKey={(r, i) => String((r as { restroom_access?: string }).restroom_access ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Incidents (P1 first)</h2>
        <DataTable rows={opens} columns={openCols} emptyMessage="No open incidents" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
