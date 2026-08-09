import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { esg_status: string; suppliers: number; pct: number };
type CategoryRow = {
  supply_category: string;
  total_suppliers: number;
  assessed: number;
  leaders: number;
  compliant: number;
  improvement_needed: number;
  high_risk: number;
  avg_overall_score: number;
  open_corrective_plans: number;
};
type MatrixRow = {
  criticality: string;
  esg_status: string;
  suppliers: number;
  avg_overall_score: number;
  avg_env_score: number;
};
type TrendRow = {
  period_month: string;
  suppliers: number;
  assessed: number;
  avg_env_score: number;
  avg_social_score: number;
  avg_governance_score: number;
  avg_overall_score: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RiskAreaRow = {
  esg_risk_area: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type QueueRow = {
  supplier_code: string;
  supplier_name: string;
  supply_category: string;
  criticality: string;
  esg_status: string;
  trend_dir: string;
  overall_esg_score: number | null;
  corrective_plans_open: number;
  reassessment_due: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    riskAreaRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3710_esg_status_rollup'),
    supabase.rpc('founder_r3710_supply_category_scorecard'),
    supabase.rpc('founder_r3710_criticality_status_matrix'),
    supabase.rpc('founder_r3710_monthly_score_trend'),
    supabase.rpc('founder_r3710_capa_status_board'),
    supabase.rpc('founder_r3710_root_cause_pareto'),
    supabase.rpc('founder_r3710_risk_digest'),
    supabase.rpc('founder_r3710_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const riskAreaRows: RiskAreaRow[] = (riskAreaRes.data as RiskAreaRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'esg_status', header: 'ESG Status' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'supply_category', header: 'Supply Category' },
    { key: 'total_suppliers', header: 'Suppliers' },
    { key: 'assessed', header: 'Assessed' },
    { key: 'leaders', header: 'Leaders' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'improvement_needed', header: 'Improvement Needed' },
    { key: 'high_risk', header: 'High Risk' },
    { key: 'avg_overall_score', header: 'Avg Overall Score' },
    { key: 'open_corrective_plans', header: 'Open Plans' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'criticality', header: 'Criticality' },
    { key: 'esg_status', header: 'ESG Status' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'avg_overall_score', header: 'Avg Overall Score' },
    { key: 'avg_env_score', header: 'Avg Env Score' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'assessed', header: 'Assessed' },
    { key: 'avg_env_score', header: 'Avg Env' },
    { key: 'avg_social_score', header: 'Avg Social' },
    { key: 'avg_governance_score', header: 'Avg Governance' },
    { key: 'avg_overall_score', header: 'Avg Overall' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const riskAreaCols: Column<RiskAreaRow>[] = [
    { key: 'esg_risk_area', header: 'ESG Risk Area' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'supplier_code', header: 'Code' },
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'supply_category', header: 'Category' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'esg_status', header: 'ESG Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'overall_esg_score', header: 'Overall Score' },
    { key: 'corrective_plans_open', header: 'Open Plans' },
    { key: 'reassessment_due', header: 'Reassessment Due' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Supplier ESG / Sustainability Assessment Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Supplier-level ESG / sustainability assessments — environmental &times; social &times;
        governance scores per critical supplier, child-labor &amp; conflict-minerals declarations,
        criticality tiers, score trends &amp; CAPA remediation. Founder-gated view: ESG status
        distribution, supply-category scorecards, criticality &times; status matrix, monthly score
        trend, root-cause pareto, risk-area digest, and the high-risk / not-assessed supplier queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. ESG status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No supplier ESG assessments logged yet."
          rowKey={(r, i) => String(r.esg_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Supply-category ESG scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No supply-category rollups."
          rowKey={(r, i) => String(r.supply_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Criticality &times; ESG status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No suppliers by criticality."
          rowKey={(r, i) => `${r.criticality}-${r.esg_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly ESG score trend</h2>
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
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. ESG risk-area digest</h2>
        <DataTable
          rows={riskAreaRows}
          columns={riskAreaCols}
          emptyMessage="No risk-area rollups."
          rowKey={(r, i) => String(r.esg_risk_area ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk / not-assessed queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk suppliers."
          rowKey={(r, i) => `${r.supplier_code}-${i}`}
        />
      </section>
    </main>
  );
}
