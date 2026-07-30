import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { adjustment_status: string; entries: number; pct: number };
type BuRow = {
  business_unit: string;
  entries: number;
  total_credit_value_rupees: number;
  total_debit_value_rupees: number;
  total_gross_sales_rupees: number;
  avg_adjustment_pct: number;
  total_unapproved_rupees: number;
  leakage_flag: number;
};
type MatrixRow = {
  business_unit: string;
  adjustment_status: string;
  entries: number;
  credit_value_rupees: number;
  unapproved_value_rupees: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  credit_notes_value_rupees: number;
  debit_notes_value_rupees: number;
  gross_sales_rupees: number;
  avg_adjustment_pct: number;
  leakage_entries: number;
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
type DigestRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  business_unit: string;
  adjustment_ref: string;
  period_month: string;
  adjustment_status: string;
  adjustment_pct: number | null;
  credit_notes_value_rupees: number;
  unapproved_value_rupees: number | null;
  pricing_error_value_rupees: number | null;
  trend_dir: string;
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
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3608_adjustment_status_rollup'),
    supabase.rpc('founder_r3608_business_unit_scorecard'),
    supabase.rpc('founder_r3608_bu_status_matrix'),
    supabase.rpc('founder_r3608_monthly_adjustment_trend'),
    supabase.rpc('founder_r3608_capa_status_board'),
    supabase.rpc('founder_r3608_root_cause_pareto'),
    supabase.rpc('founder_r3608_adjustment_impact_digest'),
    supabase.rpc('founder_r3608_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const buRows: BuRow[] = (buRes.data as BuRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'adjustment_status', header: 'Adjustment Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const buCols: Column<BuRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_credit_value_rupees', header: 'Credit Notes (INR)' },
    { key: 'total_debit_value_rupees', header: 'Debit Notes (INR)' },
    { key: 'total_gross_sales_rupees', header: 'Gross Sales (INR)' },
    { key: 'avg_adjustment_pct', header: 'Avg Adj %' },
    { key: 'total_unapproved_rupees', header: 'Unapproved (INR)' },
    { key: 'leakage_flag', header: 'Leakage / Control-Gap' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'adjustment_status', header: 'Adjustment Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'credit_value_rupees', header: 'Credit Value (INR)' },
    { key: 'unapproved_value_rupees', header: 'Unapproved (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'credit_notes_value_rupees', header: 'Credit Notes (INR)' },
    { key: 'debit_notes_value_rupees', header: 'Debit Notes (INR)' },
    { key: 'gross_sales_rupees', header: 'Gross Sales (INR)' },
    { key: 'avg_adjustment_pct', header: 'Avg Adj %' },
    { key: 'leakage_entries', header: 'Leakage Entries' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'adjustment_ref', header: 'Ref' },
    { key: 'period_month', header: 'Month' },
    { key: 'adjustment_status', header: 'Status' },
    { key: 'adjustment_pct', header: 'Adj %' },
    { key: 'credit_notes_value_rupees', header: 'Credit Notes (INR)' },
    { key: 'unapproved_value_rupees', header: 'Unapproved (INR)' },
    { key: 'pricing_error_value_rupees', header: 'Pricing Error (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Credit-Note / Debit-Note / Billing-Adjustment Reconciliation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated finance view of credit-note, debit-note &amp; billing-adjustment reconciliation and
        adjustment leakage per business unit (amc_services, spare_parts, projects, diagnostics, rentals)
        &times; period &times; credit/debit note values &times; gross sales &times; adjustment %
        &times; returns &times; pricing-error value &times; unapproved value &times; adjustment status
        &amp; trend &amp; CAPA closure. Surfaces status distribution, business-unit scorecards,
        root-cause pareto and an adjustment-impact digest so leakage_risk &amp; control_gap exposure is
        visible before it hits margin.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Adjustment-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No adjustment entries logged yet."
          rowKey={(r, i) => String(r.adjustment_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business unit &times; adjustment-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.adjustment_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly adjustment trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Adjustment-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No impact digest rows."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk leakage queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk adjustments."
          rowKey={(r, i) => `${r.adjustment_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
