import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { metric: string; value: number; detail: string };
type ByHospital = { hospital_name: string; devices: number; avg_uptime: number; total_incidents: number; total_sessions: number };
type ByEngineer = { engineer: string; devices: number; avg_uptime: number; incidents_handled: number; avg_mttr: number };
type OpenIncident = { device_serial: string; hospital_name: string; severity: string; category: string; engineer: string; opened_at: string; patient_impact: number };
type Category = { category: string; count_30d: number; avg_resolution_min: number; patient_impact_total: number };
type Battery = { device_serial: string; hospital_name: string; battery_health_pct: number; os_version: string; status: string };
type TypeBreak = { device_type: string; devices: number; avg_uptime: number; total_sessions: number; avg_battery: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ov, hosp, eng, opn, cat, bat, typ] = await Promise.all([
    supabase.rpc('kiosk_r3016_fleet_overview'),
    supabase.rpc('kiosk_r3016_by_hospital'),
    supabase.rpc('kiosk_r3016_by_engineer'),
    supabase.rpc('kiosk_r3016_open_incidents'),
    supabase.rpc('kiosk_r3016_incident_categories'),
    supabase.rpc('kiosk_r3016_battery_risk'),
    supabase.rpc('kiosk_r3016_device_type_breakdown'),
  ]);

  const overview = (ov.data ?? []) as Overview[];
  const byHospital = (hosp.data ?? []) as ByHospital[];
  const byEngineer = (eng.data ?? []) as ByEngineer[];
  const openInc = (opn.data ?? []) as OpenIncident[];
  const cats = (cat.data ?? []) as Category[];
  const battery = (bat.data ?? []) as Battery[];
  const typeBreak = (typ.data ?? []) as TypeBreak[];

  const overviewCols: Column<Overview>[] = [
    { header: 'Metric', accessor: (r) => r.metric },
    { header: 'Value', accessor: (r) => r.value },
    { header: 'Detail', accessor: (r) => r.detail },
  ];
  const hospCols: Column<ByHospital>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Devices', accessor: (r) => r.devices },
    { header: 'Avg Uptime %', accessor: (r) => r.avg_uptime },
    { header: 'Incidents 30d', accessor: (r) => r.total_incidents },
    { header: 'Sessions 30d', accessor: (r) => r.total_sessions },
  ];
  const engCols: Column<ByEngineer>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer },
    { header: 'Devices', accessor: (r) => r.devices },
    { header: 'Avg Uptime %', accessor: (r) => r.avg_uptime },
    { header: 'Incidents', accessor: (r) => r.incidents_handled },
    { header: 'Avg MTTR (min)', accessor: (r) => r.avg_mttr },
  ];
  const opnCols: Column<OpenIncident>[] = [
    { header: 'Device', accessor: (r) => r.device_serial },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Severity', accessor: (r) => r.severity.toUpperCase() },
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Engineer', accessor: (r) => r.engineer },
    { header: 'Opened', accessor: (r) => new Date(r.opened_at).toLocaleString() },
    { header: 'Patient Impact', accessor: (r) => r.patient_impact },
  ];
  const catCols: Column<Category>[] = [
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Count 30d', accessor: (r) => r.count_30d },
    { header: 'Avg Resolution (min)', accessor: (r) => r.avg_resolution_min },
    { header: 'Patient Impact Total', accessor: (r) => r.patient_impact_total },
  ];
  const batCols: Column<Battery>[] = [
    { header: 'Device', accessor: (r) => r.device_serial },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Battery %', accessor: (r) => r.battery_health_pct },
    { header: 'OS', accessor: (r) => r.os_version },
    { header: 'Status', accessor: (r) => r.status },
  ];
  const typeCols: Column<TypeBreak>[] = [
    { header: 'Device Type', accessor: (r) => r.device_type },
    { header: 'Devices', accessor: (r) => r.devices },
    { header: 'Avg Uptime %', accessor: (r) => r.avg_uptime },
    { header: 'Sessions 30d', accessor: (r) => r.total_sessions },
    { header: 'Avg Battery %', accessor: (r) => r.avg_battery },
  ];

  return (
    <main className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Kiosk Reliability Tracker</h1>
        <p className="text-sm text-gray-600">Patient-tablet & bedside-terminal fleet health across hospitals — monthly engineer accountability view (r3016).</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Fleet Overview</h2>
        <DataTable rows={overview} columns={overviewCols} emptyMessage="No overview." rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Hospital (worst uptime first)</h2>
        <DataTable rows={byHospital} columns={hospCols} emptyMessage="No hospital data." rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Engineer</h2>
        <DataTable rows={byEngineer} columns={engCols} emptyMessage="No engineer data." rowKey={(r, i) => String(r.engineer ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Incidents (P0/P1 first)</h2>
        <DataTable rows={openInc} columns={opnCols} emptyMessage="No open incidents." rowKey={(r, i) => String(r.device_serial + i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Incident Categories (30d)</h2>
        <DataTable rows={cats} columns={catCols} emptyMessage="No category data." rowKey={(r, i) => String(r.category ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Battery Risk (&lt; 75%)</h2>
        <DataTable rows={battery} columns={batCols} emptyMessage="All batteries healthy." rowKey={(r, i) => String(r.device_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Device Type Breakdown</h2>
        <DataTable rows={typeBreak} columns={typeCols} emptyMessage="No type data." rowKey={(r, i) => String(r.device_type ?? i)} />
      </section>
    </main>
  );
}
