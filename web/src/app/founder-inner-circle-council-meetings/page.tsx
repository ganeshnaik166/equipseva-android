import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [meetingsRes, recentRes, openDecRes] = await Promise.all([
    sb.rpc('r1874_list_meetings'),
    sb.rpc('r1874_recent_meetings'),
    sb.rpc('r1874_open_decisions'),
  ]);

  const meetings: any[] = Array.isArray(meetingsRes.data) ? meetingsRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];
  const openDecisions: any[] = Array.isArray(openDecRes.data) ? openDecRes.data : [];

  const meetingCols: Column<any>[] = [
    { key: 'meeting_date', header: 'Date', render: (r: any) => String(r.meeting_date ?? '') },
    { key: 'meeting_label', header: 'Label', render: (r: any) => String(r.meeting_label ?? '') },
    { key: 'topic', header: 'Topic', render: (r: any) => String(r.topic ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'attendees', header: 'Attendees', render: (r: any) => Array.isArray(r.attendee_emails) ? r.attendee_emails.join(', ') : '' },
    { key: 'held_at', header: 'Held At', render: (r: any) => r.held_at ? new Date(r.held_at).toLocaleString() : '-' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'meeting_date', header: 'Date', render: (r: any) => String(r.meeting_date ?? '') },
    { key: 'meeting_label', header: 'Label', render: (r: any) => String(r.meeting_label ?? '') },
    { key: 'topic', header: 'Topic', render: (r: any) => String(r.topic ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'attendee_count', header: 'Attendees', render: (r: any) => String(r.attendee_count ?? 0) },
    { key: 'decision_count', header: 'Decisions', render: (r: any) => String(r.decision_count ?? 0) },
  ];

  const openDecCols: Column<any>[] = [
    { key: 'meeting_date', header: 'Date', render: (r: any) => String(r.meeting_date ?? '') },
    { key: 'meeting_label', header: 'Meeting', render: (r: any) => String(r.meeting_label ?? '') },
    { key: 'decision_text', header: 'Decision', render: (r: any) => String(r.decision_text ?? '') },
    { key: 'decision_owner_email', header: 'Owner', render: (r: any) => String(r.decision_owner_email ?? '') },
    { key: 'decision_status', header: 'Status', render: (r: any) => String(r.decision_status ?? '') },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleString() : '-' },
  ];

  const totalMeetings = meetings.length;
  const heldCount = meetings.filter((m: any) => m.status === 'held').length;
  const scheduledCount = meetings.filter((m: any) => m.status === 'scheduled').length;
  const openCount = openDecisions.length;

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>
        Founder Inner Circle Council Meetings
      </h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Track cofounder, advisor & family decision meetings and open follow-ups (round 1874).
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <Stat label="Total meetings" value={String(totalMeetings)} />
        <Stat label="Held" value={String(heldCount)} />
        <Stat label="Scheduled" value={String(scheduledCount)} />
        <Stat label="Open decisions" value={String(openCount)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent (last 60 days)</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Open Decisions</h2>
        <DataTable
          rows={openDecisions}
          columns={openDecCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>All Meetings</h2>
        <DataTable
          rows={meetings}
          columns={meetingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
