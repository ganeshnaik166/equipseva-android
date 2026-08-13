import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { onboarding_status: string; customers: number; pct: number };
type RegionRow = {
  region: string;
  total_customers: number;
  on_track: number;
  stalled: number;
  at_risk_churn: number;
  completed_success: number;
  champion_identified_count: number;
  avg_adoption_score: number | null;
  avg_days_to_install: number | null;
};
type MatrixRow = {
  onboarding_stage: string;
  onboarding_status: string;
  customers: number;
  avg_adoption_score: number | null;
};
type TrendRow = {
  period_month: string;
  customers: number;
  activated_or_beyond: number;
  avg_days_to_first_use: number | null;
  avg_adoption_score: number | null;
  worsening_customers: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  region: string;
  stalled_or_at_risk_customers: number;
  avg_days_to_install: number | null;
  no_champion_count: number;
  avg_milestones_completed: number | null;
};
type RiskRow = {
  customer_name: string;
  region: string;
  period_month: string;
  onboarding_stage: string;
  onboarding_status: string;
  days_to_install: number | null;
  days_to_first_use: number | null;
  milestones_completed: number | null;
  milestones_total: number | null;
  champion_identified: boolean;
  adoption_score: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3725_onboarding_status_rollup'),
    supabase.rpc('founder_r3725_region_scorecard'),
    supabase.rpc('founder_r3725_onboarding_stage_status_matrix'),
    supabase.rpc('founder_r3725_monthly_activation_trend'),
    supabase.rpc('founder_r3725_capa_status_board'),
    supabase.rpc('founder_r3725_root_cause_pareto'),
    supabase.rpc('founder_r3725_stalled_onboarding_digest'),
    supabase.rpc('founder_r3725_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'onboarding_status', header: 'Onboarding Status' },
    { key: 'customers', header: 'Customers' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_customers', header: 'Customers' },
    { key: 'on_track', header: 'On Track' },
    { key: 'stalled', header: 'Stalled' },
    { key: 'at_risk_churn', header: 'At-Risk Churn' },
    { key: 'completed_success', header: 'Completed Success' },
    { key: 'champion_identified_count', header: 'Champion Identified' },
    { key: 'avg_adoption_score', header: 'Avg Adoption Score' },
    { key: 'avg_days_to_install', header: 'Avg Days to Install' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'onboarding_stage', header: 'Stage' },
    { key: 'onboarding_status', header: 'Onboarding Status' },
    { key: 'customers', header: 'Customers' },
    { key: 'avg_adoption_score', header: 'Avg Adoption Score' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'customers', header: 'Customers' },
    { key: 'activated_or_beyond', header: 'Activated+' },
    { key: 'avg_days_to_first_use', header: 'Avg Days to First Use' },
    { key: 'avg_adoption_score', header: 'Avg Adoption Score' },
    { key: 'worsening_customers', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'stalled_or_at_risk_customers', header: 'Stalled / At-Risk' },
    { key: 'avg_days_to_install', header: 'Avg Days to Install' },
    { key: 'no_champion_count', header: 'No Champion' },
    { key: 'avg_milestones_completed', header: 'Avg Milestones Completed' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'region', header: 'Region' },
    { key: 'period_month', header: 'Month' },
    { key: 'onboarding_stage', header: 'Stage' },
    { key: 'onboarding_status', header: 'Onboarding Status' },
    { key: 'days_to_install', header: 'Days to Install' },
    { key: 'days_to_first_use', header: 'Days to First Use' },
    { key: 'milestones_completed', header: 'Milestones Done' },
    { key: 'milestones_total', header: 'Milestones Total' },
    { key: 'champion_identified', header: 'Champion' },
    { key: 'adoption_score', header: 'Adoption Score' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Onboarding Activation — First-90-Days Milestone Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        New-customer onboarding journey (0-90 days post contract-sign) &mdash; install completion,
        training completion, first-use activation, and steady-state adoption &times; region
        &times; period month, with milestone counts, days-to-install &amp; days-to-first-use, and
        champion identification. Founder-gated view: onboarding-status distribution, region
        scorecards, stage &times; status matrix, monthly activation trend, CAPA closure for
        stalled onboardings, root-cause pareto, a stalled-onboarding digest, and a high-risk queue
        of stalled &amp; at-risk-churn customers.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Onboarding-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No onboarding rows logged yet."
          rowKey={(r, i) => String(r.onboarding_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Onboarding stage &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No onboardings by stage."
          rowKey={(r, i) => `${r.onboarding_stage}-${r.onboarding_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly activation trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Stalled-onboarding digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No stalled or at-risk onboardings."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk onboarding queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk onboardings."
          rowKey={(r, i) => `${r.customer_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
