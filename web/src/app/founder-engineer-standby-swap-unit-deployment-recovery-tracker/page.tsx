import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { swap_verdict: string; swaps: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_swaps: number;
  recovered_clean: number;
  recovered_with_issues: number;
  overdue_or_lost: number;
  paperwork_gaps: number;
  avg_days_on_site: number;
  clean_pct: number;
};
type MatrixRow = {
  failed_equipment_type: string;
  swap_condition_back: string;
  swaps: number;
  recovered_clean: number;
  avg_days_on_site: number;
};
type TrendRow = {
  deploy_date: string;
  swaps: number;
  recovered: number;
  overdue_or_lost: number;
  in_progress: number;
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
type ExposureRow = {
  exposure_category: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  swap_unit_code: string;
  failed_equipment_type: string;
  deploy_date: string;
  expected_return_date: string;
  days_on_site: number;
  swap_verdict: string;
  swap_condition_back: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3256_swap_verdict_rollup'),
    supabase.rpc('founder_r3256_engineer_scorecard'),
    supabase.rpc('founder_r3256_equipment_condition_matrix'),
    supabase.rpc('founder_r3256_daily_deploy_trend'),
    supabase.rpc('founder_r3256_capa_status_board'),
    supabase.rpc('founder_r3256_root_cause_pareto'),
    supabase.rpc('founder_r3256_exposure_digest'),
    supabase.rpc('founder_r3256_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'swap_verdict', header: 'Verdict' },
    { key: 'swaps', header: 'Swaps' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_swaps', header: 'Swaps' },
    { key: 'recovered_clean', header: 'Recovered Clean' },
    { key: 'recovered_with_issues', header: 'With Issues' },
    { key: 'overdue_or_lost', header: 'Overdue / Lost' },
    { key: 'paperwork_gaps', header: 'Paperwork Gaps' },
    { key: 'avg_days_on_site', header: 'Avg Days On Site' },
    { key: 'clean_pct', header: 'Clean %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'failed_equipment_type', header: 'Failed Equipment' },
    { key: 'swap_condition_back', header: 'Condition Back' },
    { key: 'swaps', header: 'Swaps' },
    { key: 'recovered_clean', header: 'Recovered Clean' },
    { key: 'avg_days_on_site', header: 'Avg Days On Site' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'deploy_date', header: 'Deploy Date' },
    { key: 'swaps', header: 'Swaps' },
    { key: 'recovered', header: 'Recovered' },
    { key: 'overdue_or_lost', header: 'Overdue / Lost' },
    { key: 'in_progress', header: 'In Progress' },
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

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'exposure_category', header: 'Exposure Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'swap_unit_code', header: 'Swap Unit' },
    { key: 'failed_equipment_type', header: 'Failed Equipment' },
    { key: 'deploy_date', header: 'Deployed' },
    { key: 'expected_return_date', header: 'Expected Back' },
    { key: 'days_on_site', header: 'Days On Site' },
    { key: 'swap_verdict', header: 'Verdict' },
    { key: 'swap_condition_back', header: 'Condition Back' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Standby / Swap-Unit Deployment &amp; Recovery Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-swap discipline log — engineer &times; failed equipment type &times; swap condition
        out/back &times; days on site &times; paperwork &amp; customer signature &times;
        calibration-valid-during-loan &times; recovery verdict &amp; CAPA closure. Founder-gated
        view: verdict rollups, engineer scorecards, root-cause pareto, and cost/risk exposure
        digest for overdue or damaged swap units.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Swap verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No swap deployments logged yet."
          rowKey={(r, i) => String(r.swap_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer swap-discipline scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; condition-back matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No swaps by equipment type."
          rowKey={(r, i) => `${r.failed_equipment_type}-${r.swap_condition_back}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily deployment trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.deploy_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cost / risk exposure digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure rollups."
          rowKey={(r, i) => String(r.exposure_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk swap queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk swaps."
          rowKey={(r, i) => `${r.swap_unit_code}-${r.deploy_date}-${i}`}
        />
      </section>
    </main>
  );
}
