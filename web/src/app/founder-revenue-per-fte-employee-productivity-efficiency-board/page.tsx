import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { productivity_status: string; entries: number; pct: number };
type DeptRow = {
  department: string;
  entries: number;
  above_target: number;
  on_target: number;
  below_target: number;
  critical_low: number;
  avg_rev_per_fte_rupees: number;
  avg_util_pct: number;
  on_target_or_better_pct: number;
};
type MatrixRow = {
  department: string;
  productivity_status: string;
  entries: number;
  avg_rev_per_fte_rupees: number;
  avg_gross_profit_per_fte_rupees: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_headcount_fte: number;
  total_revenue_rupees: number;
  avg_rev_per_fte_rupees: number;
  below_target: number;
  critical_low: number;
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
  finding_category: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  department: string;
  function_area: string;
  record_code: string;
  period_month: string;
  productivity_status: string;
  revenue_per_fte_rupees: number;
  target_rev_per_fte_rupees: number;
  utilization_pct: number | null;
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
    supabase.rpc('founder_r3469_productivity_status_rollup'),
    supabase.rpc('founder_r3469_department_scorecard'),
    supabase.rpc('founder_r3469_department_status_matrix'),
    supabase.rpc('founder_r3469_monthly_rev_per_fte_trend'),
    supabase.rpc('founder_r3469_capa_status_board'),
    supabase.rpc('founder_r3469_root_cause_pareto'),
    supabase.rpc('founder_r3469_productivity_impact_digest'),
    supabase.rpc('founder_r3469_high_risk_queue'),
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
    { key: 'productivity_status', header: 'Productivity Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'entries', header: 'Entries' },
    { key: 'above_target', header: 'Above' },
    { key: 'on_target', header: 'On Target' },
    { key: 'below_target', header: 'Below' },
    { key: 'critical_low', header: 'Critical Low' },
    { key: 'avg_rev_per_fte_rupees', header: 'Avg Rev/FTE (INR)' },
    { key: 'avg_util_pct', header: 'Avg Util %' },
    { key: 'on_target_or_better_pct', header: 'On-Target+ %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'productivity_status', header: 'Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_rev_per_fte_rupees', header: 'Avg Rev/FTE (INR)' },
    { key: 'avg_gross_profit_per_fte_rupees', header: 'Avg GP/FTE (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_headcount_fte', header: 'Total FTE' },
    { key: 'total_revenue_rupees', header: 'Total Revenue (INR)' },
    { key: 'avg_rev_per_fte_rupees', header: 'Avg Rev/FTE (INR)' },
    { key: 'below_target', header: 'Below' },
    { key: 'critical_low', header: 'Critical Low' },
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
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'function_area', header: 'Function' },
    { key: 'record_code', header: 'Record' },
    { key: 'period_month', header: 'Month' },
    { key: 'productivity_status', header: 'Status' },
    { key: 'revenue_per_fte_rupees', header: 'Rev/FTE (INR)' },
    { key: 'target_rev_per_fte_rupees', header: 'Target Rev/FTE (INR)' },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Revenue-per-FTE / Employee-Productivity Efficiency Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated efficiency board tracking revenue-per-FTE and employee productivity by
        department &amp; function area — headcount FTE &times; revenue &times; revenue-per-FTE
        &times; target &times; gross-profit-per-FTE &times; utilization &times; productivity status
        &times; monthly trend &amp; CAPA closure. Surfaces status distribution, department
        scorecards, department &times; status matrix, monthly trends, root-cause pareto, and a
        high-risk queue of critical-low, below-target &amp; worsening lines.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Productivity status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No productivity entries logged yet."
          rowKey={(r, i) => String(r.productivity_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Department &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by department."
          rowKey={(r, i) => `${r.department}-${r.productivity_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly revenue-per-FTE trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Productivity-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No impact digest rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk productivity queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.record_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
