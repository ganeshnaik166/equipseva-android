import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  processing_status: string;
  return_lots: number;
  total_units: number;
  pct: number;
};
type RegionRow = {
  origin_region: string;
  return_lots: number;
  total_units: number;
  total_value_rupees: number;
  dispositioned_lots: number;
  stuck_or_aging: number;
  avg_days_to_disposition: number;
  avg_disposition_pct: number;
};
type MatrixRow = {
  return_type: string;
  processing_status: string;
  return_lots: number;
  total_units: number;
  avg_days_to_disposition: number;
};
type TrendRow = {
  period_month: string;
  return_lots: number;
  total_units: number;
  total_value_rupees: number;
  credit_issued_rupees: number;
  avg_days_to_disposition: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_value_at_risk_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_value_at_risk_rupees: number;
  pct: number;
};
type DigestRow = {
  return_type: string;
  return_lots: number;
  avg_days_in_transit: number;
  avg_days_to_disposition: number;
  restocked_units: number;
  scrapped_units: number;
  refurbished_units: number;
  avg_disposition_pct: number;
};
type RiskRow = {
  return_ref: string;
  origin_region: string;
  period_month: string;
  return_type: string;
  processing_status: string;
  trend_dir: string;
  days_to_disposition: number | null;
  units_returned: number;
  disposition_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3666_processing_status_rollup'),
    supabase.rpc('founder_r3666_origin_region_scorecard'),
    supabase.rpc('founder_r3666_return_type_status_matrix'),
    supabase.rpc('founder_r3666_monthly_returns_trend'),
    supabase.rpc('founder_r3666_capa_status_board'),
    supabase.rpc('founder_r3666_root_cause_pareto'),
    supabase.rpc('founder_r3666_disposition_cycle_digest'),
    supabase.rpc('founder_r3666_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'processing_status', header: 'Processing Status' },
    { key: 'return_lots', header: 'Return Lots' },
    { key: 'total_units', header: 'Units' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'origin_region', header: 'Origin Region' },
    { key: 'return_lots', header: 'Return Lots' },
    { key: 'total_units', header: 'Units' },
    { key: 'total_value_rupees', header: 'Return Value (INR)' },
    { key: 'dispositioned_lots', header: 'Dispositioned' },
    { key: 'stuck_or_aging', header: 'Stuck / Aging' },
    { key: 'avg_days_to_disposition', header: 'Avg Days to Disposition' },
    { key: 'avg_disposition_pct', header: 'Avg Disposition %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'return_type', header: 'Return Type' },
    { key: 'processing_status', header: 'Status' },
    { key: 'return_lots', header: 'Return Lots' },
    { key: 'total_units', header: 'Units' },
    { key: 'avg_days_to_disposition', header: 'Avg Days to Disposition' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'return_lots', header: 'Return Lots' },
    { key: 'total_units', header: 'Units' },
    { key: 'total_value_rupees', header: 'Return Value (INR)' },
    { key: 'credit_issued_rupees', header: 'Credit Issued (INR)' },
    { key: 'avg_days_to_disposition', header: 'Avg Days to Disposition' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_value_at_risk_rupees', header: 'Avg Value at Risk (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_value_at_risk_rupees', header: 'Value at Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'return_type', header: 'Return Type' },
    { key: 'return_lots', header: 'Return Lots' },
    { key: 'avg_days_in_transit', header: 'Avg Days in Transit' },
    { key: 'avg_days_to_disposition', header: 'Avg Days to Disposition' },
    { key: 'restocked_units', header: 'Restocked' },
    { key: 'scrapped_units', header: 'Scrapped' },
    { key: 'refurbished_units', header: 'Refurbished' },
    { key: 'avg_disposition_pct', header: 'Avg Disposition %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'return_ref', header: 'Return Ref' },
    { key: 'origin_region', header: 'Region' },
    { key: 'period_month', header: 'Month' },
    { key: 'return_type', header: 'Type' },
    { key: 'processing_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'days_to_disposition', header: 'Days to Disposition' },
    { key: 'units_returned', header: 'Units' },
    { key: 'disposition_pct', header: 'Disposition %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Reverse-Logistics / Returns-Processing Cycle Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Reverse-logistics returns intake-to-disposition cycle — return type (defective, loaner,
        core, expired, wrong shipment) &times; origin region &times; days in transit &times; days
        to disposition &times; restock / scrap / refurb split &times; credit issued &amp; CAPA
        closure. Founder-gated view: processing-status rollups, region scorecards, root-cause
        pareto, and the stuck / aging high-risk queue across ERP, CRM &amp; field-app return
        routes like Mumbai-Pune.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Processing status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No return lots logged yet."
          rowKey={(r, i) => String(r.processing_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Origin-region scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.origin_region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Return type &times; processing status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No returns by type."
          rowKey={(r, i) => `${r.return_type}-${r.processing_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly returns trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Disposition-cycle digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No disposition digest."
          rowKey={(r, i) => String(r.return_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk (stuck / aging) queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk return lots."
          rowKey={(r, i) => `${r.return_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
