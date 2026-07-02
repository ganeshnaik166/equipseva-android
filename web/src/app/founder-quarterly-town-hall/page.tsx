import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlyTownHallPage() {
  const sb = await getSupabaseServerClient();

  const [hallsRes, upcomingRes, actionsRes] = await Promise.all([
    sb.rpc('r2078_list_halls'),
    sb.rpc('r2078_upcoming'),
    sb.rpc('r2078_recent_actions'),
  ]);

  const halls = (hallsRes.data ?? []) as any[];
  const upcoming = (upcomingRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];

  const hallCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'town_hall_date', header: 'Date', render: (r: any) => String(r.town_hall_date ?? '') },
    { key: 'attendee_count', header: 'Attendees', render: (r: any) => String(r.attendee_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'town_hall_date', header: 'Scheduled', render: (r: any) => String(r.town_hall_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'attendee_count', header: 'Expected', render: (r: any) => String(r.attendee_count ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Quarterly Town Hall</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track quarterly town halls with the team. Captures announcements, questions, themes and follow-up actions.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming Town Halls</h2>
        <DataTable rows={upcoming} columns={upcomingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Town Halls</h2>
        <DataTable rows={halls} columns={hallCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Action Log</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
