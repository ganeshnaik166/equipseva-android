import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { funnel_status: string; cohorts: number; pct: number };
type RegionRow = {
  region: string;
  cohorts: number;
  healthy: number;
  bid_starved: number;
  dropoff: number;
  broken: number;
  jobs_posted: number;
  jobs_completed: number;
  avg_conversion_pct: number;
  healthy_pct: number;
};
type MatrixRow = {
  funnel_stage: string;
  funnel_status: string;
  cohorts: number;
  jobs_posted: number;
  avg_conversion_pct: number;
};
type TrendRow = {
  period_month: string;
  cohorts: number;
  jobs_posted: number;
  jobs_with_bids: number;
  jobs_bid_accepted: number;
  jobs_completed: number;
  avg_conversion_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_gmv_at_risk_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_gmv_at_risk_rupees: number;
  pct: number;
};
type DropRow = {
  funnel_stage: string;
  cohorts: number;
  avg_post_to_bid_pct: number;
  avg_bid_to_accept_pct: number;
  avg_accept_to_complete_pct: number;
  avg_conversion_pct: number;
  worsening: number;
};
type RiskRow = {
  funnel_code: string;
  category: string;
  region: string;
  period_month: string;
  jobs_posted: number;
  bids_per_job_avg: number | null;
  funnel_stage: string;
  funnel_status: string;
  trend_dir: string;
  funnel_conversion_pct: number | null;
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
    dropRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3698_funnel_status_rollup'),
    supabase.rpc('founder_r3698_region_scorecard'),
    supabase.rpc('founder_r3698_stage_status_matrix'),
    supabase.rpc('founder_r3698_monthly_conversion_trend'),
    supabase.rpc('founder_r3698_capa_status_board'),
    supabase.rpc('founder_r3698_root_cause_pareto'),
    supabase.rpc('founder_r3698_dropoff_digest'),
    supabase.rpc('founder_r3698_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const dropRows: DropRow[] = (dropRes.data as DropRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'funnel_status', header: 'Funnel Status' },
    { key: 'cohorts', header: 'Cohorts' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'cohorts', header: 'Cohorts' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'bid_starved', header: 'Bid Starved' },
    { key: 'dropoff', header: 'Drop-off' },
    { key: 'broken', header: 'Broken' },
    { key: 'jobs_posted', header: 'Jobs Posted' },
    { key: 'jobs_completed', header: 'Jobs Completed' },
    { key: 'avg_conversion_pct', header: 'Avg Conversion %' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'funnel_stage', header: 'Funnel Stage' },
    { key: 'funnel_status', header: 'Status' },
    { key: 'cohorts', header: 'Cohorts' },
    { key: 'jobs_posted', header: 'Jobs Posted' },
    { key: 'avg_conversion_pct', header: 'Avg Conversion %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'cohorts', header: 'Cohorts' },
    { key: 'jobs_posted', header: 'Posted' },
    { key: 'jobs_with_bids', header: 'With Bids' },
    { key: 'jobs_bid_accepted', header: 'Accepted' },
    { key: 'jobs_completed', header: 'Completed' },
    { key: 'avg_conversion_pct', header: 'Avg Conversion %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_gmv_at_risk_rupees', header: 'Avg GMV at Risk (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_gmv_at_risk_rupees', header: 'Total GMV at Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const dropCols: Column<DropRow>[] = [
    { key: 'funnel_stage', header: 'Funnel Stage' },
    { key: 'cohorts', header: 'Cohorts' },
    { key: 'avg_post_to_bid_pct', header: 'Post to Bid %' },
    { key: 'avg_bid_to_accept_pct', header: 'Bid to Accept %' },
    { key: 'avg_accept_to_complete_pct', header: 'Accept to Complete %' },
    { key: 'avg_conversion_pct', header: 'Full Funnel %' },
    { key: 'worsening', header: 'Worsening' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'funnel_code', header: 'Funnel' },
    { key: 'category', header: 'Category' },
    { key: 'region', header: 'Region' },
    { key: 'period_month', header: 'Month' },
    { key: 'jobs_posted', header: 'Posted' },
    { key: 'bids_per_job_avg', header: 'Bids/Job' },
    { key: 'funnel_stage', header: 'Stage' },
    { key: 'funnel_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'funnel_conversion_pct', header: 'Conversion %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Marketplace Bid-Funnel Conversion Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Bid-funnel stage conversion across the EquipSeva marketplace — job posted &gt; bids &gt;
        accept &gt; complete per category (ventilator-repair, infusion-pump-service,
        defibrillator-amc, ct-scanner-amc) &times; region (Mumbai, Chennai, Delhi, Bengaluru,
        Hyderabad, Pune) &times; month &times; funnel stage &times; funnel status &amp; CAPA closure.
        Founder-gated view: status rollups, region scorecards, stage &times; status matrix,
        root-cause pareto, and the broken / bid-starved high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Funnel status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No funnel cohorts logged yet."
          rowKey={(r, i) => String(r.funnel_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region funnel scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Funnel stage &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No stage-status rollups."
          rowKey={(r, i) => `${r.funnel_stage}-${r.funnel_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly conversion trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Stage drop-off digest</h2>
        <DataTable
          rows={dropRows}
          columns={dropCols}
          emptyMessage="No drop-off rollups."
          rowKey={(r, i) => String(r.funnel_stage ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk funnel queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk funnels."
          rowKey={(r, i) => `${r.funnel_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
