import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type GradeRow = { grade: string; audits: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_audits: number;
  excellent: number;
  good: number;
  satisfactory: number;
  needs_improvement: number;
  failed: number;
  critical_findings: number;
  reaudits: number;
  avg_score_pct: number;
};
type MatrixRow = {
  audit_dimension: string;
  grade: string;
  audits: number;
  critical_findings: number;
  avg_score_pct: number;
};
type TrendRow = {
  audit_month: string;
  audits: number;
  passed: number;
  failed: number;
  critical_findings: number;
  reaudits: number;
  avg_score_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ImpactRow = {
  quality_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  auditor_name: string;
  audit_dimension: string;
  visit_date: string;
  grade: string;
  score_pct: number | null;
  critical_finding: boolean | null;
  reaudit_required: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    gradeRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3524_grade_rollup'),
    supabase.rpc('founder_r3524_engineer_scorecard'),
    supabase.rpc('founder_r3524_dimension_grade_matrix'),
    supabase.rpc('founder_r3524_monthly_quality_trend'),
    supabase.rpc('founder_r3524_capa_status_board'),
    supabase.rpc('founder_r3524_root_cause_pareto'),
    supabase.rpc('founder_r3524_quality_impact_digest'),
    supabase.rpc('founder_r3524_high_risk_queue'),
  ]);

  const gradeRows: GradeRow[] = (gradeRes.data as GradeRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const gradeCols: Column<GradeRow>[] = [
    { key: 'grade', header: 'Grade' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'excellent', header: 'Excellent' },
    { key: 'good', header: 'Good' },
    { key: 'satisfactory', header: 'Satisfactory' },
    { key: 'needs_improvement', header: 'Needs Improvement' },
    { key: 'failed', header: 'Failed' },
    { key: 'critical_findings', header: 'Critical' },
    { key: 'reaudits', header: 'Re-audits' },
    { key: 'avg_score_pct', header: 'Avg Score %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'audit_dimension', header: 'Dimension' },
    { key: 'grade', header: 'Grade' },
    { key: 'audits', header: 'Audits' },
    { key: 'critical_findings', header: 'Critical' },
    { key: 'avg_score_pct', header: 'Avg Score %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_month', header: 'Month' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed', header: 'Failed' },
    { key: 'critical_findings', header: 'Critical' },
    { key: 'reaudits', header: 'Re-audits' },
    { key: 'avg_score_pct', header: 'Avg Score %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'quality_impact', header: 'Quality Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'auditor_name', header: 'Auditor' },
    { key: 'audit_dimension', header: 'Dimension' },
    { key: 'visit_date', header: 'Date' },
    { key: 'grade', header: 'Grade' },
    { key: 'score_pct', header: 'Score %' },
    { key: 'critical_finding', header: 'Critical' },
    { key: 'reaudit_required', header: 'Re-audit' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Service-Quality Random-Visit Audit Scorecard Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Random supervisor field-visit service-quality audit scorecard &mdash; engineer &times; hospital
        &times; auditor &times; audit dimension (workmanship, safety &amp; PPE, documentation,
        tool-calibration, customer-interaction, SOP-adherence, cleanliness) &times; score &times; grade
        &times; critical-finding &times; re-audit &amp; CAPA closure. Founder-gated view: grade
        distribution, engineer scorecards, dimension &times; grade matrix, monthly quality trend,
        root-cause pareto, and quality-impact digest across the field-service network.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Grade distribution</h2>
        <DataTable
          rows={gradeRows}
          columns={gradeCols}
          emptyMessage="No audits logged yet."
          rowKey={(r, i) => String(r.grade ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Dimension &times; grade matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by dimension."
          rowKey={(r, i) => `${r.audit_dimension}-${r.grade}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly quality trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Quality-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No quality-impact rollups."
          rowKey={(r, i) => String(r.quality_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk audit queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk audits."
          rowKey={(r, i) => `${r.engineer_name}-${r.visit_date}-${i}`}
        />
      </section>
    </main>
  );
}
