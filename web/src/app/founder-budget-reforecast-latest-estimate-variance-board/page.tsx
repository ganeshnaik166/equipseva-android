import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  forecast_status: string;
  lines: number;
  total_variance_rupees: number;
  pct: number;
};
type CatRow = {
  category: string;
  lines: number;
  on_budget: number;
  favorable: number;
  unfavorable: number;
  at_risk: number;
  revised: number;
  healthy_pct: number;
};
type MatrixRow = {
  category: string;
  forecast_status: string;
  lines: number;
  total_variance_rupees: number;
  total_latest_estimate_rupees: number;
};
type TrendRow = {
  period_month: string;
  lines: number;
  total_original_budget_rupees: number;
  total_latest_estimate_rupees: number;
  total_variance_rupees: number;
  unfavorable: number;
  at_risk: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type ImpactRow = {
  category: string;
  lines: number;
  favorable_variance_rupees: number;
  unfavorable_variance_rupees: number;
  at_risk_variance_rupees: number;
  net_variance_rupees: number;
  total_full_year_outlook_rupees: number;
};
type RiskRow = {
  line_code: string;
  line_item: string;
  category: string;
  cost_center: string;
  period_month: string;
  latest_estimate_rupees: number;
  variance_rupees: number;
  variance_pct: number | null;
  forecast_status: string;
  trend_dir: string;
  owner: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    catRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3557_forecast_status_rollup'),
    supabase.rpc('founder_r3557_category_scorecard'),
    supabase.rpc('founder_r3557_category_status_matrix'),
    supabase.rpc('founder_r3557_monthly_reforecast_trend'),
    supabase.rpc('founder_r3557_capa_status_board'),
    supabase.rpc('founder_r3557_root_cause_pareto'),
    supabase.rpc('founder_r3557_variance_impact_digest'),
    supabase.rpc('founder_r3557_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const catRows: CatRow[] = (catRes.data as CatRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'forecast_status', header: 'Forecast Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const catCols: Column<CatRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'lines', header: 'Lines' },
    { key: 'on_budget', header: 'On Budget' },
    { key: 'favorable', header: 'Favorable' },
    { key: 'unfavorable', header: 'Unfavorable' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'revised', header: 'Revised' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'forecast_status', header: 'Forecast Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
    { key: 'total_latest_estimate_rupees', header: 'Latest Estimate (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_original_budget_rupees', header: 'Original Budget (INR)' },
    { key: 'total_latest_estimate_rupees', header: 'Latest Estimate (INR)' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
    { key: 'unfavorable', header: 'Unfavorable' },
    { key: 'at_risk', header: 'At Risk' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'lines', header: 'Lines' },
    { key: 'favorable_variance_rupees', header: 'Favorable Var (INR)' },
    { key: 'unfavorable_variance_rupees', header: 'Unfavorable Var (INR)' },
    { key: 'at_risk_variance_rupees', header: 'At-Risk Var (INR)' },
    { key: 'net_variance_rupees', header: 'Net Variance (INR)' },
    { key: 'total_full_year_outlook_rupees', header: 'Full-Year Outlook (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'line_code', header: 'Line' },
    { key: 'line_item', header: 'Line Item' },
    { key: 'category', header: 'Category' },
    { key: 'cost_center', header: 'Cost Center' },
    { key: 'period_month', header: 'Month' },
    { key: 'latest_estimate_rupees', header: 'Latest Estimate (INR)' },
    { key: 'variance_rupees', header: 'Variance (INR)' },
    { key: 'variance_pct', header: 'Variance %' },
    { key: 'forecast_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'owner', header: 'Owner' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Budget-Reforecast / Latest-Estimate Variance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder view of budget vs latest-estimate (reforecast) variance and full-year outlook per
        cost/revenue line &mdash; line item &times; category (revenue, COGS, opex, capex, headcount)
        &times; original budget &times; latest estimate &times; actuals YTD &times; variance
        rupees/pct &times; full-year outlook &times; forecast status &times; month &times; trend
        &amp; CAPA remediation. Founder-gated rollups: forecast-status distribution, category
        scorecards, category &times; status matrix, monthly reforecast trend, root-cause pareto, and
        variance-impact digest, plus a high-risk queue of at-risk &amp; unfavorable lines.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Forecast-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No reforecast lines logged yet."
          rowKey={(r, i) => String(r.forecast_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Category scorecard</h2>
        <DataTable
          rows={catRows}
          columns={catCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; forecast-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by category."
          rowKey={(r, i) => `${r.category}-${r.forecast_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly reforecast trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Variance-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No variance-impact rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk line queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.line_code}-${i}`}
        />
      </section>
    </main>
  );
}
