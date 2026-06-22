import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [memosRes, reactionsRes, summaryRes, breakdownRes] = await Promise.all([
    sb.rpc('founder_1400_list_memos_r2230'),
    sb.rpc('founder_1400_list_reactions_r2230'),
    sb.rpc('founder_1400_summary_r2230'),
    sb.rpc('founder_1400_sentiment_breakdown_r2230'),
  ]);

  const memos = (memosRes.data ?? []) as any[];
  const reactions = (reactionsRes.data ?? []) as any[];
  const summary = ((summaryRes.data ?? [])[0] ?? {}) as any;
  const breakdown = (breakdownRes.data ?? []) as any[];

  const memoCols: Column<any>[] = [
    { key: 'memo_title', header: 'Memo Title', render: (r: any) => String(r.memo_title ?? '') },
    { key: 'ship_count_at_memo', header: 'Ships', render: (r: any) => String(r.ship_count_at_memo ?? '') },
    { key: 'milestone_date', header: 'Milestone Date', render: (r: any) => String(r.milestone_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'reaction_count', header: 'Reactions', render: (r: any) => String(r.reaction_count ?? 0) },
    { key: 'published_at', header: 'Published', render: (r: any) => String(r.published_at ?? '—') },
  ];

  const reactionCols: Column<any>[] = [
    { key: 'memo_title', header: 'Memo', render: (r: any) => String(r.memo_title ?? '') },
    { key: 'reactor_name', header: 'Reactor', render: (r: any) => String(r.reactor_name ?? '') },
    { key: 'reactor_type', header: 'Type', render: (r: any) => String(r.reactor_type ?? '') },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => String(r.sentiment ?? '') },
    { key: 'reaction_text', header: 'Reaction', render: (r: any) => String(r.reaction_text ?? '').slice(0, 140) },
    { key: 'shared_publicly', header: 'Public', render: (r: any) => (r.shared_publicly ? 'yes' : 'no') },
    { key: 'received_at', header: 'Received', render: (r: any) => String(r.received_at ?? '') },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'reactor_type', header: 'Reactor Type', render: (r: any) => String(r.reactor_type ?? '') },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count ?? 0) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => String(r.positive_count ?? 0) },
    { key: 'neutral_count', header: 'Neutral', render: (r: any) => String(r.neutral_count ?? 0) },
    { key: 'negative_count', header: 'Negative', render: (r: any) => String(r.negative_count ?? 0) },
    { key: 'mixed_count', header: 'Mixed', render: (r: any) => String(r.mixed_count ?? 0) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Founder 1400 SHIPS Milestone Memo
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track founder reflection at 1400 ships — lessons, next-phase plan & reaction log
        from team &gt; investors &gt; customers.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Total Memos</div>
          <div style={{ fontSize: 24, fontWeight: 600 }}>{String(summary.total_memos ?? 0)}</div>
          <div style={{ fontSize: 12, color: '#666', marginTop: 4 }}>
            {String(summary.published_memos ?? 0)} published · {String(summary.draft_memos ?? 0)} draft
          </div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Total Reactions</div>
          <div style={{ fontSize: 24, fontWeight: 600 }}>{String(summary.total_reactions ?? 0)}</div>
          <div style={{ fontSize: 12, color: '#666', marginTop: 4 }}>
            {String(summary.positive_reactions ?? 0)} positive & {String(summary.negative_reactions ?? 0)} negative
          </div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#888' }}>Audience Mix</div>
          <div style={{ fontSize: 14, marginTop: 4 }}>
            Team: {String(summary.team_reactions ?? 0)}
          </div>
          <div style={{ fontSize: 14 }}>
            Investor: {String(summary.investor_reactions ?? 0)}
          </div>
          <div style={{ fontSize: 14 }}>
            Customer: {String(summary.customer_reactions ?? 0)}
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Memos</h2>
        <DataTable
          rows={memos}
          columns={memoCols}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Reactions Log</h2>
        <DataTable
          rows={reactions}
          columns={reactionCols}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Sentiment Breakdown</h2>
        <DataTable
          rows={breakdown}
          columns={breakdownCols}
          rowKey={(_, i) => String(i)}
        />
      </section>
    </main>
  );
}
