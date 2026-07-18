import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { attendance_verdict: string; engineers: number; pct: number };
type RegionRow = {
  region: string;
  total_records: number;
  compliant: number;
  needs_review: number;
  breach: number;
  total_geofence_mismatch: number;
  total_manual_override: number;
  avg_utilization_pct: number;
};
type MatrixRow = {
  region: string;
  period_month: string;
  records: number;
  compliant: number;
  avg_utilization_pct: number;
  total_late_checkin: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  compliant: number;
  breach: number;
  geofence_mismatch: number;
  manual_override: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ImpactRow = {
  hr_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  period_month: string;
  attendance_verdict: string;
  integrity_flag: string;
  billable_utilization_pct: number | null;
  geofence_mismatch_count: number;
  manual_override_count: number;
  missing_checkout_count: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3276_attendance_verdict_rollup'),
    supabase.rpc('founder_r3276_region_scorecard'),
    supabase.rpc('founder_r3276_region_period_matrix'),
    supabase.rpc('founder_r3276_period_trend'),
    supabase.rpc('founder_r3276_capa_status_board'),
    supabase.rpc('founder_r3276_root_cause_pareto'),
    supabase.rpc('founder_r3276_hr_impact_digest'),
    supabase.rpc('founder_r3276_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'attendance_verdict', header: 'Verdict' },
    { key: 'engineers', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'needs_review', header: 'Needs Review' },
    { key: 'breach', header: 'Breach / Escalated' },
    { key: 'total_geofence_mismatch', header: 'Geofence Mismatch' },
    { key: 'total_manual_override', header: 'Manual Override' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'period_month', header: 'Period' },
    { key: 'records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_late_checkin', header: 'Late Check-ins' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'breach', header: 'Breach / Escalated' },
    { key: 'geofence_mismatch', header: 'Geofence Mismatch' },
    { key: 'manual_override', header: 'Manual Override' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'hr_impact', header: 'HR Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'period_month', header: 'Period' },
    { key: 'attendance_verdict', header: 'Verdict' },
    { key: 'integrity_flag', header: 'Integrity Flag' },
    { key: 'billable_utilization_pct', header: 'Util %' },
    { key: 'geofence_mismatch_count', header: 'Geofence' },
    { key: 'manual_override_count', header: 'Overrides' },
    { key: 'missing_checkout_count', header: 'Missing Checkout' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Attendance &mdash; Biometric/GPS Check-in &amp; Timesheet-Integrity Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer HR log — region &times; period-month &times; attendance &times; biometric/GPS
        check-in &times; timesheet vs billable hours &times; geofence mismatch &times; manual-override
        count &times; integrity flag &amp; CAPA closure. Founder-gated view: attendance verdicts,
        region scorecards, root-cause pareto, and HR-impact digest across payroll &amp; disciplinary
        surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Attendance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No attendance records logged yet."
          rowKey={(r, i) => String(r.attendance_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region attendance scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Region &times; period matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by region and period."
          rowKey={(r, i) => `${r.region}-${r.period_month}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Period-month trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. HR impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No HR-impact rollups."
          rowKey={(r, i) => String(r.hr_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk attendance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk records."
          rowKey={(r, i) => `${r.engineer_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
