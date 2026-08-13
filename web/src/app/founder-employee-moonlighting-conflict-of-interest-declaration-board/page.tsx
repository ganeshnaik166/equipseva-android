import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { declaration_status: string; declarations: number; pct: number };
type DepartmentRow = {
  department: string;
  declarations: number;
  declared_approved: number;
  undeclared_found: number;
  conflicts_identified: number;
  approval_required_count: number;
  approved_count: number;
  avg_hours_per_week: number | null;
  high_risk_count: number;
};
type MatrixRow = {
  coi_class: string;
  declaration_status: string;
  declarations: number;
  avg_hours_per_week: number | null;
};
type TrendRow = {
  period_month: string;
  declarations: number;
  undeclared_found: number;
  conflicts_identified: number;
  approved_count: number;
  worsening_count: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  closed_count: number;
  overdue_count: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  employee_name: string;
  department: string;
  period_month: string;
  coi_class: string;
  outside_engagement_name: string | null;
  hours_per_week: number | null;
  role_risk_level: string | null;
  declaration_status: string;
  notes: string | null;
};
type RiskRow = {
  employee_name: string;
  department: string;
  period_month: string;
  coi_class: string;
  declaration_status: string;
  role_risk_level: string | null;
  conflict_identified: boolean;
  hours_per_week: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    departmentRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3732_declaration_status_rollup'),
    supabase.rpc('founder_r3732_department_scorecard'),
    supabase.rpc('founder_r3732_coi_class_status_matrix'),
    supabase.rpc('founder_r3732_monthly_declaration_trend'),
    supabase.rpc('founder_r3732_capa_status_board'),
    supabase.rpc('founder_r3732_root_cause_pareto'),
    supabase.rpc('founder_r3732_undeclared_conflict_digest'),
    supabase.rpc('founder_r3732_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const departmentRows: DepartmentRow[] = (departmentRes.data as DepartmentRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'declaration_status', header: 'Declaration Status' },
    { key: 'declarations', header: 'Declarations' },
    { key: 'pct', header: 'Share %' },
  ];

  const departmentCols: Column<DepartmentRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'declarations', header: 'Declarations' },
    { key: 'declared_approved', header: 'Declared & Approved' },
    { key: 'undeclared_found', header: 'Undeclared Found' },
    { key: 'conflicts_identified', header: 'Conflicts Identified' },
    { key: 'approval_required_count', header: 'Approval Required' },
    { key: 'approved_count', header: 'Approved' },
    { key: 'avg_hours_per_week', header: 'Avg Hours/Week' },
    { key: 'high_risk_count', header: 'High Risk' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'coi_class', header: 'COI Class' },
    { key: 'declaration_status', header: 'Declaration Status' },
    { key: 'declarations', header: 'Declarations' },
    { key: 'avg_hours_per_week', header: 'Avg Hours/Week' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'declarations', header: 'Declarations' },
    { key: 'undeclared_found', header: 'Undeclared Found' },
    { key: 'conflicts_identified', header: 'Conflicts Identified' },
    { key: 'approved_count', header: 'Approved' },
    { key: 'worsening_count', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'closed_count', header: 'Closed' },
    { key: 'overdue_count', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'employee_name', header: 'Employee' },
    { key: 'department', header: 'Department' },
    { key: 'period_month', header: 'Month' },
    { key: 'coi_class', header: 'COI Class' },
    { key: 'outside_engagement_name', header: 'Outside Engagement' },
    { key: 'hours_per_week', header: 'Hours/Week' },
    { key: 'role_risk_level', header: 'Role Risk' },
    { key: 'declaration_status', header: 'Declaration Status' },
    { key: 'notes', header: 'Notes' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'employee_name', header: 'Employee' },
    { key: 'department', header: 'Department' },
    { key: 'period_month', header: 'Month' },
    { key: 'coi_class', header: 'COI Class' },
    { key: 'declaration_status', header: 'Declaration Status' },
    { key: 'role_risk_level', header: 'Role Risk' },
    { key: 'conflict_identified', header: 'Conflict Identified' },
    { key: 'hours_per_week', header: 'Hours/Week' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Employee Moonlighting / Conflict-of-Interest Declaration Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Proactive employee self-declaration log &mdash; employee &times; department &times; period
        month &times; outside employment, board directorships, family-business interests, vendor
        relationships &amp; competitor engagements &times; approval status &times; conflicts
        identified &times; undeclared conflicts found &times; role risk &amp; CAPA closure. Covers
        proactive COI self-declaration only &mdash; distinct from any gift-hospitality anti-bribery
        register (external gifts) and from any whistleblower/ethics/POSH grievance board
        (grievances). Founder-gated view: declaration-status distribution, department scorecards,
        COI-class matrix, monthly declaration trend, CAPA closure, root-cause pareto, an undeclared-
        conflict digest, and a high-risk queue of undeclared, restricted &amp; declined declarations.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Declaration-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No COI declarations logged yet."
          rowKey={(r, i) => String(r.declaration_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department scorecard</h2>
        <DataTable
          rows={departmentRows}
          columns={departmentCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. COI class &times; declaration status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No COI-class rollups."
          rowKey={(r, i) => `${r.coi_class}-${r.declaration_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly declaration trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Undeclared-conflict digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No undeclared conflicts found."
          rowKey={(r, i) => `${r.employee_name}-${r.period_month}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk COI queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk declarations."
          rowKey={(r, i) => `${r.employee_name}-${r.department}-${i}`}
        />
      </section>
    </main>
  );
}
