import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { efficiency_status: string; units: number; pct: number };
type ScoreRow = {
  business_unit: string;
  records: number;
  avg_rev_per_employee_rupees: number;
  avg_ebitda_per_employee_rupees: number;
  avg_cost_per_employee_rupees: number;
  avg_utilization_pct: number;
  avg_productivity_index: number;
  below_or_under: number;
};
type MatrixRow = {
  business_unit: string;
  efficiency_status: string;
  records: number;
  avg_rev_per_employee_rupees: number;
  avg_productivity_index: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  total_headcount: number;
  total_revenue_rupees: number;
  avg_rev_per_employee_rupees: number;
  avg_productivity_index: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
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
  finding_category: string;
  actions: number;
  open_actions: number;
  total_impact_rupees: number;
};
type RiskRow = {
  business_unit: string;
  unit_code: string;
  period_month: string;
  efficiency_status: string;
  trend_dir: string;
  revenue_per_employee_rupees: number;
  target_rev_per_employee_rupees: number;
  utilization_pct: number;
  productivity_index: number;
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
    supabase.rpc('founder_r3592_efficiency_status_rollup'),
    supabase.rpc('founder_r3592_business_unit_scorecard'),
    supabase.rpc('founder_r3592_bu_efficiency_matrix'),
    supabase.rpc('founder_r3592_monthly_rpe_trend'),
    supabase.rpc('founder_r3592_capa_status_board'),
    supabase.rpc('founder_r3592_root_cause_pareto'),
    supabase.rpc('founder_r3592_productivity_impact_digest'),
    supabase.rpc('founder_r3592_high_risk_queue'),
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
    { key: 'units', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'records', header: 'Records' },
    { key: 'avg_rev_per_employee_rupees', header: 'Avg Rev/Emp (INR)' },
    { key: 'avg_ebitda_per_employee_rupees', header: 'Avg EBITDA/Emp (INR)' },
    { key: 'avg_cost_per_employee_rupees', header: 'Avg Cost/Emp (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Utilization %' },
    { key: 'avg_productivity_index', header: 'Avg Productivity Index' },
    { key: 'below_or_under', header: 'Below / Underproductive' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'efficiency_status', header: 'Efficiency Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_rev_per_employee_rupees', header: 'Avg Rev/Emp (INR)' },
    { key: 'avg_productivity_index', header: 'Avg Productivity Index' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'total_headcount', header: 'Headcount' },
    { key: 'total_revenue_rupees', header: 'Total Revenue (INR)' },
    { key: 'avg_rev_per_employee_rupees', header: 'Avg Rev/Emp (INR)' },
    { key: 'avg_productivity_index', header: 'Avg Productivity Index' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
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
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'unit_code', header: 'Unit Code' },
    { key: 'period_month', header: 'Month' },
    { key: 'efficiency_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'revenue_per_employee_rupees', header: 'Rev/Emp (INR)' },
    { key: 'target_rev_per_employee_rupees', header: 'Target Rev/Emp (INR)' },
    { key: 'utilization_pct', header: 'Utilization %' },
    { key: 'productivity_index', header: 'Productivity Index' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Revenue-per-Employee / Productivity &amp; Efficiency Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated view of revenue-per-employee and cost-efficiency across EquipSeva business units
        (Field Service, Spare Parts, AMC Contracts, Calibration Lab, Rentals, Refurbishment, Digital /
        SaaS &amp; Turnkey Projects). Tracks headcount, revenue/employee, EBITDA/employee, cost/employee
        vs target, utilization &amp; productivity index &times; efficiency status &times; monthly trend,
        with a CAPA board, root-cause pareto, productivity-impact digest, and a high-risk queue of
        below-target &amp; underproductive units.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Efficiency-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No productivity records logged yet."
          rowKey={(r, i) => String(r.efficiency_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit productivity scorecard</h2>
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
          emptyMessage="No records by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.efficiency_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly revenue-per-employee trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Productivity-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No productivity-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk (below-target / underproductive) queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk units."
          rowKey={(r, i) => `${r.unit_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
