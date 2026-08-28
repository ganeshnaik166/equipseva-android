import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { program_status: string; entries: number; pct: number };
type DeptRow = {
  department: string;
  entries: number;
  total_eligible: number;
  total_enrolled: number;
  total_sessions_utilized: number;
  total_cases_opened: number;
  total_cases_closed: number;
  avg_utilization_pct: number;
  avg_satisfaction_score: number;
  total_escalations: number;
};
type MatrixRow = {
  case_category: string;
  program_status: string;
  entries: number;
  avg_utilization_pct: number;
  total_escalations: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_sessions_utilized: number;
  avg_utilization_pct: number;
  total_cases_opened: number;
  total_cases_closed: number;
  total_escalations: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type EscalationRow = {
  department: string;
  entries: number;
  total_escalated: number;
  avg_escalation_rate_pct: number | null;
  worsening_entries: number;
};
type RiskRow = {
  department: string;
  period_month: string;
  case_category: string;
  program_status: string;
  cases_opened: number;
  cases_closed: number;
  escalated_to_clinical_referral: number | null;
  utilization_pct: number | null;
  satisfaction_score: number | null;
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
    escalationRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3724_program_status_rollup'),
    supabase.rpc('founder_r3724_department_scorecard'),
    supabase.rpc('founder_r3724_case_category_status_matrix'),
    supabase.rpc('founder_r3724_monthly_utilization_trend'),
    supabase.rpc('founder_r3724_capa_status_board'),
    supabase.rpc('founder_r3724_root_cause_pareto'),
    supabase.rpc('founder_r3724_escalation_spike_digest'),
    supabase.rpc('founder_r3724_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const escalationRows: EscalationRow[] = (escalationRes.data as EscalationRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'program_status', header: 'Program Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_eligible', header: 'Eligible' },
    { key: 'total_enrolled', header: 'Enrolled' },
    { key: 'total_sessions_utilized', header: 'Sessions Utilized' },
    { key: 'total_cases_opened', header: 'Cases Opened' },
    { key: 'total_cases_closed', header: 'Cases Closed' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'avg_satisfaction_score', header: 'Avg Satisfaction' },
    { key: 'total_escalations', header: 'Escalations' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'case_category', header: 'Case Category' },
    { key: 'program_status', header: 'Program Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_escalations', header: 'Escalations' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_sessions_utilized', header: 'Sessions Utilized' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_cases_opened', header: 'Cases Opened' },
    { key: 'total_cases_closed', header: 'Cases Closed' },
    { key: 'total_escalations', header: 'Escalations' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const escalationCols: Column<EscalationRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_escalated', header: 'Total Escalated' },
    { key: 'avg_escalation_rate_pct', header: 'Avg Escalation Rate %' },
    { key: 'worsening_entries', header: 'Worsening' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'period_month', header: 'Month' },
    { key: 'case_category', header: 'Case Category' },
    { key: 'program_status', header: 'Program Status' },
    { key: 'cases_opened', header: 'Cases Opened' },
    { key: 'cases_closed', header: 'Cases Closed' },
    { key: 'escalated_to_clinical_referral', header: 'Escalated' },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'satisfaction_score', header: 'Satisfaction' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Employee Assistance Program (EAP) Wellness Utilization Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Formal Employee Assistance Program counseling &amp; wellness utilization log --
        department &times; period month &times; eligible vs enrolled employees &times; sessions
        utilized &times; case open/close counts &times; clinical-referral escalation &times;
        program cost &times; satisfaction &amp; utilization rate, by case category (stress &amp;
        burnout, financial counseling, family/personal, substance-related, workplace conflict).
        Distinct from any personal mental-health pulse survey or founder burnout tracker -- this
        is the formal program&apos;s operational utilization. Founder-gated view: program-status
        distribution, department scorecards, case-category matrix, monthly trend, CAPA closure,
        root-cause pareto, an escalation-spike digest, and a high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Program-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No EAP utilization rows logged yet."
          rowKey={(r, i) => String(r.program_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Case category &times; program status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No case-category data."
          rowKey={(r, i) => `${r.case_category}-${r.program_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly utilization trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Escalation-spike digest by department</h2>
        <DataTable
          rows={escalationRows}
          columns={escalationCols}
          emptyMessage="No escalation-spike data."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk EAP entries."
          rowKey={(r, i) => `${r.department}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
