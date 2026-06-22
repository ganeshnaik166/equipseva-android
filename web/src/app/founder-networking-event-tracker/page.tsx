import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderNetworkingEventTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [eventsRes, meetsRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_networking_events_r1870'),
    sb.rpc('list_networking_meets_r1870'),
    sb.rpc('top_networking_value_events_r1870'),
    sb.rpc('recent_networking_meets_r1870'),
  ]);

  const events = (eventsRes.data ?? []) as any[];
  const meets = (meetsRes.data ?? []) as any[];
  const topEvents = (topRes.data ?? []) as any[];
  const recentMeets = (recentRes.data ?? []) as any[];

  const totalEvents = events.length;
  const attended = events.filter((e) => e.status === 'attended').length;
  const planned = events.filter((e) => e.status === 'planned').length;
  const totalMeets = meets.length;
  const followUpsPending = meets.filter((m) => m.follow_up_required).length;
  const avgScore = (() => {
    const scored = events.filter((e) => e.founder_value_score != null);
    if (scored.length === 0) return '-';
    const sum = scored.reduce((acc, e) => acc + Number(e.founder_value_score), 0);
    return (sum / scored.length).toFixed(1);
  })();

  const eventCols: Column<any>[] = [
    { key: 'event_name', header: 'Event', render: (r: any) => <span className="font-medium">{r.event_name}</span> },
    { key: 'event_type', header: 'Type', render: (r: any) => <span className="text-xs px-2 py-0.5 rounded bg-slate-100">{r.event_type}</span> },
    { key: 'event_date', header: 'Date', render: (r: any) => <span>{r.event_date}</span> },
    { key: 'location', header: 'Location', render: (r: any) => <span>{r.location ?? '-'}</span> },
    { key: 'expected_attendees', header: 'Expected', render: (r: any) => <span>{r.expected_attendees ?? '-'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => {
      const color = r.status === 'attended' ? 'bg-emerald-100 text-emerald-800'
        : r.status === 'planned' ? 'bg-blue-100 text-blue-800'
        : r.status === 'cancelled' ? 'bg-rose-100 text-rose-800'
        : 'bg-slate-100 text-slate-800';
      return <span className={`text-xs px-2 py-0.5 rounded ${color}`}>{r.status}</span>;
    } },
    { key: 'founder_value_score', header: 'Score', render: (r: any) => <span className="font-mono">{r.founder_value_score ?? '-'}</span> },
    { key: 'meet_count', header: 'Meets', render: (r: any) => <span className="font-mono">{Number(r.meet_count ?? 0)}</span> },
    { key: 'follow_up_count', header: 'Follow-ups', render: (r: any) => <span className="font-mono">{Number(r.follow_up_count ?? 0)}</span> },
  ];

  const meetCols: Column<any>[] = [
    { key: 'met_person_name', header: 'Person', render: (r: any) => <span className="font-medium">{r.met_person_name}</span> },
    { key: 'met_person_role', header: 'Role', render: (r: any) => <span>{r.met_person_role ?? '-'}</span> },
    { key: 'met_person_org', header: 'Org', render: (r: any) => <span>{r.met_person_org ?? '-'}</span> },
    { key: 'met_person_email', header: 'Email', render: (r: any) => <span className="font-mono text-xs">{r.met_person_email ?? '-'}</span> },
    { key: 'event_name', header: 'Event', render: (r: any) => <span>{r.event_name}</span> },
    { key: 'follow_up_required', header: 'Follow-up?', render: (r: any) => r.follow_up_required
      ? <span className="text-xs px-2 py-0.5 rounded bg-amber-100 text-amber-800">yes</span>
      : <span className="text-xs px-2 py-0.5 rounded bg-slate-100">no</span> },
    { key: 'met_at', header: 'Met', render: (r: any) => <span>{new Date(r.met_at).toLocaleDateString()}</span> },
  ];

  const topCols: Column<any>[] = [
    { key: 'event_name', header: 'Event', render: (r: any) => <span className="font-medium">{r.event_name}</span> },
    { key: 'event_type', header: 'Type', render: (r: any) => <span className="text-xs px-2 py-0.5 rounded bg-slate-100">{r.event_type}</span> },
    { key: 'event_date', header: 'Date', render: (r: any) => <span>{r.event_date}</span> },
    { key: 'founder_value_score', header: 'Score', render: (r: any) => <span className="font-mono font-semibold text-emerald-700">{r.founder_value_score ?? '-'}</span> },
    { key: 'meet_count', header: 'Meets', render: (r: any) => <span className="font-mono">{Number(r.meet_count ?? 0)}</span> },
    { key: 'follow_up_count', header: 'Follow-ups', render: (r: any) => <span className="font-mono">{Number(r.follow_up_count ?? 0)}</span> },
  ];

  const recentCols: Column<any>[] = [
    { key: 'met_person_name', header: 'Person', render: (r: any) => <span className="font-medium">{r.met_person_name}</span> },
    { key: 'met_person_role', header: 'Role', render: (r: any) => <span>{r.met_person_role ?? '-'}</span> },
    { key: 'met_person_org', header: 'Org', render: (r: any) => <span>{r.met_person_org ?? '-'}</span> },
    { key: 'event_name', header: 'Event', render: (r: any) => <span>{r.event_name}</span> },
    { key: 'follow_up_required', header: 'Follow-up?', render: (r: any) => r.follow_up_required
      ? <span className="text-xs px-2 py-0.5 rounded bg-amber-100 text-amber-800">yes</span>
      : <span className="text-xs px-2 py-0.5 rounded bg-slate-100">no</span> },
    { key: 'met_at', header: 'Met', render: (r: any) => <span>{new Date(r.met_at).toLocaleString()}</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Founder Networking Event Tracker</h1>
        <p className="text-sm text-slate-600 mt-1">
          Log conferences, founder dinners, investor meet-ups & industry panels. Track value score & follow-ups.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-slate-500">Total Events</div>
          <div className="text-2xl font-bold font-mono">{totalEvents}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-slate-500">Attended</div>
          <div className="text-2xl font-bold font-mono text-emerald-700">{attended}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-slate-500">Planned</div>
          <div className="text-2xl font-bold font-mono text-blue-700">{planned}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-slate-500">People Met</div>
          <div className="text-2xl font-bold font-mono">{totalMeets}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-slate-500">Follow-ups Pending</div>
          <div className="text-2xl font-bold font-mono text-amber-700">{followUpsPending}</div>
        </div>
        <div className="rounded border p-3 bg-white">
          <div className="text-xs text-slate-500">Avg Value Score</div>
          <div className="text-2xl font-bold font-mono">{avgScore}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Events</h2>
        <DataTable rows={events} columns={eventCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Value Events (score &gt;= 1, attended)</h2>
        <DataTable rows={topEvents} columns={topCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Meets (last 30 days)</h2>
        <DataTable rows={recentMeets} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Meets</h2>
        <DataTable rows={meets} columns={meetCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
