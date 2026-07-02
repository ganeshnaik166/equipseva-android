import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPublicSpeakingCalendarPage() {
  const sb = await getSupabaseServerClient();

  const [eventsRes, upcomingRes, recentPrepRes] = await Promise.all([
    sb.rpc('founder_speaking_list_events_r2050'),
    sb.rpc('founder_speaking_upcoming_r2050'),
    sb.rpc('founder_speaking_recent_prep_r2050'),
  ]);

  const events = (eventsRes.data ?? []) as any[];
  const upcoming = (upcomingRes.data ?? []) as any[];
  const recentPrep = (recentPrepRes.data ?? []) as any[];

  const eventCols: Column<any>[] = [
    { key: 'event_name', header: 'Event', render: (r: any) => r.event_name ?? '' },
    { key: 'event_date', header: 'Date', render: (r: any) => r.event_date ?? '' },
    { key: 'talk_topic', header: 'Topic', render: (r: any) => r.talk_topic ?? '' },
    { key: 'audience_size_estimate', header: 'Audience', render: (r: any) => r.audience_size_estimate ?? '' },
    { key: 'talk_status', header: 'Status', render: (r: any) => r.talk_status ?? '' },
    { key: 'prep_hours', header: 'Prep hrs', render: (r: any) => r.prep_hours ?? 0 },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '') },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'event_name', header: 'Event', render: (r: any) => r.event_name ?? '' },
    { key: 'event_date', header: 'Date', render: (r: any) => r.event_date ?? '' },
    { key: 'days_until', header: 'Days until', render: (r: any) => r.days_until ?? '' },
    { key: 'talk_topic', header: 'Topic', render: (r: any) => r.talk_topic ?? '' },
    { key: 'audience_size_estimate', header: 'Audience', render: (r: any) => r.audience_size_estimate ?? '' },
    { key: 'talk_status', header: 'Status', render: (r: any) => r.talk_status ?? '' },
    { key: 'prep_hours', header: 'Prep hrs', render: (r: any) => r.prep_hours ?? 0 },
  ];

  const prepCols: Column<any>[] = [
    { key: 'event_name', header: 'Event', render: (r: any) => r.event_name ?? '' },
    { key: 'prep_type', header: 'Prep type', render: (r: any) => r.prep_type ?? '' },
    { key: 'taken_at', header: 'When', render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : '') },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Public Speaking Calendar</h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Track committed talks, audience reach, and prep cadence. Use this view to make sure prep hours scale with audience size.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Upcoming commitments</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Events with status committed or preparing. Days until is computed from today.
        </p>
        <DataTable rows={upcoming} columns={upcomingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent prep activity</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Most recent prep log entries across all events. Look for events with zero prep entries close to their date.
        </p>
        <DataTable rows={recentPrep} columns={prepCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All speaking events</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          Full log of public speaking commitments and their status.
        </p>
        <DataTable rows={events} columns={eventCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
