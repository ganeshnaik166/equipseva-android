import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { recovery_verdict: string; advances: number; pct: number };
type DeptRow = {
  department: string;
  total_advances: number;
  on_track: number;
  behind: number;
  escalate_writeoff: number;
  at_risk: number;
  total_outstanding_rupees: number;
  recovered_pct: number;
};
type MatrixRow = {
  department: string;
  advance_type: string;
  advances: number;
  total_principal_rupees: number;
  total_outstanding_rupees: number;
  on_track: number;
};
type TrendRow = {
  disbursed_date: string;
  advances: number;
  principal_disbursed_rupees: number;
  outstanding_rupees: number;
  off_track: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_amount_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_amount_rupees: number;
  pct: number;
};
type ExposureRow = {
  financial_exposure: string;
  findings: number;
  open_findings: number;
  total_amount_rupees: number;
};
type RiskRow = {
  employee_name: string;
  department: string;
  advance_type: string;
  disbursed_date: string;
  outstanding_rupees: number;
  installments_remaining: number;
  employee_status: string;
  recovery_risk: string;
  recovery_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3337_recovery_verdict_rollup'),
    supabase.rpc('founder_r3337_department_scorecard'),
    supabase.rpc('founder_r3337_dept_advance_type_matrix'),
    supabase.rpc('founder_r3337_disbursal_trend'),
    supabase.rpc('founder_r3337_capa_status_board'),
    supabase.rpc('founder_r3337_root_cause_pareto'),
    supabase.rpc('founder_r3337_exposure_digest'),
    supabase.rpc('founder_r3337_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'recovery_verdict', header: 'Recovery Verdict' },
    { key: 'advances', header: 'Advances' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'total_advances', header: 'Advances' },
    { key: 'on_track', header: 'On Track' },
    { key: 'behind', header: 'Behind' },
    { key: 'escalate_writeoff', header: 'Escalate / Write-Off' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'recovered_pct', header: 'Recovered %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'advance_type', header: 'Advance Type' },
    { key: 'advances', header: 'Advances' },
    { key: 'total_principal_rupees', header: 'Principal (INR)' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'on_track', header: 'Deduction On Track' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'disbursed_date', header: 'Disbursed Date' },
    { key: 'advances', header: 'Advances' },
    { key: 'principal_disbursed_rupees', header: 'Principal (INR)' },
    { key: 'outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'off_track', header: 'Off Track' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_amount_rupees', header: 'Avg Amount (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'financial_exposure', header: 'Financial Exposure' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'employee_name', header: 'Employee' },
    { key: 'department', header: 'Department' },
    { key: 'advance_type', header: 'Advance Type' },
    { key: 'disbursed_date', header: 'Disbursed' },
    { key: 'outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'installments_remaining', header: 'Installments Left' },
    { key: 'employee_status', header: 'Status' },
    { key: 'recovery_risk', header: 'Risk' },
    { key: 'recovery_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Salary-Advance, Employee-Loan &amp; Advance-Recovery Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        HR-finance ledger — advance type &times; department &times; payroll-deduction health &times;
        recovery verdict &times; exit exposure &times; outstanding INR &amp; CAPA recovery /
        adjustment / write-off closure. Founder-gated view: recovery verdicts, department
        scorecards, root-cause pareto, and financial-exposure digest across active, notice-period,
        exited &amp; absconding staff.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Recovery verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No advances logged yet."
          rowKey={(r, i) => String(r.recovery_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department recovery scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Department &times; advance-type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No advances by type."
          rowKey={(r, i) => `${r.department}-${r.advance_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily disbursal trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.disbursed_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial-exposure digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure rollups."
          rowKey={(r, i) => String(r.financial_exposure ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk recovery queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk advances."
          rowKey={(r, i) => `${r.employee_name}-${r.disbursed_date}-${i}`}
        />
      </section>
    </main>
  );
}
