import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { report_status: string; reports: number; pct: number };
type EngineerRow = {
  engineer_name: string;
  total_reports: number;
  submitted: number;
  approved: number;
  returned: number;
  pending: number;
  sla_breaches: number;
  avg_submission_lag_hours: number | null;
  avg_approval_lag_hours: number | null;
  on_time_pct: number;
};
type MatrixRow = {
  service_type: string;
  report_status: string;
  reports: number;
  sla_breaches: number;
  avg_submission_lag_hours: number | null;
};
type TrendRow = {
  submission_month: string;
  reports: number;
  avg_submission_lag_hours: number | null;
  avg_approval_lag_hours: number | null;
  sla_breaches: number;
  backlog: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_lag_impact_hours: number | null;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_lag_impact_hours: number;
  pct: number;
};
type ImpactRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_lag_impact_hours: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  report_number: string;
  service_type: string;
  job_completed_date: string;
  report_status: string;
  submission_lag_hours: number | null;
  sla_hours: number;
  sla_breached: boolean;
  backlog_flag: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    engineerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3512_report_status_rollup'),
    supabase.rpc('founder_r3512_engineer_scorecard'),
    supabase.rpc('founder_r3512_service_type_status_matrix'),
    supabase.rpc('founder_r3512_monthly_submission_lag_trend'),
    supabase.rpc('founder_r3512_capa_status_board'),
    supabase.rpc('founder_r3512_root_cause_pareto'),
    supabase.rpc('founder_r3512_lag_impact_digest'),
    supabase.rpc('founder_r3512_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const engineerRows: EngineerRow[] = (engineerRes.data as EngineerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'report_status', header: 'Report Status' },
    { key: 'reports', header: 'Reports' },
    { key: 'pct', header: 'Share %' },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_reports', header: 'Reports' },
    { key: 'submitted', header: 'Submitted' },
    { key: 'approved', header: 'Approved' },
    { key: 'returned', header: 'Returned' },
    { key: 'pending', header: 'Pending' },
    { key: 'sla_breaches', header: 'SLA Breaches' },
    { key: 'avg_submission_lag_hours', header: 'Avg Submit Lag (h)' },
    { key: 'avg_approval_lag_hours', header: 'Avg Approval Lag (h)' },
    { key: 'on_time_pct', header: 'On-time %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'service_type', header: 'Service Type' },
    { key: 'report_status', header: 'Report Status' },
    { key: 'reports', header: 'Reports' },
    { key: 'sla_breaches', header: 'SLA Breaches' },
    { key: 'avg_submission_lag_hours', header: 'Avg Submit Lag (h)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'submission_month', header: 'Month' },
    { key: 'reports', header: 'Reports' },
    { key: 'avg_submission_lag_hours', header: 'Avg Submit Lag (h)' },
    { key: 'avg_approval_lag_hours', header: 'Avg Approval Lag (h)' },
    { key: 'sla_breaches', header: 'SLA Breaches' },
    { key: 'backlog', header: 'Backlog' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_lag_impact_hours', header: 'Avg Lag Impact (h)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_lag_impact_hours', header: 'Total Lag Impact (h)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_lag_impact_hours', header: 'Total Lag Impact (h)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'report_number', header: 'Report' },
    { key: 'service_type', header: 'Type' },
    { key: 'job_completed_date', header: 'Job Done' },
    { key: 'report_status', header: 'Status' },
    { key: 'submission_lag_hours', header: 'Submit Lag (h)' },
    { key: 'sla_hours', header: 'SLA (h)' },
    { key: 'sla_breached', header: 'Breached' },
    { key: 'backlog_flag', header: 'Backlog' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Field-Service-Report Turnaround / Submission-Lag Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field service-report turnaround / submission-lag log tracking the job-done &rarr; submitted
        &rarr; approved pipeline &mdash; engineer &times; hospital &times; service type (breakdown,
        preventive, installation, calibration, AMC visit) &times; submission lag &times; approval lag
        &times; SLA hours &times; breach flag &times; report status &times; backlog &amp; CAPA closure.
        Founder-gated view: report-status distribution, engineer scorecards, service-type &times;
        status matrix, monthly submission-lag trend, root-cause pareto, and the high-risk turnaround
        queue across pending, returned &amp; SLA-breached reports.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Report-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No field-service reports logged yet."
          rowKey={(r, i) => String(r.report_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer turnaround scorecard</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Service type &times; report status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No reports by service type."
          rowKey={(r, i) => `${r.service_type}-${r.report_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly submission-lag trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.submission_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Lag-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No lag-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk turnaround queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk reports."
          rowKey={(r, i) => `${r.report_number}-${i}`}
        />
      </section>
    </main>
  );
}
