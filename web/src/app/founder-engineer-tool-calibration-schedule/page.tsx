import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [schedulesRes, dueRes, recentRes] = await Promise.all([
    sb.rpc('list_schedules_r2128'),
    sb.rpc('due_soon_r2128'),
    sb.rpc('recent_actions_r2128'),
  ]);

  const schedules: any[] = Array.isArray(schedulesRes.data) ? schedulesRes.data : [];
  const due: any[] = Array.isArray(dueRes.data) ? dueRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const fmt = (v: any) => (v ? new Date(v).toLocaleString() : '—');
  const rupees = (v: any) => (v == null ? '—' : `₹${Number(v).toLocaleString('en-IN')}`);

  const scheduleCols: Column<any>[] = [
    { key: 'tool_label', header: 'Tool', render: (r: any) => r.tool_label ?? '—' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'last_calibration_at', header: 'Last Calibrated', render: (r: any) => fmt(r.last_calibration_at) },
    { key: 'next_calibration_due_at', header: 'Next Due', render: (r: any) => fmt(r.next_calibration_due_at) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmt(r.captured_at) },
  ];

  const dueCols: Column<any>[] = [
    { key: 'tool_label', header: 'Tool', render: (r: any) => r.tool_label ?? '—' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'next_calibration_due_at', header: 'Next Due', render: (r: any) => fmt(r.next_calibration_due_at) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'schedule_id', header: 'Schedule', render: (r: any) => String(r.schedule_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'cost_rupees', header: 'Cost', render: (r: any) => rupees(r.cost_rupees) },
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmt(r.taken_at) },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Engineer Tool Calibration Schedule
      </h1>
      <p style={{ color: '#666', marginBottom: '2rem' }}>
        Track tool calibration cadence across the engineer fleet. Surface items that are due soon or overdue,
        log calibration events, and keep the founder action log in sync.
      </p>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          All Schedules ({schedules.length})
        </h2>
        <DataTable rows={schedules} columns={scheduleCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Due Soon and Overdue ({due.length})
        </h2>
        <DataTable rows={due} columns={dueCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Recent Calibration Actions ({recent.length})
        </h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
