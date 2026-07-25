import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type CatRow = {
  copq_category: string;
  cost_items: number;
  total_cost_rupees: number;
  avg_pct_of_revenue: number;
  preventable_items: number;
  pct: number;
};
type DeptRow = {
  department: string;
  cost_items: number;
  total_cost_rupees: number;
  internal_failure_rupees: number;
  external_failure_rupees: number;
  appraisal_rupees: number;
  prevention_rupees: number;
  preventable_items: number;
};
type MatrixRow = {
  copq_category: string;
  cost_driver: string;
  cost_items: number;
  total_cost_rupees: number;
  preventable_items: number;
};
type TrendRow = {
  period_month: string;
  cost_items: number;
  total_cost_rupees: number;
  failure_rupees: number;
  appraisal_rupees: number;
  prevention_rupees: number;
  external_failure_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_impact_rupees: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  cost_driver: string;
  cost_items: number;
  total_cost_rupees: number;
  external_failure_rupees: number;
  preventable_rupees: number;
  avg_pct_of_revenue: number;
};
type RiskRow = {
  cost_item: string;
  cost_code: string;
  copq_category: string;
  cost_driver: string;
  department: string;
  cost_rupees: number;
  pct_of_revenue: number;
  period_month: string;
  cost_trend: string;
  preventable: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    catRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3433_copq_category_rollup'),
    supabase.rpc('founder_r3433_department_scorecard'),
    supabase.rpc('founder_r3433_category_driver_matrix'),
    supabase.rpc('founder_r3433_monthly_copq_trend'),
    supabase.rpc('founder_r3433_capa_status_board'),
    supabase.rpc('founder_r3433_root_cause_pareto'),
    supabase.rpc('founder_r3433_financial_impact_digest'),
    supabase.rpc('founder_r3433_high_risk_queue'),
  ]);

  const catRows: CatRow[] = (catRes.data as CatRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const catCols: Column<CatRow>[] = [
    { key: 'copq_category', header: 'COPQ Category' },
    { key: 'cost_items', header: 'Cost Items' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'avg_pct_of_revenue', header: 'Avg % of Revenue' },
    { key: 'preventable_items', header: 'Preventable' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'cost_items', header: 'Cost Items' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'internal_failure_rupees', header: 'Internal Failure (INR)' },
    { key: 'external_failure_rupees', header: 'External Failure (INR)' },
    { key: 'appraisal_rupees', header: 'Appraisal (INR)' },
    { key: 'prevention_rupees', header: 'Prevention (INR)' },
    { key: 'preventable_items', header: 'Preventable' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'copq_category', header: 'COPQ Category' },
    { key: 'cost_driver', header: 'Cost Driver' },
    { key: 'cost_items', header: 'Cost Items' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'preventable_items', header: 'Preventable' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'cost_items', header: 'Cost Items' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'failure_rupees', header: 'Failure (INR)' },
    { key: 'appraisal_rupees', header: 'Appraisal (INR)' },
    { key: 'prevention_rupees', header: 'Prevention (INR)' },
    { key: 'external_failure_rupees', header: 'External Failure (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'cost_driver', header: 'Cost Driver' },
    { key: 'cost_items', header: 'Cost Items' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'external_failure_rupees', header: 'External Failure (INR)' },
    { key: 'preventable_rupees', header: 'Preventable (INR)' },
    { key: 'avg_pct_of_revenue', header: 'Avg % of Revenue' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'cost_item', header: 'Cost Item' },
    { key: 'cost_code', header: 'Code' },
    { key: 'copq_category', header: 'Category' },
    { key: 'cost_driver', header: 'Driver' },
    { key: 'department', header: 'Department' },
    { key: 'cost_rupees', header: 'Cost (INR)' },
    { key: 'pct_of_revenue', header: '% of Revenue' },
    { key: 'period_month', header: 'Month' },
    { key: 'cost_trend', header: 'Trend' },
    { key: 'preventable', header: 'Preventable' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Cost-of-Poor-Quality (COPQ) &mdash; Failure / Appraisal / Prevention Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated Cost-of-Poor-Quality ledger &mdash; every quality-cost line bucketed by COPQ
        category (internal failure, external failure, appraisal &amp; prevention) &times; cost driver
        (scrap, rework, warranty claims, field returns, complaint handling, re-inspection, inspection,
        training &amp; process improvement) &times; department &times; cost in rupees &times; percent of
        revenue &times; period month &times; trend &times; preventability &amp; CAPA closure. Views span
        category distribution, department scorecards, category &times; driver matrix, monthly COPQ trend,
        root-cause pareto, financial-impact digest, and a high-risk queue of the largest and rising
        external-failure costs.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. COPQ category distribution</h2>
        <DataTable
          rows={catRows}
          columns={catCols}
          emptyMessage="No quality-cost lines logged yet."
          rowKey={(r, i) => String(r.copq_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department COPQ scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; cost-driver matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No costs by category and driver."
          rowKey={(r, i) => `${r.copq_category}-${r.cost_driver}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly COPQ trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No financial-impact rollups."
          rowKey={(r, i) => String(r.cost_driver ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk COPQ queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cost lines."
          rowKey={(r, i) => `${r.cost_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
