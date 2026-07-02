import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerApprenticeMentorshipPage() {
  const sb = await getSupabaseServerClient();

  const [pairsRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_pairs_r2068'),
    sb.rpc('active_pairs_r2068'),
    sb.rpc('recent_meetings_r2068'),
  ]);

  const pairs = (pairsRes.data ?? []) as any[];
  const active = (activeRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const pairCols: Column<any>[] = [
    { key: 'id', header: 'Pair', render: (r: any) => String(r.id).slice(0, 8) },
    { key: 'mentor_user_id', header: 'Mentor', render: (r: any) => String(r.mentor_user_id ?? '').slice(0, 8) },
    { key: 'apprentice_user_id', header: 'Apprentice', render: (r: any) => String(r.apprentice_user_id ?? '').slice(0, 8) },
    { key: 'mentorship_focus', header: 'Focus', render: (r: any) => String(r.mentorship_focus ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'paired_at', header: 'Paired', render: (r: any) => r.paired_at ? new Date(r.paired_at).toLocaleDateString() : '' },
    { key: 'expected_completion_date', header: 'Expected', render: (r: any) => r.expected_completion_date ? String(r.expected_completion_date) : '' },
    { key: 'last_meeting_at', header: 'Last Meeting', render: (r: any) => r.last_meeting_at ? new Date(r.last_meeting_at).toLocaleDateString() : 'none' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'id', header: 'Pair', render: (r: any) => String(r.id).slice(0, 8) },
    { key: 'mentor_user_id', header: 'Mentor', render: (r: any) => String(r.mentor_user_id ?? '').slice(0, 8) },
    { key: 'apprentice_user_id', header: 'Apprentice', render: (r: any) => String(r.apprentice_user_id ?? '').slice(0, 8) },
    { key: 'mentorship_focus', header: 'Focus', render: (r: any) => String(r.mentorship_focus ?? '') },
    { key: 'paired_at', header: 'Paired', render: (r: any) => r.paired_at ? new Date(r.paired_at).toLocaleDateString() : '' },
    { key: 'last_meeting_at', header: 'Last Meeting', render: (r: any) => r.last_meeting_at ? new Date(r.last_meeting_at).toLocaleDateString() : 'none' },
  ];

  const meetingCols: Column<any>[] = [
    { key: 'id', header: 'Meeting', render: (r: any) => String(r.id).slice(0, 8) },
    { key: 'pair_id', header: 'Pair', render: (r: any) => String(r.pair_id ?? '').slice(0, 8) },
    { key: 'meeting_date', header: 'Date', render: (r: any) => r.meeting_date ? String(r.meeting_date) : '' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'topic_md', header: 'Topic', render: (r: any) => String(r.topic_md ?? '').slice(0, 80) },
    { key: 'by_email', header: 'Logged By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '' },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Apprentice Mentorship</h1>
        <p className="text-sm text-gray-600 mt-1">Track mentor and apprentice pairs across technical, business, customer, safety, and leadership focus.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Pairs</h2>
        <p className="text-xs text-gray-500 mb-2">Total pairs tracked: {pairs.length}</p>
        <DataTable rows={pairs} columns={pairCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Active Pairs</h2>
        <p className="text-xs text-gray-500 mb-2">Currently active mentorships: {active.length}</p>
        <DataTable rows={active} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Meetings</h2>
        <p className="text-xs text-gray-500 mb-2">Latest meeting logs across all pairs.</p>
        <DataTable rows={recent} columns={meetingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
