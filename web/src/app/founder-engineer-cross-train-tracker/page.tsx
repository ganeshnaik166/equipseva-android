import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCrossTrainTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [assignmentsRes, assessmentsRes, summaryRes, completedRes] = await Promise.all([
    sb.rpc('list_cross_train_assignments_r1752'),
    sb.rpc('list_cross_train_assessments_r1752', { p_assignment_id: null }),
    sb.rpc('cross_train_progress_summary_r1752'),
    sb.rpc('completed_cross_trains_r1752'),
  ]);

  const assignments: any[] = assignmentsRes.data ?? [];
  const assessments: any[] = assessmentsRes.data ?? [];
  const summary: any[] = summaryRes.data ?? [];
  const completed: any[] = completedRes.data ?? [];

  const assignmentCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id?.slice(0, 8) ?? '-' },
    { key: 'target_equipment_category', header: 'Category', render: (r: any) => r.target_equipment_category ?? '-' },
    { key: 'trainer_email', header: 'Trainer', render: (r: any) => r.trainer_email ?? '-' },
    { key: 'started_on', header: 'Started', render: (r: any) => r.started_on ?? '-' },
    { key: 'target_completion_date', header: 'Target', render: (r: any) => r.target_completion_date ?? '-' },
    { key: 'hours_logged', header: 'Hours', render: (r: any) => String(r.hours_logged ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
  ];

  const assessmentCols: Column<any>[] = [
    { key: 'assignment_id', header: 'Assignment', render: (r: any) => String(r.assignment_id ?? '').slice(0, 8) },
    { key: 'assessment_date', header: 'Date', render: (r: any) => r.assessment_date ?? '-' },
    { key: 'assessment_type', header: 'Type', render: (r: any) => r.assessment_type ?? '-' },
    { key: 'score', header: 'Score', render: (r: any) => (r.score == null ? '-' : String(r.score)) },
    { key: 'passed', header: 'Passed', render: (r: any) => (r.passed ? 'yes' : 'no') },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '-' },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt ?? 0) },
    { key: 'total_hours', header: 'Total Hours', render: (r: any) => String(r.total_hours ?? 0) },
  ];

  const completedCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? r.engineer_user_id?.slice(0, 8) ?? '-' },
    { key: 'target_equipment_category', header: 'Category', render: (r: any) => r.target_equipment_category ?? '-' },
    { key: 'status', header: 'Outcome', render: (r: any) => r.status ?? '-' },
    { key: 'hours_logged', header: 'Hours', render: (r: any) => String(r.hours_logged ?? 0) },
    { key: 'decided_at', header: 'Decided', render: (r: any) => (r.decided_at ? new Date(r.decided_at).toLocaleDateString() : '-') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Cross-Train Tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track engineers cross-training into new equipment categories — assignments, assessments, and outcomes.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Progress Summary</h2>
        <DataTable rows={summary} columns={summaryCols} rowKey={(r: any, i: number) => String(r.status ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active & Recent Assignments</h2>
        <DataTable rows={assignments} columns={assignmentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Assessments (written / practical / shadow / independent job)</h2>
        <DataTable rows={assessments} columns={assessmentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Completed Cross-Trains</h2>
        <DataTable rows={completed} columns={completedCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
