import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { comp_status: string; records: number; total_headcount: number; pct: number };
type DeptRow = {
  department: string;
  periods: number;
  total_headcount: number;
  total_comp_rupees: number;
  total_revenue_rupees: number;
  blended_comp_to_revenue_pct: number;
  avg_revenue_per_head_rupees: number;
  over_weight_periods: number;
};
type MatrixRow = {
  department: string;
  comp_status: string;
  records: number;
  total_headcount: number;
  avg_comp_to_revenue_pct: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  total_comp_rupees: number;
  total_revenue_rupees: number;
  blended_comp_to_revenue_pct: number;
  avg_attrition_pct: number;
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
type DigestRow = {
  department: string;
  total_headcount: number;
  total_comp_rupees: number;
  total_revenue_rupees: number;
  comp_to_revenue_pct: number;
  avg_cost_per_head_rupees: number;
  revenue_per_head_rupees: number;
};
type RiskRow = {
  department: string;
  metric_code: string;
  period_month: string;
  headcount: number;
  comp_to_revenue_pct: number;
  target_comp_ratio_pct: number;
  revenue_per_head_rupees: number;
  attrition_pct: number | null;
  comp_status: string;
  trend_dir: string;
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
    supabase.rpc('founder_r3609_comp_status_rollup'),
    supabase.rpc('founder_r3609_department_scorecard'),
    supabase.rpc('founder_r3609_department_status_matrix'),
    supabase.rpc('founder_r3609_monthly_comp_ratio_trend'),
    supabase.rpc('founder_r3609_capa_status_board'),
    supabase.rpc('founder_r3609_root_cause_pareto'),
    supabase.rpc('founder_r3609_payroll_cost_digest'),
    supabase.rpc('founder_r3609_high_risk_queue'),
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
    { key: 'comp_status', header: 'Comp Status' },
    { key: 'records', header: 'Records' },
    { key: 'total_headcount', header: 'Headcount' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'periods', header: 'Periods' },
    { key: 'total_headcount', header: 'Headcount' },
    { key: 'total_comp_rupees', header: 'Total Comp (INR)' },
    { key: 'total_revenue_rupees', header: 'Total Revenue (INR)' },
    { key: 'blended_comp_to_revenue_pct', header: 'Comp / Rev %' },
    { key: 'avg_revenue_per_head_rupees', header: 'Avg Rev / Head (INR)' },
    { key: 'over_weight_periods', header: 'Over-Weight Periods' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'comp_status', header: 'Comp Status' },
    { key: 'records', header: 'Records' },
    { key: 'total_headcount', header: 'Headcount' },
    { key: 'avg_comp_to_revenue_pct', header: 'Avg Comp / Rev %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'total_comp_rupees', header: 'Total Comp (INR)' },
    { key: 'total_revenue_rupees', header: 'Total Revenue (INR)' },
    { key: 'blended_comp_to_revenue_pct', header: 'Blended Comp / Rev %' },
    { key: 'avg_attrition_pct', header: 'Avg Attrition %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'total_headcount', header: 'Headcount' },
    { key: 'total_comp_rupees', header: 'Total Comp (INR)' },
    { key: 'total_revenue_rupees', header: 'Total Revenue (INR)' },
    { key: 'comp_to_revenue_pct', header: 'Comp / Rev %' },
    { key: 'avg_cost_per_head_rupees', header: 'Cost / Head (INR)' },
    { key: 'revenue_per_head_rupees', header: 'Rev / Head (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'metric_code', header: 'Metric' },
    { key: 'period_month', header: 'Month' },
    { key: 'headcount', header: 'Headcount' },
    { key: 'comp_to_revenue_pct', header: 'Comp / Rev %' },
    { key: 'target_comp_ratio_pct', header: 'Target %' },
    { key: 'revenue_per_head_rupees', header: 'Rev / Head (INR)' },
    { key: 'attrition_pct', header: 'Attrition %' },
    { key: 'comp_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Compensation-Ratio / Payroll-Cost Efficiency Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated payroll-finance view — department &times; period &times; headcount &times; total
        compensation &times; revenue &times; comp-to-revenue ratio &times; target ratio &times; average
        cost-per-head &times; revenue-per-head &times; variable-pay share &times; attrition &amp;
        comp-efficiency status across business units (AMC services, spare parts, projects, diagnostics,
        rentals, field service, sales &amp; corporate). Rolls up comp-status distribution, department
        scorecards, monthly comp-ratio trend, payroll-cost digest, root-cause pareto &amp; the
        over-weight / critical high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Comp-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No compensation-ratio records yet."
          rowKey={(r, i) => String(r.comp_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Department &times; comp-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by department."
          rowKey={(r, i) => `${r.department}-${r.comp_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly comp-ratio trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Payroll-cost digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No payroll-cost rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk departments."
          rowKey={(r, i) => `${r.metric_code}-${i}`}
        />
      </section>
    </main>
  );
}
