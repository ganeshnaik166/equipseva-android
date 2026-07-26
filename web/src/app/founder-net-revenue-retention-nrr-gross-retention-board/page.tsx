import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { retention_status: string; accounts: number; pct: number };
type SegmentRow = {
  customer_segment: string;
  accounts: number;
  expanding: number;
  stable: number;
  contracting: number;
  churning: number;
  total_starting_arr_rupees: number;
  total_ending_arr_rupees: number;
  avg_nrr_pct: number;
  avg_grr_pct: number;
};
type MatrixRow = {
  customer_segment: string;
  retention_status: string;
  accounts: number;
  total_ending_arr_rupees: number;
  avg_nrr_pct: number;
};
type TrendRow = {
  period_month: string;
  accounts: number;
  total_starting_arr_rupees: number;
  total_expansion_rupees: number;
  total_contraction_rupees: number;
  total_churn_rupees: number;
  total_ending_arr_rupees: number;
  avg_nrr_pct: number;
  avg_grr_pct: number;
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
  retention_status: string;
  accounts: number;
  total_expansion_rupees: number;
  total_contraction_rupees: number;
  total_churn_rupees: number;
  net_arr_change_rupees: number;
};
type RiskRow = {
  customer_name: string;
  account_code: string;
  customer_segment: string;
  cohort: string;
  period_month: string;
  retention_status: string;
  nrr_pct: number | null;
  grr_pct: number | null;
  contraction_rupees: number | null;
  churn_rupees: number | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    segmentRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3465_retention_status_rollup'),
    supabase.rpc('founder_r3465_segment_scorecard'),
    supabase.rpc('founder_r3465_segment_status_matrix'),
    supabase.rpc('founder_r3465_monthly_nrr_trend'),
    supabase.rpc('founder_r3465_capa_status_board'),
    supabase.rpc('founder_r3465_root_cause_pareto'),
    supabase.rpc('founder_r3465_arr_impact_digest'),
    supabase.rpc('founder_r3465_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const segmentRows: SegmentRow[] = (segmentRes.data as SegmentRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'retention_status', header: 'Retention Status' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'pct', header: 'Share %' },
  ];

  const segmentCols: Column<SegmentRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'expanding', header: 'Expanding' },
    { key: 'stable', header: 'Stable' },
    { key: 'contracting', header: 'Contracting' },
    { key: 'churning', header: 'Churning' },
    { key: 'total_starting_arr_rupees', header: 'Starting ARR (INR)' },
    { key: 'total_ending_arr_rupees', header: 'Ending ARR (INR)' },
    { key: 'avg_nrr_pct', header: 'Avg NRR %' },
    { key: 'avg_grr_pct', header: 'Avg GRR %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'retention_status', header: 'Retention Status' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_ending_arr_rupees', header: 'Ending ARR (INR)' },
    { key: 'avg_nrr_pct', header: 'Avg NRR %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_starting_arr_rupees', header: 'Starting ARR (INR)' },
    { key: 'total_expansion_rupees', header: 'Expansion (INR)' },
    { key: 'total_contraction_rupees', header: 'Contraction (INR)' },
    { key: 'total_churn_rupees', header: 'Churn (INR)' },
    { key: 'total_ending_arr_rupees', header: 'Ending ARR (INR)' },
    { key: 'avg_nrr_pct', header: 'Avg NRR %' },
    { key: 'avg_grr_pct', header: 'Avg GRR %' },
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
    { key: 'retention_status', header: 'Retention Status' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_expansion_rupees', header: 'Expansion (INR)' },
    { key: 'total_contraction_rupees', header: 'Contraction (INR)' },
    { key: 'total_churn_rupees', header: 'Churn (INR)' },
    { key: 'net_arr_change_rupees', header: 'Net ARR Change (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'account_code', header: 'Account' },
    { key: 'customer_segment', header: 'Segment' },
    { key: 'cohort', header: 'Cohort' },
    { key: 'period_month', header: 'Month' },
    { key: 'retention_status', header: 'Status' },
    { key: 'nrr_pct', header: 'NRR %' },
    { key: 'grr_pct', header: 'GRR %' },
    { key: 'contraction_rupees', header: 'Contraction (INR)' },
    { key: 'churn_rupees', header: 'Churn (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Net-Revenue-Retention (NRR) / Gross-Retention Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated retention board decomposing net-revenue-retention across customer cohorts &mdash;
        starting ARR &times; expansion &times; contraction &times; churn &times; ending ARR &times; NRR%
        &amp; GRR% by segment (enterprise hospitals, regional chains, standalone clinics, diagnostic labs
        &amp; government). Views: retention-status distribution, segment scorecards, segment &times; status
        matrix, monthly NRR/GRR trend, CAPA status board, root-cause pareto, ARR-impact digest, and a
        high-risk queue of churning / contracting / worsening accounts.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Retention-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No retention rows logged yet."
          rowKey={(r, i) => String(r.retention_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Customer-segment scorecard</h2>
        <DataTable
          rows={segmentRows}
          columns={segmentCols}
          emptyMessage="No segment rollups."
          rowKey={(r, i) => String(r.customer_segment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Segment &times; retention-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.customer_segment}-${r.retention_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly NRR / GRR trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. ARR-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No ARR-impact rollups."
          rowKey={(r, i) => String(r.retention_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk retention queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk accounts."
          rowKey={(r, i) => `${r.account_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
