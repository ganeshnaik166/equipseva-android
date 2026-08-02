import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { change_status: string; changes: number; pct: number };
type ClassRow = {
  change_class: string;
  total_changes: number;
  implemented: number;
  in_progress: number;
  awaiting_approval: number;
  on_hold: number;
  overdue_changes: number;
  avg_days_open: number;
  avg_implementation_pct: number;
  implemented_pct: number;
};
type MatrixRow = {
  change_class: string;
  change_status: string;
  changes: number;
  avg_days_open: number;
  avg_implementation_pct: number;
};
type TrendRow = {
  period_month: string;
  changes: number;
  implemented: number;
  overdue_changes: number;
  vv_required_cnt: number;
  reg_notifications: number;
  avg_days_open: number;
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
type AgingRow = {
  age_bucket: string;
  changes: number;
  avg_implementation_pct: number;
  overdue_changes: number;
  on_hold_changes: number;
  reg_notifications: number;
};
type RiskRow = {
  change_ref: string;
  device_name: string;
  change_class: string;
  change_status: string;
  trend_dir: string;
  days_open: number;
  implementation_pct: number;
  regulatory_notification_needed: boolean;
  target_close_date: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    classRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    agingRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3652_change_status_rollup'),
    supabase.rpc('founder_r3652_change_class_scorecard'),
    supabase.rpc('founder_r3652_class_status_matrix'),
    supabase.rpc('founder_r3652_monthly_change_trend'),
    supabase.rpc('founder_r3652_capa_status_board'),
    supabase.rpc('founder_r3652_root_cause_pareto'),
    supabase.rpc('founder_r3652_aging_impact_digest'),
    supabase.rpc('founder_r3652_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const classRows: ClassRow[] = (classRes.data as ClassRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const agingRows: AgingRow[] = (agingRes.data as AgingRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'change_status', header: 'Change Status' },
    { key: 'changes', header: 'Changes' },
    { key: 'pct', header: 'Share %' },
  ];

  const classCols: Column<ClassRow>[] = [
    { key: 'change_class', header: 'Change Class' },
    { key: 'total_changes', header: 'Changes' },
    { key: 'implemented', header: 'Implemented' },
    { key: 'in_progress', header: 'In Progress' },
    { key: 'awaiting_approval', header: 'Awaiting Approval' },
    { key: 'on_hold', header: 'On Hold' },
    { key: 'overdue_changes', header: 'Overdue' },
    { key: 'avg_days_open', header: 'Avg Days Open' },
    { key: 'avg_implementation_pct', header: 'Avg Impl %' },
    { key: 'implemented_pct', header: 'Implemented %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'change_class', header: 'Change Class' },
    { key: 'change_status', header: 'Status' },
    { key: 'changes', header: 'Changes' },
    { key: 'avg_days_open', header: 'Avg Days Open' },
    { key: 'avg_implementation_pct', header: 'Avg Impl %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'changes', header: 'Changes' },
    { key: 'implemented', header: 'Implemented' },
    { key: 'overdue_changes', header: 'Overdue' },
    { key: 'vv_required_cnt', header: 'V&V Required' },
    { key: 'reg_notifications', header: 'Reg Notifications' },
    { key: 'avg_days_open', header: 'Avg Days Open' },
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

  const agingCols: Column<AgingRow>[] = [
    { key: 'age_bucket', header: 'Age Bucket' },
    { key: 'changes', header: 'Changes' },
    { key: 'avg_implementation_pct', header: 'Avg Impl %' },
    { key: 'overdue_changes', header: 'Overdue' },
    { key: 'on_hold_changes', header: 'On Hold' },
    { key: 'reg_notifications', header: 'Reg Notifications' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'change_ref', header: 'ECN Ref' },
    { key: 'device_name', header: 'Device' },
    { key: 'change_class', header: 'Class' },
    { key: 'change_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'days_open', header: 'Days Open' },
    { key: 'implementation_pct', header: 'Impl %' },
    { key: 'regulatory_notification_needed', header: 'Reg Notify' },
    { key: 'target_close_date', header: 'Target Close' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Design-Change Control / ECN Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Design-change control / engineering change note (ECN) lifecycle log &mdash; change class
        (design, process, supplier, labeling, software) &times; status &times; risk-assessment done
        &times; regulatory notification &times; V&amp;V required &times; days open &times; affected
        documents &times; implementation % &amp; CAPA closure. Founder-gated view: status rollups,
        change-class scorecards, aging-impact digest, root-cause pareto, and the overdue / on-hold
        high-risk queue across ISO 13485 &amp; CDSCO change-control surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Change status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No design changes logged yet."
          rowKey={(r, i) => String(r.change_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Change-class scorecard</h2>
        <DataTable
          rows={classRows}
          columns={classCols}
          emptyMessage="No change-class rollups."
          rowKey={(r, i) => String(r.change_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Change class &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No changes by class."
          rowKey={(r, i) => `${r.change_class}-${r.change_status}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Aging-impact digest</h2>
        <DataTable
          rows={agingRows}
          columns={agingCols}
          emptyMessage="No aging rollups."
          rowKey={(r, i) => String(r.age_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk change queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk changes."
          rowKey={(r, i) => `${r.change_ref}-${i}`}
        />
      </section>
    </main>
  );
}
