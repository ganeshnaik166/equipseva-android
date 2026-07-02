import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string | number };

export const dynamic = 'force-dynamic';

export default async function FounderEngineerFieldTestPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let tests: any[] = [];
  let running: any[] = [];
  let outcomes: any[] = [];
  let candidates: any[] = [];
  let leaderboard: any[] = [];

  try {
    const { data } = await sb.rpc('founder_field_test_kpis');
    kpis = data ?? {};
  } catch { kpis = {}; }

  try {
    const { data } = await sb.rpc('founder_field_test_list');
    tests = (data ?? []) as any[];
  } catch { tests = []; }

  try {
    const { data } = await sb.rpc('founder_field_test_running');
    running = (data ?? []) as any[];
  } catch { running = []; }

  try {
    const { data } = await sb.rpc('founder_field_test_outcomes_recent');
    outcomes = (data ?? []) as any[];
  } catch { outcomes = []; }

  try {
    const { data } = await sb.rpc('founder_field_test_graduation_candidates');
    candidates = (data ?? []) as any[];
  } catch { candidates = []; }

  try {
    const { data } = await sb.rpc('founder_field_test_engineer_leaderboard');
    leaderboard = (data ?? []) as any[];
  } catch { leaderboard = []; }

  const kpiCards: Kpi[] = [
    { label: 'Total tests', value: kpis.total_tests ?? 0 },
    { label: 'Planned', value: kpis.planned ?? 0 },
    { label: 'Running', value: kpis.running ?? 0 },
    { label: 'Paused', value: kpis.paused ?? 0 },
    { label: 'Complete', value: kpis.complete ?? 0 },
    { label: 'Graduated to fleet', value: kpis.graduated ?? 0 },
    { label: 'Rejected', value: kpis.rejected ?? 0 },
    { label: 'Tool tests', value: kpis.tool_tests ?? 0 },
    { label: 'SOP tests', value: kpis.sop_tests ?? 0 },
    { label: 'Workflow tests', value: kpis.workflow_tests ?? 0 },
    { label: 'Training tests', value: kpis.training_tests ?? 0 },
    { label: 'Equipment tests', value: kpis.equipment_tests ?? 0 },
    { label: 'Total outcomes recorded', value: kpis.total_outcomes ?? 0 },
    { label: 'Successes', value: kpis.successes ?? 0 },
    { label: 'Failures + dropouts', value: (kpis.failures ?? 0) + (kpis.dropouts ?? 0) },
    { label: 'Unique engineers in beta', value: kpis.unique_engineers ?? 0 },
  ];

  const testCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'test_kind', header: 'Kind', render: (r: any) => r.test_kind ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'enrolled', header: 'Enrolled', render: (r: any) => `${r.enrolled ?? 0} / ${r.cohort_size_target ?? 0}` },
    { key: 'success_rate_pct', header: 'Success %', render: (r: any) => `${r.success_rate_pct ?? 0}%` },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleDateString() : '—' },
  ];

  const runningCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'test_kind', header: 'Kind', render: (r: any) => r.test_kind ?? '—' },
    { key: 'success_metric', header: 'Metric', render: (r: any) => r.success_metric ?? '—' },
    { key: 'baseline_value', header: 'Baseline', render: (r: any) => r.baseline_value ?? '—' },
    { key: 'observed_value', header: 'Observed', render: (r: any) => r.observed_value ?? '—' },
    { key: 'success_threshold_pct', header: 'Threshold %', render: (r: any) => `${r.success_threshold_pct ?? 0}%` },
    { key: 'enrolled', header: 'Enrolled', render: (r: any) => r.enrolled ?? 0 },
    { key: 'days_running', header: 'Days', render: (r: any) => r.days_running ?? 0 },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'test_title', header: 'Test', render: (r: any) => r.test_title ?? '—' },
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => (r.engineer_id ?? '').toString().slice(0, 8) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
    { key: 'metric_value', header: 'Value', render: (r: any) => r.metric_value ?? '—' },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleDateString() : '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const candidateCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'test_kind', header: 'Kind', render: (r: any) => r.test_kind ?? '—' },
    { key: 'observed_rate_pct', header: 'Observed %', render: (r: any) => `${r.observed_rate_pct ?? 0}%` },
    { key: 'success_threshold_pct', header: 'Threshold %', render: (r: any) => `${r.success_threshold_pct ?? 0}%` },
    { key: 'enrolled', header: 'Enrolled', render: (r: any) => `${r.enrolled ?? 0} / ${r.cohort_size_target ?? 0}` },
  ];

  const leaderboardCols: Column<any>[] = [
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => (r.engineer_id ?? '').toString().slice(0, 8) },
    { key: 'tests_run', header: 'Tests run', render: (r: any) => r.tests_run ?? 0 },
    { key: 'successes', header: 'Successes', render: (r: any) => r.successes ?? 0 },
    { key: 'failures', header: 'Failures', render: (r: any) => r.failures ?? 0 },
    { key: 'success_rate_pct', header: 'Success %', render: (r: any) => `${r.success_rate_pct ?? 0}%` },
  ];

  return (
    <div style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Engineer field-test program</h1>
        <p style={{ color: '#666', marginTop: 8 }}>
          Beta-test new tools, SOPs, workflows, and training with engineer subsets. Track per-test
          cohorts and outcomes, then graduate winners to the full fleet.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
        {kpiCards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
            <div style={{ color: '#666', fontSize: 12 }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{String(k.value)}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>All field tests</h2>
        <DataTable columns={testCols} rows={tests} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Currently running</h2>
        <DataTable columns={runningCols} rows={running} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Graduation candidates</h2>
        <DataTable columns={candidateCols} rows={candidates} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Recent outcomes</h2>
        <DataTable columns={outcomeCols} rows={outcomes} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Engineer beta leaderboard</h2>
        <DataTable columns={leaderboardCols} rows={leaderboard} rowKey={(r: any) => r.engineer_id} />
      </section>
    </div>
  );
}
