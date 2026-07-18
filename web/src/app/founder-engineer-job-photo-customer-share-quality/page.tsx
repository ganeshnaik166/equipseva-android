import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [sharesRes, engagementRes, topHospitalsRes, channelRes, privacyRes, positiveRes, trendRes] = await Promise.all([
    sb.rpc('list_shares_r2510'),
    sb.rpc('list_engagement_log_r2510'),
    sb.rpc('top_engaged_hospitals_r2510'),
    sb.rpc('channel_breakdown_r2510'),
    sb.rpc('privacy_focus_r2510'),
    sb.rpc('top_positive_feedback_r2510'),
    sb.rpc('weekly_share_trend_r2510'),
  ]);

  const shares: any[] = (sharesRes.data ?? []) as any[];
  const engagement: any[] = (engagementRes.data ?? []) as any[];
  const topHospitals: any[] = (topHospitalsRes.data ?? []) as any[];
  const channels: any[] = (channelRes.data ?? []) as any[];
  const privacy: any[] = (privacyRes.data ?? []) as any[];
  const positives: any[] = (positiveRes.data ?? []) as any[];
  const trend: any[] = (trendRes.data ?? []) as any[];

  const totalShares = shares.length;
  const totalPhotos = shares.reduce((a, r) => a + (Number(r.photo_count) || 0), 0);
  const totalViews = shares.reduce((a, r) => a + (Number(r.view_count) || 0), 0);
  const positiveCount = shares.filter((r) => r.customer_feedback === 'positive').length;
  const privacyOkCount = shares.filter((r) => r.privacy_signoff_ok).length;

  const sharesCols: Column<any>[] = [
    { key: 'shared_at', header: 'Shared', render: (r: any) => new Date(r.shared_at).toLocaleDateString() },
    { key: 'hospital', header: 'Hospital owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'channel', header: 'Channel', render: (r: any) => r.share_channel },
    { key: 'photos', header: 'Photos', render: (r: any) => String(r.photo_count) },
    { key: 'views', header: 'Views', render: (r: any) => String(r.view_count) },
    { key: 'feedback', header: 'Feedback', render: (r: any) => r.customer_feedback },
    { key: 'privacy', header: 'Privacy OK', render: (r: any) => (r.privacy_signoff_ok ? 'yes' : 'no') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'quote', header: 'Quote', render: (r: any) => r.customer_quote_text ?? '—' },
  ];

  const engagementCols: Column<any>[] = [
    { key: 'viewed_at', header: 'Viewed', render: (r: any) => new Date(r.viewed_at).toLocaleString() },
    { key: 'viewer', header: 'Viewer', render: (r: any) => r.viewer_email ?? '—' },
    { key: 'channel', header: 'Channel', render: (r: any) => r.share_channel },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'action', header: 'Action', render: (r: any) => r.action_taken },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topHospitalsCols: Column<any>[] = [
    { key: 'owner', header: 'Hospital owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'shares', header: 'Shares', render: (r: any) => String(r.shares_count) },
    { key: 'views', header: 'Total views', render: (r: any) => String(r.total_views) },
    { key: 'actions', header: 'Actions taken', render: (r: any) => String(r.total_actions) },
    { key: 'positive', header: 'Positive', render: (r: any) => String(r.positive_count) },
  ];

  const channelCols: Column<any>[] = [
    { key: 'channel', header: 'Channel', render: (r: any) => r.share_channel },
    { key: 'shares', header: 'Shares', render: (r: any) => String(r.shares_count) },
    { key: 'photos', header: 'Photos', render: (r: any) => String(r.total_photos) },
    { key: 'views', header: 'Views', render: (r: any) => String(r.total_views) },
    { key: 'avg', header: 'Avg views/share', render: (r: any) => String(r.avg_views_per_share) },
  ];

  const privacyCols: Column<any>[] = [
    { key: 'status', header: 'Privacy status', render: (r: any) => r.privacy_status },
    { key: 'shares', header: 'Shares', render: (r: any) => String(r.shares_count) },
    { key: 'photos', header: 'Photos', render: (r: any) => String(r.total_photos) },
    { key: 'pct', header: 'Pct of total', render: (r: any) => `${r.pct_of_total}%` },
  ];

  const positiveCols: Column<any>[] = [
    { key: 'shared_at', header: 'Shared', render: (r: any) => new Date(r.shared_at).toLocaleDateString() },
    { key: 'owner', header: 'Hospital', render: (r: any) => r.owner_email ?? '—' },
    { key: 'channel', header: 'Channel', render: (r: any) => r.share_channel },
    { key: 'views', header: 'Views', render: (r: any) => String(r.view_count) },
    { key: 'quote', header: 'Quote', render: (r: any) => r.customer_quote_text ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week', header: 'Week', render: (r: any) => r.week_label },
    { key: 'shares', header: 'Shares', render: (r: any) => String(r.shares_count) },
    { key: 'photos', header: 'Photos', render: (r: any) => String(r.total_photos) },
    { key: 'views', header: 'Views', render: (r: any) => String(r.total_views) },
    { key: 'positive', header: 'Positive', render: (r: any) => String(r.positive_count) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Job Photo Customer Share Quality</h1>
        <p className="text-sm text-gray-500">r2510 · photos shared with customers &gt; channel &gt; views &gt; feedback &gt; privacy</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total shares</div>
          <div className="text-2xl font-semibold">{totalShares}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total photos</div>
          <div className="text-2xl font-semibold">{totalPhotos}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total views</div>
          <div className="text-2xl font-semibold text-blue-600">{totalViews}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Positive feedback</div>
          <div className="text-2xl font-semibold text-green-600">{positiveCount}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Privacy OK</div>
          <div className="text-2xl font-semibold">{privacyOkCount}/{totalShares}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All shares</h2>
        <DataTable rows={shares} columns={sharesCols} emptyMessage="No shares yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top engaged hospitals</h2>
        <DataTable rows={topHospitals} columns={topHospitalsCols} emptyMessage="No hospital engagement yet" rowKey={(r: any, i: number) => String(r.owner_email ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Channel breakdown</h2>
        <DataTable rows={channels} columns={channelCols} emptyMessage="No channels yet" rowKey={(r: any, i: number) => String(r.share_channel ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Privacy focus</h2>
        <DataTable rows={privacy} columns={privacyCols} emptyMessage="No privacy data yet" rowKey={(r: any, i: number) => String(r.privacy_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top positive feedback</h2>
        <DataTable rows={positives} columns={positiveCols} emptyMessage="No positive feedback yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly share trend</h2>
        <DataTable rows={trend} columns={trendCols} emptyMessage="No trend data yet" rowKey={(r: any, i: number) => String(r.week_label ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engagement log</h2>
        <DataTable rows={engagement} columns={engagementCols} emptyMessage="No engagement events" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
