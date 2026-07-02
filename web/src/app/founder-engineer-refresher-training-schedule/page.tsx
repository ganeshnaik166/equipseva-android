import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TrainingRow = {
  id: string;
  training_topic: string;
  scheduled_date: string;
  target_attendee_count: number;
  actual_attendee_count: number;
  status: string;
  captured_at: string;
};

type UpcomingRow = {
  id: string;
  training_topic: string;
  scheduled_date: string;
  target_attendee_count: number;
  status: string;
};

type RecentAttendanceRow = {
  id: string;
  training_id: string;
  training_topic: string;
  attendee_user_id: string;
  attended: boolean;
  comprehension_score: number | null;
  recorded_at: string;
  by_email: string | null;
};

export default async function FounderEngineerRefresherTrainingSchedulePage() {
  const sb = await getSupabaseServerClient();

  const [trainingsRes, upcomingRes, recentRes] = await Promise.all([
    sb.rpc('list_trainings_r2092'),
    sb.rpc('upcoming_trainings_r2092'),
    sb.rpc('recent_attendances_r2092'),
  ]);

  const trainings: TrainingRow[] = (trainingsRes.data as TrainingRow[]) ?? [];
  const upcoming: UpcomingRow[] = (upcomingRes.data as UpcomingRow[]) ?? [];
  const recent: RecentAttendanceRow[] = (recentRes.data as RecentAttendanceRow[]) ?? [];

  const totalScheduled = trainings.filter((t) => t.status === 'scheduled').length;
  const totalCompleted = trainings.filter((t) => t.status === 'completed').length;
  const totalAttended = recent.filter((r) => r.attended).length;

  const trainingCols: Column<TrainingRow>[] = [
    { key: 'training_topic', header: 'Topic', render: (r: any) => String(r.training_topic ?? '') },
    { key: 'scheduled_date', header: 'Scheduled Date', render: (r: any) => String(r.scheduled_date ?? '') },
    { key: 'target_attendee_count', header: 'Target', render: (r: any) => String(r.target_attendee_count ?? 0) },
    { key: 'actual_attendee_count', header: 'Actual', render: (r: any) => String(r.actual_attendee_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '') },
  ];

  const upcomingCols: Column<UpcomingRow>[] = [
    { key: 'training_topic', header: 'Topic', render: (r: any) => String(r.training_topic ?? '') },
    { key: 'scheduled_date', header: 'Scheduled Date', render: (r: any) => String(r.scheduled_date ?? '') },
    { key: 'target_attendee_count', header: 'Target', render: (r: any) => String(r.target_attendee_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const recentCols: Column<RecentAttendanceRow>[] = [
    { key: 'training_topic', header: 'Training', render: (r: any) => String(r.training_topic ?? '') },
    { key: 'attendee_user_id', header: 'Attendee', render: (r: any) => String(r.attendee_user_id ?? '').slice(0, 8) },
    { key: 'attended', header: 'Attended', render: (r: any) => (r.attended ? 'yes' : 'no') },
    { key: 'comprehension_score', header: 'Score', render: (r: any) => (r.comprehension_score == null ? '' : String(r.comprehension_score)) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => (r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
          Engineer Refresher Training Schedule
        </h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          Schedule refresher sessions, log attendance, and track comprehension across the engineer fleet.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Scheduled</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalScheduled}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Completed</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalCompleted}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Recent Attended</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalAttended}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Upcoming</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{upcoming.length}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Upcoming Trainings</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Scheduled Trainings</h2>
        <DataTable
          rows={trainings}
          columns={trainingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent Attendance Log</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer style={{ marginTop: '32px', paddingTop: '16px', borderTop: '1px solid #e5e7eb', fontSize: '12px', color: '#666' }}>
        Round 2092 — founder-only refresher training console. All writes audit to founder_action_log.
      </footer>
    </main>
  );
}
