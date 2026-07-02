import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerAdvisoryBoardPage() {
  const sb = await getSupabaseServerClient();

  const [membersRes, meetingsRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_cab_members_r1954'),
    sb.rpc('list_cab_meetings_r1954'),
    sb.rpc('top_cab_contributors_r1954'),
    sb.rpc('recent_cab_meetings_r1954'),
  ]);

  const members: any[] = Array.isArray(membersRes.data) ? membersRes.data : [];
  const meetings: any[] = Array.isArray(meetingsRes.data) ? meetingsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const memberCols: Column<any>[] = [
    { key: 'member_name', header: 'Name', render: (r: any) => r.member_name ?? '' },
    { key: 'member_email', header: 'Email', render: (r: any) => r.member_email ?? '' },
    { key: 'organization', header: 'Organization', render: (r: any) => r.organization ?? '' },
    { key: 'role', header: 'Role', render: (r: any) => r.role ?? '' },
    { key: 'joined_at', header: 'Joined', render: (r: any) => r.joined_at ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'term_length_months', header: 'Term (months)', render: (r: any) => String(r.term_length_months ?? 0) },
  ];

  const meetingCols: Column<any>[] = [
    { key: 'meeting_date', header: 'Date', render: (r: any) => r.meeting_date ?? '' },
    { key: 'member_name', header: 'Member', render: (r: any) => r.member_name ?? '' },
    { key: 'topic_md', header: 'Topic', render: (r: any) => r.topic_md ?? '' },
    { key: 'attended', header: 'Attended', render: (r: any) => (r.attended ? 'yes' : 'no') },
    { key: 'contribution_md', header: 'Contribution', render: (r: any) => r.contribution_md ?? '' },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => (r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '') },
  ];

  const topCols: Column<any>[] = [
    { key: 'member_name', header: 'Member', render: (r: any) => r.member_name ?? '' },
    { key: 'organization', header: 'Organization', render: (r: any) => r.organization ?? '' },
    { key: 'meetings_attended', header: 'Attended', render: (r: any) => String(r.meetings_attended ?? 0) },
    { key: 'total_meetings', header: 'Total', render: (r: any) => String(r.total_meetings ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'meeting_date', header: 'Date', render: (r: any) => r.meeting_date ?? '' },
    { key: 'member_name', header: 'Member', render: (r: any) => r.member_name ?? '' },
    { key: 'organization', header: 'Organization', render: (r: any) => r.organization ?? '' },
    { key: 'topic_md', header: 'Topic', render: (r: any) => r.topic_md ?? '' },
    { key: 'attended', header: 'Attended', render: (r: any) => (r.attended ? 'yes' : 'no') },
  ];

  const activeCount = members.filter((m) => m.status === 'active').length;

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Customer Advisory Board</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track CAB members and their meeting contributions. Showing at least the last 90 days of meetings.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total members</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{members.length}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active members</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{activeCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total meetings</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{meetings.length}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Recent meetings (90d)</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{recent.length}</div>
        </div>
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Members</h2>
        <DataTable rows={members} columns={memberCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top contributors</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.member_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent meetings</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All meetings</h2>
        <DataTable rows={meetings} columns={meetingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
