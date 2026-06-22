import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Founder180BatchReflectionPage() {
  const sb = await getSupabaseServerClient();

  const [reflectionsRes, recentReactionsRes, takeawaysRes] = await Promise.all([
    sb.rpc('list_reflections_r2018'),
    sb.rpc('recent_reactions_r2018'),
    sb.rpc('top_takeaways_r2018'),
  ]);

  const reflections: any[] = Array.isArray(reflectionsRes.data) ? reflectionsRes.data : [];
  const recentReactions: any[] = Array.isArray(recentReactionsRes.data) ? recentReactionsRes.data : [];
  const takeaways: any[] = Array.isArray(takeawaysRes.data) ? takeawaysRes.data : [];

  const reflectionCols: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => String(r.milestone_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'written_at', header: 'Written', render: (r: any) => r.written_at ? new Date(r.written_at).toLocaleString() : '' },
    { key: 'reflection_md', header: 'Reflection', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.reflection_md ?? '').slice(0, 240)}</span> },
    { key: 'top_wins_md', header: 'Top Wins', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.top_wins_md ?? '').slice(0, 200)}</span> },
    { key: 'top_misses_md', header: 'Top Misses', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.top_misses_md ?? '').slice(0, 200)}</span> },
    { key: 'founder_takeaways_md', header: 'Founder Takeaways', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.founder_takeaways_md ?? '').slice(0, 200)}</span> },
  ];

  const reactionCols: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => String(r.milestone_label ?? '') },
    { key: 'reactor_email', header: 'Reactor', render: (r: any) => String(r.reactor_email ?? '') },
    { key: 'reactor_role', header: 'Role', render: (r: any) => String(r.reactor_role ?? '') },
    { key: 'reaction_md', header: 'Reaction', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.reaction_md ?? '').slice(0, 240)}</span> },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
  ];

  const takeawayCols: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => String(r.milestone_label ?? '') },
    { key: 'founder_takeaways_md', header: 'Takeaways', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.founder_takeaways_md ?? '')}</span> },
    { key: 'written_at', header: 'Written', render: (r: any) => r.written_at ? new Date(r.written_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, marginBottom: 8 }}>Founder 1200-Ship 180-Batch Reflection</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Milestone retrospective log capturing wins, misses, and founder takeaways at every 180-batch wall mark.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Reflections</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>All milestone reflections, newest first.</p>
        <DataTable rows={reflections} columns={reflectionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Top Founder Takeaways</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>Published takeaways, most recent 20.</p>
        <DataTable rows={takeaways} columns={takeawayCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 8 }}>Recent Reactions</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>Latest 50 reactions across team, investors, customers, and external observers.</p>
        <DataTable rows={recentReactions} columns={reactionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
