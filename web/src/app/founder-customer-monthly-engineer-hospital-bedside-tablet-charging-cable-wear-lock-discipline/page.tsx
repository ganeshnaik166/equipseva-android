import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type WearRollup = { hospital_name: string; inspections: number; avg_wear: number; urgent_replaces: number; escalations: number };
type CableMix = { cable_type: string; total: number; fail_count: number; fail_pct: number | null };
type EngineerQuality = { engineer_name: string; visits: number; replaced_count: number; avg_torque: number | null };
type GradeDist = { discipline_grade: string; hospitals: number; avg_lock_engaged: number; theft_attempts: number };
type RedAlert = { hospital_name: string; ward_code: string; bedside_tablet_serial: string; unauthorized_unplug_events: number; theft_attempts: number; remediation_due_date: string | null };
type JacketRow = { jacket_condition: string; count_n: number; avg_connector_play: number };
type VisitCompliance = { hospital_name: string; tablets: number; visits_done: number; compliance_pct: number | null };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [wear, mix, eng, grade, red, jacket, visit] = await Promise.all([
    sb.rpc('rpc_r3072_hospital_wear_rollup'),
    sb.rpc('rpc_r3072_cable_type_failure_mix'),
    sb.rpc('rpc_r3072_engineer_inspection_quality'),
    sb.rpc('rpc_r3072_lock_discipline_grade_distribution'),
    sb.rpc('rpc_r3072_no_kit_red_alerts'),
    sb.rpc('rpc_r3072_jacket_condition_heatmap'),
    sb.rpc('rpc_r3072_monthly_visit_compliance'),
  ]);

  const wearRows: WearRollup[] = wear.data ?? [];
  const mixRows: CableMix[] = mix.data ?? [];
  const engRows: EngineerQuality[] = eng.data ?? [];
  const gradeRows: GradeDist[] = grade.data ?? [];
  const redRows: RedAlert[] = red.data ?? [];
  const jacketRows: JacketRow[] = jacket.data ?? [];
  const visitRows: VisitCompliance[] = visit.data ?? [];

  const wearCols: Column<WearRollup>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Inspections', accessor: (r) => r.inspections },
    { header: 'Avg Wear %', accessor: (r) => r.avg_wear },
    { header: 'Urgent Replaces', accessor: (r) => r.urgent_replaces },
    { header: 'Escalations', accessor: (r) => r.escalations },
  ];

  const mixCols: Column<CableMix>[] = [
    { header: 'Cable Type', accessor: (r) => r.cable_type },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Fail Count', accessor: (r) => r.fail_count },
    { header: 'Fail %', accessor: (r) => r.fail_pct ?? '—' },
  ];

  const engCols: Column<EngineerQuality>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Replaced', accessor: (r) => r.replaced_count },
    { header: 'Avg Torque Nm', accessor: (r) => r.avg_torque ?? '—' },
  ];

  const gradeCols: Column<GradeDist>[] = [
    { header: 'Grade', accessor: (r) => r.discipline_grade },
    { header: 'Hospitals', accessor: (r) => r.hospitals },
    { header: 'Avg Lock Engaged %', accessor: (r) => r.avg_lock_engaged },
    { header: 'Theft Attempts', accessor: (r) => r.theft_attempts },
  ];

  const redCols: Column<RedAlert>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Ward', accessor: (r) => r.ward_code },
    { header: 'Tablet', accessor: (r) => r.bedside_tablet_serial },
    { header: 'Unplugs', accessor: (r) => r.unauthorized_unplug_events },
    { header: 'Theft Attempts', accessor: (r) => r.theft_attempts },
    { header: 'Remediation Due', accessor: (r) => r.remediation_due_date ?? '—' },
  ];

  const jacketCols: Column<JacketRow>[] = [
    { header: 'Jacket Condition', accessor: (r) => r.jacket_condition },
    { header: 'Count', accessor: (r) => r.count_n },
    { header: 'Avg Connector Play mm', accessor: (r) => r.avg_connector_play },
  ];

  const visitCols: Column<VisitCompliance>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Tablets', accessor: (r) => r.tablets },
    { header: 'Visits Done', accessor: (r) => r.visits_done },
    { header: 'Compliance %', accessor: (r) => r.compliance_pct ?? '—' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Bedside Tablet Charging Cable Wear & Lock Discipline</h1>
        <p className="text-sm text-gray-600">Monthly engineer visits across hospital wards — cable wear, lock kit engagement, theft & unplug events.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Hospital Wear Rollup</h2>
        <DataTable rows={wearRows} columns={wearCols} emptyMessage="No inspections" rowKey={(r, i) => String((r as { hospital_name?: string }).hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Cable Type Failure Mix</h2>
        <DataTable rows={mixRows} columns={mixCols} emptyMessage="No cable data" rowKey={(r, i) => String((r as { cable_type?: string }).cable_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Engineer Inspection Quality</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineer visits" rowKey={(r, i) => String((r as { engineer_name?: string }).engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Lock Discipline Grade Distribution</h2>
        <DataTable rows={gradeRows} columns={gradeCols} emptyMessage="No grade data" rowKey={(r, i) => String((r as { discipline_grade?: string }).discipline_grade ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">No-Kit Red Alerts</h2>
        <DataTable rows={redRows} columns={redCols} emptyMessage="No red alerts" rowKey={(r, i) => String((r as { bedside_tablet_serial?: string }).bedside_tablet_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Jacket Condition Heatmap</h2>
        <DataTable rows={jacketRows} columns={jacketCols} emptyMessage="No jacket data" rowKey={(r, i) => String((r as { jacket_condition?: string }).jacket_condition ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Monthly Visit Compliance</h2>
        <DataTable rows={visitRows} columns={visitCols} emptyMessage="No visits" rowKey={(r, i) => String((r as { hospital_name?: string }).hospital_name ?? i)} />
      </section>
    </div>
  );
}
