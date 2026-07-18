import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  continuity_verdict: string;
  roles: number;
  spof_roles: number;
  pct: number;
};
type EntityRow = {
  entity_name: string;
  total_roles: number;
  mission_critical: number;
  vulnerable: number;
  spof_roles: number;
  avg_knowledge_documented_pct: number;
  avg_bus_factor: number;
};
type MatrixRow = {
  function_area: string;
  criticality: string;
  roles: number;
  spof_roles: number;
  avg_knowledge_documented_pct: number;
};
type TrendRow = {
  last_review_date: string;
  roles: number;
  vulnerable: number;
  spof_roles: number;
  avg_knowledge_documented_pct: number;
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
  business_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  entity_name: string;
  role_title: string;
  incumbent_name: string;
  function_area: string;
  criticality: string;
  bus_factor: number;
  successor_readiness: string;
  retention_risk: string;
  continuity_verdict: string;
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
    supabase.rpc('founder_r3265_continuity_verdict_rollup'),
    supabase.rpc('founder_r3265_entity_scorecard'),
    supabase.rpc('founder_r3265_function_criticality_matrix'),
    supabase.rpc('founder_r3265_review_trend'),
    supabase.rpc('founder_r3265_capa_status_board'),
    supabase.rpc('founder_r3265_root_cause_pareto'),
    supabase.rpc('founder_r3265_business_impact_digest'),
    supabase.rpc('founder_r3265_high_risk_queue'),
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
    { key: 'continuity_verdict', header: 'Continuity Verdict' },
    { key: 'roles', header: 'Roles' },
    { key: 'spof_roles', header: 'Single Points of Failure' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity / Hospital Account' },
    { key: 'total_roles', header: 'Roles' },
    { key: 'mission_critical', header: 'Mission-Critical' },
    { key: 'vulnerable', header: 'Vulnerable' },
    { key: 'spof_roles', header: 'SPOF' },
    { key: 'avg_knowledge_documented_pct', header: 'Avg Docs %' },
    { key: 'avg_bus_factor', header: 'Avg Bus Factor' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'function_area', header: 'Function' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'roles', header: 'Roles' },
    { key: 'spof_roles', header: 'SPOF' },
    { key: 'avg_knowledge_documented_pct', header: 'Avg Docs %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'last_review_date', header: 'Review Date' },
    { key: 'roles', header: 'Roles' },
    { key: 'vulnerable', header: 'Vulnerable' },
    { key: 'spof_roles', header: 'SPOF' },
    { key: 'avg_knowledge_documented_pct', header: 'Avg Docs %' },
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
    { key: 'business_impact', header: 'Business Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'role_title', header: 'Role' },
    { key: 'incumbent_name', header: 'Incumbent' },
    { key: 'function_area', header: 'Function' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'bus_factor', header: 'Bus Factor' },
    { key: 'successor_readiness', header: 'Successor' },
    { key: 'retention_risk', header: 'Retention Risk' },
    { key: 'continuity_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Key-Person Succession &amp; Business-Continuity Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Key-person risk register — critical role &times; incumbent &times; function &times;
        criticality &times; bus-factor &times; successor readiness &times; knowledge-documentation %
        &times; single-point-of-failure &times; retention risk &times; cross-training &amp;
        continuity CAPA. Founder-gated view: continuity verdicts, entity scorecards, function &times;
        criticality matrix, root-cause pareto and business-impact digest across the EquipSeva
        leadership bench.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Continuity verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No key-person records yet."
          rowKey={(r, i) => String(r.continuity_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity succession scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Function &times; criticality matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No roles by function."
          rowKey={(r, i) => `${r.function_area}-${r.criticality}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Succession-review trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No review-trend data."
          rowKey={(r, i) => String(r.last_review_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Business-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No business-impact rollups."
          rowKey={(r, i) => String(r.business_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk key-person queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk roles."
          rowKey={(r, i) => `${r.incumbent_name}-${r.role_title}-${i}`}
        />
      </section>
    </main>
  );
}
