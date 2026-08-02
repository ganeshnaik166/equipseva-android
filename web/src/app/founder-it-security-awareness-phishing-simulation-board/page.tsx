import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { awareness_status: string; campaigns: number; pct: number };
type DeptRow = {
  department: string;
  total_campaigns: number;
  staff_targeted_total: number;
  links_clicked_total: number;
  credentials_submitted_total: number;
  reported_total: number;
  avg_click_rate_pct: number;
  avg_report_rate_pct: number;
  avg_training_completion_pct: number;
  high_risk_campaigns: number;
};
type MatrixRow = {
  campaign_type: string;
  awareness_status: string;
  campaigns: number;
  avg_click_rate_pct: number;
  avg_report_rate_pct: number;
};
type TrendRow = {
  period_month: string;
  campaigns: number;
  staff_targeted_total: number;
  links_clicked_total: number;
  credentials_submitted_total: number;
  repeat_clickers_total: number;
  avg_click_rate_pct: number;
  avg_report_rate_pct: number;
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
type RepeatRow = {
  department: string;
  campaigns: number;
  repeat_clickers_total: number;
  credentials_submitted_total: number;
  avg_click_rate_pct: number;
  worsening_campaigns: number;
};
type RiskRow = {
  department: string;
  campaign_ref: string;
  campaign_type: string;
  campaign_date: string;
  awareness_status: string;
  trend_dir: string;
  click_rate_pct: number | null;
  report_rate_pct: number | null;
  credentials_submitted: number;
  repeat_clickers: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    repeatRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3661_awareness_status_rollup'),
    supabase.rpc('founder_r3661_department_scorecard'),
    supabase.rpc('founder_r3661_campaign_type_status_matrix'),
    supabase.rpc('founder_r3661_monthly_click_rate_trend'),
    supabase.rpc('founder_r3661_capa_status_board'),
    supabase.rpc('founder_r3661_root_cause_pareto'),
    supabase.rpc('founder_r3661_repeat_clicker_digest'),
    supabase.rpc('founder_r3661_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const repeatRows: RepeatRow[] = (repeatRes.data as RepeatRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'awareness_status', header: 'Awareness Status' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'total_campaigns', header: 'Campaigns' },
    { key: 'staff_targeted_total', header: 'Staff Targeted' },
    { key: 'links_clicked_total', header: 'Links Clicked' },
    { key: 'credentials_submitted_total', header: 'Creds Submitted' },
    { key: 'reported_total', header: 'Reported to IT' },
    { key: 'avg_click_rate_pct', header: 'Avg Click %' },
    { key: 'avg_report_rate_pct', header: 'Avg Report %' },
    { key: 'avg_training_completion_pct', header: 'Avg Training %' },
    { key: 'high_risk_campaigns', header: 'High-Risk / Untrained' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'campaign_type', header: 'Campaign Type' },
    { key: 'awareness_status', header: 'Awareness Status' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'avg_click_rate_pct', header: 'Avg Click %' },
    { key: 'avg_report_rate_pct', header: 'Avg Report %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'staff_targeted_total', header: 'Staff Targeted' },
    { key: 'links_clicked_total', header: 'Links Clicked' },
    { key: 'credentials_submitted_total', header: 'Creds Submitted' },
    { key: 'repeat_clickers_total', header: 'Repeat Clickers' },
    { key: 'avg_click_rate_pct', header: 'Avg Click %' },
    { key: 'avg_report_rate_pct', header: 'Avg Report %' },
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

  const repeatCols: Column<RepeatRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'repeat_clickers_total', header: 'Repeat Clickers' },
    { key: 'credentials_submitted_total', header: 'Creds Submitted' },
    { key: 'avg_click_rate_pct', header: 'Avg Click %' },
    { key: 'worsening_campaigns', header: 'Worsening' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'campaign_ref', header: 'Campaign' },
    { key: 'campaign_type', header: 'Type' },
    { key: 'campaign_date', header: 'Date' },
    { key: 'awareness_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'click_rate_pct', header: 'Click %' },
    { key: 'report_rate_pct', header: 'Report %' },
    { key: 'credentials_submitted', header: 'Creds Submitted' },
    { key: 'repeat_clickers', header: 'Repeat Clickers' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        IT Security-Awareness / Phishing-Simulation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Internal staff security-awareness and phishing-simulation results — department &times;
        campaign type (phishing email, smishing, vishing, USB drop, awareness module) &times; click
        rate &times; credential submission &times; report-to-IT rate &times; training completion
        &times; repeat clickers &amp; CAPA closure. Founder-gated view: awareness-status rollups,
        department scorecards, monthly click-rate trend, root-cause pareto, and the high-risk /
        untrained queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Awareness status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No campaigns logged yet."
          rowKey={(r, i) => String(r.awareness_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Campaign type &times; awareness status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No campaigns by type."
          rowKey={(r, i) => `${r.campaign_type}-${r.awareness_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly click-rate trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Repeat-clicker digest</h2>
        <DataTable
          rows={repeatRows}
          columns={repeatCols}
          emptyMessage="No repeat-clicker data."
          rowKey={(r, i) => `${r.department}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk / untrained queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk campaigns."
          rowKey={(r, i) => `${r.campaign_ref}-${r.campaign_date}-${i}`}
        />
      </section>
    </main>
  );
}
