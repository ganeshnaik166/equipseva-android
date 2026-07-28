import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { efficiency_status: string; units: number; pct: number };
type ScoreRow = {
  business_unit: string;
  periods: number;
  avg_roce_pct: number;
  avg_target_roce_pct: number;
  avg_spread_over_wacc_pct: number;
  total_ebit_rupees: number;
  value_creating: number;
  below_or_destroying: number;
  on_target_or_better_pct: number;
};
type MatrixRow = {
  business_unit: string;
  efficiency_status: string;
  periods: number;
  avg_roce_pct: number;
  avg_spread_over_wacc_pct: number;
};
type TrendRow = {
  period_month: string;
  units: number;
  avg_roce_pct: number;
  avg_target_roce_pct: number;
  avg_spread_over_wacc_pct: number;
  value_destroying: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_capital_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_capital_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_capital_impact_rupees: number;
};
type RiskRow = {
  business_unit: string;
  record_code: string;
  period_month: string;
  roce_pct: number;
  target_roce_pct: number;
  spread_over_wacc_pct: number;
  efficiency_status: string;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3581_efficiency_status_rollup'),
    supabase.rpc('founder_r3581_business_unit_scorecard'),
    supabase.rpc('founder_r3581_unit_efficiency_matrix'),
    supabase.rpc('founder_r3581_monthly_roce_trend'),
    supabase.rpc('founder_r3581_capa_status_board'),
    supabase.rpc('founder_r3581_root_cause_pareto'),
    supabase.rpc('founder_r3581_capital_efficiency_impact_digest'),
    supabase.rpc('founder_r3581_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'efficiency_status', header: 'Efficiency Status' },
    { key: 'units', header: 'Unit-Months' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'periods', header: 'Periods' },
    { key: 'avg_roce_pct', header: 'Avg ROCE %' },
    { key: 'avg_target_roce_pct', header: 'Avg Target %' },
    { key: 'avg_spread_over_wacc_pct', header: 'Avg Spread vs WACC %' },
    { key: 'total_ebit_rupees', header: 'Total EBIT (INR)' },
    { key: 'value_creating', header: 'Value Creating' },
    { key: 'below_or_destroying', header: 'Below / Destroying' },
    { key: 'on_target_or_better_pct', header: 'On-Target+ %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'efficiency_status', header: 'Efficiency Status' },
    { key: 'periods', header: 'Periods' },
    { key: 'avg_roce_pct', header: 'Avg ROCE %' },
    { key: 'avg_spread_over_wacc_pct', header: 'Avg Spread vs WACC %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'units', header: 'Unit-Months' },
    { key: 'avg_roce_pct', header: 'Avg ROCE %' },
    { key: 'avg_target_roce_pct', header: 'Avg Target %' },
    { key: 'avg_spread_over_wacc_pct', header: 'Avg Spread vs WACC %' },
    { key: 'value_destroying', header: 'Value Destroying' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_capital_impact_rupees', header: 'Avg Capital Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_capital_impact_rupees', header: 'Total Capital Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_capital_impact_rupees', header: 'Total Capital Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'record_code', header: 'Record' },
    { key: 'period_month', header: 'Month' },
    { key: 'roce_pct', header: 'ROCE %' },
    { key: 'target_roce_pct', header: 'Target %' },
    { key: 'spread_over_wacc_pct', header: 'Spread vs WACC %' },
    { key: 'efficiency_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Return-on-Capital-Employed (ROCE) / Capital-Efficiency Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated capital-efficiency board across business units (AMC Services, Spare Parts,
        Rental Fleet, Installation Projects, Calibration Lab, Marketplace, Consumables &amp;
        Refurbishment). Tracks monthly EBIT &times; capital employed &times; ROCE % vs target
        &times; spread over WACC &times; asset base &times; working capital &times; efficiency
        status &amp; trend, with a capital-remediation CAPA loop. Views: efficiency-status mix,
        business-unit scorecard, unit &times; status matrix, monthly ROCE trend, CAPA status board,
        root-cause pareto, capital-impact digest, and a high-risk value-destroying queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Efficiency-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No ROCE records logged yet."
          rowKey={(r, i) => String(r.efficiency_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit ROCE scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business unit &times; efficiency-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.business_unit}-${r.efficiency_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly ROCE trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Capital-efficiency impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No impact-digest rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk capital-efficiency queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk business units."
          rowKey={(r, i) => `${r.record_code}-${i}`}
        />
      </section>
    </main>
  );
}
