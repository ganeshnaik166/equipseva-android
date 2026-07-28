import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ApprovalRow = { approval_status: string; windows: number; pct: number };
type ScoreRow = {
  window_type: string;
  total_windows: number;
  completed: number;
  rescheduled: number;
  rejected: number;
  overrun_windows: number;
  downtime_not_agreed: number;
  avg_overrun_hrs: number;
  completed_pct: number;
};
type MatrixRow = {
  window_type: string;
  clinical_impact: string;
  windows: number;
  completed: number;
  rejected: number;
  avg_overrun_hrs: number;
};
type TrendRow = {
  window_month: string;
  windows: number;
  completed: number;
  rescheduled: number;
  rejected: number;
  overrun_windows: number;
  avg_overrun_hrs: number;
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
type DigestRow = {
  clinical_impact: string;
  windows: number;
  overrun_windows: number;
  total_overrun_hrs: number;
  avg_overrun_hrs: number;
  service_suspended: number;
};
type RiskRow = {
  hospital_name: string;
  work_order: string;
  device_model: string;
  window_type: string;
  planned_start: string;
  approval_status: string;
  clinical_impact: string;
  overrun_hrs: number | null;
  downtime_agreed: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    approvalRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3556_approval_status_rollup'),
    supabase.rpc('founder_r3556_window_type_scorecard'),
    supabase.rpc('founder_r3556_window_type_impact_matrix'),
    supabase.rpc('founder_r3556_monthly_window_trend'),
    supabase.rpc('founder_r3556_capa_status_board'),
    supabase.rpc('founder_r3556_root_cause_pareto'),
    supabase.rpc('founder_r3556_overrun_impact_digest'),
    supabase.rpc('founder_r3556_high_risk_queue'),
  ]);

  const approvalRows: ApprovalRow[] = (approvalRes.data as ApprovalRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const approvalCols: Column<ApprovalRow>[] = [
    { key: 'approval_status', header: 'Approval Status' },
    { key: 'windows', header: 'Windows' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'window_type', header: 'Window Type' },
    { key: 'total_windows', header: 'Windows' },
    { key: 'completed', header: 'Completed' },
    { key: 'rescheduled', header: 'Rescheduled' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'overrun_windows', header: 'Overrun' },
    { key: 'downtime_not_agreed', header: 'No Downtime Agreed' },
    { key: 'avg_overrun_hrs', header: 'Avg Overrun (hrs)' },
    { key: 'completed_pct', header: 'Completed %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'window_type', header: 'Window Type' },
    { key: 'clinical_impact', header: 'Clinical Impact' },
    { key: 'windows', header: 'Windows' },
    { key: 'completed', header: 'Completed' },
    { key: 'rejected', header: 'Rejected / Resched' },
    { key: 'avg_overrun_hrs', header: 'Avg Overrun (hrs)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'window_month', header: 'Month' },
    { key: 'windows', header: 'Windows' },
    { key: 'completed', header: 'Completed' },
    { key: 'rescheduled', header: 'Rescheduled' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'overrun_windows', header: 'Overrun' },
    { key: 'avg_overrun_hrs', header: 'Avg Overrun (hrs)' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'clinical_impact', header: 'Clinical Impact' },
    { key: 'windows', header: 'Windows' },
    { key: 'overrun_windows', header: 'Overrun Windows' },
    { key: 'total_overrun_hrs', header: 'Total Overrun (hrs)' },
    { key: 'avg_overrun_hrs', header: 'Avg Overrun (hrs)' },
    { key: 'service_suspended', header: 'Service Suspended' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'work_order', header: 'Work Order' },
    { key: 'device_model', header: 'Device' },
    { key: 'window_type', header: 'Type' },
    { key: 'planned_start', header: 'Planned Start' },
    { key: 'approval_status', header: 'Approval' },
    { key: 'clinical_impact', header: 'Clinical Impact' },
    { key: 'overrun_hrs', header: 'Overrun (hrs)' },
    { key: 'downtime_agreed', header: 'Downtime Agreed' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Planned-Maintenance-Window / Downtime-Coordination Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Planned maintenance-window &amp; downtime-coordination log &mdash; window type (scheduled PM,
        upgrade, repair, calibration, statutory, installation) &times; hospital &times; device &times;
        planned vs actual duration &times; overrun hrs &times; approval status &times; clinical impact
        &times; downtime agreement &amp; CAPA closure. Founder-gated view: approval-status mix,
        window-type scorecards, window-type &times; clinical-impact matrix, overrun digest, root-cause
        pareto, and the high-risk queue across NABH &amp; AMC-SLA surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Approval-status distribution</h2>
        <DataTable
          rows={approvalRows}
          columns={approvalCols}
          emptyMessage="No maintenance windows logged yet."
          rowKey={(r, i) => String(r.approval_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Window-type scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No window-type rollups."
          rowKey={(r, i) => String(r.window_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Window type &times; clinical-impact matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No windows by type."
          rowKey={(r, i) => `${r.window_type}-${r.clinical_impact}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly window trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.window_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Overrun / clinical-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No overrun-impact rollups."
          rowKey={(r, i) => String(r.clinical_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk window queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk windows."
          rowKey={(r, i) => `${r.work_order}-${i}`}
        />
      </section>
    </main>
  );
}
