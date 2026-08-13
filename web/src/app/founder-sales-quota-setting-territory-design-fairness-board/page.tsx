import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { fairness_status: string; reps: number; pct: number };
type TerritoryRow = {
  territory_name: string;
  reps: number;
  well_calibrated: number;
  overreach: number;
  disputed_unresolved: number;
  appeals_filed: number;
  appeals_upheld: number;
  avg_quota_to_potential_ratio: number;
  avg_fairness_score: number;
  total_new_quota_rupees: number;
};
type MatrixRow = {
  quota_class: string;
  fairness_status: string;
  reps: number;
  avg_quota_increase_pct: number;
  avg_fairness_score: number;
};
type TrendRow = {
  period_month: string;
  reps: number;
  avg_quota_increase_pct: number;
  avg_quota_to_potential_ratio: number;
  appeals_filed: number;
  worsening_reps: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  closed_count: number;
  overdue_count: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type AppealRow = {
  territory_name: string;
  rep_name: string;
  period_month: string;
  prior_year_attainment_pct: number | null;
  quota_to_potential_ratio: number | null;
  appeal_upheld: boolean;
  territory_realigned: boolean;
  fairness_status: string;
};
type RiskRow = {
  rep_name: string;
  territory_name: string;
  period_month: string;
  fairness_status: string;
  quota_to_potential_ratio: number | null;
  quota_increase_pct: number | null;
  rep_fairness_score: number | null;
  appeal_filed: boolean;
  territory_realigned: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    territoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    appealRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3729_fairness_status_rollup'),
    supabase.rpc('founder_r3729_territory_scorecard'),
    supabase.rpc('founder_r3729_quota_class_status_matrix'),
    supabase.rpc('founder_r3729_monthly_quota_increase_trend'),
    supabase.rpc('founder_r3729_capa_status_board'),
    supabase.rpc('founder_r3729_root_cause_pareto'),
    supabase.rpc('founder_r3729_appeal_digest'),
    supabase.rpc('founder_r3729_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const territoryRows: TerritoryRow[] = (territoryRes.data as TerritoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const appealRows: AppealRow[] = (appealRes.data as AppealRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'fairness_status', header: 'Fairness Status' },
    { key: 'reps', header: 'Reps' },
    { key: 'pct', header: 'Share %' },
  ];

  const territoryCols: Column<TerritoryRow>[] = [
    { key: 'territory_name', header: 'Territory' },
    { key: 'reps', header: 'Reps' },
    { key: 'well_calibrated', header: 'Well Calibrated' },
    { key: 'overreach', header: 'Overreach' },
    { key: 'disputed_unresolved', header: 'Disputed' },
    { key: 'appeals_filed', header: 'Appeals Filed' },
    { key: 'appeals_upheld', header: 'Appeals Upheld' },
    { key: 'avg_quota_to_potential_ratio', header: 'Avg Quota/Potential' },
    { key: 'avg_fairness_score', header: 'Avg Fairness Score' },
    { key: 'total_new_quota_rupees', header: 'Total New Quota (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'quota_class', header: 'Quota Class' },
    { key: 'fairness_status', header: 'Fairness Status' },
    { key: 'reps', header: 'Reps' },
    { key: 'avg_quota_increase_pct', header: 'Avg Quota Increase %' },
    { key: 'avg_fairness_score', header: 'Avg Fairness Score' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'reps', header: 'Reps' },
    { key: 'avg_quota_increase_pct', header: 'Avg Quota Increase %' },
    { key: 'avg_quota_to_potential_ratio', header: 'Avg Quota/Potential' },
    { key: 'appeals_filed', header: 'Appeals Filed' },
    { key: 'worsening_reps', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'closed_count', header: 'Closed' },
    { key: 'overdue_count', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const appealCols: Column<AppealRow>[] = [
    { key: 'territory_name', header: 'Territory' },
    { key: 'rep_name', header: 'Rep' },
    { key: 'period_month', header: 'Month' },
    { key: 'prior_year_attainment_pct', header: 'Prior-Year Attainment %' },
    { key: 'quota_to_potential_ratio', header: 'Quota/Potential' },
    { key: 'appeal_upheld', header: 'Appeal Upheld' },
    { key: 'territory_realigned', header: 'Territory Realigned' },
    { key: 'fairness_status', header: 'Fairness Status' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'rep_name', header: 'Rep' },
    { key: 'territory_name', header: 'Territory' },
    { key: 'period_month', header: 'Month' },
    { key: 'fairness_status', header: 'Fairness Status' },
    { key: 'quota_to_potential_ratio', header: 'Quota/Potential' },
    { key: 'quota_increase_pct', header: 'Quota Increase %' },
    { key: 'rep_fairness_score', header: 'Fairness Score' },
    { key: 'appeal_filed', header: 'Appeal Filed' },
    { key: 'territory_realigned', header: 'Territory Realigned' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Sales Quota-Setting / Territory-Design Fairness Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Quota-setting process governance log &mdash; rep &times; territory &times; period month
        &times; prior-year attainment vs new quota vs territory potential &times; quota-to-potential
        ratio &times; quota increase % &times; appeal outcomes &times; territory realignment &times;
        fairness score &amp; CAPA closure. Covers the quota-setting process itself &mdash; distinct
        from territory geographic heatmap/coverage-visualization pages and from commission
        attainment/payout-accuracy pages, which apply only after quotas are already set. Founder-gated
        view: fairness-status distribution, territory scorecards, quota-class matrix, monthly quota
        increase trend, CAPA closure, root-cause pareto, appeal digest, and a high-risk queue of
        disputed &amp; overreach quotas.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Fairness-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No quota-fairness rows logged yet."
          rowKey={(r, i) => String(r.fairness_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Territory scorecard</h2>
        <DataTable
          rows={territoryRows}
          columns={territoryCols}
          emptyMessage="No territory rollups."
          rowKey={(r, i) => String(r.territory_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Quota class &times; fairness status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No quota-class rollups."
          rowKey={(r, i) => `${r.quota_class}-${r.fairness_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly quota-increase trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Appeal digest</h2>
        <DataTable
          rows={appealRows}
          columns={appealCols}
          emptyMessage="No appeals filed."
          rowKey={(r, i) => `${r.rep_name}-${r.period_month}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk quota queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk quotas."
          rowKey={(r, i) => `${r.rep_name}-${r.territory_name}-${i}`}
        />
      </section>
    </main>
  );
}
