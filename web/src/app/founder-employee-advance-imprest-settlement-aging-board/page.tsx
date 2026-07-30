import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { settlement_status: string; advances: number; pct: number };
type DeptRow = {
  department: string;
  total_advances: number;
  settled: number;
  on_track: number;
  overdue: number;
  escalated: number;
  recovery_from_salary: number;
  total_issued_rupees: number;
  total_outstanding_rupees: number;
  total_overdue_rupees: number;
  settled_pct: number;
};
type MatrixRow = {
  aging_bucket: string;
  settlement_status: string;
  advances: number;
  total_outstanding_rupees: number;
  total_overdue_rupees: number;
};
type TrendRow = {
  period_month: string;
  advances: number;
  total_issued_rupees: number;
  total_settled_rupees: number;
  total_outstanding_rupees: number;
  total_overdue_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  aging_bucket: string;
  advances: number;
  total_overdue_rupees: number;
  total_outstanding_rupees: number;
  avg_days_outstanding: number;
};
type RiskRow = {
  employee_name: string;
  advance_ref: string;
  department: string;
  advance_type: string;
  period_month: string;
  settlement_status: string;
  aging_bucket: string;
  days_outstanding: number;
  overdue_rupees: number;
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
    supabase.rpc('founder_r3617_settlement_status_rollup'),
    supabase.rpc('founder_r3617_department_scorecard'),
    supabase.rpc('founder_r3617_aging_settlement_matrix'),
    supabase.rpc('founder_r3617_monthly_settlement_trend'),
    supabase.rpc('founder_r3617_capa_status_board'),
    supabase.rpc('founder_r3617_root_cause_pareto'),
    supabase.rpc('founder_r3617_overdue_impact_digest'),
    supabase.rpc('founder_r3617_high_risk_queue'),
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
    { key: 'settlement_status', header: 'Settlement Status' },
    { key: 'advances', header: 'Advances' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'total_advances', header: 'Advances' },
    { key: 'settled', header: 'Settled' },
    { key: 'on_track', header: 'On Track' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'recovery_from_salary', header: 'Salary Recovery' },
    { key: 'total_issued_rupees', header: 'Issued (INR)' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'total_overdue_rupees', header: 'Overdue (INR)' },
    { key: 'settled_pct', header: 'Settled %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'aging_bucket', header: 'Aging Bucket' },
    { key: 'settlement_status', header: 'Settlement Status' },
    { key: 'advances', header: 'Advances' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'total_overdue_rupees', header: 'Overdue (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'advances', header: 'Advances' },
    { key: 'total_issued_rupees', header: 'Issued (INR)' },
    { key: 'total_settled_rupees', header: 'Settled (INR)' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'total_overdue_rupees', header: 'Overdue (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'aging_bucket', header: 'Aging Bucket' },
    { key: 'advances', header: 'Advances' },
    { key: 'total_overdue_rupees', header: 'Overdue (INR)' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'avg_days_outstanding', header: 'Avg Days Outstanding' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'employee_name', header: 'Employee' },
    { key: 'advance_ref', header: 'Advance Ref' },
    { key: 'department', header: 'Department' },
    { key: 'advance_type', header: 'Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'settlement_status', header: 'Status' },
    { key: 'aging_bucket', header: 'Aging' },
    { key: 'days_outstanding', header: 'Days Out' },
    { key: 'overdue_rupees', header: 'Overdue (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Employee Advance / Imprest Settlement Aging Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Employee advance &amp; imprest settlement ledger — advance type (travel, imprest, project,
        medical, salary advance) &times; department &times; period month &times; issued /
        settled / outstanding / overdue rupees &times; days outstanding &times; aging bucket
        &times; settlement status &times; trend &amp; CAPA recovery closure. Founder-gated view:
        settlement-status rollups, department scorecards, aging &times; status matrix, root-cause
        pareto, and overdue-impact digest across all business units.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Settlement status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No advances logged yet."
          rowKey={(r, i) => String(r.settlement_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Aging bucket &times; settlement status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No advances by aging bucket."
          rowKey={(r, i) => `${r.aging_bucket}-${r.settlement_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly settlement trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Overdue-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No overdue-impact rollups."
          rowKey={(r, i) => String(r.aging_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk advance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk advances."
          rowKey={(r, i) => `${r.advance_ref}-${i}`}
        />
      </section>
    </main>
  );
}
