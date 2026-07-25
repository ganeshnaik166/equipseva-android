import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { dio_status: string; lines: number; pct: number };
type CategoryRow = {
  category: string;
  lines: number;
  on_target: number;
  above_target: number;
  below_target: number;
  critical_excess: number;
  total_inventory_value_rupees: number;
  total_excess_capital_rupees: number;
  avg_dio_days: number;
  avg_turns: number;
};
type MatrixRow = {
  category: string;
  dio_status: string;
  lines: number;
  total_inventory_value_rupees: number;
  excess_capital_rupees: number;
  avg_dio_days: number;
};
type TrendRow = {
  period_month: string;
  lines: number;
  avg_dio_days: number;
  avg_target_dio_days: number;
  avg_turns: number;
  avg_target_turns: number;
  total_excess_capital_rupees: number;
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
type DigestRow = {
  category: string;
  lines: number;
  lines_with_excess: number;
  total_excess_capital_rupees: number;
  avg_excess_per_line_rupees: number;
  worst_dio_days: number;
};
type RiskRow = {
  line_code: string;
  category: string;
  warehouse: string;
  period_month: string;
  dio_status: string;
  dio_days: number;
  target_dio_days: number;
  turns_per_year: number;
  excess_capital_rupees: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3449_dio_status_rollup'),
    supabase.rpc('founder_r3449_category_scorecard'),
    supabase.rpc('founder_r3449_category_status_matrix'),
    supabase.rpc('founder_r3449_monthly_dio_trend'),
    supabase.rpc('founder_r3449_capa_status_board'),
    supabase.rpc('founder_r3449_root_cause_pareto'),
    supabase.rpc('founder_r3449_excess_capital_digest'),
    supabase.rpc('founder_r3449_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'dio_status', header: 'DIO Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'lines', header: 'Lines' },
    { key: 'on_target', header: 'On Target' },
    { key: 'above_target', header: 'Above Target' },
    { key: 'below_target', header: 'Below Target' },
    { key: 'critical_excess', header: 'Critical Excess' },
    { key: 'total_inventory_value_rupees', header: 'Inv Value (INR)' },
    { key: 'total_excess_capital_rupees', header: 'Excess Capital (INR)' },
    { key: 'avg_dio_days', header: 'Avg DIO Days' },
    { key: 'avg_turns', header: 'Avg Turns' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'dio_status', header: 'DIO Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_inventory_value_rupees', header: 'Inv Value (INR)' },
    { key: 'excess_capital_rupees', header: 'Excess Capital (INR)' },
    { key: 'avg_dio_days', header: 'Avg DIO Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'lines', header: 'Lines' },
    { key: 'avg_dio_days', header: 'Avg DIO Days' },
    { key: 'avg_target_dio_days', header: 'Target DIO Days' },
    { key: 'avg_turns', header: 'Avg Turns' },
    { key: 'avg_target_turns', header: 'Target Turns' },
    { key: 'total_excess_capital_rupees', header: 'Excess Capital (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_capital_at_risk_rupees', header: 'Avg Capital At Risk (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_capital_at_risk_rupees', header: 'Total Capital At Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'lines', header: 'Lines' },
    { key: 'lines_with_excess', header: 'Lines With Excess' },
    { key: 'total_excess_capital_rupees', header: 'Total Excess Capital (INR)' },
    { key: 'avg_excess_per_line_rupees', header: 'Avg Excess / Line (INR)' },
    { key: 'worst_dio_days', header: 'Worst DIO Days' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'line_code', header: 'Line' },
    { key: 'category', header: 'Category' },
    { key: 'warehouse', header: 'Warehouse' },
    { key: 'period_month', header: 'Month' },
    { key: 'dio_status', header: 'Status' },
    { key: 'dio_days', header: 'DIO Days' },
    { key: 'target_dio_days', header: 'Target DIO' },
    { key: 'turns_per_year', header: 'Turns/Yr' },
    { key: 'excess_capital_rupees', header: 'Excess Capital (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Inventory Days-Inventory-Outstanding (DIO) / Stock-Turns Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder spare-parts Days-Inventory-Outstanding (DIO) &amp; stock-turns vs target per category
        &times; warehouse — average inventory value &times; annual COGS &times; DIO days vs target
        &times; turns/year vs target &times; excess capital locked &times; monthly trend &amp; CAPA
        closure. Founder-gated view: DIO-status distribution, category scorecards, category &times;
        status matrix, root-cause pareto, and excess-capital impact digest across warehouses. Lines
        flagged critical-excess, above-target, or worsening surface in the high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. DIO status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No DIO board lines logged yet."
          rowKey={(r, i) => String(r.dio_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; DIO-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by category."
          rowKey={(r, i) => `${r.category}-${r.dio_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly DIO / turns trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Excess-capital impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No excess-capital rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk DIO queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.line_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
