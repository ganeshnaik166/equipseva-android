import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  quality_status: string;
  entries: number;
  total_net_profit_rupees: number;
  pct: number;
};
type UnitRow = {
  business_unit: string;
  months: number;
  total_net_profit_rupees: number;
  total_ocf_rupees: number;
  avg_accruals_ratio_pct: number;
  avg_cash_realization_pct: number;
  red_flag_months: number;
};
type MatrixRow = {
  business_unit: string;
  quality_status: string;
  entries: number;
  avg_accruals_ratio_pct: number;
  avg_cash_realization_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_net_profit_rupees: number;
  total_ocf_rupees: number;
  avg_accruals_ratio_pct: number;
  avg_cash_realization_pct: number;
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
type AccrualRow = {
  business_unit: string;
  entries: number;
  total_accruals_rupees: number;
  avg_accruals_ratio_pct: number;
  total_non_recurring_rupees: number;
  total_provision_rupees: number;
  total_one_time_gains_rupees: number;
};
type RiskRow = {
  business_unit: string;
  entry_code: string;
  period_month: string;
  quality_status: string;
  accruals_ratio_pct: number | null;
  cash_realization_pct: number | null;
  net_profit_rupees: number;
  operating_cash_flow_rupees: number;
  trend_dir: string;
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
    accrualRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3612_quality_status_rollup'),
    supabase.rpc('founder_r3612_business_unit_scorecard'),
    supabase.rpc('founder_r3612_unit_quality_matrix'),
    supabase.rpc('founder_r3612_monthly_quality_trend'),
    supabase.rpc('founder_r3612_capa_status_board'),
    supabase.rpc('founder_r3612_root_cause_pareto'),
    supabase.rpc('founder_r3612_accruals_digest'),
    supabase.rpc('founder_r3612_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const unitRows: UnitRow[] = (unitRes.data as UnitRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const accrualRows: AccrualRow[] = (accrualRes.data as AccrualRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'quality_status', header: 'Quality Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_net_profit_rupees', header: 'Net Profit (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const unitCols: Column<UnitRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'months', header: 'Months' },
    { key: 'total_net_profit_rupees', header: 'Net Profit (INR)' },
    { key: 'total_ocf_rupees', header: 'Op Cash Flow (INR)' },
    { key: 'avg_accruals_ratio_pct', header: 'Avg Accruals Ratio %' },
    { key: 'avg_cash_realization_pct', header: 'Avg Cash Real %' },
    { key: 'red_flag_months', header: 'Aggressive / Red-Flag' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'quality_status', header: 'Quality Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_accruals_ratio_pct', header: 'Avg Accruals Ratio %' },
    { key: 'avg_cash_realization_pct', header: 'Avg Cash Real %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_net_profit_rupees', header: 'Net Profit (INR)' },
    { key: 'total_ocf_rupees', header: 'Op Cash Flow (INR)' },
    { key: 'avg_accruals_ratio_pct', header: 'Avg Accruals Ratio %' },
    { key: 'avg_cash_realization_pct', header: 'Avg Cash Real %' },
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

  const accrualCols: Column<AccrualRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_accruals_rupees', header: 'Total Accruals (INR)' },
    { key: 'avg_accruals_ratio_pct', header: 'Avg Accruals Ratio %' },
    { key: 'total_non_recurring_rupees', header: 'Non-Recurring (INR)' },
    { key: 'total_provision_rupees', header: 'Provisions (INR)' },
    { key: 'total_one_time_gains_rupees', header: 'One-Time Gains (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'entry_code', header: 'Entry' },
    { key: 'period_month', header: 'Month' },
    { key: 'quality_status', header: 'Status' },
    { key: 'accruals_ratio_pct', header: 'Accruals Ratio %' },
    { key: 'cash_realization_pct', header: 'Cash Real %' },
    { key: 'net_profit_rupees', header: 'Net Profit (INR)' },
    { key: 'operating_cash_flow_rupees', header: 'Op Cash Flow (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Earnings-Quality / Accruals-Ratio / Cash-Realization Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated earnings-quality lens across business units (AMC services, spare parts, projects,
        diagnostics, rentals, consumables, turnkey installations &amp; refurbished equipment). Tracks net
        profit &times; operating cash flow &times; accruals &times; accruals-ratio % &times; cash-realization %
        &times; non-recurring items &times; provisions &times; one-time gains, with a quality verdict from
        high-quality through aggressive &amp; red-flag. Low cash realization or a high accruals ratio signals
        profit that is not converting to cash &mdash; the CAPA board, root-cause pareto and high-risk queue
        surface where reported earnings are being propped by accruals or one-time items.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Earnings-quality status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No earnings-quality entries logged yet."
          rowKey={(r, i) => String(r.quality_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit scorecard</h2>
        <DataTable
          rows={unitRows}
          columns={unitCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business unit &times; quality-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.business_unit}-${r.quality_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly earnings-quality trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Accruals digest</h2>
        <DataTable
          rows={accrualRows}
          columns={accrualCols}
          emptyMessage="No accruals data."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk earnings-quality queue</h2>
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
