import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Founder1300ShipMemoPage() {
  const sb = await getSupabaseServerClient();

  const [memosRes, recentRes, topRes] = await Promise.all([
    sb.rpc('list_memos_r2126'),
    sb.rpc('recent_reactions_r2126'),
    sb.rpc('top_reactions_r2126'),
  ]);

  const memos = (memosRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];

  const memoCols: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => String(r.milestone_label ?? '') },
    { key: 'written_at', header: 'Written', render: (r: any) => r.written_at ? new Date(r.written_at).toLocaleString() : '' },
    { key: 'summary_md', header: 'Summary', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.summary_md ?? '').slice(0, 220)}</span> },
    { key: 'top_lessons_md', header: 'Top Lessons', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.top_lessons_md ?? '').slice(0, 220)}</span> },
    { key: 'next_chapter_md', header: 'Next Chapter', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.next_chapter_md ?? '').slice(0, 220)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
    { key: 'milestone_label', header: 'Memo', render: (r: any) => String(r.milestone_label ?? '') },
    { key: 'reactor_email', header: 'Reactor', render: (r: any) => String(r.reactor_email ?? '') },
    { key: 'reactor_role', header: 'Role', render: (r: any) => String(r.reactor_role ?? '') },
    { key: 'reaction_md', header: 'Reaction', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.reaction_md ?? '').slice(0, 260)}</span> },
  ];

  const topCols: Column<any>[] = [
    { key: 'reactor_role', header: 'Role', render: (r: any) => String(r.reactor_role ?? '') },
    { key: 'reaction_count', header: 'Reactions', render: (r: any) => Number(r.reaction_count ?? 0).toLocaleString() },
    { key: 'latest_at', header: 'Latest', render: (r: any) => r.latest_at ? new Date(r.latest_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Founder 1300-Ship Memo</h1>
      <p style={{ color: '#555', marginBottom: 18 }}>
        Milestone memos at 1300 ships and reactions from team, investors, customers, observers.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Memos</h2>
        <DataTable rows={memos} columns={memoCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent Reactions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top Reactions by Role</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.reactor_role ?? i)} />
      </section>
    </main>
  );
}
