import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; records: number; pct: number };
type DeptRow = {
  department: string;
  records: number;
  compliant: number;
  leave_in_progress: number;
  pay_discrepancy: number;
  creche_unavailable: number;
  return_overdue: number;
  avg_leave_availed_days: number | null;
  avg_creche_utilization_pct: number | null;
};
type MatrixRow = {
  benefit_class: string;
  compliance_status: string;
  records: number;
  avg_leave_availed_days: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  leave_entitled_days_total: number;
  leave_availed_days_total: number;
  pay_discrepancy_records: number;
  return_overdue_records: number;
};
type CapaRow = { capa_status: string; findings: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; pct: number };
type DigestRow = {
  department: string;
  records: number;
  pay_discrepancy_records: number;
  avg_leave_availed_days: number | null;
  avg_creche_utilization_pct: number | null;
};
type RiskRow = {
  employee_name: string;
  department: string;
  period_month: string;
  benefit_class: string;
  compliance_status: string;
  return_to_work_date: string | null;
  return_to_work_status: string | null;
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
    supabase.rpc('founder_r3749_compliance_status_rollup'),
    supabase.rpc('founder_r3749_department_scorecard'),
    supabase.rpc('founder_r3749_benefit_class_status_matrix'),
    supabase.rpc('founder_r3749_monthly_leave_trend'),
    supabase.rpc('founder_r3749_capa_status_board'),
    supabase.rpc('founder_r3749_root_cause_pareto'),
    supabase.rpc('founder_r3749_pay_discrepancy_digest'),
    supabase.rpc('founder_r3749_high_risk_queue'),
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
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'leave_in_progress', header: 'Leave In Progress' },
    { key: 'pay_discrepancy', header: 'Pay Discrepancy' },
    { key: 'creche_unavailable', header: 'Creche Unavailable' },
    { key: 'return_overdue', header: 'Return Overdue' },
    { key: 'avg_leave_availed_days', header: 'Avg Leave Availed (days)' },
    { key: 'avg_creche_utilization_pct', header: 'Avg Creche Util %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'benefit_class', header: 'Benefit Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_leave_availed_days', header: 'Avg Leave Availed (days)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'leave_entitled_days_total', header: 'Leave Entitled (days)' },
    { key: 'leave_availed_days_total', header: 'Leave Availed (days)' },
    { key: 'pay_discrepancy_records', header: 'Pay Discrepancy' },
    { key: 'return_overdue_records', header: 'Return Overdue' },
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
    { key: 'records', header: 'Records' },
    { key: 'pay_discrepancy_records', header: 'Pay Discrepancy' },
    { key: 'avg_leave_availed_days', header: 'Avg Leave Availed (days)' },
    { key: 'avg_creche_utilization_pct', header: 'Avg Creche Util %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'employee_name', header: 'Employee' },
    { key: 'department', header: 'Department' },
    { key: 'period_month', header: 'Month' },
    { key: 'benefit_class', header: 'Benefit Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'return_to_work_date', header: 'Return-to-Work Date' },
    { key: 'return_to_work_status', header: 'Return-to-Work Status' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Statutory Maternity-Benefit / Creche-Facility Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Maternity Benefit Act &amp; creche-facility compliance log — employee &times; department
        &times; period month &times; leave entitlement vs. days availed &times; pay continuity
        through leave &times; creche facility usage &amp; utilization &times; return-to-work
        outcome &amp; CAPA closure. Founder-gated view: compliance-status distribution, department
        scorecards, benefit-class &times; status matrix, monthly leave trend, a pay-discrepancy
        digest, and a high-risk queue of pay-discrepancy &amp; overdue-return cases.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No maternity-benefit rows logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Benefit class &times; compliance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No benefit-class rollups."
          rowKey={(r, i) => `${r.benefit_class}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly leave trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Pay-discrepancy digest by department</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No pay-discrepancy cases."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cases."
          rowKey={(r, i) => `${r.employee_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
