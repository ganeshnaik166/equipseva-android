import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { review_status: string; reviews: number; pct: number };
type SiteRow = {
  site_scope: string;
  reviews: number;
  on_time: number;
  late: number;
  pending_or_overdue: number;
  avg_input_coverage_pct: number;
  avg_closure_pct: number;
  total_overdue_actions: number;
};
type MatrixRow = {
  input_area: string;
  review_status: string;
  reviews: number;
  avg_closure_pct: number;
  overdue_actions: number;
};
type TrendRow = {
  period_month: string;
  reviews: number;
  decisions: number;
  actions_assigned: number;
  actions_closed: number;
  avg_closure_pct: number;
  overdue_actions: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type OverdueRow = {
  review_ref: string;
  site_scope: string;
  review_date: string;
  review_status: string;
  actions_assigned: number;
  actions_closed: number;
  overdue_actions: number;
  action_closure_pct: number;
  trend_dir: string;
};
type RiskRow = {
  review_ref: string;
  site_scope: string;
  period_month: string;
  review_date: string;
  review_status: string;
  input_area: string;
  overdue_actions: number;
  action_closure_pct: number;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    siteRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    overdueRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3703_review_status_rollup'),
    supabase.rpc('founder_r3703_site_scope_scorecard'),
    supabase.rpc('founder_r3703_input_area_status_matrix'),
    supabase.rpc('founder_r3703_monthly_closure_trend'),
    supabase.rpc('founder_r3703_capa_status_board'),
    supabase.rpc('founder_r3703_root_cause_pareto'),
    supabase.rpc('founder_r3703_overdue_action_digest'),
    supabase.rpc('founder_r3703_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const overdueRows: OverdueRow[] = (overdueRes.data as OverdueRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'review_status', header: 'Review Status' },
    { key: 'reviews', header: 'Reviews' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_scope', header: 'Site / Scope' },
    { key: 'reviews', header: 'Reviews' },
    { key: 'on_time', header: 'On Time' },
    { key: 'late', header: 'Late' },
    { key: 'pending_or_overdue', header: 'Pending / Overdue' },
    { key: 'avg_input_coverage_pct', header: 'Avg Input Coverage %' },
    { key: 'avg_closure_pct', header: 'Avg Closure %' },
    { key: 'total_overdue_actions', header: 'Overdue Actions' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'input_area', header: 'Input Area' },
    { key: 'review_status', header: 'Review Status' },
    { key: 'reviews', header: 'Reviews' },
    { key: 'avg_closure_pct', header: 'Avg Closure %' },
    { key: 'overdue_actions', header: 'Overdue Actions' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'reviews', header: 'Reviews' },
    { key: 'decisions', header: 'Decisions' },
    { key: 'actions_assigned', header: 'Actions Assigned' },
    { key: 'actions_closed', header: 'Actions Closed' },
    { key: 'avg_closure_pct', header: 'Avg Closure %' },
    { key: 'overdue_actions', header: 'Overdue Actions' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { key: 'review_ref', header: 'Review Ref' },
    { key: 'site_scope', header: 'Site / Scope' },
    { key: 'review_date', header: 'Review Date' },
    { key: 'review_status', header: 'Status' },
    { key: 'actions_assigned', header: 'Assigned' },
    { key: 'actions_closed', header: 'Closed' },
    { key: 'overdue_actions', header: 'Overdue' },
    { key: 'action_closure_pct', header: 'Closure %' },
    { key: 'trend_dir', header: 'Trend' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'review_ref', header: 'Review Ref' },
    { key: 'site_scope', header: 'Site / Scope' },
    { key: 'period_month', header: 'Month' },
    { key: 'review_date', header: 'Review Date' },
    { key: 'review_status', header: 'Status' },
    { key: 'input_area', header: 'Input Area' },
    { key: 'overdue_actions', header: 'Overdue' },
    { key: 'action_closure_pct', header: 'Closure %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        QMS Management-Review (ISO-13485) Action Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        ISO-13485 clause-5.6 management-review meetings — site scope &times; inputs required vs
        covered &times; decisions made &times; actions assigned vs closed &times; overdue actions
        &times; input area (audit results, customer feedback, process performance, CAPA status,
        regulatory changes, resource needs) &times; review status &amp; trend, plus CAPA closure.
        Founder-gated view: status rollups, site scorecards, input-area &times; status matrix,
        monthly closure trend, root-cause pareto, overdue-action digest &amp; high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Review status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No management reviews logged yet."
          rowKey={(r, i) => String(r.review_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site-scope scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.site_scope ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Input area &times; review status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No reviews by input area."
          rowKey={(r, i) => `${r.input_area}-${r.review_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly action-closure trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Overdue-action digest</h2>
        <DataTable
          rows={overdueRows}
          columns={overdueCols}
          emptyMessage="No reviews with overdue actions."
          rowKey={(r, i) => `${r.review_ref}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk review queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk reviews."
          rowKey={(r, i) => `${r.review_ref}-${r.review_date}-${i}`}
        />
      </section>
    </main>
  );
}
