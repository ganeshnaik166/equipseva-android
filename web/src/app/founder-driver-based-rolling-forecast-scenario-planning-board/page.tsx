import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { driver_verdict: string; drivers: number; pct: number };
type ScoreRow = {
  account_name: string;
  total_drivers: number;
  on_plan: number;
  upside_lever: number;
  risk_watch: number;
  reforecast_trigger: number;
  revenue_drivers: number;
  cost_drivers: number;
  total_sensitivity_rupees: number;
  on_plan_pct: number;
};
type MatrixRow = {
  forecast_month: string;
  category: string;
  drivers: number;
  total_sensitivity_rupees: number;
  risk_watch: number;
};
type TrendRow = {
  forecast_month: string;
  drivers: number;
  on_plan: number;
  risk_watch: number;
  reforecast_trigger: number;
  total_sensitivity_rupees: number;
};
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type ImpactRow = { forecast_impact: string; findings: number; open_findings: number; total_cost_rupees: number };
type RiskRow = {
  account_name: string;
  region: string;
  driver_ref: string;
  forecast_driver: string;
  forecast_month: string;
  current_value: number;
  base_case_value: number;
  downside_case_value: number;
  trend: string;
  assumption_confidence: string;
  driver_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, impactRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3389_driver_verdict_rollup'),
    supabase.rpc('founder_r3389_account_scorecard'),
    supabase.rpc('founder_r3389_month_category_matrix'),
    supabase.rpc('founder_r3389_forecast_month_trend'),
    supabase.rpc('founder_r3389_capa_status_board'),
    supabase.rpc('founder_r3389_root_cause_pareto'),
    supabase.rpc('founder_r3389_forecast_impact_digest'),
    supabase.rpc('founder_r3389_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'driver_verdict', header: 'Driver Verdict' },
    { key: 'drivers', header: 'Drivers' },
    { key: 'pct', header: 'Share %' },
  ];
  const scoreCols: Column<ScoreRow>[] = [
    { key: 'account_name', header: 'Account/Entity' },
    { key: 'total_drivers', header: 'Drivers' },
    { key: 'on_plan', header: 'On Plan' },
    { key: 'upside_lever', header: 'Upside Lever' },
    { key: 'risk_watch', header: 'Risk Watch' },
    { key: 'reforecast_trigger', header: 'Reforecast' },
    { key: 'revenue_drivers', header: 'Revenue Drv' },
    { key: 'cost_drivers', header: 'Cost Drv' },
    { key: 'total_sensitivity_rupees', header: 'Sensitivity (INR)' },
    { key: 'on_plan_pct', header: 'On-Plan %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'forecast_month', header: 'Month' },
    { key: 'category', header: 'Category' },
    { key: 'drivers', header: 'Drivers' },
    { key: 'total_sensitivity_rupees', header: 'Sensitivity (INR)' },
    { key: 'risk_watch', header: 'Risk Watch' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'forecast_month', header: 'Month' },
    { key: 'drivers', header: 'Drivers' },
    { key: 'on_plan', header: 'On Plan' },
    { key: 'risk_watch', header: 'Risk Watch' },
    { key: 'reforecast_trigger', header: 'Reforecast' },
    { key: 'total_sensitivity_rupees', header: 'Sensitivity (INR)' },
  ];
  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];
  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];
  const impactCols: Column<ImpactRow>[] = [
    { key: 'forecast_impact', header: 'Forecast Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];
  const riskCols: Column<RiskRow>[] = [
    { key: 'account_name', header: 'Account/Entity' },
    { key: 'region', header: 'Region' },
    { key: 'driver_ref', header: 'Ref' },
    { key: 'forecast_driver', header: 'Driver' },
    { key: 'forecast_month', header: 'Month' },
    { key: 'current_value', header: 'Current' },
    { key: 'base_case_value', header: 'Base Case' },
    { key: 'downside_case_value', header: 'Downside' },
    { key: 'trend', header: 'Trend' },
    { key: 'assumption_confidence', header: 'Confidence' },
    { key: 'driver_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Driver-Based Rolling-Forecast &amp; Scenario-Planning Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Operational forecast drivers &mdash; base &times; upside &times; downside cases &times; sensitivity impact
        &times; assumption confidence &amp; reforecast triggers &amp; CAPA. Founder-gated FP&amp;A view: driver-verdict
        rollup, entity scorecard, month &times; category sensitivity matrix, and assumption-validation queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Driver verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No drivers tracked yet." rowKey={(r, i) => String(r.driver_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity forecast scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No entity rollups." rowKey={(r, i) => String(r.account_name ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Month &times; category sensitivity matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.forecast_month}-${r.category}-${i}`} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Forecast-month trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.forecast_month ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No CAPA findings." rowKey={(r, i) => String(r.capa_status ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable rows={causeRows} columns={causeCols} emptyMessage="No root-cause data." rowKey={(r, i) => String(r.root_cause ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Forecast-impact digest</h2>
        <DataTable rows={impactRows} columns={impactCols} emptyMessage="No forecast-impact rollups." rowKey={(r, i) => String(r.forecast_impact ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Assumption-validation queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No at-risk drivers." rowKey={(r, i) => `${r.driver_ref}-${i}`} />
      </section>
    </main>
  );
}
