import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

async function callRpc(sb: any, name: string): Promise<any[]> {
  try {
    const { data, error } = await sb.rpc(name);
    if (error) return [];
    return Array.isArray(data) ? data : (data ? [data] : []);
  } catch {
    return [];
  }
}

function fmtNum(v: any): string {
  if (v === null || v === undefined) return '—';
  const n = Number(v);
  if (!Number.isFinite(n)) return String(v);
  return n.toLocaleString('en-IN');
}

function fmtDate(v: any): string {
  if (!v) return '—';
  try { return new Date(v).toLocaleString('en-IN'); } catch { return String(v); }
}

export default async function FounderContentCalendarV2Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [summaryRows, upcoming, reviewQueue, channels, authors, published, events] = await Promise.all([
    callRpc(sb, 'rpc_fccv2_pipeline_summary'),
    callRpc(sb, 'rpc_fccv2_upcoming_schedule'),
    callRpc(sb, 'rpc_fccv2_review_queue'),
    callRpc(sb, 'rpc_fccv2_channel_breakdown'),
    callRpc(sb, 'rpc_fccv2_author_leaderboard'),
    callRpc(sb, 'rpc_fccv2_recently_published'),
    callRpc(sb, 'rpc_fccv2_recent_events'),
  ]);

  const s: any = summaryRows[0] ?? {};

  const kpis: Kpi[] = [
    { label: 'Total pieces', value: fmtNum(s.total_pieces) },
    { label: 'Draft', value: fmtNum(s.draft_n) },
    { label: 'In review', value: fmtNum(s.in_review_n) },
    { label: 'Scheduled', value: fmtNum(s.scheduled_n) },
    { label: 'Published', value: fmtNum(s.published_n) },
    { label: 'Spiked', value: fmtNum(s.spiked_n) },
    { label: 'Pending review', value: fmtNum(s.pending_review_n) },
    { label: 'Approved', value: fmtNum(s.approved_n) },
    { label: 'Changes requested', value: fmtNum(s.changes_requested_n) },
    { label: 'Rejected', value: fmtNum(s.rejected_n) },
    { label: 'Predicted reach', value: fmtNum(s.total_reach_predicted) },
    { label: 'Actual reach', value: fmtNum(s.total_reach_actual) },
    { label: 'Scheduled next 7d', value: fmtNum(s.scheduled_next_7d) },
    { label: 'Scheduled next 30d', value: fmtNum(s.scheduled_next_30d) },
    { label: 'Published last 30d', value: fmtNum(s.published_last_30d) },
    { label: 'Active authors', value: fmtNum(s.authors_active) },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'scheduled_for', header: 'When', render: (r: any) => fmtDate(r.scheduled_for) },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
    { key: 'topic', header: 'Topic', render: (r: any) => r.topic ?? '—' },
    { key: 'headline', header: 'Headline', render: (r: any) => r.headline ?? '—' },
    { key: 'author_email', header: 'Author', render: (r: any) => r.author_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'reach_predicted_n', header: 'Predicted reach', render: (r: any) => fmtNum(r.reach_predicted_n) },
    { key: 'review_state', header: 'Review', render: (r: any) => r.review_state ?? '—' },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'headline', header: 'Headline', render: (r: any) => r.headline ?? '—' },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
    { key: 'topic', header: 'Topic', render: (r: any) => r.topic ?? '—' },
    { key: 'author_email', header: 'Author', render: (r: any) => r.author_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'review_state', header: 'Review state', render: (r: any) => r.review_state ?? '—' },
    { key: 'reach_predicted_n', header: 'Predicted reach', render: (r: any) => fmtNum(r.reach_predicted_n) },
    { key: 'hours_in_queue', header: 'Hours in queue', render: (r: any) => fmtNum(r.hours_in_queue) },
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  const channelCols: Column<any>[] = [
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
    { key: 'total', header: 'Total', render: (r: any) => fmtNum(r.total) },
    { key: 'drafts', header: 'Drafts', render: (r: any) => fmtNum(r.drafts) },
    { key: 'scheduled', header: 'Scheduled', render: (r: any) => fmtNum(r.scheduled) },
    { key: 'published', header: 'Published', render: (r: any) => fmtNum(r.published) },
    { key: 'avg_predicted_reach', header: 'Avg predicted', render: (r: any) => fmtNum(r.avg_predicted_reach) },
    { key: 'total_actual_reach', header: 'Actual reach', render: (r: any) => fmtNum(r.total_actual_reach) },
    { key: 'pending_review', header: 'Pending review', render: (r: any) => fmtNum(r.pending_review) },
  ];

  const authorCols: Column<any>[] = [
    { key: 'author_email', header: 'Author', render: (r: any) => r.author_email ?? '—' },
    { key: 'pieces_total', header: 'Pieces', render: (r: any) => fmtNum(r.pieces_total) },
    { key: 'pieces_published', header: 'Published', render: (r: any) => fmtNum(r.pieces_published) },
    { key: 'pieces_pending', header: 'Pending', render: (r: any) => fmtNum(r.pieces_pending) },
    { key: 'total_predicted_reach', header: 'Predicted reach', render: (r: any) => fmtNum(r.total_predicted_reach) },
    { key: 'total_actual_reach', header: 'Actual reach', render: (r: any) => fmtNum(r.total_actual_reach) },
    { key: 'approval_rate_pct', header: 'Approval %', render: (r: any) => fmtNum(r.approval_rate_pct) },
  ];

  const publishedCols: Column<any>[] = [
    { key: 'published_at', header: 'Published', render: (r: any) => fmtDate(r.published_at) },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
    { key: 'topic', header: 'Topic', render: (r: any) => r.topic ?? '—' },
    { key: 'headline', header: 'Headline', render: (r: any) => r.headline ?? '—' },
    { key: 'author_email', header: 'Author', render: (r: any) => r.author_email ?? '—' },
    { key: 'reach_predicted_n', header: 'Predicted', render: (r: any) => fmtNum(r.reach_predicted_n) },
    { key: 'reach_actual_n', header: 'Actual', render: (r: any) => fmtNum(r.reach_actual_n) },
    { key: 'delta_pct', header: 'Delta %', render: (r: any) => fmtNum(r.delta_pct) },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Founder Content Calendar v2</h1>
        <p style={{ color: '#666' }}>Plan content across LinkedIn, blog, newsletter. Track status, review queue, and reach prediction vs actual.</p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 12 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
            <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Upcoming schedule</h2>
        <DataTable rows={upcoming} columns={upcomingCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Review queue</h2>
        <DataTable rows={reviewQueue} columns={reviewCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Channel breakdown</h2>
        <DataTable rows={channels} columns={channelCols} rowKey={(r: any) => r.channel} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Author leaderboard</h2>
        <DataTable rows={authors} columns={authorCols} rowKey={(r: any) => r.author_email} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recently published</h2>
        <DataTable rows={published} columns={publishedCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent events</h2>
        <ul style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {events.length === 0 ? (
            <li style={{ color: '#666' }}>No recent events.</li>
          ) : (
            events.map((e: any) => (
              <li key={e.id} style={{ border: '1px solid #e5e7eb', borderRadius: 6, padding: 10 }}>
                <div style={{ fontSize: 12, color: '#666' }}>{fmtDate(e.occurred_at)} · {e.actor_email ?? '—'}</div>
                <div style={{ fontWeight: 600 }}>{e.event_type ?? '—'} · {e.channel ?? '—'}</div>
                <div>{e.headline ?? '—'}</div>
              </li>
            ))
          )}
        </ul>
      </section>
    </main>
  );
}
