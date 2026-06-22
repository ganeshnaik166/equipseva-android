import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [schedules, upcoming, actions] = await Promise.all([
    sb.rpc('list_schedules_r2013'),
    sb.rpc('upcoming_checkins_r2013'),
    sb.rpc('recent_actions_r2013'),
  ]);

  const scheduleRows: any[] = (schedules.data as any[]) ?? [];
  const upcomingRows: any[] = (upcoming.data as any[]) ?? [];
  const actionRows: any[] = (actions.data as any[]) ?? [];

  const scheduleCols: Column<any>[] = [
    { key: 'label', header: 'Label', render: (r: any) => r.checkin_label },
    { key: 'type', header: 'Type', render: (r: any) => r.checkin_type },
    { key: 'scheduled_for', header: 'Scheduled', render: (r: any) => new Date(r.scheduled_for).toLocaleString() },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'completed_at', header: 'Completed', render: (r: any) => (r.completed_at ? new Date(r.completed_at).toLocaleString() : '—') },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'label', header: 'Label', render: (r: any) => r.checkin_label },
    { key: 'type', header: 'Type', render: (r: any) => r.checkin_type },
    { key: 'scheduled_for', header: 'When', render: (r: any) => new Date(r.scheduled_for).toLocaleString() },
    { key: 'investor', header: 'Investor', render: (r: any) => String(r.investor_id).slice(0, 8) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'notes', header: 'Notes', render: (r: any) => (r.notes_md ? String(r.notes_md).slice(0, 80) : '—') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Compliance Checkin Schedule</h1>
        <p className="text-sm text-gray-600">Schedule and track compliance check-ins with investors across governance, financial, regulatory, operational, and legal categories.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming Check-ins</h2>
        <DataTable rows={upcomingRows} columns={upcomingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Schedules</h2>
        <DataTable rows={scheduleRows} columns={scheduleCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <DataTable rows={actionRows} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
