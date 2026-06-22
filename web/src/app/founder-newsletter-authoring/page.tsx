import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderNewsletterAuthoringPage() {
  const sb = await getSupabaseServerClient();

  const [draftsRes, queueRes, engagementRes, recentRes] = await Promise.all([
    sb.rpc('list_drafts_r1950'),
    sb.rpc('scheduled_or_sending_r1950'),
    sb.rpc('list_engagement_r1950', { p_draft_id: null }),
    sb.rpc('recent_engagement_r1950', { p_days: 30 }),
  ]);

  const drafts: any[] = (draftsRes.data as any[]) || [];
  const queue: any[] = (queueRes.data as any[]) || [];
  const engagement: any[] = (engagementRes.data as any[]) || [];
  const recent: any[] = (recentRes.data as any[]) || [];

  const totalDrafts = drafts.length;
  const sentCount = drafts.filter((d) => d.send_status === 'sent').length;
  const scheduledCount = drafts.filter((d) => d.send_status === 'scheduled').length;
  const reviewingCount = drafts.filter((d) => d.send_status === 'reviewing').length;
  const totalAudience = drafts.reduce((a, d) => a + Number(d.audience_count || 0), 0);

  const statusBadge = (s: string) => {
    const map: Record<string, string> = {
      draft: 'bg-gray-100 text-gray-700',
      reviewing: 'bg-amber-100 text-amber-800',
      scheduled: 'bg-blue-100 text-blue-800',
      sent: 'bg-green-100 text-green-800',
      cancelled: 'bg-red-100 text-red-700',
    };
    return <span className={`px-2 py-0.5 rounded text-xs font-medium ${map[s] || 'bg-gray-100 text-gray-700'}`}>{s}</span>;
  };

  const draftCols: Column<any>[] = [
    { key: 'edition_label', header: 'Edition', render: (r: any) => <span className="font-medium">{r.edition_label}</span> },
    { key: 'headline', header: 'Headline', render: (r: any) => <span className="text-sm">{r.headline}</span> },
    { key: 'send_status', header: 'Status', render: (r: any) => statusBadge(r.send_status) },
    { key: 'audience_count', header: 'Audience', render: (r: any) => <span className="tabular-nums">{r.audience_count}</span> },
    { key: 'scheduled_for', header: 'Scheduled', render: (r: any) => r.scheduled_for ? new Date(r.scheduled_for).toLocaleString() : '—' },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '—' },
    { key: 'created_at', header: 'Created', render: (r: any) => new Date(r.created_at).toLocaleDateString() },
  ];

  const queueCols: Column<any>[] = [
    { key: 'edition_label', header: 'Edition', render: (r: any) => <span className="font-medium">{r.edition_label}</span> },
    { key: 'headline', header: 'Headline', render: (r: any) => r.headline },
    { key: 'send_status', header: 'Status', render: (r: any) => statusBadge(r.send_status) },
    { key: 'scheduled_for', header: 'Scheduled For', render: (r: any) => r.scheduled_for ? new Date(r.scheduled_for).toLocaleString() : '—' },
    { key: 'audience_count', header: 'Audience', render: (r: any) => <span className="tabular-nums">{r.audience_count}</span> },
  ];

  const engagementCols: Column<any>[] = [
    { key: 'reported_at', header: 'When', render: (r: any) => new Date(r.reported_at).toLocaleString() },
    { key: 'engagement_type', header: 'Type', render: (r: any) => <span className="text-xs px-2 py-0.5 bg-indigo-100 text-indigo-800 rounded">{r.engagement_type}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '—' },
    { key: 'value_metric', header: 'Value', render: (r: any) => r.value_metric != null ? <span className="tabular-nums">{Number(r.value_metric).toFixed(2)}</span> : '—' },
    { key: 'draft_id', header: 'Draft', render: (r: any) => <code className="text-xs">{String(r.draft_id).slice(0, 8)}</code> },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span className="text-xs text-gray-600">{r.notes_md ? String(r.notes_md).slice(0, 80) : '—'}</span> },
  ];

  const recentCols: Column<any>[] = [
    { key: 'engagement_type', header: 'Type', render: (r: any) => <span className="font-medium">{r.engagement_type}</span> },
    { key: 'event_count', header: 'Events', render: (r: any) => <span className="tabular-nums font-semibold">{r.event_count}</span> },
    { key: 'avg_metric', header: 'Avg Metric', render: (r: any) => r.avg_metric != null ? Number(r.avg_metric).toFixed(2) : '—' },
    { key: 'last_reported', header: 'Last Reported', render: (r: any) => r.last_reported ? new Date(r.last_reported).toLocaleString() : '—' },
  ];

  return (
    <div className="max-w-7xl mx-auto p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Newsletter Authoring</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track external newsletter drafts from idea to send. Pipeline shows editions at least once moved beyond draft.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Total Drafts</div>
          <div className="text-2xl font-bold tabular-nums">{totalDrafts}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Sent</div>
          <div className="text-2xl font-bold tabular-nums text-green-700">{sentCount}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Scheduled</div>
          <div className="text-2xl font-bold tabular-nums text-blue-700">{scheduledCount}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Reviewing</div>
          <div className="text-2xl font-bold tabular-nums text-amber-700">{reviewingCount}</div>
        </div>
        <div className="border rounded-lg p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Audience Reach</div>
          <div className="text-2xl font-bold tabular-nums">{totalAudience.toLocaleString()}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Drafts</h2>
        <p className="text-sm text-gray-600 mb-3">
          Most recent first. Audience counts above zero mean the recipient list is locked in.
        </p>
        <DataTable rows={drafts} columns={draftCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Scheduled and In Review</h2>
        <p className="text-sm text-gray-600 mb-3">
          Editions queued to send or awaiting founder sign-off. Sort order: scheduled time ascending.
        </p>
        <DataTable rows={queue} columns={queueCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engagement Log</h2>
        <p className="text-sm text-gray-600 mb-3">
          Reported reactions across all editions. Includes open-rate snapshots, replies, link clicks, unsubscribes and shares.
        </p>
        <DataTable rows={engagement} columns={engagementCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Engagement Rollup (30 days)</h2>
        <p className="text-sm text-gray-600 mb-3">
          Aggregated by engagement type for the last 30 days. Avg metric shown where applicable.
        </p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r, i) => String(r.engagement_type ?? i)} />
      </section>
    </div>
  );
}
