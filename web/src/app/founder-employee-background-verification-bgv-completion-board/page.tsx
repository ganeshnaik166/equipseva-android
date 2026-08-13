import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { bgv_status: string; records: number; pct: number };
type DeptRow = {
  department: string;
  records: number;
  completed_clean: number;
  completed_red_flag: number;
  overdue: number;
  vendor_delay: number;
  avg_days_to_complete: number | null;
  red_flags_total: number;
};
type MatrixRow = {
  bgv_class: string;
  bgv_status: string;
  records: number;
  avg_days_to_complete: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  completed: number;
  avg_days_to_complete: number | null;
  red_flags_total: number;
  worsening_records: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  department: string;
  records: number;
  red_flags_total: number;
  high_severity_flags: number;
  avg_days_to_complete: number | null;
  vendor_delay_records: number;
};
type RiskRow = {
  employee_name: string;
  department: string;
  bgv_class: string;
  period_month: string;
  bgv_status: string;
  days_to_complete: number | null;
  red_flags_found: number | null;
  red_flag_severity: string | null;
  vendor_name: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3741_bgv_status_rollup'),
    supabase.rpc('founder_r3741_department_scorecard'),
    supabase.rpc('founder_r3741_bgv_class_status_matrix'),
    supabase.rpc('founder_r3741_monthly_completion_trend'),
    supabase.rpc('founder_r3741_capa_status_board'),
    supabase.rpc('founder_r3741_root_cause_pareto'),
    supabase.rpc('founder_r3741_red_flag_digest'),
    supabase.rpc('founder_r3741_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'bgv_status', header: 'BGV Status' },
    { key: 'records', header: 'Employees' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'records', header: 'Employees' },
    { key: 'completed_clean', header: 'Completed Clean' },
    { key: 'completed_red_flag', header: 'Completed w/ Red Flag' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'vendor_delay', header: 'Vendor Delay' },
    { key: 'avg_days_to_complete', header: 'Avg Days to Complete' },
    { key: 'red_flags_total', header: 'Red Flags Total' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'bgv_class', header: 'Check Type' },
    { key: 'bgv_status', header: 'BGV Status' },
    { key: 'records', header: 'Employees' },
    { key: 'avg_days_to_complete', header: 'Avg Days to Complete' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Employees' },
    { key: 'completed', header: 'Completed' },
    { key: 'avg_days_to_complete', header: 'Avg Days to Complete' },
    { key: 'red_flags_total', header: 'Red Flags Total' },
    { key: 'worsening_records', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'records', header: 'Employees Flagged' },
    { key: 'red_flags_total', header: 'Red Flags Total' },
    { key: 'high_severity_flags', header: 'High-Severity Flags' },
    { key: 'avg_days_to_complete', header: 'Avg Days to Complete' },
    { key: 'vendor_delay_records', header: 'Vendor-Delay Cases' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'employee_name', header: 'Employee' },
    { key: 'department', header: 'Department' },
    { key: 'bgv_class', header: 'Check Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'bgv_status', header: 'BGV Status' },
    { key: 'days_to_complete', header: 'Days to Complete' },
    { key: 'red_flags_found', header: 'Red Flags Found' },
    { key: 'red_flag_severity', header: 'Severity' },
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Employee Background-Verification (BGV) Completion Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Employee pre/post-joining background-verification completion log — checks completed
        (criminal record, education, employment history, address, reference) &times; department
        &times; period month &times; turnaround time &times; red-flags found &amp; severity
        &times; vendor performance &amp; CAPA closure. Distinct from any investor-reference-checks
        page, which covers investor due-diligence, not employee BGV. Founder-gated view:
        status distribution, department scorecards, check-type &times; status matrix, monthly
        completion trend, CAPA status board, root-cause pareto, a red-flag digest, and a
        high-risk queue of overdue, vendor-delayed &amp; red-flagged cases.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. BGV-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No BGV rows logged yet."
          rowKey={(r, i) => String(r.bgv_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Check type &times; BGV status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by type."
          rowKey={(r, i) => `${r.bgv_class}-${r.bgv_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly completion trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Red-flag digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No red-flag findings."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk BGV queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk BGV cases."
          rowKey={(r, i) => `${r.employee_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
