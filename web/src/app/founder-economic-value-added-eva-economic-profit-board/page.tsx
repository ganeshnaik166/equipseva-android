import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  eva_status: string;
  line_items: number;
  total_eva_rupees: number;
  pct: number;
};
type BuRow = {
  business_unit: string;
  line_items: number;
  total_nopat_rupees: number;
  total_capital_employed_rupees: number;
  total_capital_charge_rupees: number;
  total_eva_rupees: number;
  avg_roic_pct: number;
  avg_wacc_pct: number;
};
type MatrixRow = {
  business_unit: string;
  eva_status: string;
  line_items: number;
  total_eva_rupees: number;
  avg_value_spread_pct: number;
};
type TrendRow = {
  period_month: string;
  line_items: number;
  total_nopat_rupees: number;
  total_capital_charge_rupees: number;
  total_eva_rupees: number;
  avg_eva_margin_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
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
  trend_dir: string;
  line_items: number;
  total_eva_rupees: number;
  avg_eva_margin_pct: number;
  value_creating: number;
  value_destroying: number;
};
type RiskRow = {
  business_unit: string;
  eva_record_code: string;
  period_month: string;
  eva_rupees: number;
  eva_margin_pct: number;
  roic_pct: number;
  wacc_pct: number;
  value_spread_pct: number;
  eva_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    buRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3602_eva_status_rollup'),
    supabase.rpc('founder_r3602_business_unit_scorecard'),
    supabase.rpc('founder_r3602_business_unit_status_matrix'),
    supabase.rpc('founder_r3602_monthly_eva_trend'),
    supabase.rpc('founder_r3602_capa_status_board'),
    supabase.rpc('founder_r3602_root_cause_pareto'),
    supabase.rpc('founder_r3602_value_creation_digest'),
    supabase.rpc('founder_r3602_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const buRows: BuRow[] = (buRes.data as BuRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'eva_status', header: 'EVA Status' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_eva_rupees', header: 'Total EVA (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const buCols: Column<BuRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_nopat_rupees', header: 'NOPAT (INR)' },
    { key: 'total_capital_employed_rupees', header: 'Capital Employed (INR)' },
    { key: 'total_capital_charge_rupees', header: 'Capital Charge (INR)' },
    { key: 'total_eva_rupees', header: 'EVA (INR)' },
    { key: 'avg_roic_pct', header: 'Avg ROIC %' },
    { key: 'avg_wacc_pct', header: 'Avg WACC %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'eva_status', header: 'EVA Status' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_eva_rupees', header: 'Total EVA (INR)' },
    { key: 'avg_value_spread_pct', header: 'Avg Value Spread %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_nopat_rupees', header: 'NOPAT (INR)' },
    { key: 'total_capital_charge_rupees', header: 'Capital Charge (INR)' },
    { key: 'total_eva_rupees', header: 'EVA (INR)' },
    { key: 'avg_eva_margin_pct', header: 'Avg EVA Margin %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
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
    { key: 'trend_dir', header: 'Trend Direction' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_eva_rupees', header: 'Total EVA (INR)' },
    { key: 'avg_eva_margin_pct', header: 'Avg EVA Margin %' },
    { key: 'value_creating', header: 'Value Creating' },
    { key: 'value_destroying', header: 'Eroding / Destroying' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'eva_record_code', header: 'Record' },
    { key: 'period_month', header: 'Month' },
    { key: 'eva_rupees', header: 'EVA (INR)' },
    { key: 'eva_margin_pct', header: 'EVA Margin %' },
    { key: 'roic_pct', header: 'ROIC %' },
    { key: 'wacc_pct', header: 'WACC %' },
    { key: 'value_spread_pct', header: 'Value Spread %' },
    { key: 'eva_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Economic Value Added (EVA) / Economic-Profit Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-business-unit economic profit &mdash; EVA = NOPAT - (capital employed
        &times; WACC). Business unit &times; period &times; NOPAT &times; capital employed &times;
        WACC &times; capital charge &times; EVA &times; EVA margin &times; target EVA &times; ROIC
        &times; value spread &times; momentum &amp; value-improvement CAPA closure. Founder-gated
        view: EVA-status distribution, business-unit scorecards, root-cause pareto, and a
        high-risk queue for value-eroding &amp; value-destroying line items.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. EVA status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No EVA rows logged yet."
          rowKey={(r, i) => String(r.eva_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit economic-profit scorecard</h2>
        <DataTable
          rows={buRows}
          columns={buCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business unit &times; EVA status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.business_unit}-${r.eva_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly EVA trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Value-creation digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No value-creation rollups."
          rowKey={(r, i) => String(r.trend_dir ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk value-erosion queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk line items."
          rowKey={(r, i) => `${r.eva_record_code}-${i}`}
        />
      </section>
    </main>
  );
}
