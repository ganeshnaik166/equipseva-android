import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInternalVlogPage() {
  const sb = await getSupabaseServerClient();

  const [vlogsRes, summaryRes, reactorsRes, reactionsRes] = await Promise.all([
    sb.rpc('list_vlogs_r1866'),
    sb.rpc('weekly_summary_r1866'),
    sb.rpc('top_engaged_reactors_r1866'),
    sb.rpc('list_reactions_r1866', { p_vlog_id: null }),
  ]);

  const vlogs: any[] = Array.isArray(vlogsRes.data) ? vlogsRes.data : [];
  const summary: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];
  const reactors: any[] = Array.isArray(reactorsRes.data) ? reactorsRes.data : [];
  const reactions: any[] = Array.isArray(reactionsRes.data) ? reactionsRes.data : [];

  const error =
    vlogsRes.error?.message ||
    summaryRes.error?.message ||
    reactorsRes.error?.message ||
    reactionsRes.error?.message ||
    null;

  const totalVlogs = vlogs.length;
  const publishedCount = vlogs.filter((v) => v.status === 'published').length;
  const draftCount = vlogs.filter((v) => v.status === 'draft').length;
  const totalReactions = reactions.length;

  const vlogColumns: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '—') },
    { key: 'audience', header: 'Audience', render: (r: any) => String(r.audience ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    {
      key: 'published_at',
      header: 'Published',
      render: (r: any) => (r.published_at ? new Date(r.published_at).toLocaleString() : '—'),
    },
    { key: 'view_count', header: 'Views', render: (r: any) => String(r.view_count ?? 0) },
    { key: 'reaction_count', header: 'Reactions', render: (r: any) => String(r.reaction_count ?? 0) },
    { key: 'has_video', header: 'Video', render: (r: any) => (r.has_video ? 'Yes' : 'No') },
  ];

  const summaryColumns: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '—') },
    { key: 'total_vlogs', header: 'Total', render: (r: any) => String(r.total_vlogs ?? 0) },
    { key: 'published_count', header: 'Published', render: (r: any) => String(r.published_count ?? 0) },
    { key: 'draft_count', header: 'Drafts', render: (r: any) => String(r.draft_count ?? 0) },
    { key: 'total_reactions', header: 'Reactions', render: (r: any) => String(r.total_reactions ?? 0) },
    { key: 'total_views', header: 'Views', render: (r: any) => String(r.total_views ?? 0) },
  ];

  const reactorColumns: Column<any>[] = [
    { key: 'reactor_email', header: 'Reactor', render: (r: any) => String(r.reactor_email ?? '—') },
    { key: 'reaction_count', header: 'Total', render: (r: any) => String(r.reaction_count ?? 0) },
    { key: 'appreciate_count', header: 'Appreciate', render: (r: any) => String(r.appreciate_count ?? 0) },
    { key: 'question_count', header: 'Questions', render: (r: any) => String(r.question_count ?? 0) },
    { key: 'clarify_count', header: 'Clarify', render: (r: any) => String(r.clarify_count ?? 0) },
    { key: 'concern_count', header: 'Concerns', render: (r: any) => String(r.concern_count ?? 0) },
    {
      key: 'last_reacted_at',
      header: 'Last',
      render: (r: any) => (r.last_reacted_at ? new Date(r.last_reacted_at).toLocaleString() : '—'),
    },
  ];

  const reactionColumns: Column<any>[] = [
    {
      key: 'reacted_at',
      header: 'When',
      render: (r: any) => (r.reacted_at ? new Date(r.reacted_at).toLocaleString() : '—'),
    },
    { key: 'reactor_email', header: 'Reactor', render: (r: any) => String(r.reactor_email ?? '—') },
    { key: 'reaction', header: 'Type', render: (r: any) => String(r.reaction ?? '—') },
    {
      key: 'reaction_md',
      header: 'Note',
      render: (r: any) => {
        const t = String(r.reaction_md ?? '');
        return t.length > 120 ? t.slice(0, 117) + '...' : t || '—';
      },
    },
    { key: 'vlog_id', header: 'Vlog', render: (r: any) => String(r.vlog_id ?? '—').slice(0, 8) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder Internal Vlog</h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Weekly written &amp; video updates to the team (Bezos-style memo &gt; meeting).
        </p>
      </header>

      {error ? (
        <div
          style={{
            background: '#fee',
            border: '1px solid #fcc',
            padding: 12,
            borderRadius: 6,
            marginBottom: 24,
            color: '#900',
          }}
        >
          Error: {error}
        </div>
      ) : null}

      <section style={{ marginBottom: 32 }}>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: 12,
          }}
        >
          <div style={{ background: '#f5f5f5', padding: 16, borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Vlogs</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalVlogs}</div>
          </div>
          <div style={{ background: '#f5f5f5', padding: 16, borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Published</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{publishedCount}</div>
          </div>
          <div style={{ background: '#f5f5f5', padding: 16, borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Drafts</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{draftCount}</div>
          </div>
          <div style={{ background: '#f5f5f5', padding: 16, borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Reactions</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalReactions}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Vlogs</h2>
        <DataTable
          rows={vlogs}
          columns={vlogColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Weekly Summary</h2>
        <DataTable
          rows={summary}
          columns={summaryColumns}
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Engaged Reactors</h2>
        <DataTable
          rows={reactors}
          columns={reactorColumns}
          rowKey={(r: any, i: number) => String(r.reactor_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Reactions</h2>
        <DataTable
          rows={reactions}
          columns={reactionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
