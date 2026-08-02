import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { study_status: string; studies: number; pct: number };
type MethodRow = {
  study_method: string;
  total_studies: number;
  supporting: number;
  on_track: number;
  failing: number;
  claim_gaps: number;
  not_started: number;
  avg_completion_pct: number;
  supporting_pct: number;
};
type MatrixRow = {
  study_method: string;
  study_status: string;
  studies: number;
  total_failures: number;
  avg_aging_factor: number;
};
type TrendRow = {
  period_month: string;
  studies: number;
  planned: number;
  completed: number;
  failures: number;
  completion_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type GapRow = {
  device_name: string;
  studies: number;
  claim_gaps: number;
  timepoint_failures: number;
  avg_gap_months: number | null;
  worsening: number;
};
type RiskRow = {
  device_name: string;
  study_ref: string;
  period_month: string;
  study_method: string;
  study_status: string;
  labeled_months: number;
  validated_months: number;
  failures_observed: number;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    methodRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3651_study_status_rollup'),
    supabase.rpc('founder_r3651_study_method_scorecard'),
    supabase.rpc('founder_r3651_method_status_matrix'),
    supabase.rpc('founder_r3651_monthly_timepoint_trend'),
    supabase.rpc('founder_r3651_capa_status_board'),
    supabase.rpc('founder_r3651_root_cause_pareto'),
    supabase.rpc('founder_r3651_claim_gap_digest'),
    supabase.rpc('founder_r3651_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const methodRows: MethodRow[] = (methodRes.data as MethodRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'study_status', header: 'Study Status' },
    { key: 'studies', header: 'Studies' },
    { key: 'pct', header: 'Share %' },
  ];

  const methodCols: Column<MethodRow>[] = [
    { key: 'study_method', header: 'Method' },
    { key: 'total_studies', header: 'Studies' },
    { key: 'supporting', header: 'Supporting Claim' },
    { key: 'on_track', header: 'On Track' },
    { key: 'failing', header: 'Timepoint Failures' },
    { key: 'claim_gaps', header: 'Claim Gaps' },
    { key: 'not_started', header: 'Not Started' },
    { key: 'avg_completion_pct', header: 'Avg Completion %' },
    { key: 'supporting_pct', header: 'Supporting %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'study_method', header: 'Method' },
    { key: 'study_status', header: 'Status' },
    { key: 'studies', header: 'Studies' },
    { key: 'total_failures', header: 'Failures' },
    { key: 'avg_aging_factor', header: 'Avg Aging Factor' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'studies', header: 'Studies' },
    { key: 'planned', header: 'Timepoints Planned' },
    { key: 'completed', header: 'Timepoints Completed' },
    { key: 'failures', header: 'Failures' },
    { key: 'completion_pct', header: 'Completion %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const gapCols: Column<GapRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'studies', header: 'Studies' },
    { key: 'claim_gaps', header: 'Claim Gaps' },
    { key: 'timepoint_failures', header: 'Timepoint Failures' },
    { key: 'avg_gap_months', header: 'Avg Gap (Months)' },
    { key: 'worsening', header: 'Worsening' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'study_ref', header: 'Study Ref' },
    { key: 'period_month', header: 'Month' },
    { key: 'study_method', header: 'Method' },
    { key: 'study_status', header: 'Status' },
    { key: 'labeled_months', header: 'Labeled (Mo)' },
    { key: 'validated_months', header: 'Validated (Mo)' },
    { key: 'failures_observed', header: 'Failures' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Shelf-Life / Stability-Study Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Shelf-life and stability-study register — device &times; study method (real-time,
        accelerated, both, extension protocol) &times; labeled vs validated shelf life &times;
        timepoints planned vs completed &times; failures observed &times; aging factor &amp; CAPA
        closure. Founder-gated view: study-status distribution, method scorecards, monthly
        timepoint trend, claim-gap digest, and the high-risk queue of timepoint failures &amp;
        claim gaps.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Study status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No stability studies logged yet."
          rowKey={(r, i) => String(r.study_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Study-method scorecard</h2>
        <DataTable
          rows={methodRows}
          columns={methodCols}
          emptyMessage="No method rollups."
          rowKey={(r, i) => String(r.study_method ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Study method &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No studies by method."
          rowKey={(r, i) => `${r.study_method}-${r.study_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly timepoint trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Claim-gap digest by device</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No claim-gap rollups."
          rowKey={(r, i) => String(r.device_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk study queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk studies."
          rowKey={(r, i) => `${r.study_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
