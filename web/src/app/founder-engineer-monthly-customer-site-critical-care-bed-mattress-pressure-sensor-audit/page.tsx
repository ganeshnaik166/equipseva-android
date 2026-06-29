import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type AuditRow = {
  id: string;
  audit_month: string;
  bed_asset_tag: string;
  ward_name: string;
  bed_model: string;
  mattress_type: string;
  sensor_count: number;
  audit_status: string;
  overall_pressure_kpa: number;
  patient_present: boolean;
};

type StatusRow = { audit_status: string; n: number; avg_pressure: number };
type WardRow = { ward_name: string; n_audits: number; n_failed: number; n_passed: number; avg_pressure: number };
type MattressRow = { mattress_type: string; n: number; fail_rate: number };
type IssueRow = {
  reading_id: string;
  bed_asset_tag: string;
  ward_name: string;
  sensor_index: number;
  zone: string;
  measured_kpa: number;
  expected_min_kpa: number;
  expected_max_kpa: number;
  result: string;
  remediation: string | null;
};
type ZoneRow = { zone: string; n_readings: number; n_failures: number; fail_rate: number };
type TrendRow = { audit_month: string; n: number; n_failed: number; n_passed: number; avg_pressure: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, statusRes, wardRes, mattressRes, issuesRes, zoneRes, trendRes] = await Promise.all([
    sb.rpc('list_bed_audits_r3050'),
    sb.rpc('audit_status_breakdown_r3050'),
    sb.rpc('ward_summary_r3050'),
    sb.rpc('mattress_type_rollup_r3050'),
    sb.rpc('sensor_reading_issues_r3050'),
    sb.rpc('zone_failure_heatmap_r3050'),
    sb.rpc('monthly_audit_trend_r3050'),
  ]);

  const audits: AuditRow[] = (auditsRes.data as AuditRow[] | null) ?? [];
  const status: StatusRow[] = (statusRes.data as StatusRow[] | null) ?? [];
  const wards: WardRow[] = (wardRes.data as WardRow[] | null) ?? [];
  const mattress: MattressRow[] = (mattressRes.data as MattressRow[] | null) ?? [];
  const issues: IssueRow[] = (issuesRes.data as IssueRow[] | null) ?? [];
  const zones: ZoneRow[] = (zoneRes.data as ZoneRow[] | null) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];

  const auditCols: Column<AuditRow>[] = [
    { key: 'audit_month', header: 'Month', render: (r: any) => r.audit_month },
    { key: 'bed_asset_tag', header: 'Bed', render: (r: any) => r.bed_asset_tag },
    { key: 'ward_name', header: 'Ward', render: (r: any) => r.ward_name },
    { key: 'bed_model', header: 'Model', render: (r: any) => r.bed_model },
    { key: 'mattress_type', header: 'Mattress', render: (r: any) => r.mattress_type },
    { key: 'sensor_count', header: 'Sensors', render: (r: any) => r.sensor_count },
    { key: 'audit_status', header: 'Status', render: (r: any) => r.audit_status },
    { key: 'overall_pressure_kpa', header: 'Avg kPa', render: (r: any) => r.overall_pressure_kpa },
    { key: 'patient_present', header: 'Patient', render: (r: any) => (r.patient_present ? 'yes' : 'no') },
  ];

  const statusCols: Column<StatusRow>[] = [
    { key: 'audit_status', header: 'Status', render: (r: any) => r.audit_status },
    { key: 'n', header: 'Count', render: (r: any) => r.n },
    { key: 'avg_pressure', header: 'Avg kPa', render: (r: any) => r.avg_pressure },
  ];

  const wardCols: Column<WardRow>[] = [
    { key: 'ward_name', header: 'Ward', render: (r: any) => r.ward_name },
    { key: 'n_audits', header: 'Audits', render: (r: any) => r.n_audits },
    { key: 'n_failed', header: 'Failed', render: (r: any) => r.n_failed },
    { key: 'n_passed', header: 'Passed', render: (r: any) => r.n_passed },
    { key: 'avg_pressure', header: 'Avg kPa', render: (r: any) => r.avg_pressure },
  ];

  const mattressCols: Column<MattressRow>[] = [
    { key: 'mattress_type', header: 'Mattress', render: (r: any) => r.mattress_type },
    { key: 'n', header: 'Count', render: (r: any) => r.n },
    { key: 'fail_rate', header: 'Fail rate %', render: (r: any) => r.fail_rate },
  ];

  const issueCols: Column<IssueRow>[] = [
    { key: 'bed_asset_tag', header: 'Bed', render: (r: any) => r.bed_asset_tag },
    { key: 'ward_name', header: 'Ward', render: (r: any) => r.ward_name },
    { key: 'sensor_index', header: 'Sensor', render: (r: any) => r.sensor_index },
    { key: 'zone', header: 'Zone', render: (r: any) => r.zone },
    { key: 'measured_kpa', header: 'Measured kPa', render: (r: any) => r.measured_kpa },
    { key: 'expected_min_kpa', header: 'Min', render: (r: any) => r.expected_min_kpa },
    { key: 'expected_max_kpa', header: 'Max', render: (r: any) => r.expected_max_kpa },
    { key: 'result', header: 'Result', render: (r: any) => r.result },
    { key: 'remediation', header: 'Remediation', render: (r: any) => r.remediation ?? '—' },
  ];

  const zoneCols: Column<ZoneRow>[] = [
    { key: 'zone', header: 'Zone', render: (r: any) => r.zone },
    { key: 'n_readings', header: 'Readings', render: (r: any) => r.n_readings },
    { key: 'n_failures', header: 'Failures', render: (r: any) => r.n_failures },
    { key: 'fail_rate', header: 'Fail rate %', render: (r: any) => r.fail_rate },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_month', header: 'Month', render: (r: any) => r.audit_month },
    { key: 'n', header: 'Audits', render: (r: any) => r.n },
    { key: 'n_failed', header: 'Failed', render: (r: any) => r.n_failed },
    { key: 'n_passed', header: 'Passed', render: (r: any) => r.n_passed },
    { key: 'avg_pressure', header: 'Avg kPa', render: (r: any) => r.avg_pressure },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Monthly Bed Mattress Pressure-Sensor Audit
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Critical-care bed mattress + pressure-sensor audits. Pressure measured in kPa per zone; readings flagged when measured value falls outside expected min/max range.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All audits ({audits.length})</h2>
        <DataTable rows={audits} columns={auditCols} emptyMessage="No audits yet." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status breakdown ({status.length})</h2>
        <DataTable rows={status} columns={statusCols} emptyMessage="No data." rowKey={(r: any, i: number) => String(r.audit_status ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Ward summary ({wards.length})</h2>
        <DataTable rows={wards} columns={wardCols} emptyMessage="No data." rowKey={(r: any, i: number) => String(r.ward_name ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Mattress type rollup ({mattress.length})</h2>
        <DataTable rows={mattress} columns={mattressCols} emptyMessage="No data." rowKey={(r: any, i: number) => String(r.mattress_type ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Sensor reading issues ({issues.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Readings where measured kPa is outside the expected min/max band, or sensor is dead/noisy.
        </p>
        <DataTable rows={issues} columns={issueCols} emptyMessage="No issues." rowKey={(r: any, i: number) => String(r.reading_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Zone failure heatmap ({zones.length})</h2>
        <DataTable rows={zones} columns={zoneCols} emptyMessage="No data." rowKey={(r: any, i: number) => String(r.zone ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly trend ({trend.length})</h2>
        <DataTable rows={trend} columns={trendCols} emptyMessage="No data." rowKey={(r: any, i: number) => String(r.audit_month ?? i)} />
      </section>
    </div>
  );
}