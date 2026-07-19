import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { quality_verdict: string; audits: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_audits: number;
  thorough: number;
  acceptable: number;
  superficial: number;
  incomplete_falsified: number;
  missing_safety_test: number;
  missing_calibration: number;
  avg_completion_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  region: string;
  audits: number;
  thorough: number;
  avg_completion_pct: number;
  avg_blank_entries: number;
};
type TrendRow = {
  pm_date: string;
  audits: number;
  thorough: number;
  superficial_incomplete: number;
  missing_safety_test: number;
  missing_measured_values: number;
};
type CapaRow = {
  action_status: string;
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
  engineer_name: string;
  region: string;
  hospital_name: string;
  job_code: string;
  equipment_type: string;
  pm_date: string;
  quality_verdict: string;
  supervisor_review_status: string | null;
  completion_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    riskImpactRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3332_quality_verdict_rollup'),
    supabase.rpc('founder_r3332_engineer_scorecard'),
    supabase.rpc('founder_r3332_equipment_region_matrix'),
    supabase.rpc('founder_r3332_daily_quality_trend'),
    supabase.rpc('founder_r3332_capa_status_board'),
    supabase.rpc('founder_r3332_root_cause_pareto'),
    supabase.rpc('founder_r3332_risk_impact_digest'),
    supabase.rpc('founder_r3332_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const riskImpactRows: RiskImpactRow[] = (riskImpactRes.data as RiskImpactRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'quality_verdict', header: 'Quality Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'thorough', header: 'Thorough' },
    { key: 'acceptable', header: 'Acceptable' },
    { key: 'superficial', header: 'Superficial' },
    { key: 'incomplete_falsified', header: 'Incomplete / Falsified' },
    { key: 'missing_safety_test', header: 'No Safety Test' },
    { key: 'missing_calibration', header: 'No Cal Record' },
    { key: 'avg_completion_pct', header: 'Avg Completion %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'region', header: 'Region' },
    { key: 'audits', header: 'Audits' },
    { key: 'thorough', header: 'Thorough' },
    { key: 'avg_completion_pct', header: 'Avg Completion %' },
    { key: 'avg_blank_entries', header: 'Avg Blank Entries' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'pm_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'thorough', header: 'Thorough' },
    { key: 'superficial_incomplete', header: 'Superficial / Incomplete' },
    { key: 'missing_safety_test', header: 'No Safety Test' },
    { key: 'missing_measured_values', header: 'No Measured Values' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'action_status', header: 'CAPA Status' },
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
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'job_code', header: 'Job' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'pm_date', header: 'Date' },
    { key: 'quality_verdict', header: 'Verdict' },
    { key: 'supervisor_review_status', header: 'Review' },
    { key: 'completion_pct', header: 'Completion %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Preventive-Maintenance Checklist Completeness &amp; Quality Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        PM quality-assurance log — engineer &times; equipment type &times; checklist completion %
        &times; measured-value capture &times; electrical-safety &amp; calibration recording &times;
        blank / ditto-entry detection &times; time-on-site &times; supervisor review &amp; CAPA
        closure. Founder-gated view: quality verdicts, engineer scorecards, root-cause pareto, and
        risk-impact digest to catch superficial or falsification-suspected PM jobs before they reach
        patients.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Quality verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No PM audits logged yet."
          rowKey={(r, i) => String(r.quality_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer quality scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; region matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by equipment and region."
          rowKey={(r, i) => `${r.equipment_type}-${r.region}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily PM-quality trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.pm_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.action_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk PM queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk PM jobs."
          rowKey={(r, i) => `${r.job_code}-${r.pm_date}-${i}`}
        />
      </section>
    </main>
  );
}
