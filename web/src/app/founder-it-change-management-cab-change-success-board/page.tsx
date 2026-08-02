import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { change_status: string; entries: number; pct: number };
type SystemRow = {
  system_name: string;
  periods: number;
  total_submitted: number;
  total_implemented: number;
  avg_success_rate_pct: number;
  total_failed: number;
  total_rollbacks: number;
  avg_lead_time_days: number;
};
type MatrixRow = {
  change_category: string;
  change_status: string;
  entries: number;
  total_implemented: number;
  total_rollbacks: number;
  avg_success_rate_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_submitted: number;
  total_implemented: number;
  total_failed: number;
  total_emergency: number;
  avg_success_rate_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_downtime_minutes: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_downtime_minutes: number;
  pct: number;
};
type FailRow = {
  system_name: string;
  failed_entries: number;
  total_failed_changes: number;
  total_rollbacks: number;
  total_emergency: number;
  avg_success_rate_pct: number;
};
type RiskRow = {
  change_ref: string;
  system_name: string;
  period_month: string;
  change_category: string;
  change_status: string;
  failed_changes: number;
  rollback_count: number;
  emergency_pct: number | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    systemRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    failRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3669_change_status_rollup'),
    supabase.rpc('founder_r3669_system_scorecard'),
    supabase.rpc('founder_r3669_category_status_matrix'),
    supabase.rpc('founder_r3669_monthly_change_trend'),
    supabase.rpc('founder_r3669_capa_status_board'),
    supabase.rpc('founder_r3669_root_cause_pareto'),
    supabase.rpc('founder_r3669_failed_change_digest'),
    supabase.rpc('founder_r3669_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const systemRows: SystemRow[] = (systemRes.data as SystemRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const failRows: FailRow[] = (failRes.data as FailRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'change_status', header: 'Change Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const systemCols: Column<SystemRow>[] = [
    { key: 'system_name', header: 'System' },
    { key: 'periods', header: 'Periods' },
    { key: 'total_submitted', header: 'Submitted' },
    { key: 'total_implemented', header: 'Implemented' },
    { key: 'avg_success_rate_pct', header: 'Avg Success %' },
    { key: 'total_failed', header: 'Failed' },
    { key: 'total_rollbacks', header: 'Rollbacks' },
    { key: 'avg_lead_time_days', header: 'Avg Lead Time (d)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'change_category', header: 'Category' },
    { key: 'change_status', header: 'Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_implemented', header: 'Implemented' },
    { key: 'total_rollbacks', header: 'Rollbacks' },
    { key: 'avg_success_rate_pct', header: 'Avg Success %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_submitted', header: 'Submitted' },
    { key: 'total_implemented', header: 'Implemented' },
    { key: 'total_failed', header: 'Failed' },
    { key: 'total_emergency', header: 'Emergency' },
    { key: 'avg_success_rate_pct', header: 'Avg Success %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_downtime_minutes', header: 'Avg Downtime (min)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_downtime_minutes', header: 'Total Downtime (min)' },
    { key: 'pct', header: 'Share %' },
  ];

  const failCols: Column<FailRow>[] = [
    { key: 'system_name', header: 'System' },
    { key: 'failed_entries', header: 'Failing Periods' },
    { key: 'total_failed_changes', header: 'Failed Changes' },
    { key: 'total_rollbacks', header: 'Rollbacks' },
    { key: 'total_emergency', header: 'Emergency' },
    { key: 'avg_success_rate_pct', header: 'Avg Success %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'change_ref', header: 'Change Ref' },
    { key: 'system_name', header: 'System' },
    { key: 'period_month', header: 'Month' },
    { key: 'change_category', header: 'Category' },
    { key: 'change_status', header: 'Status' },
    { key: 'failed_changes', header: 'Failed' },
    { key: 'rollback_count', header: 'Rollbacks' },
    { key: 'emergency_pct', header: 'Emergency %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        IT Change-Management (CAB) / Change-Success Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        CAB change-governance log — system (SAP ERP, Salesforce CRM, EquipSeva field app, Supabase
        prod DB, WMS, firewall, CI-CD) &times; monthly change volume &times; approval &amp;
        implementation counts &times; success rate &times; emergency-change share &times; rollbacks
        &times; lead time &amp; CAPA closure. Founder-gated view: change-status rollups, system
        scorecards, category &times; status matrix, root-cause pareto, and the high-risk queue of
        incident-causing &amp; unauthorized changes.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Change-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No change records logged yet."
          rowKey={(r, i) => String(r.change_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. System change scorecard</h2>
        <DataTable
          rows={systemRows}
          columns={systemCols}
          emptyMessage="No system rollups."
          rowKey={(r, i) => String(r.system_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No changes by category."
          rowKey={(r, i) => `${r.change_category}-${r.change_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly change trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Failed-change impact digest</h2>
        <DataTable
          rows={failRows}
          columns={failCols}
          emptyMessage="No failed-change rollups."
          rowKey={(r, i) => String(r.system_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk change queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk changes."
          rowKey={(r, i) => `${r.change_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
