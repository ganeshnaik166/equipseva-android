import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type IsoRow = { measured_iso_class: string; audits: number; fail_count: number };
type CityRow = { city: string; audits: number; passed: number; failed: number; pass_rate_pct: number | null };
type EngineerRow = { engineer_name: string; audits: number; pass_count: number; fail_count: number; marginal_count: number };
type FailingRow = { hospital_name: string; ot_room_label: string; measured_iso_class: string; target_iso_class: string; particles_05um_per_m3: number; hepa_filter_age_months: number | null };
type HepaRow = { bucket: string; ots: number; fail_count: number };
type StatusRow = { status: string; actions: number; total_cost_rupees: number };
type CritRow = { action_type: string; severity: string; assigned_engineer: string; scheduled_date: string | null; remarks: string | null };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [iso, city, eng, fail, hepa, status, crit] = await Promise.all([
    sb.rpc('r3074_iso_class_distribution'),
    sb.rpc('r3074_city_pass_rate'),
    sb.rpc('r3074_engineer_scorecard'),
    sb.rpc('r3074_failing_ots'),
    sb.rpc('r3074_hepa_age_buckets'),
    sb.rpc('r3074_remediation_status_summary'),
    sb.rpc('r3074_critical_open_actions'),
  ]);

  const isoRows: IsoRow[] = (iso.data as IsoRow[]) ?? [];
  const cityRows: CityRow[] = (city.data as CityRow[]) ?? [];
  const engRows: EngineerRow[] = (eng.data as EngineerRow[]) ?? [];
  const failRows: FailingRow[] = (fail.data as FailingRow[]) ?? [];
  const hepaRows: HepaRow[] = (hepa.data as HepaRow[]) ?? [];
  const statusRows: StatusRow[] = (status.data as StatusRow[]) ?? [];
  const critRows: CritRow[] = (crit.data as CritRow[]) ?? [];

  const isoCols: Column<IsoRow>[] = [
    { header: 'ISO Class', accessor: (r) => r.measured_iso_class },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Fails', accessor: (r) => r.fail_count },
  ];

  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Passed', accessor: (r) => r.passed },
    { header: 'Failed', accessor: (r) => r.failed },
    { header: 'Pass %', accessor: (r) => r.pass_rate_pct ?? '-' },
  ];

  const engCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Pass', accessor: (r) => r.pass_count },
    { header: 'Fail', accessor: (r) => r.fail_count },
    { header: 'Marginal', accessor: (r) => r.marginal_count },
  ];

  const failCols: Column<FailingRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'OT', accessor: (r) => r.ot_room_label },
    { header: 'Measured', accessor: (r) => r.measured_iso_class },
    { header: 'Target', accessor: (r) => r.target_iso_class },
    { header: '0.5um/m3', accessor: (r) => r.particles_05um_per_m3 },
    { header: 'HEPA age (mo)', accessor: (r) => r.hepa_filter_age_months ?? '-' },
  ];

  const hepaCols: Column<HepaRow>[] = [
    { header: 'HEPA Age Bucket', accessor: (r) => r.bucket },
    { header: 'OTs', accessor: (r) => r.ots },
    { header: 'Fails', accessor: (r) => r.fail_count },
  ];

  const statusCols: Column<StatusRow>[] = [
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Actions', accessor: (r) => r.actions },
    { header: 'Total Cost (Rs)', accessor: (r) => r.total_cost_rupees },
  ];

  const critCols: Column<CritRow>[] = [
    { header: 'Action', accessor: (r) => r.action_type },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Engineer', accessor: (r) => r.assigned_engineer },
    { header: 'Scheduled', accessor: (r) => r.scheduled_date ?? '-' },
    { header: 'Remarks', accessor: (r) => r.remarks ?? '-' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly OT Air Particle Count & ISO-Class Audit</h1>
        <p className="text-sm text-gray-500">Round r3074 — particle counts & remediation across customer OTs</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">ISO Class Distribution</h2>
        <DataTable rows={isoRows} columns={isoCols} emptyMessage="No audits" rowKey={(r, i) => String((r as { measured_iso_class?: string }).measured_iso_class ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Pass Rate</h2>
        <DataTable rows={cityRows} columns={cityCols} emptyMessage="No cities" rowKey={(r, i) => String((r as { city?: string }).city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Scorecard</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as { engineer_name?: string }).engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failing & Retest OTs</h2>
        <DataTable rows={failRows} columns={failCols} emptyMessage="All OTs passing" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">HEPA Filter Age Buckets</h2>
        <DataTable rows={hepaRows} columns={hepaCols} emptyMessage="No data" rowKey={(r, i) => String((r as { bucket?: string }).bucket ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Remediation Status Summary</h2>
        <DataTable rows={statusRows} columns={statusCols} emptyMessage="No actions" rowKey={(r, i) => String((r as { status?: string }).status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical Open Actions</h2>
        <DataTable rows={critRows} columns={critCols} emptyMessage="No critical open actions" rowKey={(r, i) => String(i)} />
      </section>
    </main>
  );
}
