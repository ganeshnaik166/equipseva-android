import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderBoardMemberTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [membersRes, attendanceRes, missedRes, recentRes] = await Promise.all([
    sb.rpc('list_board_members_r1918'),
    sb.rpc('list_board_attendance_r1918'),
    sb.rpc('missed_recent_board_r1918'),
    sb.rpc('recent_board_attendance_r1918'),
  ]);

  const members: any[] = membersRes.data ?? [];
  const attendance: any[] = attendanceRes.data ?? [];
  const missed: any[] = missedRes.data ?? [];
  const recent: any[] = recentRes.data ?? [];

  const totalMembers = members.length;
  const activeMembers = members.filter((m) => m.status === 'active').length;
  const votingMembers = members.filter((m) => m.voting_rights && m.status === 'active').length;
  const resignedCount = members.filter((m) => m.status === 'resigned').length;

  const memberCols: Column<any>[] = [
    { key: 'member_name', header: 'Name', render: (r: any) => r.member_name ?? '—' },
    { key: 'member_email', header: 'Email', render: (r: any) => r.member_email ?? '—' },
    { key: 'role', header: 'Role', render: (r: any) => String(r.role ?? '—').replace(/_/g, ' ') },
    { key: 'voting_rights', header: 'Voting', render: (r: any) => (r.voting_rights ? 'yes' : 'observer') },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'joined_at', header: 'Joined', render: (r: any) => (r.joined_at ? new Date(r.joined_at).toLocaleDateString() : '—') },
    { key: 'term_end_date', header: 'Term ends', render: (r: any) => r.term_end_date ?? 'open' },
  ];

  const attendanceCols: Column<any>[] = [
    { key: 'meeting_date', header: 'Meeting', render: (r: any) => r.meeting_date ?? '—' },
    { key: 'member_name', header: 'Member', render: (r: any) => r.member_name ?? '—' },
    { key: 'attended', header: 'Attended', render: (r: any) => (r.attended ? 'yes' : 'no') },
    { key: 'contribution_score', header: 'Score (0 to 10)', render: (r: any) => (r.contribution_score ?? '—') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ? String(r.notes_md).slice(0, 80) : '—') },
  ];

  const missedCols: Column<any>[] = [
    { key: 'member_name', header: 'Member', render: (r: any) => r.member_name ?? '—' },
    { key: 'role', header: 'Role', render: (r: any) => String(r.role ?? '—').replace(/_/g, ' ') },
    { key: 'total_recent', header: 'Recent logged', render: (r: any) => r.total_recent ?? 0 },
    { key: 'missed_count', header: 'Missed', render: (r: any) => r.missed_count ?? 0 },
  ];

  const recentCols: Column<any>[] = [
    { key: 'meeting_date', header: 'Date', render: (r: any) => r.meeting_date ?? '—' },
    { key: 'member_name', header: 'Member', render: (r: any) => r.member_name ?? '—' },
    { key: 'role', header: 'Role', render: (r: any) => String(r.role ?? '—').replace(/_/g, ' ') },
    { key: 'attended', header: 'Attended', render: (r: any) => (r.attended ? 'yes' : 'no') },
    { key: 'contribution_score', header: 'Score', render: (r: any) => (r.contribution_score ?? '—') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder Board Member Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Board roster, voting rights, observer seats, meeting attendance, and contribution scores.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, background: '#f7f7f8', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total members</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalMembers}</div>
        </div>
        <div style={{ padding: 16, background: '#f0fdf4', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{activeMembers}</div>
        </div>
        <div style={{ padding: 16, background: '#eff6ff', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Voting rights</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{votingMembers}</div>
        </div>
        <div style={{ padding: 16, background: '#fef2f2', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Resigned</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{resignedCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Board roster</h2>
        <DataTable rows={members} columns={memberCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Missed at least 2 of last 4 meetings
        </h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Active members flagged for follow-up on attendance.
        </p>
        <DataTable rows={missed} columns={missedCols} rowKey={(r: any, i: number) => String(r.member_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent attendance (last 20)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All attendance log</h2>
        <DataTable rows={attendance} columns={attendanceCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
