import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { esg_verdict: string; metrics: number; pct: number };
type PillarRow = {
  esg_pillar: string;
  total_metrics: number;
  on_track: number;
  ahead: number;
  behind: number;
  data_gap: number;
  disclosure_ready: number;
  avg_variance_pct: number;
  on_track_pct: number;
};
type MatrixRow = {
  metric_name: string;
  period_quarter: string;
  metrics: number;
  on_track: number;
  behind: number;
  avg_variance_pct: number;
};
type TrendRow = {
  period_quarter: string;
  metrics: number;
  on_track: number;
  behind: number;
  data_gap: number;
  disclosure_ready: number;
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
type ImpactRow = {
  disclosure_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  metric_name: string;
  esg_pillar: string;
  period_quarter: string;
  esg_verdict: string;
  data_quality: string | null;
  materiality: string | null;
  brsr_disclosure_ready: boolean | null;
  variance_vs_target_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    pillarRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3409_esg_verdict_rollup'),
    supabase.rpc('founder_r3409_pillar_scorecard'),
    supabase.rpc('founder_r3409_metric_quarter_matrix'),
    supabase.rpc('founder_r3409_quarterly_trend'),
    supabase.rpc('founder_r3409_capa_status_board'),
    supabase.rpc('founder_r3409_root_cause_pareto'),
    supabase.rpc('founder_r3409_disclosure_impact_digest'),
    supabase.rpc('founder_r3409_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const pillarRows: PillarRow[] = (pillarRes.data as PillarRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'esg_verdict', header: 'ESG Verdict' },
    { key: 'metrics', header: 'Metrics' },
    { key: 'pct', header: 'Share %' },
  ];

  const pillarCols: Column<PillarRow>[] = [
    { key: 'esg_pillar', header: 'Pillar' },
    { key: 'total_metrics', header: 'Metrics' },
    { key: 'on_track', header: 'On Track / Ahead' },
    { key: 'ahead', header: 'Ahead' },
    { key: 'behind', header: 'Behind' },
    { key: 'data_gap', header: 'Data / Disclosure Gap' },
    { key: 'disclosure_ready', header: 'BRSR Ready' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
    { key: 'on_track_pct', header: 'On Track %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'metric_name', header: 'Metric' },
    { key: 'period_quarter', header: 'Quarter' },
    { key: 'metrics', header: 'Metrics' },
    { key: 'on_track', header: 'On Track' },
    { key: 'behind', header: 'At Risk' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_quarter', header: 'Quarter' },
    { key: 'metrics', header: 'Metrics' },
    { key: 'on_track', header: 'On Track' },
    { key: 'behind', header: 'Behind' },
    { key: 'data_gap', header: 'Data / Disclosure Gap' },
    { key: 'disclosure_ready', header: 'BRSR Ready' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'disclosure_impact', header: 'Disclosure Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Site' },
    { key: 'metric_name', header: 'Metric' },
    { key: 'esg_pillar', header: 'Pillar' },
    { key: 'period_quarter', header: 'Quarter' },
    { key: 'esg_verdict', header: 'Verdict' },
    { key: 'data_quality', header: 'Data Quality' },
    { key: 'materiality', header: 'Materiality' },
    { key: 'brsr_disclosure_ready', header: 'BRSR Ready' },
    { key: 'variance_vs_target_pct', header: 'Variance %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder ESG BRSR Carbon-Accounting &amp; Sustainability Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Business Responsibility &amp; Sustainability Reporting (BRSR) governance — ESG pillar
        (environment / social / governance) &times; metric (Scope 1/2/3 emissions tCO2e, energy
        intensity, water usage, e-waste recycled, diversity ratio, safety LTIFR, board independence,
        supplier ESG screened) &times; period quarter &times; current vs target value &times; variance
        &times; trend &times; data quality (verified / estimated / unverified) &times; BRSR disclosure
        readiness &times; materiality &amp; CAPA closure. Founder-gated view: ESG verdicts, pillar
        scorecards, root-cause pareto, and disclosure-impact digest across SEBI BRSR &amp; investor
        ESG surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. ESG verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No ESG metrics logged yet."
          rowKey={(r, i) => String(r.esg_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. ESG pillar scorecard</h2>
        <DataTable
          rows={pillarRows}
          columns={pillarCols}
          emptyMessage="No pillar rollups."
          rowKey={(r, i) => String(r.esg_pillar ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Metric &times; quarter matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No metrics by quarter."
          rowKey={(r, i) => `${r.metric_name}-${r.period_quarter}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Quarterly ESG trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_quarter ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Disclosure impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No disclosure-impact rollups."
          rowKey={(r, i) => String(r.disclosure_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk ESG queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk metrics."
          rowKey={(r, i) => `${r.hospital_name}-${r.metric_name}-${r.period_quarter}-${i}`}
        />
      </section>
    </main>
  );
}
