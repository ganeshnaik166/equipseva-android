import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [retros, recent, top] = await Promise.all([
    sb.rpc('list_retros_r2058'),
    sb.rpc('recent_reactions_r2058'),
    sb.rpc('top_reactions_r2058'),
  ]);

  const retroRows: any[] = Array.isArray(retros.data) ? retros.data : [];
  const recentRows: any[] = Array.isArray(recent.data) ? recent.data : [];
  const topRows: any[] = Array.isArray(top.data) ? top.data : [];

  const retroCols: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => String(r.milestone_label ?? '') },
    { key: 'written_at', header: 'Written', render: (r: any) => r.written_at ? new Date(r.written_at).toLocaleString() : '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'reaction_count', header: 'Reactions', render: (r: any) => String(r.reaction_count ?? 0) },
    { key: 'summary_md', header: 'Summary', render: (r: any) => String(r.summary_md ?? '').slice(0, 120) },
    { key: 'what_kept_working_md', header: 'Kept Working', render: (r: any) => String(r.what_kept_working_md ?? '').slice(0, 120) },
    { key: 'what_quit_md', header: 'Quit', render: (r: any) => String(r.what_quit_md ?? '').slice(0, 120) },
    { key: 'founder_outlook_md', header: 'Outlook', render: (r: any) => String(r.founder_outlook_md ?? '').slice(0, 120) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => String(r.milestone_label ?? '') },
    { key: 'reactor_email', header: 'Reactor', render: (r: any) => String(r.reactor_email ?? '') },
    { key: 'reactor_role', header: 'Role', render: (r: any) => String(r.reactor_role ?? '') },
    { key: 'reaction_md', header: 'Reaction', render: (r: any) => String(r.reaction_md ?? '').slice(0, 200) },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => String(r.milestone_label ?? '') },
    { key: 'reactor_role', header: 'Role', render: (r: any) => String(r.reactor_role ?? '') },
    { key: 'reaction_count', header: 'Count', render: (r: any) => String(r.reaction_count ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder 190-Batch Retrospective</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Milestone retrospectives across the founder console journey. Captures what kept working, what got quit, and the founder outlook plus reactions from team, investors, customers, and external observers.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Retrospectives</h2>
        <DataTable rows={retroRows} columns={retroCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Reactions</h2>
        <DataTable rows={recentRows} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Reactions by Role</h2>
        <DataTable rows={topRows} columns={topCols} rowKey={(r: any, i: number) => String(r.retrospective_id ?? '') + '-' + String(r.reactor_role ?? '') + '-' + String(i)} />
      </section>
    </main>
  );
}
