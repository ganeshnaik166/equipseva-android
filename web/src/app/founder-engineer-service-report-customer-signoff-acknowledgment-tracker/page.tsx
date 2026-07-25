import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { report_status: string; reports: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_reports: number;
  signed: number;
  disputed_cnt: number;
  rejected: number;
  avg_customer_rating: number | null;
  avg_signoff_lag_hours: number | null;
  signed_pct: number;
};
type MatrixRow = {
  service_type: string;
  report_status: string;
  reports: number;
  avg_customer_rating: number | null;
  avg_signoff_lag_hours: number | null;
};
type TrendRow = {
  signoff_month: string;
  reports: number;
  signed: number;
  disputed_cnt: number;
  avg_signoff_lag_hours: number | null;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number | null;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type ImpactRow = {
  service_type: string;
  reports: number;
  disputed_cnt: number;
  unsigned: number;
  avg_signoff_lag_hours: number | null;
  max_signoff_lag_hours: number | null;
};
type RiskRow = {
  engineer_name: string;
  report_number: string;
  hospital_name: string;
  service_type: string;
  report_status: string;
  signoff_method: string;
  visit_date: string;
  signoff_lag_hours: number | null;
  customer_rating: number | null;
  disputed: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3432_report_status_rollup'),
    supabase.rpc('founder_r3432_engineer_scorecard'),
    supabase.rpc('founder_r3432_service_type_status_matrix'),
    supabase.rpc('founder_r3432_monthly_signoff_trend'),
    supabase.rpc('founder_r3432_capa_status_board'),
    supabase.rpc('founder_r3432_root_cause_pareto'),
    supabase.rpc('founder_r3432_signoff_impact_digest'),
    supabase.rpc('founder_r3432_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'report_status', header: 'Report Status', render: (r) => r.report_status },
    { key: 'reports', header: 'Reports', render: (r) => r.reports },
    { key: 'pct', header: 'Share %', render: (r) => `${r.pct}%` },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'total_reports', header: 'Reports', render: (r) => r.total_reports },
    { key: 'signed', header: 'Signed', render: (r) => r.signed },
    { key: 'disputed_cnt', header: 'Disputed', render: (r) => r.disputed_cnt },
    { key: 'rejected', header: 'Rejected', render: (r) => r.rejected },
    { key: 'avg_customer_rating', header: 'Avg Rating', render: (r) => r.avg_customer_rating ?? '—' },
    { key: 'avg_signoff_lag_hours', header: 'Avg Lag (hrs)', render: (r) => r.avg_signoff_lag_hours ?? '—' },
    { key: 'signed_pct', header: 'Signed %', render: (r) => `${r.signed_pct}%` },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'service_type', header: 'Service Type', render: (r) => r.service_type },
    { key: 'report_status', header: 'Report Status', render: (r) => r.report_status },
    { key: 'reports', header: 'Reports', render: (r) => r.reports },
    { key: 'avg_customer_rating', header: 'Avg Rating', render: (r) => r.avg_customer_rating ?? '—' },
    { key: 'avg_signoff_lag_hours', header: 'Avg Lag (hrs)', render: (r) => r.avg_signoff_lag_hours ?? '—' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'signoff_month', header: 'Month', render: (r) => r.signoff_month },
    { key: 'reports', header: 'Reports', render: (r) => r.reports },
    { key: 'signed', header: 'Signed', render: (r) => r.signed },
    { key: 'disputed_cnt', header: 'Disputed', render: (r) => r.disputed_cnt },
    { key: 'avg_signoff_lag_hours', header: 'Avg Lag (hrs)', render: (r) => r.avg_signoff_lag_hours ?? '—' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status', render: (r) => r.capa_status },
    { key: 'findings', header: 'Findings', render: (r) => r.findings },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)', render: (r) => (r.avg_impact_rupees == null ? '—' : `₹${r.avg_impact_rupees}`) },
    { key: 'overdue_flag', header: 'Overdue / Escalated', render: (r) => r.overdue_flag },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause', render: (r) => r.root_cause },
    { key: 'occurrences', header: 'Occurrences', render: (r) => r.occurrences },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)', render: (r) => `₹${r.total_impact_rupees}` },
    { key: 'pct', header: 'Share %', render: (r) => `${r.pct}%` },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'service_type', header: 'Service Type', render: (r) => r.service_type },
    { key: 'reports', header: 'Reports', render: (r) => r.reports },
    { key: 'disputed_cnt', header: 'Disputed', render: (r) => r.disputed_cnt },
    { key: 'unsigned', header: 'Unsigned', render: (r) => r.unsigned },
    { key: 'avg_signoff_lag_hours', header: 'Avg Lag (hrs)', render: (r) => r.avg_signoff_lag_hours ?? '—' },
    { key: 'max_signoff_lag_hours', header: 'Max Lag (hrs)', render: (r) => r.max_signoff_lag_hours ?? '—' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'report_number', header: 'Report #', render: (r) => r.report_number },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'service_type', header: 'Service', render: (r) => r.service_type },
    { key: 'report_status', header: 'Status', render: (r) => r.report_status },
    { key: 'signoff_method', header: 'Method', render: (r) => r.signoff_method },
    { key: 'visit_date', header: 'Visit', render: (r) => r.visit_date },
    { key: 'signoff_lag_hours', header: 'Lag (hrs)', render: (r) => r.signoff_lag_hours ?? '—' },
    { key: 'customer_rating', header: 'Rating', render: (r) => r.customer_rating ?? '—' },
    { key: 'disputed', header: 'Disputed', render: (r) => (r.disputed ? 'Yes' : 'No') },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Service-Report / Job-Card Customer Sign-off &amp; Acknowledgment Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer service-report / job-card customer sign-off &amp; acknowledgment log — report
        status (draft, submitted, customer-signed, disputed, rejected) &times; engineer scorecard
        &times; service-type &times; sign-off method (digital OTP, physical signature, email ack)
        &times; sign-off lag hours &times; customer rating &times; dispute flag &amp; CAPA closure.
        Founder-gated view: status distribution, engineer scorecards, service-type matrix, monthly
        sign-off trend, root-cause pareto, and a high-risk queue of unsigned, aging &amp; disputed
        job-cards where sign-off lag &gt; 48h or rating &lt; 3.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Report status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No service reports logged yet."
          rowKey={(r, i) => String(r.report_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer sign-off scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Service-type &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No reports by service type."
          rowKey={(r, i) => `${r.service_type}-${r.report_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly sign-off trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.signoff_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Sign-off lag &amp; dispute impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.service_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue (unsigned / aging / disputed)</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk job-cards."
          rowKey={(r, i) => `${r.report_number}-${i}`}
        />
      </section>
    </main>
  );
}
