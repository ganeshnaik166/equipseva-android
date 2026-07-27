import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; checks: number; pct: number };
type TaskRow = {
  care_task: string;
  total_checks: number;
  completed: number;
  partial: number;
  missed: number;
  escalated_count: number;
  issues_total: number;
  avg_adherence_pct: number;
  completion_pct: number;
};
type MatrixRow = {
  care_task: string;
  compliance_status: string;
  checks: number;
  avg_adherence_pct: number;
  issues_total: number;
};
type TrendRow = {
  check_month: string;
  checks: number;
  completed: number;
  missed: number;
  escalated_count: number;
  avg_adherence_pct: number;
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
type ImpactRow = {
  adherence_band: string;
  checks: number;
  missed: number;
  escalated_count: number;
  issues_total: number;
  avg_adherence_pct: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  device_model: string;
  operator_name: string;
  care_task: string;
  frequency: string;
  check_date: string;
  compliance_status: string;
  adherence_pct: number | null;
  issues_found: number | null;
  escalated: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    taskRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3496_compliance_status_rollup'),
    supabase.rpc('founder_r3496_care_task_scorecard'),
    supabase.rpc('founder_r3496_care_task_status_matrix'),
    supabase.rpc('founder_r3496_monthly_adherence_trend'),
    supabase.rpc('founder_r3496_capa_status_board'),
    supabase.rpc('founder_r3496_root_cause_pareto'),
    supabase.rpc('founder_r3496_adherence_impact_digest'),
    supabase.rpc('founder_r3496_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const taskRows: TaskRow[] = (taskRes.data as TaskRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'checks', header: 'Checks' },
    { key: 'pct', header: 'Share %' },
  ];

  const taskCols: Column<TaskRow>[] = [
    { key: 'care_task', header: 'Care Task' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'completed', header: 'Completed' },
    { key: 'partial', header: 'Partial' },
    { key: 'missed', header: 'Missed' },
    { key: 'escalated_count', header: 'Escalated' },
    { key: 'issues_total', header: 'Issues' },
    { key: 'avg_adherence_pct', header: 'Avg Adherence %' },
    { key: 'completion_pct', header: 'Completion %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'care_task', header: 'Care Task' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'checks', header: 'Checks' },
    { key: 'avg_adherence_pct', header: 'Avg Adherence %' },
    { key: 'issues_total', header: 'Issues' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_month', header: 'Month' },
    { key: 'checks', header: 'Checks' },
    { key: 'completed', header: 'Completed' },
    { key: 'missed', header: 'Missed' },
    { key: 'escalated_count', header: 'Escalated' },
    { key: 'avg_adherence_pct', header: 'Avg Adherence %' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'adherence_band', header: 'Adherence Band' },
    { key: 'checks', header: 'Checks' },
    { key: 'missed', header: 'Missed' },
    { key: 'escalated_count', header: 'Escalated' },
    { key: 'issues_total', header: 'Issues' },
    { key: 'avg_adherence_pct', header: 'Avg Adherence %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_model', header: 'Device' },
    { key: 'operator_name', header: 'Operator' },
    { key: 'care_task', header: 'Care Task' },
    { key: 'frequency', header: 'Frequency' },
    { key: 'check_date', header: 'Date' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'adherence_pct', header: 'Adherence %' },
    { key: 'issues_found', header: 'Issues' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer First-Line-Maintenance / Operator Daily-Care Checklist Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Autonomous-maintenance / operator daily-care (first-line maintenance) checklist tracker &mdash;
        care task (cleaning, lubrication, visual inspection, consumable check, calibration verify, leak
        check, filter check) &times; frequency &times; compliance status &times; adherence % &times;
        issues found &times; escalation &amp; CAPA closure across Indian hospital fleets. Founder-gated
        view: compliance rollups, care-task scorecards, root-cause pareto, and an adherence-impact
        digest spanning NABH &amp; ISO&nbsp;13485 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No care checks logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Care-task scorecard</h2>
        <DataTable
          rows={taskRows}
          columns={taskCols}
          emptyMessage="No care-task rollups."
          rowKey={(r, i) => String(r.care_task ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Care-task &times; compliance-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by care task."
          rowKey={(r, i) => `${r.care_task}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly adherence trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.check_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Adherence-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No adherence-impact rollups."
          rowKey={(r, i) => String(r.adherence_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk care queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk checks."
          rowKey={(r, i) => `${r.device_model}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
