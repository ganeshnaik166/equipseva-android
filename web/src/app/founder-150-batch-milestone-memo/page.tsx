import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [memosRes, recentRes, lessonsRes] = await Promise.all([
    sb.rpc('list_memos_r1898'),
    sb.rpc('recent_reactions_r1898'),
    sb.rpc('top_lessons_r1898'),
  ]);

  const memos: any[] = Array.isArray(memosRes.data) ? memosRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];
  const lessons: any[] = Array.isArray(lessonsRes.data) ? lessonsRes.data : [];

  const memoCols: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => <span className="font-medium">{String(r.milestone_label ?? '')}</span> },
    { key: 'written_at', header: 'Written', render: (r: any) => <span className="text-xs text-gray-600">{r.written_at ? new Date(r.written_at).toLocaleString() : '-'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs uppercase">{String(r.status ?? '')}</span> },
    { key: 'reaction_count', header: 'Reactions', render: (r: any) => <span>{Number(r.reaction_count ?? 0)}</span> },
    { key: 'summary_md', header: 'Summary', render: (r: any) => <span className="text-xs text-gray-700 line-clamp-2">{String(r.summary_md ?? '').slice(0, 200)}</span> },
  ];

  const recentCols: Column<any>[] = [
    { key: 'recorded_at', header: 'When', render: (r: any) => <span className="text-xs text-gray-600">{r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '-'}</span> },
    { key: 'milestone_label', header: 'Memo', render: (r: any) => <span>{String(r.milestone_label ?? '')}</span> },
    { key: 'reactor_email', header: 'Reactor', render: (r: any) => <span className="text-xs">{String(r.reactor_email ?? '')}</span> },
    { key: 'reactor_role', header: 'Role', render: (r: any) => <span className="text-xs uppercase">{String(r.reactor_role ?? '')}</span> },
    { key: 'reaction_md', header: 'Reaction', render: (r: any) => <span className="text-xs text-gray-700 line-clamp-2">{String(r.reaction_md ?? '').slice(0, 180)}</span> },
  ];

  const lessonCols: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => <span className="font-medium">{String(r.milestone_label ?? '')}</span> },
    { key: 'written_at', header: 'Written', render: (r: any) => <span className="text-xs text-gray-600">{r.written_at ? new Date(r.written_at).toLocaleDateString() : '-'}</span> },
    { key: 'top_lessons_md', header: 'Top Lessons', render: (r: any) => <span className="text-xs text-gray-700 line-clamp-3">{String(r.top_lessons_md ?? '').slice(0, 260)}</span> },
    { key: 'top_patterns_md', header: 'Top Patterns', render: (r: any) => <span className="text-xs text-gray-700 line-clamp-3">{String(r.top_patterns_md ?? '').slice(0, 260)}</span> },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Founder 150-Batch Milestone Memo</h1>
        <p className="text-sm text-gray-600">What 150 batches taught us — lessons, patterns, founder notes, and reactions from team & investors.</p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Published memos</h2>
        <p className="text-xs text-gray-500">Most recent first. Reactions counted across all roles.</p>
        <DataTable rows={memos} columns={memoCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top lessons & patterns</h2>
        <p className="text-xs text-gray-500">Latest 20 published memos — lesson & pattern columns side-by-side.</p>
        <DataTable rows={lessons} columns={lessonCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent reactions</h2>
        <p className="text-xs text-gray-500">Latest 50 reactions across all memos.</p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
