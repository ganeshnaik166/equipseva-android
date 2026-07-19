import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { talent_verdict: string; employees: number; pct: number };
type DeptRow = {
  department: string;
  total_employees: number;
  accelerate: number;
  retain_develop: number;
  monitor_or_plan: number;
  high_flight_risk: number;
  critical_retention: number;
  ready_now: number;
  hipo_pct: number;
};
type MatrixRow = {
  performance_axis: string;
  potential_axis: string;
  employees: number;
  critical_retention: number;
  high_flight_risk: number;
  ready_now: number;
};
type TrendRow = {
  review_date: string;
  reviews: number;
  accelerate: number;
  exit_managed: number;
  high_flight_risk: number;
  critical_retention: number;
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
type RiskImpactRow = {
  risk_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type QueueRow = {
  employee_name: string;
  department: string;
  current_role: string;
  current_band: string;
  nine_box_cell: string;
  talent_verdict: string;
  retention_priority: string;
  flight_risk: string;
  readiness: string;
  successor_for_role: string | null;
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
    riskImpactRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3353_verdict_rollup'),
    supabase.rpc('founder_r3353_department_scorecard'),
    supabase.rpc('founder_r3353_nine_box_matrix'),
    supabase.rpc('founder_r3353_review_trend'),
    supabase.rpc('founder_r3353_capa_status_board'),
    supabase.rpc('founder_r3353_root_cause_pareto'),
    supabase.rpc('founder_r3353_risk_impact_digest'),
    supabase.rpc('founder_r3353_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const riskImpactRows: RiskImpactRow[] = (riskImpactRes.data as RiskImpactRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'talent_verdict', header: 'Talent Verdict' },
    { key: 'employees', header: 'Employees' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'total_employees', header: 'Employees' },
    { key: 'accelerate', header: 'Accelerate' },
    { key: 'retain_develop', header: 'Retain/Develop' },
    { key: 'monitor_or_plan', header: 'Monitor/Plan' },
    { key: 'high_flight_risk', header: 'High Flight-Risk' },
    { key: 'critical_retention', header: 'Critical Retention' },
    { key: 'ready_now', header: 'Ready Now' },
    { key: 'hipo_pct', header: 'HiPo %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'performance_axis', header: 'Performance' },
    { key: 'potential_axis', header: 'Potential' },
    { key: 'employees', header: 'Employees' },
    { key: 'critical_retention', header: 'Critical Retention' },
    { key: 'high_flight_risk', header: 'High Flight-Risk' },
    { key: 'ready_now', header: 'Ready Now' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'review_date', header: 'Review Date' },
    { key: 'reviews', header: 'Reviews' },
    { key: 'accelerate', header: 'Accelerate' },
    { key: 'exit_managed', header: 'Exit Managed' },
    { key: 'high_flight_risk', header: 'High Flight-Risk' },
    { key: 'critical_retention', header: 'Critical Retention' },
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

  const riskImpactCols: Column<RiskImpactRow>[] = [
    { key: 'risk_impact', header: 'Risk Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'employee_name', header: 'Employee' },
    { key: 'department', header: 'Department' },
    { key: 'current_role', header: 'Role' },
    { key: 'current_band', header: 'Band' },
    { key: 'nine_box_cell', header: '9-Box Cell' },
    { key: 'talent_verdict', header: 'Verdict' },
    { key: 'retention_priority', header: 'Retention' },
    { key: 'flight_risk', header: 'Flight-Risk' },
    { key: 'readiness', header: 'Readiness' },
    { key: 'successor_for_role', header: 'Successor For' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Talent Pipeline, HiPo Nine-Box &amp; Succession-Bench Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Talent-review log — employee &times; department &times; band &times; performance-axis
        &times; potential-axis &times; nine-box cell &times; retention priority &times; succession
        readiness &times; development action &times; flight-risk &times; talent verdict &amp; CAPA
        closure. Founder-gated view: verdict rollups, department scorecards, the performance
        &times; potential nine-box matrix, root-cause pareto, and risk-impact digest across
        succession-bench and retention surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Talent verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No talent reviews logged yet."
          rowKey={(r, i) => String(r.talent_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department talent scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Nine-box: performance &times; potential</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.performance_axis}-${r.potential_axis}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Review-date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.review_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Risk-impact digest</h2>
        <DataTable
          rows={riskImpactRows}
          columns={riskImpactCols}
          emptyMessage="No risk-impact rollups."
          rowKey={(r, i) => String(r.risk_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk talent queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk employees."
          rowKey={(r, i) => `${r.employee_name}-${i}`}
        />
      </section>
    </main>
  );
}
