import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { reinvestment_status: string; entries: number; pct: number };
type UnitRow = {
  business_unit: string;
  total_entries: number;
  net_profit_rupees: number;
  retained_earnings_rupees: number;
  capex_reinvested_rupees: number;
  avg_retention_ratio_pct: number;
  avg_reinvestment_ratio_pct: number;
  avg_roe_pct: number;
  under_reinvesting: number;
};
type MatrixRow = {
  business_unit: string;
  reinvestment_status: string;
  entries: number;
  avg_reinvestment_ratio_pct: number;
  avg_growth_rate_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  avg_retention_ratio_pct: number;
  avg_reinvestment_ratio_pct: number;
  total_capex_reinvested_rupees: number;
  under_reinvesting: number;
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
type ImpactRow = {
  growth_impact: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  business_unit: string;
  entry_code: string;
  period_month: string;
  reinvestment_status: string;
  retention_ratio_pct: number | null;
  reinvestment_ratio_pct: number | null;
  target_reinvestment_pct: number | null;
  roe_pct: number | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    unitRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3615_reinvestment_status_rollup'),
    supabase.rpc('founder_r3615_business_unit_scorecard'),
    supabase.rpc('founder_r3615_business_unit_status_matrix'),
    supabase.rpc('founder_r3615_monthly_reinvestment_trend'),
    supabase.rpc('founder_r3615_capa_status_board'),
    supabase.rpc('founder_r3615_root_cause_pareto'),
    supabase.rpc('founder_r3615_growth_impact_digest'),
    supabase.rpc('founder_r3615_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const unitRows: UnitRow[] = (unitRes.data as UnitRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'reinvestment_status', header: 'Reinvestment Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const unitCols: Column<UnitRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'total_entries', header: 'Entries' },
    { key: 'net_profit_rupees', header: 'Net Profit (INR)' },
    { key: 'retained_earnings_rupees', header: 'Retained (INR)' },
    { key: 'capex_reinvested_rupees', header: 'Capex Reinvested (INR)' },
    { key: 'avg_retention_ratio_pct', header: 'Avg Retention %' },
    { key: 'avg_reinvestment_ratio_pct', header: 'Avg Reinvestment %' },
    { key: 'avg_roe_pct', header: 'Avg ROE %' },
    { key: 'under_reinvesting', header: 'At-Risk Entries' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'reinvestment_status', header: 'Reinvestment Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_reinvestment_ratio_pct', header: 'Avg Reinvestment %' },
    { key: 'avg_growth_rate_pct', header: 'Avg Growth %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_retention_ratio_pct', header: 'Avg Retention %' },
    { key: 'avg_reinvestment_ratio_pct', header: 'Avg Reinvestment %' },
    { key: 'total_capex_reinvested_rupees', header: 'Capex Reinvested (INR)' },
    { key: 'under_reinvesting', header: 'Under-Reinvesting' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'growth_impact', header: 'Growth Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'entry_code', header: 'Entry' },
    { key: 'period_month', header: 'Month' },
    { key: 'reinvestment_status', header: 'Status' },
    { key: 'retention_ratio_pct', header: 'Retention %' },
    { key: 'reinvestment_ratio_pct', header: 'Reinvestment %' },
    { key: 'target_reinvestment_pct', header: 'Target %' },
    { key: 'roe_pct', header: 'ROE %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Reinvestment / Retention-Ratio (Plough-Back) Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder earnings-retention &amp; reinvestment (plough-back) board — net profit &times;
        dividends paid &times; retained earnings &times; retention ratio &times; capex reinvested
        &times; reinvestment ratio vs target &times; growth rate &times; ROE, per business unit
        (AMC services, spare parts, projects, diagnostics, rentals &amp; refurbishment) and per
        month, with CAPA closure. Founder-gated view: reinvestment-status mix, business-unit
        scorecards, root-cause pareto, growth-impact digest &amp; a high-risk plough-back queue
        where reinvestment falls below target or the trend is worsening.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Reinvestment status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No reinvestment entries logged yet."
          rowKey={(r, i) => String(r.reinvestment_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit reinvestment scorecard</h2>
        <DataTable
          rows={unitRows}
          columns={unitCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business-unit &times; reinvestment-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.reinvestment_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly reinvestment trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Growth-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No growth-impact rollups."
          rowKey={(r, i) => String(r.growth_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk plough-back queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk entries."
          rowKey={(r, i) => `${r.entry_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
