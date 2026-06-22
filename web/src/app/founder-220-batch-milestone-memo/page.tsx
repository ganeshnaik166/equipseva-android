import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [memosRes, recentRes, topRes] = await Promise.all([
    sb.rpc('list_memos_r2178'),
    sb.rpc('recent_reactions_r2178'),
    sb.rpc('top_reactions_r2178'),
  ]);

  const memos: any[] = Array.isArray(memosRes.data) ? memosRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];

  const memoCols: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => String(r.milestone_label ?? '') },
    { key: 'written_at', header: 'Written', render: (r: any) => r.written_at ? new Date(r.written_at).toLocaleString() : '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'summary_md', header: 'Summary', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.summary_md ?? '').slice(0, 280)}</span> },
    { key: 'top_lessons_md', header: 'Top Lessons', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.top_lessons_md ?? '').slice(0, 280)}</span> },
    { key: 'next_500_plan_md', header: 'Next 500 Plan', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.next_500_plan_md ?? '').slice(0, 280)}</span> },
  ];

  const reactionCols: Column<any>[] = [
    { key: 'recorded_at', header: 'When', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
    { key: 'reactor_email', header: 'Reactor', render: (r: any) => String(r.reactor_email ?? '') },
    { key: 'reactor_role', header: 'Role', render: (r: any) => String(r.reactor_role ?? '') },
    { key: 'reaction_md', header: 'Reaction', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.reaction_md ?? '').slice(0, 280)}</span> },
    { key: 'memo_id', header: 'Memo', render: (r: any) => <code style={{ fontSize: 11 }}>{String(r.memo_id ?? '').slice(0, 8)}</code> },
  ];

  const topCols: Column<any>[] = [
    { key: 'reactor_role', header: 'Role', render: (r: any) => String(r.reactor_role ?? '') },
    { key: 'reaction_count', header: 'Reactions', render: (r: any) => Number(r.reaction_count ?? 0).toLocaleString() },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Founder 220-Batch Milestone Memo</h1>
        <p style={{ color: '#666', marginTop: 8 }}>
          Round r2178 — 220-batch milestone memo. Track founder reflections, top lessons, and the next-500 plan.
          Reactions from team, investors, customers & external observers.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Milestone Memos</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Showing {memos.length} memo(s). Status filter — published &amp; archived both shown.
        </p>
        <DataTable<any> rows={memos} columns={memoCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Reactions</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Latest 50 reactions across all memos.
        </p>
        <DataTable<any> rows={recent} columns={reactionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Reaction Counts by Role</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Aggregate reaction counts grouped by reactor role.
        </p>
        <DataTable<any> rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.reactor_role ?? i)} />
      </section>
    </main>
  );
}
