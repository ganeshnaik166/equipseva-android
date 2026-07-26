import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { variance_verdict: string; entries: number; pct: number };
type ScorecardRow = {
  lever_category: string;
  entries: number;
  favorable: number;
  neutral: number;
  unfavorable: number;
  accretive: number;
  total_lever_effect_rupees: number;
  avg_margin_pct: number;
  avg_target_margin_pct: number;
};
type MatrixRow = {
  lever_category: string;
  impact_direction: string;
  entries: number;
  total_lever_effect_rupees: number;
  favorable: number;
  unfavorable: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_base_ebitda_rupees: number;
  total_lever_effect_rupees: number;
  total_actual_ebitda_rupees: number;
  avg_margin_pct: number;
  unfavorable: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_ebitda_at_risk_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_ebitda_at_risk_rupees: number;
  pct: number;
};
type ImpactRow = {
  impact_direction: string;
  entries: number;
  total_lever_effect_rupees: number;
  avg_margin_pct: number;
  unfavorable: number;
  worsening: number;
};
type RiskRow = {
  business_unit: string;
  bridge_ref: string;
  cost_lever: string;
  lever_category: string;
  period_month: string;
  variance_verdict: string;
  impact_direction: string;
  trend_dir: string;
  lever_effect_rupees: number;
  ebitda_margin_pct: number | null;
  target_margin_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    scorecardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3477_variance_verdict_rollup'),
    supabase.rpc('founder_r3477_lever_category_scorecard'),
    supabase.rpc('founder_r3477_lever_impact_matrix'),
    supabase.rpc('founder_r3477_monthly_ebitda_trend'),
    supabase.rpc('founder_r3477_capa_status_board'),
    supabase.rpc('founder_r3477_root_cause_pareto'),
    supabase.rpc('founder_r3477_ebitda_impact_digest'),
    supabase.rpc('founder_r3477_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'variance_verdict', header: 'Variance Verdict' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'lever_category', header: 'Lever Category' },
    { key: 'entries', header: 'Entries' },
    { key: 'favorable', header: 'Favorable' },
    { key: 'neutral', header: 'Neutral' },
    { key: 'unfavorable', header: 'Unfavorable' },
    { key: 'accretive', header: 'Accretive' },
    { key: 'total_lever_effect_rupees', header: 'Total Lever Effect (INR)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'avg_target_margin_pct', header: 'Avg Target %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'lever_category', header: 'Lever Category' },
    { key: 'impact_direction', header: 'Impact Direction' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_lever_effect_rupees', header: 'Total Lever Effect (INR)' },
    { key: 'favorable', header: 'Favorable' },
    { key: 'unfavorable', header: 'Unfavorable' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_base_ebitda_rupees', header: 'Base EBITDA (INR)' },
    { key: 'total_lever_effect_rupees', header: 'Lever Effect (INR)' },
    { key: 'total_actual_ebitda_rupees', header: 'Actual EBITDA (INR)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'unfavorable', header: 'Unfavorable' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_ebitda_at_risk_rupees', header: 'EBITDA at Risk (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_ebitda_at_risk_rupees', header: 'EBITDA at Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'impact_direction', header: 'Impact Direction' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_lever_effect_rupees', header: 'Total Lever Effect (INR)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'unfavorable', header: 'Unfavorable' },
    { key: 'worsening', header: 'Worsening' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'bridge_ref', header: 'Ref' },
    { key: 'cost_lever', header: 'Cost Lever' },
    { key: 'lever_category', header: 'Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'variance_verdict', header: 'Verdict' },
    { key: 'impact_direction', header: 'Impact' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'lever_effect_rupees', header: 'Lever Effect (INR)' },
    { key: 'ebitda_margin_pct', header: 'Margin %' },
    { key: 'target_margin_pct', header: 'Target %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        EBITDA Margin-Bridge / Cost-Lever Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder EBITDA margin bridge &mdash; decompose each month&apos;s EBITDA change into
        revenue &amp; cost-lever effects across business units. Lever category (revenue growth,
        price, COGS, opex, headcount, one-time) &times; impact direction (accretive &lt; neutral
        &lt; dilutive) &times; variance verdict &times; trend &times; base / lever / actual EBITDA
        &amp; margin vs target &amp; CAPA closure. Founder-gated view: verdict distribution, lever
        scorecards, root-cause pareto, and the high-risk queue where variance is unfavorable,
        impact is dilutive, or the trend is worsening.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Variance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No bridge entries logged yet."
          rowKey={(r, i) => String(r.variance_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Lever category scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No lever-category rollups."
          rowKey={(r, i) => String(r.lever_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Lever category &times; impact direction matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by lever category."
          rowKey={(r, i) => `${r.lever_category}-${r.impact_direction}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly EBITDA trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. EBITDA-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact-direction rollups."
          rowKey={(r, i) => String(r.impact_direction ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk cost-lever queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk levers."
          rowKey={(r, i) => `${r.bridge_ref}-${i}`}
        />
      </section>
    </main>
  );
}
