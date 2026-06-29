import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type FleetRow = { total_audits: number; total_stands: number; grade_a: number; grade_b: number; grade_c: number; grade_d: number; grade_f: number; avg_battery_pct: number; retire_count: number };
type WardRow = { ward_code: string; stand_count: number; avg_battery: number; fail_brakes: number; retires: number };
type EngineerRow = { engineer_name: string; audits_done: number; avg_grade_score: number; retires_flagged: number };
type CriticalRow = { stand_serial: string; ward_code: string; overall_grade: string; battery_health_pct: number; brake_lock_status: string; action_required: string; next_audit_due: string };
type TicketRow = { ticket_status: string; count_total: number; p0_count: number; total_cost: number };
type DefectRow = { defect_class: string; ticket_count: number; open_count: number; total_cost: number; avg_eta_days: number };
type BucketRow = { bucket: string; stand_count: number; action_replace: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [fleet, ward, eng, crit, tick, defect, bucket] = await Promise.all([
    supabase.rpc('rpc_r3040_fleet_summary'),
    supabase.rpc('rpc_r3040_ward_breakdown'),
    supabase.rpc('rpc_r3040_engineer_scorecard'),
    supabase.rpc('rpc_r3040_critical_units'),
    supabase.rpc('rpc_r3040_ticket_pipeline'),
    supabase.rpc('rpc_r3040_defect_class_spend'),
    supabase.rpc('rpc_r3040_battery_buckets'),
  ]);

  const fleetRows: FleetRow[] = (fleet.data as FleetRow[]) ?? [];
  const wardRows: WardRow[] = (ward.data as WardRow[]) ?? [];
  const engRows: EngineerRow[] = (eng.data as EngineerRow[]) ?? [];
  const critRows: CriticalRow[] = (crit.data as CriticalRow[]) ?? [];
  const tickRows: TicketRow[] = (tick.data as TicketRow[]) ?? [];
  const defectRows: DefectRow[] = (defect.data as DefectRow[]) ?? [];
  const bucketRows: BucketRow[] = (bucket.data as BucketRow[]) ?? [];

  const fleetCols: Column<FleetRow>[] = [
    { key: 'total_audits', header: 'Audits' },
    { key: 'total_stands', header: 'Stands' },
    { key: 'grade_a', header: 'A' },
    { key: 'grade_b', header: 'B' },
    { key: 'grade_c', header: 'C' },
    { key: 'grade_d', header: 'D' },
    { key: 'grade_f', header: 'F' },
    { key: 'avg_battery_pct', header: 'Avg Battery %' },
    { key: 'retire_count', header: 'Retire' },
  ];

  const wardCols: Column<WardRow>[] = [
    { key: 'ward_code', header: 'Ward' },
    { key: 'stand_count', header: 'Stands' },
    { key: 'avg_battery', header: 'Avg Battery %' },
    { key: 'fail_brakes', header: 'Fail Brakes' },
    { key: 'retires', header: 'Retires' },
  ];

  const engCols: Column<EngineerRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'audits_done', header: 'Audits' },
    { key: 'avg_grade_score', header: 'Avg Grade (5=A)' },
    { key: 'retires_flagged', header: 'Retires Flagged' },
  ];

  const critCols: Column<CriticalRow>[] = [
    { key: 'stand_serial', header: 'Serial' },
    { key: 'ward_code', header: 'Ward' },
    { key: 'overall_grade', header: 'Grade' },
    { key: 'battery_health_pct', header: 'Battery %' },
    { key: 'brake_lock_status', header: 'Brake' },
    { key: 'action_required', header: 'Action' },
    { key: 'next_audit_due', header: 'Next Audit' },
  ];

  const tickCols: Column<TicketRow>[] = [
    { key: 'ticket_status', header: 'Status' },
    { key: 'count_total', header: 'Count' },
    { key: 'p0_count', header: 'P0' },
    { key: 'total_cost', header: 'Total Cost (Rs)' },
  ];

  const defectCols: Column<DefectRow>[] = [
    { key: 'defect_class', header: 'Defect Class' },
    { key: 'ticket_count', header: 'Tickets' },
    { key: 'open_count', header: 'Open' },
    { key: 'total_cost', header: 'Total Cost (Rs)' },
    { key: 'avg_eta_days', header: 'Avg ETA Days' },
  ];

  const bucketCols: Column<BucketRow>[] = [
    { key: 'bucket', header: 'Battery Bucket' },
    { key: 'stand_count', header: 'Stands' },
    { key: 'action_replace', header: 'Flagged Replace' },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Smart IV Stand Battery & Brake Lock Audit (r3040)</h1>
        <p style={{ color: '#666', marginTop: 4 }}>Monthly engineer audit of smart IV stand fleet — battery health, brake lock torque, wheel swivel, alarm function.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Fleet Summary</h2>
        <DataTable rows={fleetRows} columns={fleetCols} emptyMessage="No fleet data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Ward Breakdown</h2>
        <DataTable rows={wardRows} columns={wardCols} emptyMessage="No wards" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Engineer Scorecard</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Critical Units (Grade D/F)</h2>
        <DataTable rows={critRows} columns={critCols} emptyMessage="No critical units" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Remediation Ticket Pipeline</h2>
        <DataTable rows={tickRows} columns={tickCols} emptyMessage="No tickets" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Defect Class Spend</h2>
        <DataTable rows={defectRows} columns={defectCols} emptyMessage="No defect data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Battery Health Distribution</h2>
        <DataTable rows={bucketRows} columns={bucketCols} emptyMessage="No battery data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>
    </div>
  );
}
