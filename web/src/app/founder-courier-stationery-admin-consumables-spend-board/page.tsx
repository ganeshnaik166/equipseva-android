import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { spend_status: string; entries: number; pct: number };
type OfficeRow = {
  office_location: string;
  entries: number;
  within_ct: number;
  over_ct: number;
  risk_ct: number;
  total_spend_rupees: number;
  total_budget_rupees: number;
  unapproved_rupees: number;
  within_pct: number;
};
type MatrixRow = {
  category: string;
  spend_status: string;
  entries: number;
  total_spend_rupees: number;
  avg_variance_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_spend_rupees: number;
  total_budget_rupees: number;
  over_budget_ct: number;
  unapproved_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_excess_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_excess_rupees: number;
  pct: number;
};
type VarianceRow = {
  variance_band: string;
  entries: number;
  total_spend_rupees: number;
  total_budget_rupees: number;
  unapproved_rupees: number;
};
type RiskRow = {
  office_location: string;
  record_code: string;
  spend_category: string;
  category: string;
  period_month: string;
  monthly_spend_rupees: number;
  budget_rupees: number;
  variance_pct: number | null;
  spend_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    officeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    varianceRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3677_spend_status_rollup'),
    supabase.rpc('founder_r3677_office_scorecard'),
    supabase.rpc('founder_r3677_category_status_matrix'),
    supabase.rpc('founder_r3677_monthly_spend_trend'),
    supabase.rpc('founder_r3677_capa_status_board'),
    supabase.rpc('founder_r3677_root_cause_pareto'),
    supabase.rpc('founder_r3677_variance_digest'),
    supabase.rpc('founder_r3677_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const officeRows: OfficeRow[] = (officeRes.data as OfficeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const varianceRows: VarianceRow[] = (varianceRes.data as VarianceRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const officeCols: Column<OfficeRow>[] = [
    { key: 'office_location', header: 'Office' },
    { key: 'entries', header: 'Entries' },
    { key: 'within_ct', header: 'Within / On Budget' },
    { key: 'over_ct', header: 'Over Budget' },
    { key: 'risk_ct', header: 'Fragmented / Uncontrolled' },
    { key: 'total_spend_rupees', header: 'Spend (INR)' },
    { key: 'total_budget_rupees', header: 'Budget (INR)' },
    { key: 'unapproved_rupees', header: 'Unapproved (INR)' },
    { key: 'within_pct', header: 'Discipline %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_spend_rupees', header: 'Spend (INR)' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_spend_rupees', header: 'Spend (INR)' },
    { key: 'total_budget_rupees', header: 'Budget (INR)' },
    { key: 'over_budget_ct', header: 'Over / Uncontrolled' },
    { key: 'unapproved_rupees', header: 'Unapproved (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_excess_rupees', header: 'Avg Excess (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_excess_rupees', header: 'Total Excess (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const varianceCols: Column<VarianceRow>[] = [
    { key: 'variance_band', header: 'Variance Band' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_spend_rupees', header: 'Spend (INR)' },
    { key: 'total_budget_rupees', header: 'Budget (INR)' },
    { key: 'unapproved_rupees', header: 'Unapproved (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'office_location', header: 'Office' },
    { key: 'record_code', header: 'Record' },
    { key: 'spend_category', header: 'Spend Category' },
    { key: 'category', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'monthly_spend_rupees', header: 'Spend (INR)' },
    { key: 'budget_rupees', header: 'Budget (INR)' },
    { key: 'variance_pct', header: 'Variance %' },
    { key: 'spend_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Courier / Stationery / Admin-Consumables Spend Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Office-admin consumables spend discipline — office &times; category (document courier,
        spare-parts courier, stationery, pantry, housekeeping, misc admin) &times; monthly spend vs
        budget &times; variance % &times; transactions &amp; avg ticket &times; bulk-purchase share
        &times; vendor fragmentation &times; unapproved spend &amp; CAPA closure. Founder-gated view:
        spend-status rollups, office scorecards, variance-band digest, root-cause pareto, and the
        over-budget / uncontrolled high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Spend status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No spend records logged yet."
          rowKey={(r, i) => String(r.spend_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Office spend scorecard</h2>
        <DataTable
          rows={officeRows}
          columns={officeCols}
          emptyMessage="No office rollups."
          rowKey={(r, i) => String(r.office_location ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; spend-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by category."
          rowKey={(r, i) => `${r.category}-${r.spend_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly spend trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Variance-band digest</h2>
        <DataTable
          rows={varianceRows}
          columns={varianceCols}
          emptyMessage="No variance rollups."
          rowKey={(r, i) => String(r.variance_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk spend queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk spend records."
          rowKey={(r, i) => `${r.record_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
