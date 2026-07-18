import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { discipline_verdict: string; months: number; pct: number };
type EntityRow = {
  entity_name: string;
  months_tracked: number;
  total_collections_lakhs: number;
  total_gross_burn_lakhs: number;
  total_net_burn_lakhs: number;
  avg_burn_multiple: number;
  avg_variance_pct: number;
  disciplined_months: number;
};
type MatrixRow = {
  burn_category: string;
  collections_health: string;
  months: number;
  avg_net_burn_lakhs: number;
  avg_variance_pct: number;
};
type TrendRow = {
  period_month: string;
  entities: number;
  total_collections_lakhs: number;
  total_gross_burn_lakhs: number;
  total_net_burn_lakhs: number;
  avg_burn_multiple: number;
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
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  entity_name: string;
  board_ref: string;
  period_month: string;
  closing_cash_lakhs: number | null;
  runway_months: number | null;
  burn_multiple: number | null;
  variance_vs_plan_pct: number | null;
  discipline_verdict: string;
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
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3201_discipline_verdict_rollup'),
    supabase.rpc('founder_r3201_entity_scorecard'),
    supabase.rpc('founder_r3201_burn_category_matrix'),
    supabase.rpc('founder_r3201_monthly_trend'),
    supabase.rpc('founder_r3201_capa_status_board'),
    supabase.rpc('founder_r3201_root_cause_pareto'),
    supabase.rpc('founder_r3201_regulatory_impact_digest'),
    supabase.rpc('founder_r3201_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'discipline_verdict', header: 'Verdict' },
    { key: 'months', header: 'Months' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'months_tracked', header: 'Months' },
    { key: 'total_collections_lakhs', header: 'Collections (L)' },
    { key: 'total_gross_burn_lakhs', header: 'Gross Burn (L)' },
    { key: 'total_net_burn_lakhs', header: 'Net Burn (L)' },
    { key: 'avg_burn_multiple', header: 'Avg Burn Multiple' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
    { key: 'disciplined_months', header: 'Disciplined Months' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'burn_category', header: 'Burn Category' },
    { key: 'collections_health', header: 'Collections Health' },
    { key: 'months', header: 'Months' },
    { key: 'avg_net_burn_lakhs', header: 'Avg Net Burn (L)' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entities', header: 'Entities' },
    { key: 'total_collections_lakhs', header: 'Collections (L)' },
    { key: 'total_gross_burn_lakhs', header: 'Gross Burn (L)' },
    { key: 'total_net_burn_lakhs', header: 'Net Burn (L)' },
    { key: 'avg_burn_multiple', header: 'Avg Burn Multiple' },
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

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Governance Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'board_ref', header: 'Ref' },
    { key: 'period_month', header: 'Month' },
    { key: 'closing_cash_lakhs', header: 'Closing Cash (L)' },
    { key: 'runway_months', header: 'Runway (mo)' },
    { key: 'burn_multiple', header: 'Burn Multiple' },
    { key: 'variance_vs_plan_pct', header: 'Variance %' },
    { key: 'discipline_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Working-Capital Runway &amp; Burn-Discipline Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Monthly runway ledger &mdash; opening cash &times; collections &times; gross/net burn &times;
        runway months &times; burn multiple &times; variance vs plan &amp; CAPA closure. Founder-gated view:
        discipline verdicts, entity scorecards, root-cause pareto, and governance-impact digest
        across board &amp; investor-covenant surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Discipline verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No runway months logged yet."
          rowKey={(r, i) => String(r.discipline_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity runway scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Burn category &times; collections health matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No burn-category rollups."
          rowKey={(r, i) => `${r.burn_category}-${r.collections_health}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly cash &amp; burn trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Governance impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No governance-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk runway queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk months."
          rowKey={(r, i) => `${r.board_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
