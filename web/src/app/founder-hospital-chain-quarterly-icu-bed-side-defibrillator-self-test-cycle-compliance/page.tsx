import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type ChainSummary = { chain_code: string; total_cycles: number; passed_cycles: number; failed_cycles: number; overdue_cycles: number; pass_rate_pct: number | null };
type QuarterTrend = { quarter_label: string; total_cycles: number; passed_cycles: number; failed_cycles: number; aborted_cycles: number };
type MfgHeatmap = { manufacturer: string; total: number; failed: number; aborted: number; failure_rate_pct: number | null };
type OverdueUnit = { chain_code: string; hospital_code: string; icu_ward_code: string; defib_asset_tag: string; scheduled_at: string; days_overdue: number };
type SeverityRow = { severity: string; open_count: number; resolved_count: number; total_downtime_hours: number; total_cost_rupees: number };
type RiskHospital = { chain_code: string; hospital_code: string; open_incidents: number; patients_at_risk: number; total_cost_rupees: number };
type RecurringAsset = { defib_asset_tag: string; chain_code: string; hospital_code: string; incident_count: number; distinct_kinds: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [s1, s2, s3, s4, s5, s6, s7] = await Promise.all([
    sb.rpc('fn_r3047_chain_compliance_summary'),
    sb.rpc('fn_r3047_quarter_trend'),
    sb.rpc('fn_r3047_manufacturer_failure_heatmap'),
    sb.rpc('fn_r3047_overdue_units'),
    sb.rpc('fn_r3047_incident_severity_breakdown'),
    sb.rpc('fn_r3047_top_risk_hospitals'),
    sb.rpc('fn_r3047_recurring_fault_assets'),
  ]);

  const chains = (s1.data ?? []) as ChainSummary[];
  const quarters = (s2.data ?? []) as QuarterTrend[];
  const mfgs = (s3.data ?? []) as MfgHeatmap[];
  const overdue = (s4.data ?? []) as OverdueUnit[];
  const severity = (s5.data ?? []) as SeverityRow[];
  const risk = (s6.data ?? []) as RiskHospital[];
  const recurring = (s7.data ?? []) as RecurringAsset[];

  const chainCols: Column<ChainSummary>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Total', accessor: (r) => r.total_cycles },
    { header: 'Passed', accessor: (r) => r.passed_cycles },
    { header: 'Failed', accessor: (r) => r.failed_cycles },
    { header: 'Overdue', accessor: (r) => r.overdue_cycles },
    { header: 'Pass %', accessor: (r) => (r.pass_rate_pct ?? 0) + '%' },
  ];

  const quarterCols: Column<QuarterTrend>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'Total', accessor: (r) => r.total_cycles },
    { header: 'Passed', accessor: (r) => r.passed_cycles },
    { header: 'Failed', accessor: (r) => r.failed_cycles },
    { header: 'Aborted', accessor: (r) => r.aborted_cycles },
  ];

  const mfgCols: Column<MfgHeatmap>[] = [
    { header: 'Manufacturer', accessor: (r) => r.manufacturer },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Failed', accessor: (r) => r.failed },
    { header: 'Aborted', accessor: (r) => r.aborted },
    { header: 'Failure %', accessor: (r) => (r.failure_rate_pct ?? 0) + '%' },
  ];

  const overdueCols: Column<OverdueUnit>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Hospital', accessor: (r) => r.hospital_code },
    { header: 'Ward', accessor: (r) => r.icu_ward_code },
    { header: 'Asset', accessor: (r) => r.defib_asset_tag },
    { header: 'Scheduled', accessor: (r) => new Date(r.scheduled_at).toLocaleDateString() },
    { header: 'Days Overdue', accessor: (r) => r.days_overdue },
  ];

  const sevCols: Column<SeverityRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity.toUpperCase() },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Resolved', accessor: (r) => r.resolved_count },
    { header: 'Downtime hrs', accessor: (r) => r.total_downtime_hours },
    { header: 'Cost (Rs)', accessor: (r) => r.total_cost_rupees.toLocaleString() },
  ];

  const riskCols: Column<RiskHospital>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Hospital', accessor: (r) => r.hospital_code },
    { header: 'Open Incidents', accessor: (r) => r.open_incidents },
    { header: 'Patients at Risk', accessor: (r) => r.patients_at_risk },
    { header: 'Cost (Rs)', accessor: (r) => r.total_cost_rupees.toLocaleString() },
  ];

  const recurCols: Column<RecurringAsset>[] = [
    { header: 'Asset', accessor: (r) => r.defib_asset_tag },
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Hospital', accessor: (r) => r.hospital_code },
    { header: 'Incidents', accessor: (r) => r.incident_count },
    { header: 'Distinct Fault Kinds', accessor: (r) => r.distinct_kinds },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">ICU Bed-Side Defibrillator Quarterly Self-Test Compliance</h1>
        <p className="text-sm text-gray-600 mt-1">
          Fleet-wide view of quarterly self-test cycles across hospital chains. Pass rate &gt;= 95% is target; any P0/P1 incident escalates same day.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Chain compliance summary</h2>
        <DataTable rows={chains} columns={chainCols} emptyMessage="No chains tracked yet." rowKey={(r, i) => String((r as { chain_code?: string }).chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Quarter-over-quarter trend</h2>
        <DataTable rows={quarters} columns={quarterCols} emptyMessage="No quarters with data." rowKey={(r, i) => String((r as { quarter_label?: string }).quarter_label ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Manufacturer failure heatmap</h2>
        <DataTable rows={mfgs} columns={mfgCols} emptyMessage="No manufacturer data." rowKey={(r, i) => String((r as { manufacturer?: string }).manufacturer ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Overdue units (scheduled &lt; now)</h2>
        <DataTable rows={overdue} columns={overdueCols} emptyMessage="No overdue units — fleet on schedule." rowKey={(r, i) => String((r as { defib_asset_tag?: string }).defib_asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Incident severity breakdown</h2>
        <DataTable rows={severity} columns={sevCols} emptyMessage="No incidents on file." rowKey={(r, i) => String((r as { severity?: string }).severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top risk hospitals</h2>
        <DataTable rows={risk} columns={riskCols} emptyMessage="No risk concentration detected." rowKey={(r, i) => String((r as { hospital_code?: string }).hospital_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recurring-fault assets (&gt;= 2 incidents)</h2>
        <DataTable rows={recurring} columns={recurCols} emptyMessage="No recurring-fault assets." rowKey={(r, i) => String((r as { defib_asset_tag?: string }).defib_asset_tag ?? i)} />
      </section>
    </div>
  );
}
