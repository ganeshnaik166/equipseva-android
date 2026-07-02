import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type HospitalRow = { hospital_name: string; checks_total: number; calibrated_count: number; drift_count: number; failed_count: number; avg_close_seconds: number; open_followups: number };
type CalibRow = { sensor_calibration_status: string; doors: number; share_pct: number };
type SlowRow = { hospital_name: string; door_location: string; door_model: string; auto_close_seconds: number; target_seconds: number; gap_seconds: number; follow_up_status: string };
type EngRow = { engineer_name: string; doors_checked: number; calibrated_pct: number; avg_close_seconds: number };
type IncRow = { incident_type: string; total: number; critical_count: number; avg_resolution_min: number; total_ot_disruption: number };
type EscRow = { hospital_name: string; incident_type: string; severity: string; reported_by: string; ot_disruption_minutes: number; resolution_status: string };
type SealRow = { seal_integrity: string; doors: number; avg_pressure_psi: number; low_pressure_count: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [a, b, c, d, e, f, g] = await Promise.all([
    supabase.rpc('rpc_r3004_summary_by_hospital'),
    supabase.rpc('rpc_r3004_calibration_breakdown'),
    supabase.rpc('rpc_r3004_slow_close_doors'),
    supabase.rpc('rpc_r3004_engineer_coverage'),
    supabase.rpc('rpc_r3004_incident_summary'),
    supabase.rpc('rpc_r3004_open_escalations'),
    supabase.rpc('rpc_r3004_seal_pressure_health'),
  ]);

  const hospitalRows: HospitalRow[] = (a.data ?? []) as HospitalRow[];
  const calibRows: CalibRow[] = (b.data ?? []) as CalibRow[];
  const slowRows: SlowRow[] = (c.data ?? []) as SlowRow[];
  const engRows: EngRow[] = (d.data ?? []) as EngRow[];
  const incRows: IncRow[] = (e.data ?? []) as IncRow[];
  const escRows: EscRow[] = (f.data ?? []) as EscRow[];
  const sealRows: SealRow[] = (g.data ?? []) as SealRow[];

  const hospitalCols: Column<HospitalRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Checks', accessor: (r) => r.checks_total },
    { header: 'Calibrated', accessor: (r) => r.calibrated_count },
    { header: 'Drift', accessor: (r) => r.drift_count },
    { header: 'Failed', accessor: (r) => r.failed_count },
    { header: 'Avg close (s)', accessor: (r) => r.avg_close_seconds },
    { header: 'Open follow-ups', accessor: (r) => r.open_followups },
  ];

  const calibCols: Column<CalibRow>[] = [
    { header: 'Calibration status', accessor: (r) => r.sensor_calibration_status },
    { header: 'Doors', accessor: (r) => r.doors },
    { header: 'Share %', accessor: (r) => r.share_pct },
  ];

  const slowCols: Column<SlowRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Door', accessor: (r) => r.door_location },
    { header: 'Model', accessor: (r) => r.door_model },
    { header: 'Close (s)', accessor: (r) => r.auto_close_seconds },
    { header: 'Target (s)', accessor: (r) => r.target_seconds },
    { header: 'Gap (s)', accessor: (r) => r.gap_seconds },
    { header: 'Follow-up', accessor: (r) => r.follow_up_status },
  ];

  const engCols: Column<EngRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Doors checked', accessor: (r) => r.doors_checked },
    { header: 'Calibrated %', accessor: (r) => r.calibrated_pct },
    { header: 'Avg close (s)', accessor: (r) => r.avg_close_seconds },
  ];

  const incCols: Column<IncRow>[] = [
    { header: 'Incident type', accessor: (r) => r.incident_type },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Critical', accessor: (r) => r.critical_count },
    { header: 'Avg resolution (min)', accessor: (r) => r.avg_resolution_min },
    { header: 'OT disruption (min)', accessor: (r) => r.total_ot_disruption },
  ];

  const escCols: Column<EscRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Incident', accessor: (r) => r.incident_type },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Reported by', accessor: (r) => r.reported_by },
    { header: 'OT disruption (min)', accessor: (r) => r.ot_disruption_minutes },
    { header: 'Status', accessor: (r) => r.resolution_status },
  ];

  const sealCols: Column<SealRow>[] = [
    { header: 'Seal integrity', accessor: (r) => r.seal_integrity },
    { header: 'Doors', accessor: (r) => r.doors },
    { header: 'Avg pressure (psi)', accessor: (r) => r.avg_pressure_psi },
    { header: 'Low pressure', accessor: (r) => r.low_pressure_count },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Pneumatic Door Auto-Close &amp; Sensor Calibration Tracker</h1>
        <p className="text-sm text-gray-600">Monthly customer-engineer hospital pneumatic door audit — close timing &gt;= target, sensor calibration drift, seal integrity, incident escalations.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospital summary</h2>
        <DataTable<HospitalRow> rows={hospitalRows} columns={hospitalCols} emptyMessage="No hospital data" rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Calibration breakdown</h2>
        <DataTable<CalibRow> rows={calibRows} columns={calibCols} emptyMessage="No calibration data" rowKey={(r, i) => String(r.sensor_calibration_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Slow-close doors (close &gt; target)</h2>
        <DataTable<SlowRow> rows={slowRows} columns={slowCols} emptyMessage="All doors within target" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer coverage</h2>
        <DataTable<EngRow> rows={engRows} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Incident summary</h2>
        <DataTable<IncRow> rows={incRows} columns={incCols} emptyMessage="No incidents" rowKey={(r, i) => String(r.incident_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open escalations</h2>
        <DataTable<EscRow> rows={escRows} columns={escCols} emptyMessage="No open escalations" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Seal & pressure health</h2>
        <DataTable<SealRow> rows={sealRows} columns={sealCols} emptyMessage="No seal data" rowKey={(r, i) => String(r.seal_integrity ?? i)} />
      </section>
    </div>
  );
}
