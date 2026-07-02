import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [elections, upcoming, recent] = await Promise.all([
    sb.rpc('list_director_elections_r2001'),
    sb.rpc('upcoming_director_elections_r2001'),
    sb.rpc('recent_director_actions_r2001', { p_limit: 50 }),
  ]);

  const electionRows: any[] = Array.isArray(elections.data) ? elections.data : [];
  const upcomingRows: any[] = Array.isArray(upcoming.data) ? upcoming.data : [];
  const recentRows: any[] = Array.isArray(recent.data) ? recent.data : [];

  const electionCols: Column<any>[] = [
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => String(r.candidate_name ?? '') },
    { key: 'election_type', header: 'Type', render: (r: any) => String(r.election_type ?? '') },
    { key: 'election_date', header: 'Election Date', render: (r: any) => String(r.election_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'term_end_date', header: 'Term End', render: (r: any) => String(r.term_end_date ?? '') },
    { key: 'votes_for', header: 'Votes For', render: (r: any) => String(r.votes_for ?? 0) },
    { key: 'votes_against', header: 'Votes Against', render: (r: any) => String(r.votes_against ?? 0) },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => String(r.candidate_name ?? '') },
    { key: 'election_type', header: 'Type', render: (r: any) => String(r.election_type ?? '') },
    { key: 'election_date', header: 'Scheduled', render: (r: any) => String(r.election_date ?? '') },
    { key: 'term_end_date', header: 'Term End', render: (r: any) => String(r.term_end_date ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => String(r.taken_at ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Director-Election Tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track investor-designated director nominations, votes, term renewals, and replacements.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Elections</h2>
        <DataTable rows={electionRows} columns={electionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Upcoming Scheduled Elections</h2>
        <DataTable rows={upcomingRows} columns={upcomingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Director Actions</h2>
        <DataTable rows={recentRows} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
