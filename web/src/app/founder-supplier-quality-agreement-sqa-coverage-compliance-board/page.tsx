import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { sqa_status: string; suppliers: number; pct: number };
type CategoryRow = {
  supply_category: string;
  suppliers: number;
  signed_cnt: number;
  unsigned_cnt: number;
  expired_cnt: number;
  renewal_due_cnt: number;
  avg_spend_covered_pct: number;
  total_open_deviations: number;
};
type MatrixRow = {
  criticality: string;
  sqa_status: string;
  suppliers: number;
  avg_spend_covered_pct: number;
  open_deviations: number;
};
type TrendRow = {
  period_month: string;
  suppliers: number;
  signed_cnt: number;
  unsigned_cnt: number;
  expired_cnt: number;
  avg_spend_covered_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_spend_at_risk_lakh: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_spend_at_risk_lakh: number;
  pct: number;
};
type GapRow = {
  gap_category: string;
  actions: number;
  open_actions: number;
  total_spend_at_risk_lakh: number;
};
type RiskRow = {
  supplier_code: string;
  supplier_name: string;
  supply_category: string;
  period_month: string;
  criticality: string;
  sqa_status: string;
  days_to_expiry: number | null;
  spend_covered_pct: number | null;
  open_deviations: number | null;
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
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3656_sqa_status_rollup'),
    supabase.rpc('founder_r3656_supply_category_scorecard'),
    supabase.rpc('founder_r3656_criticality_status_matrix'),
    supabase.rpc('founder_r3656_monthly_coverage_trend'),
    supabase.rpc('founder_r3656_capa_status_board'),
    supabase.rpc('founder_r3656_root_cause_pareto'),
    supabase.rpc('founder_r3656_coverage_gap_digest'),
    supabase.rpc('founder_r3656_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'sqa_status', header: 'SQA Status' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'supply_category', header: 'Supply Category' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'signed_cnt', header: 'Signed' },
    { key: 'unsigned_cnt', header: 'Unsigned / Negotiating' },
    { key: 'expired_cnt', header: 'Expired' },
    { key: 'renewal_due_cnt', header: 'Renewal Due' },
    { key: 'avg_spend_covered_pct', header: 'Avg Spend Covered %' },
    { key: 'total_open_deviations', header: 'Open Deviations' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'criticality', header: 'Criticality' },
    { key: 'sqa_status', header: 'SQA Status' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'avg_spend_covered_pct', header: 'Avg Spend Covered %' },
    { key: 'open_deviations', header: 'Open Deviations' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'signed_cnt', header: 'Signed' },
    { key: 'unsigned_cnt', header: 'Unsigned / Negotiating' },
    { key: 'expired_cnt', header: 'Expired' },
    { key: 'avg_spend_covered_pct', header: 'Avg Spend Covered %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_spend_at_risk_lakh', header: 'Avg Spend at Risk (Lakh)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_spend_at_risk_lakh', header: 'Total Spend at Risk (Lakh)' },
    { key: 'pct', header: 'Share %' },
  ];

  const gapCols: Column<GapRow>[] = [
    { key: 'gap_category', header: 'Coverage Gap' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_spend_at_risk_lakh', header: 'Total Spend at Risk (Lakh)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'supplier_code', header: 'Code' },
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'supply_category', header: 'Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'sqa_status', header: 'SQA Status' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'spend_covered_pct', header: 'Spend Covered %' },
    { key: 'open_deviations', header: 'Open Deviations' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Supplier Quality-Agreement (SQA) Coverage &amp; Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Supplier quality-agreement coverage and currency per critical supplier — SQA signed
        &times; effective / expiry currency &times; days-to-expiry &times; change-notification
        clause &times; audit-rights clause &times; spend covered % &times; open deviations
        &times; criticality &amp; CAPA closure. Founder-gated view: SQA status rollup,
        supply-category scorecards, criticality &times; status matrix, monthly coverage trend,
        root-cause pareto, and the unsigned / expired high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. SQA status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No SQA records logged yet."
          rowKey={(r, i) => String(r.sqa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Supply-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No supply-category rollups."
          rowKey={(r, i) => String(r.supply_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Criticality &times; SQA-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.criticality}-${r.sqa_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly coverage trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Coverage-gap digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No coverage-gap rollups."
          rowKey={(r, i) => String(r.gap_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk supplier queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk suppliers."
          rowKey={(r, i) => `${r.supplier_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
