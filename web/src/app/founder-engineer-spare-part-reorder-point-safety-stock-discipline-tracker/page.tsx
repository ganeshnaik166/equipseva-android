import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { stock_verdict: string; skus: number; pct: number };
type LocRow = {
  store_location: string;
  total_skus: number;
  healthy: number;
  reorder_now: number;
  below_safety: number;
  stockout: number;
  dead_stock: number;
  healthy_pct: number;
};
type MatrixRow = {
  store_location: string;
  equipment_family: string;
  skus: number;
  at_risk: number;
  avg_days_of_cover: number;
  total_stockout_days: number;
};
type TrendRow = {
  review_date: string;
  skus_reviewed: number;
  reorder_now: number;
  below_safety: number;
  stockout: number;
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
  store_location: string;
  part_sku: string;
  part_name: string;
  equipment_family: string;
  on_hand_qty: number;
  reorder_point: number;
  safety_stock: number;
  days_of_cover: number | null;
  stockout_days_last_90: number;
  abc_class: string;
  stock_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    locRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3272_stock_verdict_rollup'),
    supabase.rpc('founder_r3272_location_scorecard'),
    supabase.rpc('founder_r3272_location_family_matrix'),
    supabase.rpc('founder_r3272_daily_review_trend'),
    supabase.rpc('founder_r3272_capa_status_board'),
    supabase.rpc('founder_r3272_root_cause_pareto'),
    supabase.rpc('founder_r3272_business_impact_digest'),
    supabase.rpc('founder_r3272_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const locRows: LocRow[] = (locRes.data as LocRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'stock_verdict', header: 'Stock Verdict' },
    { key: 'skus', header: 'SKUs' },
    { key: 'pct', header: 'Share %' },
  ];

  const locCols: Column<LocRow>[] = [
    { key: 'store_location', header: 'Store Location' },
    { key: 'total_skus', header: 'SKUs' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'reorder_now', header: 'Reorder Now' },
    { key: 'below_safety', header: 'Below Safety' },
    { key: 'stockout', header: 'Stockout' },
    { key: 'dead_stock', header: 'Dead Stock' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'store_location', header: 'Store Location' },
    { key: 'equipment_family', header: 'Equipment Family' },
    { key: 'skus', header: 'SKUs' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'avg_days_of_cover', header: 'Avg Days of Cover' },
    { key: 'total_stockout_days', header: 'Stockout Days (90d)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'review_date', header: 'Review Date' },
    { key: 'skus_reviewed', header: 'SKUs Reviewed' },
    { key: 'reorder_now', header: 'Reorder Now' },
    { key: 'below_safety', header: 'Below Safety' },
    { key: 'stockout', header: 'Stockout' },
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
    { key: 'store_location', header: 'Store Location' },
    { key: 'part_sku', header: 'SKU' },
    { key: 'part_name', header: 'Part Name' },
    { key: 'equipment_family', header: 'Family' },
    { key: 'on_hand_qty', header: 'On Hand' },
    { key: 'reorder_point', header: 'Reorder Pt' },
    { key: 'safety_stock', header: 'Safety Stock' },
    { key: 'days_of_cover', header: 'Days of Cover' },
    { key: 'stockout_days_last_90', header: 'Stockout Days (90d)' },
    { key: 'abc_class', header: 'ABC' },
    { key: 'stock_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Spare-Part Reorder-Point &amp; Safety-Stock Discipline Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per SKU-location stock discipline — store location &times; equipment family &times; on-hand
        vs reorder-point &amp; safety-stock &times; days-of-cover &times; ABC class &times; stock
        verdict &amp; replenishment CAPA. Founder-gated view: stock verdicts, location scorecards,
        root-cause pareto, and business-impact digest across EquipSeva regional hubs &amp; pooled
        van stock.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Stock verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No stock rows logged yet."
          rowKey={(r, i) => String(r.stock_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Store-location scorecard</h2>
        <DataTable
          rows={locRows}
          columns={locCols}
          emptyMessage="No location rollups."
          rowKey={(r, i) => String(r.store_location ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Store-location &times; equipment-family matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No rows by location and family."
          rowKey={(r, i) => `${r.store_location}-${r.equipment_family}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily review trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.review_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Business impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No business-impact rollups."
          rowKey={(r, i) => String(r.business_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk stock queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk SKU-locations."
          rowKey={(r, i) => `${r.part_sku}-${r.store_location}-${i}`}
        />
      </section>
    </main>
  );
}
