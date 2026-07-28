import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type GateRow = {
  gate_decision: string;
  projects: number;
  total_investment_rupees: number;
  pct: number;
};
type BuRow = {
  business_unit: string;
  total_projects: number;
  accepted: number;
  conditional: number;
  rejected: number;
  below_hurdle: number;
  avg_spread_pct: number;
  total_investment_rupees: number;
  accept_pct: number;
};
type MatrixRow = {
  business_unit: string;
  gate_decision: string;
  projects: number;
  total_investment_rupees: number;
  avg_irr_pct: number;
};
type TrendRow = {
  period_month: string;
  projects: number;
  avg_wacc_pct: number;
  avg_hurdle_rate_pct: number;
  avg_project_irr_pct: number;
  avg_spread_pct: number;
  below_hurdle: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_capital_at_risk_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_capital_at_risk_rupees: number;
  pct: number;
};
type ImpactRow = {
  portfolio_impact: string;
  findings: number;
  open_findings: number;
  total_capital_at_risk_rupees: number;
};
type RiskRow = {
  project_name: string;
  project_code: string;
  business_unit: string;
  period_month: string;
  gate_decision: string;
  wacc_pct: number | null;
  hurdle_rate_pct: number | null;
  project_irr_pct: number | null;
  spread_over_hurdle_pct: number | null;
  investment_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    gateRes,
    buRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3525_gate_decision_rollup'),
    supabase.rpc('founder_r3525_business_unit_scorecard'),
    supabase.rpc('founder_r3525_bu_gate_matrix'),
    supabase.rpc('founder_r3525_monthly_irr_hurdle_trend'),
    supabase.rpc('founder_r3525_capa_status_board'),
    supabase.rpc('founder_r3525_root_cause_pareto'),
    supabase.rpc('founder_r3525_investment_impact_digest'),
    supabase.rpc('founder_r3525_high_risk_queue'),
  ]);

  const gateRows: GateRow[] = (gateRes.data as GateRow[]) ?? [];
  const buRows: BuRow[] = (buRes.data as BuRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const gateCols: Column<GateRow>[] = [
    { key: 'gate_decision', header: 'Gate Decision' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_investment_rupees', header: 'Investment (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const buCols: Column<BuRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'total_projects', header: 'Projects' },
    { key: 'accepted', header: 'Accepted' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'rejected', header: 'Rejected / Defer / Revise' },
    { key: 'below_hurdle', header: 'Below Hurdle' },
    { key: 'avg_spread_pct', header: 'Avg Spread %' },
    { key: 'total_investment_rupees', header: 'Investment (INR)' },
    { key: 'accept_pct', header: 'Accept %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'gate_decision', header: 'Gate Decision' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_investment_rupees', header: 'Investment (INR)' },
    { key: 'avg_irr_pct', header: 'Avg IRR %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'projects', header: 'Projects' },
    { key: 'avg_wacc_pct', header: 'Avg WACC %' },
    { key: 'avg_hurdle_rate_pct', header: 'Avg Hurdle %' },
    { key: 'avg_project_irr_pct', header: 'Avg IRR %' },
    { key: 'avg_spread_pct', header: 'Avg Spread %' },
    { key: 'below_hurdle', header: 'Below Hurdle' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_capital_at_risk_rupees', header: 'Avg Capital at Risk (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_capital_at_risk_rupees', header: 'Capital at Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'portfolio_impact', header: 'Portfolio Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_capital_at_risk_rupees', header: 'Capital at Risk (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'project_name', header: 'Project' },
    { key: 'project_code', header: 'Code' },
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'period_month', header: 'Month' },
    { key: 'gate_decision', header: 'Gate' },
    { key: 'wacc_pct', header: 'WACC %' },
    { key: 'hurdle_rate_pct', header: 'Hurdle %' },
    { key: 'project_irr_pct', header: 'IRR %' },
    { key: 'spread_over_hurdle_pct', header: 'Spread %' },
    { key: 'investment_rupees', header: 'Investment (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Cost-of-Capital / WACC Hurdle-Rate Investment Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder capital-allocation gating board — project &times; business unit &times; cost of debt
        &amp; cost of equity &times; blended WACC &times; risk-adjusted hurdle rate &times; project IRR
        &times; spread over hurdle &times; investment outlay &times; gate decision &amp; CAPA closure.
        Founder-gated view: gate-decision distribution, business-unit scorecards, IRR-vs-hurdle trend,
        root-cause pareto, and investment-impact digest across the capital committee&rsquo;s portfolio.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Gate decision distribution</h2>
        <DataTable
          rows={gateRows}
          columns={gateCols}
          emptyMessage="No gating decisions logged yet."
          rowKey={(r, i) => String(r.gate_decision ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit scorecard</h2>
        <DataTable
          rows={buRows}
          columns={buCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business-unit &times; gate-decision matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No projects by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.gate_decision}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly IRR-vs-hurdle trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Investment-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No investment-impact rollups."
          rowKey={(r, i) => String(r.portfolio_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk investment queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk projects."
          rowKey={(r, i) => `${r.project_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
