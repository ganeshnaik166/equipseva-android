import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { election_status: string; records: number; pct: number };
type DeptRow = {
  department: string;
  records: number;
  fully_elected_optimal: number;
  partially_elected: number;
  not_elected: number;
  over_allocated: number;
  forfeiture_risk: number;
  avg_election_completion_pct: number | null;
  avg_utilization_pct: number | null;
  forfeiture_risk_total_rupees: number | null;
};
type MatrixRow = {
  declaration_class: string;
  election_status: string;
  records: number;
  avg_utilization_pct: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  total_allocated_rupees_total: number;
  total_utilized_rupees_total: number;
  forfeiture_risk_rupees_total: number;
  avg_utilization_pct: number | null;
};
type CapaRow = { capa_status: string; findings: number; overdue_flag: number };
type CauseRow = { root_cause: string | null; occurrences: number; pct: number };
type ForfeitureRow = {
  department: string;
  records: number;
  forfeiture_risk_records: number;
  forfeiture_risk_total_rupees: number | null;
  avg_utilization_pct: number | null;
};
type RiskRow = {
  employee_name: string;
  department: string;
  period_month: string;
  declaration_class: string;
  election_status: string;
  utilization_pct: number | null;
  forfeiture_risk_rupees: number | null;
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
    forfeitureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3752_election_status_rollup'),
    supabase.rpc('founder_r3752_department_scorecard'),
    supabase.rpc('founder_r3752_declaration_class_status_matrix'),
    supabase.rpc('founder_r3752_monthly_utilization_trend'),
    supabase.rpc('founder_r3752_capa_status_board'),
    supabase.rpc('founder_r3752_root_cause_pareto'),
    supabase.rpc('founder_r3752_forfeiture_risk_digest'),
    supabase.rpc('founder_r3752_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const forfeitureRows: ForfeitureRow[] = (forfeitureRes.data as ForfeitureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'election_status', header: 'Election Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'records', header: 'Records' },
    { key: 'fully_elected_optimal', header: 'Fully Elected/Optimal' },
    { key: 'partially_elected', header: 'Partially Elected' },
    { key: 'not_elected', header: 'Not Elected' },
    { key: 'over_allocated', header: 'Over Allocated' },
    { key: 'forfeiture_risk', header: 'Forfeiture Risk' },
    { key: 'avg_election_completion_pct', header: 'Avg Completion %' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'forfeiture_risk_total_rupees', header: 'Forfeiture Risk Total (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'declaration_class', header: 'Declaration Class' },
    { key: 'election_status', header: 'Election Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'total_allocated_rupees_total', header: 'Total Allocated (INR)' },
    { key: 'total_utilized_rupees_total', header: 'Total Utilized (INR)' },
    { key: 'forfeiture_risk_rupees_total', header: 'Forfeiture Risk Total (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
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

  const forfeitureCols: Column<ForfeitureRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'records', header: 'Records' },
    { key: 'forfeiture_risk_records', header: 'Forfeiture Risk Records' },
    { key: 'forfeiture_risk_total_rupees', header: 'Forfeiture Risk Total (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'employee_name', header: 'Employee' },
    { key: 'department', header: 'Department' },
    { key: 'period_month', header: 'Month' },
    { key: 'declaration_class', header: 'Declaration Class' },
    { key: 'election_status', header: 'Election Status' },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'forfeiture_risk_rupees', header: 'Forfeiture Risk (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Employee Flexible-Benefits / Cafeteria-Plan Election Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-employee flexible-benefits/cafeteria-plan (LTA, meal vouchers, fuel allowance,
        medical reimbursement, books &amp; periodicals) election and utilization log &mdash;
        employee &times; department &times; period month &times; components offered vs elected
        &times; election-completion rate &times; allocated vs utilized amount &times;
        tax-optimal utilization &times; unused-component forfeiture risk &amp; CAPA closure.
        Founder-gated view: election-status distribution, department scorecards, declaration
        class &times; status matrix, monthly utilization trend, CAPA closure, root-cause pareto,
        a forfeiture-risk digest, and a high-risk election queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Election-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No flexible-benefits election rows logged yet."
          rowKey={(r, i) => String(r.election_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Declaration class &times; election status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No elections by declaration class."
          rowKey={(r, i) => `${r.declaration_class}-${r.election_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly utilization trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Forfeiture-risk digest by department</h2>
        <DataTable
          rows={forfeitureRows}
          columns={forfeitureCols}
          emptyMessage="No forfeiture-risk rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk election queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk elections."
          rowKey={(r, i) => `${r.employee_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
