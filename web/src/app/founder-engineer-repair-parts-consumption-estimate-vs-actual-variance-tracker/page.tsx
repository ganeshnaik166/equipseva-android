import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ReasonRow = { variance_reason: string; repairs: number; pct: number };
type CategoryRow = {
  part_category: string;
  total_repairs: number;
  accurate: number;
  under_estimated: number;
  over_estimated: number;
  avg_qty_variance: number;
  avg_cost_variance_pct: number;
  total_cost_variance_rupees: number;
};
type MatrixRow = {
  part_category: string;
  variance_reason: string;
  repairs: number;
  avg_qty_variance: number;
  avg_cost_variance_pct: number;
};
type TrendRow = {
  repair_month: string;
  repairs: number;
  under_estimated: number;
  over_estimated: number;
  avg_cost_variance_pct: number;
  total_cost_variance_rupees: number;
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
  impact_band: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  engineer_name: string;
  ticket_code: string;
  device_model: string;
  part_category: string;
  repair_date: string;
  variance_reason: string;
  qty_variance: number;
  cost_variance_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    reasonRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3568_variance_reason_rollup'),
    supabase.rpc('founder_r3568_part_category_scorecard'),
    supabase.rpc('founder_r3568_category_reason_matrix'),
    supabase.rpc('founder_r3568_monthly_variance_trend'),
    supabase.rpc('founder_r3568_capa_status_board'),
    supabase.rpc('founder_r3568_root_cause_pareto'),
    supabase.rpc('founder_r3568_cost_variance_impact_digest'),
    supabase.rpc('founder_r3568_high_risk_queue'),
  ]);

  const reasonRows: ReasonRow[] = (reasonRes.data as ReasonRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const reasonCols: Column<ReasonRow>[] = [
    { key: 'variance_reason', header: 'Variance Reason' },
    { key: 'repairs', header: 'Repairs' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'part_category', header: 'Part Category' },
    { key: 'total_repairs', header: 'Repairs' },
    { key: 'accurate', header: 'Accurate' },
    { key: 'under_estimated', header: 'Under-Est' },
    { key: 'over_estimated', header: 'Over-Est' },
    { key: 'avg_qty_variance', header: 'Avg Qty Var' },
    { key: 'avg_cost_variance_pct', header: 'Avg Cost Var %' },
    { key: 'total_cost_variance_rupees', header: 'Total Cost Var (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'part_category', header: 'Part Category' },
    { key: 'variance_reason', header: 'Variance Reason' },
    { key: 'repairs', header: 'Repairs' },
    { key: 'avg_qty_variance', header: 'Avg Qty Var' },
    { key: 'avg_cost_variance_pct', header: 'Avg Cost Var %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'repair_month', header: 'Month' },
    { key: 'repairs', header: 'Repairs' },
    { key: 'under_estimated', header: 'Under-Est' },
    { key: 'over_estimated', header: 'Over-Est' },
    { key: 'avg_cost_variance_pct', header: 'Avg Cost Var %' },
    { key: 'total_cost_variance_rupees', header: 'Total Cost Var (INR)' },
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
    { key: 'impact_band', header: 'Impact Band' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'ticket_code', header: 'Ticket' },
    { key: 'device_model', header: 'Device' },
    { key: 'part_category', header: 'Category' },
    { key: 'repair_date', header: 'Date' },
    { key: 'variance_reason', header: 'Reason' },
    { key: 'qty_variance', header: 'Qty Var' },
    { key: 'cost_variance_pct', header: 'Cost Var %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Repair Parts-Consumption Estimate-vs-Actual Variance Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Repair parts consumption estimated-at-diagnosis vs actual-consumed variance (quote accuracy) —
        engineer &times; hospital &times; ticket &times; device model &times; part category &times;
        estimated/actual quantity &times; estimated/actual cost &times; cost-variance % &times;
        variance reason (under-estimated, over-estimated, scope change, additional fault, no-fault-found,
        accurate) &amp; CAPA closure. Founder-gated view: variance-reason mix, part-category scorecards,
        root-cause pareto, and cost-variance impact digest across the field-service repair book.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Variance-reason distribution</h2>
        <DataTable
          rows={reasonRows}
          columns={reasonCols}
          emptyMessage="No repair variance rows logged yet."
          rowKey={(r, i) => String(r.variance_reason ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Part-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No part-category rollups."
          rowKey={(r, i) => String(r.part_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Part category &times; variance reason matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No repairs by part category."
          rowKey={(r, i) => `${r.part_category}-${r.variance_reason}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly variance trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.repair_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cost-variance impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact-band rollups."
          rowKey={(r, i) => String(r.impact_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk variance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk variance rows."
          rowKey={(r, i) => `${r.ticket_code}-${r.repair_date}-${i}`}
        />
      </section>
    </main>
  );
}
