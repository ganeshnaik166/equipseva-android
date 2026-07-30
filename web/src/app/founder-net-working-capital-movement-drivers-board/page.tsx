import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  nwc_status: string;
  entries: number;
  total_nwc_rupees: number;
  pct: number;
};
type BuRow = {
  business_unit: string;
  entries: number;
  total_nwc_rupees: number;
  avg_nwc_to_revenue_pct: number;
  avg_target_pct: number;
  total_cash_released_rupees: number;
  at_risk: number;
  avg_dso_days: number;
};
type MatrixRow = {
  business_unit: string;
  nwc_status: string;
  entries: number;
  total_nwc_rupees: number;
  total_cash_released_rupees: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_nwc_rupees: number;
  total_nwc_change_rupees: number;
  total_cash_released_rupees: number;
  avg_nwc_to_revenue_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cash_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cash_impact_rupees: number;
  pct: number;
};
type CashRow = {
  business_unit: string;
  months: number;
  total_cash_released_rupees: number;
  total_nwc_change_rupees: number;
  avg_nwc_to_revenue_pct: number;
};
type RiskRow = {
  business_unit: string;
  movement_code: string;
  period_month: string;
  nwc_status: string;
  net_working_capital_rupees: number;
  nwc_change_rupees: number;
  nwc_to_revenue_pct: number;
  target_nwc_to_revenue_pct: number;
  dso_days: number;
  trend_dir: string | null;
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
    cashRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3600_nwc_status_rollup'),
    supabase.rpc('founder_r3600_business_unit_scorecard'),
    supabase.rpc('founder_r3600_business_unit_status_matrix'),
    supabase.rpc('founder_r3600_monthly_nwc_trend'),
    supabase.rpc('founder_r3600_capa_status_board'),
    supabase.rpc('founder_r3600_root_cause_pareto'),
    supabase.rpc('founder_r3600_cash_release_digest'),
    supabase.rpc('founder_r3600_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const buRows: BuRow[] = (buRes.data as BuRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const cashRows: CashRow[] = (cashRes.data as CashRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'nwc_status', header: 'NWC Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_nwc_rupees', header: 'Total NWC (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const buCols: Column<BuRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_nwc_rupees', header: 'Total NWC (INR)' },
    { key: 'avg_nwc_to_revenue_pct', header: 'Avg NWC/Rev %' },
    { key: 'avg_target_pct', header: 'Avg Target %' },
    { key: 'total_cash_released_rupees', header: 'Cash Released (INR)' },
    { key: 'at_risk', header: 'Bloated / Critical' },
    { key: 'avg_dso_days', header: 'Avg DSO Days' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'nwc_status', header: 'NWC Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_nwc_rupees', header: 'Total NWC (INR)' },
    { key: 'total_cash_released_rupees', header: 'Cash Released (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_nwc_rupees', header: 'Total NWC (INR)' },
    { key: 'total_nwc_change_rupees', header: 'NWC Change (INR)' },
    { key: 'total_cash_released_rupees', header: 'Cash Released (INR)' },
    { key: 'avg_nwc_to_revenue_pct', header: 'Avg NWC/Rev %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cash_impact_rupees', header: 'Avg Cash Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cash_impact_rupees', header: 'Total Cash Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const cashCols: Column<CashRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'months', header: 'Months' },
    { key: 'total_cash_released_rupees', header: 'Cash Released (INR)' },
    { key: 'total_nwc_change_rupees', header: 'NWC Change (INR)' },
    { key: 'avg_nwc_to_revenue_pct', header: 'Avg NWC/Rev %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'movement_code', header: 'Movement' },
    { key: 'period_month', header: 'Month' },
    { key: 'nwc_status', header: 'Status' },
    { key: 'net_working_capital_rupees', header: 'NWC (INR)' },
    { key: 'nwc_change_rupees', header: 'NWC Change (INR)' },
    { key: 'nwc_to_revenue_pct', header: 'NWC/Rev %' },
    { key: 'target_nwc_to_revenue_pct', header: 'Target %' },
    { key: 'dso_days', header: 'DSO Days' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Net-Working-Capital Movement &amp; Drivers Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated net-working-capital movement log — business unit (AMC services, spare parts,
        projects, diagnostics, rentals) &times; period &times; receivables &times; inventory &times;
        payables &times; net working capital &times; NWC change &times; NWC-to-revenue % vs target
        &times; cash released &times; DSO/DPO/DIO days &times; status verdict &times; trend &amp; CAPA
        closure. Rollups cover the NWC-status mix, business-unit scorecards, root-cause pareto, and
        the high-risk queue where NWC is bloated or critical or drifting above target.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. NWC status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No NWC movements logged yet."
          rowKey={(r, i) => String(r.nwc_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business unit &times; NWC status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No movements by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.nwc_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly NWC trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cash-release digest</h2>
        <DataTable
          rows={cashRows}
          columns={cashCols}
          emptyMessage="No cash-release rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk NWC queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk movements."
          rowKey={(r, i) => `${r.movement_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
