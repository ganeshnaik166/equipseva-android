import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCalendarBufferTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [periodsRes, shortRes, recentRes] = await Promise.all([
    sb.rpc('list_periods_r2174'),
    sb.rpc('short_periods_r2174'),
    sb.rpc('recent_actions_r2174'),
  ]);

  const periods: any[] = (periodsRes.data as any[]) ?? [];
  const shorts: any[] = (shortRes.data as any[]) ?? [];
  const recents: any[] = (recentRes.data as any[]) ?? [];

  const periodCols: Column<any>[] = [
    { key: 'week_label', header: 'Week', render: (r: any) => String(r.week_label ?? '') },
    { key: 'scheduled_buffer_hours', header: 'Scheduled (h)', render: (r: any) => String(r.scheduled_buffer_hours ?? 0) },
    { key: 'actual_buffer_hours', header: 'Actual (h)', render: (r: any) => String(r.actual_buffer_hours ?? 0) },
    { key: 'buffer_protection_pct', header: 'Protection %', render: (r: any) => String(r.buffer_protection_pct ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const shortCols: Column<any>[] = [
    { key: 'week_label', header: 'Week', render: (r: any) => String(r.week_label ?? '') },
    { key: 'buffer_protection_pct', header: 'Protection %', render: (r: any) => String(r.buffer_protection_pct ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Calendar Buffer Tracker</h1>
        <p className="text-sm text-gray-600">Track no-meeting buffer windows: scheduled vs actual, protection %, and recovery actions.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Periods</h2>
        <DataTable rows={periods} columns={periodCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Short or None Buffers</h2>
        <DataTable rows={shorts} columns={shortCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <DataTable rows={recents} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
