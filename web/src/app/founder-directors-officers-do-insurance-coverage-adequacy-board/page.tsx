import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { adequacy_status: string; entities: number; pct: number };
type EntityRow = {
  entity_name: string;
  policies: number;
  avg_coverage_limit_rupees: number | null;
  avg_peer_benchmark_limit_rupees: number | null;
  avg_coverage_gap_pct: number | null;
  total_claims_filed: number;
  total_claims_paid_rupees: number;
  underinsured_count: number;
  avg_key_exclusions_flagged: number | null;
};
type MatrixRow = {
  entity_class: string;
  adequacy_status: string;
  entities: number;
  avg_coverage_gap_pct: number | null;
  total_claims_paid_rupees: number;
};
type TrendRow = {
  period_month: string;
  entities: number;
  avg_coverage_gap_pct: number | null;
  total_premium_rupees: number;
  total_claims_paid_rupees: number;
  underinsured_count: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type ExclusionRow = {
  entity_class: string;
  entities: number;
  total_key_exclusions_flagged: number;
  avg_key_exclusions_flagged: number | null;
  high_exclusion_entities: number;
};
type RiskRow = {
  entity_name: string;
  entity_class: string;
  policy_year: string;
  period_month: string;
  adequacy_status: string;
  coverage_limit_rupees: number | null;
  peer_benchmark_limit_rupees: number | null;
  coverage_gap_pct: number | null;
  claims_filed: number | null;
  key_exclusions_flagged: number | null;
  renewal_due_date: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    entityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exclusionRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3740_adequacy_status_rollup'),
    supabase.rpc('founder_r3740_entity_scorecard'),
    supabase.rpc('founder_r3740_entity_class_status_matrix'),
    supabase.rpc('founder_r3740_monthly_coverage_gap_trend'),
    supabase.rpc('founder_r3740_capa_status_board'),
    supabase.rpc('founder_r3740_root_cause_pareto'),
    supabase.rpc('founder_r3740_exclusion_digest'),
    supabase.rpc('founder_r3740_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exclusionRows: ExclusionRow[] = (exclusionRes.data as ExclusionRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'adequacy_status', header: 'Adequacy Status' },
    { key: 'entities', header: 'Entities' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'policies', header: 'Policies' },
    { key: 'avg_coverage_limit_rupees', header: 'Avg Coverage Limit (INR)' },
    { key: 'avg_peer_benchmark_limit_rupees', header: 'Avg Peer Benchmark (INR)' },
    { key: 'avg_coverage_gap_pct', header: 'Avg Coverage Gap %' },
    { key: 'total_claims_filed', header: 'Claims Filed' },
    { key: 'total_claims_paid_rupees', header: 'Claims Paid (INR)' },
    { key: 'underinsured_count', header: 'Underinsured Periods' },
    { key: 'avg_key_exclusions_flagged', header: 'Avg Exclusions Flagged' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'entity_class', header: 'Entity Class' },
    { key: 'adequacy_status', header: 'Adequacy Status' },
    { key: 'entities', header: 'Entities' },
    { key: 'avg_coverage_gap_pct', header: 'Avg Coverage Gap %' },
    { key: 'total_claims_paid_rupees', header: 'Claims Paid (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entities', header: 'Entities' },
    { key: 'avg_coverage_gap_pct', header: 'Avg Coverage Gap %' },
    { key: 'total_premium_rupees', header: 'Total Premium (INR)' },
    { key: 'total_claims_paid_rupees', header: 'Claims Paid (INR)' },
    { key: 'underinsured_count', header: 'Underinsured' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const exclusionCols: Column<ExclusionRow>[] = [
    { key: 'entity_class', header: 'Entity Class' },
    { key: 'entities', header: 'Entities' },
    { key: 'total_key_exclusions_flagged', header: 'Total Exclusions Flagged' },
    { key: 'avg_key_exclusions_flagged', header: 'Avg Exclusions Flagged' },
    { key: 'high_exclusion_entities', header: 'High-Exclusion Entities (3+)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'entity_class', header: 'Entity Class' },
    { key: 'policy_year', header: 'Policy Year' },
    { key: 'period_month', header: 'Month' },
    { key: 'adequacy_status', header: 'Adequacy Status' },
    { key: 'coverage_limit_rupees', header: 'Coverage Limit (INR)' },
    { key: 'peer_benchmark_limit_rupees', header: 'Peer Benchmark (INR)' },
    { key: 'coverage_gap_pct', header: 'Coverage Gap %' },
    { key: 'claims_filed', header: 'Claims Filed' },
    { key: 'key_exclusions_flagged', header: 'Exclusions Flagged' },
    { key: 'renewal_due_date', header: 'Renewal Due' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Directors &amp; Officers (D&amp;O) Insurance Coverage Adequacy Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        D&amp;O liability insurance coverage adequacy across entities and subsidiaries — entity
        &times; policy year &times; period month &times; coverage limit vs peer benchmark &times;
        premium &amp; deductible &times; claims history &times; key exclusions flagged &times;
        renewal runway &amp; CAPA closure. Founder-gated view: adequacy-status distribution,
        entity scorecards, entity-class &times; status matrix, monthly coverage-gap trend,
        exclusion digest, and a high-risk queue of underinsured &amp; claim-impacted policies.
        Distinct from the insurance-broker performance scorecard, which tracks broker service
        quality rather than D&amp;O coverage adequacy itself.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Adequacy-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No D&O coverage rows logged yet."
          rowKey={(r, i) => String(r.adequacy_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity coverage scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Entity class &times; adequacy status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entities by class."
          rowKey={(r, i) => `${r.entity_class}-${r.adequacy_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly coverage-gap trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Exclusion digest by entity class</h2>
        <DataTable
          rows={exclusionRows}
          columns={exclusionCols}
          emptyMessage="No exclusion rollups."
          rowKey={(r, i) => String(r.entity_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk coverage queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk D&O policies."
          rowKey={(r, i) => `${r.entity_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
