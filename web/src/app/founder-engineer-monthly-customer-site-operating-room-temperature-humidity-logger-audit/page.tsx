import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { metric: string; value: string };
type Audit = {
  id: string;
  audit_code: string;
  customer_site: string;
  hospital_city: string;
  operating_room_label: string;
  engineer_name: string;
  audit_month: string;
  audit_status: string;
  logger_make: string;
  logger_serial: string;
  calibration_due_date: string | null;
  last_calibration_date: string | null;
  visit_outcome: string;
  compliance_score_pct: number;
  temp_range_compliant: boolean;
  humidity_range_compliant: boolean;
  nabh_clause_ref: string;
  followup_required: boolean;
  followup_due_date: string | null;
  notes: string | null;
};
type Excursion = {
  audit_code: string;
  customer_site: string;
  reading_timestamp: string;
  temperature_celsius: number;
  humidity_percent: number;
  excursion_minutes: number;
};
type ByEngineer = { engineer_name: string; audit_count: number; avg_score: number; fails: number };
type CalDue = {
  audit_code: string;
  customer_site: string;
  logger_make: string;
  logger_serial: string;
  calibration_due_date: string;
  days_until_due: number;
};
type Followup = {
  audit_code: string;
  customer_site: string;
  visit_outcome: string;
  followup_due_date: string | null;
  notes: string | null;
};
type MakeRow = { logger_make: string; units: number; avg_compliance: number; sensor_errors: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [overview, audits, excursions, byEngineer, calDue, followups, makeBreakdown] = await Promise.all([
    supabase.rpc('founder_or_audit_overview_r3010'),
    supabase.rpc('founder_or_audit_list_r3010'),
    supabase.rpc('founder_or_audit_critical_excursions_r3010'),
    supabase.rpc('founder_or_audit_by_engineer_r3010'),
    supabase.rpc('founder_or_audit_calibration_due_r3010'),
    supabase.rpc('founder_or_audit_followups_r3010'),
    supabase.rpc('founder_or_audit_logger_make_breakdown_r3010'),
  ]);

  const overviewRows: Overview[] = (overview.data ?? []) as Overview[];
  const auditRows: Audit[] = (audits.data ?? []) as Audit[];
  const excursionRows: Excursion[] = (excursions.data ?? []) as Excursion[];
  const engineerRows: ByEngineer[] = (byEngineer.data ?? []) as ByEngineer[];
  const calDueRows: CalDue[] = (calDue.data ?? []) as CalDue[];
  const followupRows: Followup[] = (followups.data ?? []) as Followup[];
  const makeRows: MakeRow[] = (makeBreakdown.data ?? []) as MakeRow[];

  const overviewCols: Column<Overview>[] = [
    { header: 'Metric', accessor: (r) => r.metric },
    { header: 'Value', accessor: (r) => r.value },
  ];
  const auditCols: Column<Audit>[] = [
    { header: 'Code', accessor: (r) => r.audit_code },
    { header: 'Site', accessor: (r) => r.customer_site },
    { header: 'OR', accessor: (r) => r.operating_room_label },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Status', accessor: (r) => r.audit_status },
    { header: 'Logger', accessor: (r) => `${r.logger_make} / ${r.logger_serial}` },
    { header: 'Outcome', accessor: (r) => r.visit_outcome },
    { header: 'Score %', accessor: (r) => r.compliance_score_pct.toString() },
    { header: 'Temp OK', accessor: (r) => (r.temp_range_compliant ? 'yes' : 'no') },
    { header: 'RH OK', accessor: (r) => (r.humidity_range_compliant ? 'yes' : 'no') },
    { header: 'Followup', accessor: (r) => (r.followup_required ? 'yes' : 'no') },
  ];
  const excursionCols: Column<Excursion>[] = [
    { header: 'Code', accessor: (r) => r.audit_code },
    { header: 'Site', accessor: (r) => r.customer_site },
    { header: 'When', accessor: (r) => r.reading_timestamp },
    { header: 'Temp C', accessor: (r) => r.temperature_celsius.toString() },
    { header: 'RH %', accessor: (r) => r.humidity_percent.toString() },
    { header: 'Excursion min', accessor: (r) => r.excursion_minutes.toString() },
  ];
  const engineerCols: Column<ByEngineer>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audit_count.toString() },
    { header: 'Avg Score', accessor: (r) => r.avg_score.toString() },
    { header: 'Fails', accessor: (r) => r.fails.toString() },
  ];
  const calCols: Column<CalDue>[] = [
    { header: 'Code', accessor: (r) => r.audit_code },
    { header: 'Site', accessor: (r) => r.customer_site },
    { header: 'Make', accessor: (r) => r.logger_make },
    { header: 'Serial', accessor: (r) => r.logger_serial },
    { header: 'Due', accessor: (r) => r.calibration_due_date },
    { header: 'Days left', accessor: (r) => r.days_until_due.toString() },
  ];
  const followupCols: Column<Followup>[] = [
    { header: 'Code', accessor: (r) => r.audit_code },
    { header: 'Site', accessor: (r) => r.customer_site },
    { header: 'Outcome', accessor: (r) => r.visit_outcome },
    { header: 'Due', accessor: (r) => r.followup_due_date ?? '-' },
    { header: 'Notes', accessor: (r) => r.notes ?? '-' },
  ];
  const makeCols: Column<MakeRow>[] = [
    { header: 'Make', accessor: (r) => r.logger_make },
    { header: 'Units', accessor: (r) => r.units.toString() },
    { header: 'Avg Compliance', accessor: (r) => r.avg_compliance.toString() },
    { header: 'Sensor Errors', accessor: (r) => r.sensor_errors.toString() },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">OR Temperature & Humidity Logger Audit</h1>
        <p className="text-sm text-gray-500">Monthly engineer site audits — NABH FMS compliance for OR environmental controls.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Overview</h2>
        <DataTable rows={overviewRows} columns={overviewCols} emptyMessage="No overview data" rowKey={(r, i) => String(r.metric ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">All Audits (lowest compliance first)</h2>
        <DataTable rows={auditRows} columns={auditCols} emptyMessage="No audits scheduled" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Critical Excursions (temp/RH out of spec)</h2>
        <DataTable rows={excursionRows} columns={excursionCols} emptyMessage="No critical excursions" rowKey={(r, i) => String(r.audit_code + i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">By Engineer (worst avg first)</h2>
        <DataTable rows={engineerRows} columns={engineerCols} emptyMessage="No engineer data" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Calibration Due</h2>
        <DataTable rows={calDueRows} columns={calCols} emptyMessage="No calibration records" rowKey={(r, i) => String(r.audit_code + i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Open Followups</h2>
        <DataTable rows={followupRows} columns={followupCols} emptyMessage="No open followups" rowKey={(r, i) => String(r.audit_code + i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Logger Make Breakdown</h2>
        <DataTable rows={makeRows} columns={makeCols} emptyMessage="No logger data" rowKey={(r, i) => String(r.logger_make ?? i)} />
      </section>
    </div>
  );
}
