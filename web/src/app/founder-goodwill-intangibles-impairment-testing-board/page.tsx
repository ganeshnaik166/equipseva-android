import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { impairment_status: string; cgus: number; pct: number };
type AssetRow = {
  asset_type: string;
  total_cgus: number;
  clean: number;
  watch: number;
  trigger_review: number;
  impaired: number;
  reversed: number;
  avg_headroom_pct: number;
  total_carrying_rupees: number;
};
type MatrixRow = {
  asset_type: string;
  impairment_status: string;
  cgus: number;
  total_carrying_rupees: number;
  total_headroom_rupees: number;
  avg_headroom_pct: number;
};
type TrendRow = {
  test_month: string;
  cgus: number;
  impaired: number;
  thin_headroom: number;
  avg_headroom_pct: number;
  total_headroom_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_charge_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_charge_rupees: number;
  pct: number;
};
type DigestRow = {
  impairment_status: string;
  cgus: number;
  total_carrying_rupees: number;
  total_recoverable_rupees: number;
  total_headroom_rupees: number;
  avg_discount_rate_pct: number;
};
type RiskRow = {
  cgu_name: string;
  cgu_code: string;
  asset_type: string;
  reporting_unit: string;
  test_date: string;
  impairment_status: string;
  carrying_value_rupees: number | null;
  recoverable_value_rupees: number | null;
  headroom_rupees: number | null;
  headroom_pct: number | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    assetRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3529_impairment_status_rollup'),
    supabase.rpc('founder_r3529_asset_type_scorecard'),
    supabase.rpc('founder_r3529_asset_status_matrix'),
    supabase.rpc('founder_r3529_monthly_headroom_trend'),
    supabase.rpc('founder_r3529_capa_status_board'),
    supabase.rpc('founder_r3529_root_cause_pareto'),
    supabase.rpc('founder_r3529_impairment_impact_digest'),
    supabase.rpc('founder_r3529_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const assetRows: AssetRow[] = (assetRes.data as AssetRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'impairment_status', header: 'Impairment Status' },
    { key: 'cgus', header: 'CGUs' },
    { key: 'pct', header: 'Share %' },
  ];

  const assetCols: Column<AssetRow>[] = [
    { key: 'asset_type', header: 'Asset Type' },
    { key: 'total_cgus', header: 'CGUs' },
    { key: 'clean', header: 'No Impairment' },
    { key: 'watch', header: 'Watch' },
    { key: 'trigger_review', header: 'Trigger Review' },
    { key: 'impaired', header: 'Impaired' },
    { key: 'reversed', header: 'Reversed' },
    { key: 'avg_headroom_pct', header: 'Avg Headroom %' },
    { key: 'total_carrying_rupees', header: 'Total Carrying (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'asset_type', header: 'Asset Type' },
    { key: 'impairment_status', header: 'Impairment Status' },
    { key: 'cgus', header: 'CGUs' },
    { key: 'total_carrying_rupees', header: 'Total Carrying (INR)' },
    { key: 'total_headroom_rupees', header: 'Total Headroom (INR)' },
    { key: 'avg_headroom_pct', header: 'Avg Headroom %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_month', header: 'Test Month' },
    { key: 'cgus', header: 'CGUs Tested' },
    { key: 'impaired', header: 'Impaired' },
    { key: 'thin_headroom', header: 'Thin Headroom' },
    { key: 'avg_headroom_pct', header: 'Avg Headroom %' },
    { key: 'total_headroom_rupees', header: 'Total Headroom (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_charge_rupees', header: 'Avg Charge (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_charge_rupees', header: 'Total Charge (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'impairment_status', header: 'Impairment Status' },
    { key: 'cgus', header: 'CGUs' },
    { key: 'total_carrying_rupees', header: 'Total Carrying (INR)' },
    { key: 'total_recoverable_rupees', header: 'Total Recoverable (INR)' },
    { key: 'total_headroom_rupees', header: 'Total Headroom (INR)' },
    { key: 'avg_discount_rate_pct', header: 'Avg Discount Rate %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'cgu_name', header: 'CGU' },
    { key: 'cgu_code', header: 'Code' },
    { key: 'asset_type', header: 'Asset Type' },
    { key: 'reporting_unit', header: 'Reporting Unit' },
    { key: 'test_date', header: 'Test Date' },
    { key: 'impairment_status', header: 'Status' },
    { key: 'carrying_value_rupees', header: 'Carrying (INR)' },
    { key: 'recoverable_value_rupees', header: 'Recoverable (INR)' },
    { key: 'headroom_rupees', header: 'Headroom (INR)' },
    { key: 'headroom_pct', header: 'Headroom %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Goodwill / Intangibles Impairment-Testing Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated Ind AS 36 impairment-testing board — cash-generating units and intangibles
        (goodwill, brands, customer relationships, technology, licences &amp; software) tested for
        carrying value &gt; recoverable value. Tracks headroom (&#8377; &amp; %) &times; discount and
        growth assumptions &times; impairment status &times; trend direction, with CAPA closure across
        recognised charges, trigger reviews &amp; reversals. Views: status distribution, asset-type
        scorecard, asset &times; status matrix, monthly headroom trend, CAPA board, root-cause pareto,
        impairment-impact digest &amp; the high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Impairment status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No impairment tests logged yet."
          rowKey={(r, i) => String(r.impairment_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Asset-type scorecard</h2>
        <DataTable
          rows={assetRows}
          columns={assetCols}
          emptyMessage="No asset-type rollups."
          rowKey={(r, i) => String(r.asset_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Asset type &times; impairment status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by asset type."
          rowKey={(r, i) => `${r.asset_type}-${r.impairment_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly headroom trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.test_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Impairment-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No impairment-impact rollups."
          rowKey={(r, i) => String(r.impairment_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk CGU queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk CGUs."
          rowKey={(r, i) => `${r.cgu_code}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
