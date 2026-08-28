import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { drill_status: string; drills: number; pct: number };
type ScenarioRow = {
  scenario_type: string;
  drills: number;
  passed_within_sla: number;
  failed_sla: number;
  avg_response_time_minutes: number | null;
  avg_target_response_minutes: number | null;
  coverage_gaps: number;
  documentation_not_ready: number;
};
type MatrixRow = {
  scenario_class: string;
  drill_status: string;
  drills: number;
  avg_response_time_minutes: number | null;
};
type TrendRow = {
  period_month: string;
  drills: number;
  avg_response_time_minutes: number | null;
  avg_target_response_minutes: number | null;
  gaps_identified_total: number;
  worsening_drills: number;
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
type GapRow = {
  scenario_class: string;
  drills: number;
  coverage_inadequate: number;
  documentation_not_ready: number;
  avg_insurer_notified_within_hours: number | null;
  lessons_not_captured: number;
};
type RiskRow = {
  drill_name: string;
  scenario_type: string;
  scenario_class: string;
  period_month: string;
  drill_date: string | null;
  drill_status: string;
  response_time_minutes: number | null;
  target_response_minutes: number | null;
  policy_coverage_adequate: boolean;
  claim_documentation_ready: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scenarioRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3733_drill_status_rollup'),
    supabase.rpc('founder_r3733_scenario_type_scorecard'),
    supabase.rpc('founder_r3733_scenario_class_status_matrix'),
    supabase.rpc('founder_r3733_monthly_response_time_trend'),
    supabase.rpc('founder_r3733_capa_status_board'),
    supabase.rpc('founder_r3733_root_cause_pareto'),
    supabase.rpc('founder_r3733_coverage_gap_digest'),
    supabase.rpc('founder_r3733_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scenarioRows: ScenarioRow[] = (scenarioRes.data as ScenarioRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'drill_status', header: 'Drill Status' },
    { key: 'drills', header: 'Drills' },
    { key: 'pct', header: 'Share %' },
  ];

  const scenarioCols: Column<ScenarioRow>[] = [
    { key: 'scenario_type', header: 'Scenario Type' },
    { key: 'drills', header: 'Drills' },
    { key: 'passed_within_sla', header: 'Passed w/ SLA' },
    { key: 'failed_sla', header: 'Failed SLA' },
    { key: 'avg_response_time_minutes', header: 'Avg Response (min)' },
    { key: 'avg_target_response_minutes', header: 'Avg Target (min)' },
    { key: 'coverage_gaps', header: 'Coverage Gaps' },
    { key: 'documentation_not_ready', header: 'Docs Not Ready' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'scenario_class', header: 'Scenario Class' },
    { key: 'drill_status', header: 'Drill Status' },
    { key: 'drills', header: 'Drills' },
    { key: 'avg_response_time_minutes', header: 'Avg Response (min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'drills', header: 'Drills' },
    { key: 'avg_response_time_minutes', header: 'Avg Response (min)' },
    { key: 'avg_target_response_minutes', header: 'Avg Target (min)' },
    { key: 'gaps_identified_total', header: 'Gaps Identified' },
    { key: 'worsening_drills', header: 'Worsening' },
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

  const gapCols: Column<GapRow>[] = [
    { key: 'scenario_class', header: 'Scenario Class' },
    { key: 'drills', header: 'Drills' },
    { key: 'coverage_inadequate', header: 'Coverage Inadequate' },
    { key: 'documentation_not_ready', header: 'Docs Not Ready' },
    { key: 'avg_insurer_notified_within_hours', header: 'Avg Insurer Notice (hrs)' },
    { key: 'lessons_not_captured', header: 'Lessons Not Captured' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'drill_name', header: 'Drill' },
    { key: 'scenario_type', header: 'Scenario Type' },
    { key: 'scenario_class', header: 'Scenario Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'drill_date', header: 'Drill Date' },
    { key: 'drill_status', header: 'Drill Status' },
    { key: 'response_time_minutes', header: 'Response (min)' },
    { key: 'target_response_minutes', header: 'Target (min)' },
    { key: 'policy_coverage_adequate', header: 'Coverage Adequate' },
    { key: 'claim_documentation_ready', header: 'Docs Ready' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Cyber-Insurance Claim Readiness / Breach-Response Drill Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Tabletop &amp; functional breach-response drill log — scenario type &times; scenario class
        (ransomware, data breach, DDoS, insider threat, third-party vendor breach) &times; period
        month &times; response-time SLA &times; policy-coverage adequacy &times; claim-documentation
        readiness &times; insurer-notification timing &amp; CAPA closure. This board tracks
        insurance claim readiness and drill exercises specifically &mdash; it is distinct from any
        technical DR/backup-posture or IT backup-restore-test board. Founder-gated view:
        drill-status distribution, scenario scorecards, coverage-gap digest, root-cause pareto,
        and a high-risk queue of failed or unconducted drills.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Drill-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No drill rows logged yet."
          rowKey={(r, i) => String(r.drill_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Scenario-type scorecard</h2>
        <DataTable
          rows={scenarioRows}
          columns={scenarioCols}
          emptyMessage="No scenario rollups."
          rowKey={(r, i) => String(r.scenario_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Scenario class &times; drill status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No drills by scenario class."
          rowKey={(r, i) => `${r.scenario_class}-${r.drill_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly response-time trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Coverage-gap digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No coverage gaps identified."
          rowKey={(r, i) => String(r.scenario_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk drill queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk drills."
          rowKey={(r, i) => `${r.drill_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
