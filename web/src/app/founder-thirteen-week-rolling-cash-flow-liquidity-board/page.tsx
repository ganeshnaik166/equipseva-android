import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { cash_verdict: string; lines: number; pct: number };
type WeekRow = {
  week_ending: string;
  week_number: number;
  lines: number;
  on_plan: number;
  needs_action: number;
  buffer_breaches: number;
  total_forecast_rupees: number;
  total_actual_rupees: number;
  min_running_balance_rupees: number;
};
type MatrixRow = {
  cash_line: string;
  liquidity_status: string;
  lines: number;
  on_plan: number;
  needs_action: number;
  avg_variance_pct: number;
};
type TrendRow = {
  week_ending: string;
  week_number: number;
  lines: number;
  buffer_breaches: number;
  needs_action: number;
  min_running_balance_rupees: number;
  total_variance_rupees: number;
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
  facility_impact: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  counterparty_name: string;
  week_ending: string;
  week_number: number;
  cash_line: string;
  forecast_amount_rupees: number;
  actual_amount_rupees: number;
  variance_rupees: number;
  liquidity_status: string;
  cash_verdict: string;
  collection_confidence: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    weekRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3421_cash_verdict_rollup'),
    supabase.rpc('founder_r3421_week_scorecard'),
    supabase.rpc('founder_r3421_cash_line_liquidity_matrix'),
    supabase.rpc('founder_r3421_weekly_liquidity_trend'),
    supabase.rpc('founder_r3421_capa_status_board'),
    supabase.rpc('founder_r3421_root_cause_pareto'),
    supabase.rpc('founder_r3421_facility_impact_digest'),
    supabase.rpc('founder_r3421_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const weekRows: WeekRow[] = (weekRes.data as WeekRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'cash_verdict', header: 'Cash Verdict' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const weekCols: Column<WeekRow>[] = [
    { key: 'week_ending', header: 'Week Ending' },
    { key: 'week_number', header: 'Wk #' },
    { key: 'lines', header: 'Lines' },
    { key: 'on_plan', header: 'On Plan' },
    { key: 'needs_action', header: 'Needs Action' },
    { key: 'buffer_breaches', header: 'Buffer Breaches' },
    { key: 'total_forecast_rupees', header: 'Forecast (INR)' },
    { key: 'total_actual_rupees', header: 'Actual (INR)' },
    { key: 'min_running_balance_rupees', header: 'Min Running Bal (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'cash_line', header: 'Cash Line' },
    { key: 'liquidity_status', header: 'Liquidity Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'on_plan', header: 'On Plan' },
    { key: 'needs_action', header: 'Needs Action' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'week_ending', header: 'Week Ending' },
    { key: 'week_number', header: 'Wk #' },
    { key: 'lines', header: 'Lines' },
    { key: 'buffer_breaches', header: 'Buffer Breaches' },
    { key: 'needs_action', header: 'Needs Action' },
    { key: 'min_running_balance_rupees', header: 'Min Running Bal (INR)' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
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
    { key: 'facility_impact', header: 'Facility Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'counterparty_name', header: 'Counterparty' },
    { key: 'week_ending', header: 'Week Ending' },
    { key: 'week_number', header: 'Wk #' },
    { key: 'cash_line', header: 'Cash Line' },
    { key: 'forecast_amount_rupees', header: 'Forecast (INR)' },
    { key: 'actual_amount_rupees', header: 'Actual (INR)' },
    { key: 'variance_rupees', header: 'Variance (INR)' },
    { key: 'liquidity_status', header: 'Liquidity' },
    { key: 'cash_verdict', header: 'Verdict' },
    { key: 'collection_confidence', header: 'Confidence' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder 13-Week Rolling Cash-Flow &amp; Liquidity Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Direct 13-week rolling cash-flow forecast and liquidity-runway governance for EquipSeva.
        Rows track each week &times; cash line (opening balance, AMC / spares / project collections,
        payroll, vendor payments, statutory taxes, capex, loan EMI, closing balance) with forecast
        vs actual variance, running balance, min-buffer breach flags and collection confidence.
        Founder-gated view: cash verdicts, per-week scorecards, cash-line &times; liquidity-status
        matrix, weekly liquidity trend, root-cause pareto, and facility-impact digest &mdash; with a
        CAPA log of collection, payment-deferral &amp; facility actions.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Cash verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No cash-flow lines logged yet."
          rowKey={(r, i) => String(r.cash_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Per-week scorecard</h2>
        <DataTable
          rows={weekRows}
          columns={weekCols}
          emptyMessage="No weekly rollups."
          rowKey={(r, i) => String(r.week_ending ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Cash line &times; liquidity status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by cash line."
          rowKey={(r, i) => `${r.cash_line}-${r.liquidity_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Weekly liquidity trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.week_ending ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Facility impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No facility-impact rollups."
          rowKey={(r, i) => String(r.facility_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk liquidity queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.counterparty_name}-${r.week_ending}-${r.cash_line}-${i}`}
        />
      </section>
    </main>
  );
}
