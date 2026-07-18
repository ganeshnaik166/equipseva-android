import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { delivery_verdict: string; features: number; pct: number };
type EntityRow = {
  committed_to_entity: string;
  total_features: number;
  on_time_count: number;
  late_count: number;
  at_risk_count: number;
  scope_cuts: number;
  avg_slip_days: number;
  on_time_pct: number;
};
type MatrixRow = {
  committed_quarter: string;
  feature_area: string;
  features: number;
  late_or_slipped: number;
  avg_slip_days: number;
};
type TrendRow = {
  plan_month: string;
  features: number;
  shipped: number;
  late: number;
  avg_slip_days: number;
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
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  committed_to_entity: string;
  feature_code: string;
  feature_name: string;
  committed_quarter: string;
  committed_to: string;
  planned_ship_date: string;
  slip_days: number | null;
  delivery_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    entityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3213_delivery_verdict_rollup'),
    supabase.rpc('founder_r3213_entity_scorecard'),
    supabase.rpc('founder_r3213_quarter_area_matrix'),
    supabase.rpc('founder_r3213_monthly_slip_trend'),
    supabase.rpc('founder_r3213_capa_status_board'),
    supabase.rpc('founder_r3213_root_cause_pareto'),
    supabase.rpc('founder_r3213_commitment_impact_digest'),
    supabase.rpc('founder_r3213_high_risk_commitments'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'delivery_verdict', header: 'Verdict' },
    { key: 'features', header: 'Features' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'committed_to_entity', header: 'Committed To' },
    { key: 'total_features', header: 'Features' },
    { key: 'on_time_count', header: 'On Time' },
    { key: 'late_count', header: 'Late' },
    { key: 'at_risk_count', header: 'At Risk / Slipped' },
    { key: 'scope_cuts', header: 'Scope Cuts' },
    { key: 'avg_slip_days', header: 'Avg Slip Days' },
    { key: 'on_time_pct', header: 'On-Time %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'committed_quarter', header: 'Quarter' },
    { key: 'feature_area', header: 'Feature Area' },
    { key: 'features', header: 'Features' },
    { key: 'late_or_slipped', header: 'Late / Slipped' },
    { key: 'avg_slip_days', header: 'Avg Slip Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'plan_month', header: 'Planned Month' },
    { key: 'features', header: 'Features' },
    { key: 'shipped', header: 'Shipped' },
    { key: 'late', header: 'Late' },
    { key: 'avg_slip_days', header: 'Avg Slip Days' },
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
    { key: 'regulatory_impact', header: 'Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'committed_to_entity', header: 'Committed To' },
    { key: 'feature_code', header: 'Code' },
    { key: 'feature_name', header: 'Feature' },
    { key: 'committed_quarter', header: 'Quarter' },
    { key: 'committed_to', header: 'Channel' },
    { key: 'planned_ship_date', header: 'Planned' },
    { key: 'slip_days', header: 'Slip Days' },
    { key: 'delivery_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Product-Roadmap Commitment vs Delivery Slippage Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Roadmap commitment log — feature × committed quarter × committed-to × planned vs shipped ×
        slip days × scope-cut &amp; CAPA recovery. Founder-gated view: delivery verdicts, entity
        scorecards, quarter &amp; area matrix, root-cause pareto, and commitment-impact digest across
        customer, board &amp; regulatory promises.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Delivery verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No roadmap commitments logged yet."
          rowKey={(r, i) => String(r.delivery_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Committed-to entity scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.committed_to_entity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Quarter × feature-area matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No commitments by quarter."
          rowKey={(r, i) => `${r.committed_quarter}-${r.feature_area}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly slip trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.plan_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Commitment impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk commitments queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk commitments."
          rowKey={(r, i) => `${r.feature_code}-${i}`}
        />
      </section>
    </main>
  );
}
