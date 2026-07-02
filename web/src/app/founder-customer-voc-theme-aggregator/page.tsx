import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [overviewRes, channelsRes, alertsRes, areasRes, actionableRes, themesRes] = await Promise.all([
    sb.rpc('fn_voc_overview_r2280'),
    sb.rpc('fn_voc_channel_breakdown_r2280'),
    sb.rpc('fn_voc_theme_alerts_r2280'),
    sb.rpc('fn_voc_product_area_sentiment_r2280'),
    sb.rpc('fn_voc_recent_actionable_r2280'),
    sb.rpc('fn_voc_top_recurring_themes_r2280'),
  ]);

  const overview = (overviewRes.data ?? [])[0] ?? {
    total_items_30d: 0,
    critical_items_30d: 0,
    open_alerts: 0,
    code_red_alerts: 0,
    avg_sentiment_30d: 0,
    unique_themes_30d: 0,
    actionable_pending: 0,
  };

  const channels = channelsRes.data ?? [];
  const alerts = alertsRes.data ?? [];
  const areas = areasRes.data ?? [];
  const actionable = actionableRes.data ?? [];
  const themes = themesRes.data ?? [];

  const channelCols: Column<any>[] = [
    { key: 'source_channel', header: 'Channel', render: (r) => String(r.source_channel).replace(/_/g, ' ') },
    { key: 'item_count', header: 'Items (30d)', render: (r) => r.item_count },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
    { key: 'avg_sentiment', header: 'Avg sentiment', render: (r) => (r.avg_sentiment ?? 0).toFixed(2) },
    { key: 'last_captured_at', header: 'Last seen', render: (r) => r.last_captured_at ? new Date(r.last_captured_at).toLocaleString() : '—' },
  ];

  const alertCols: Column<any>[] = [
    { key: 'theme_label', header: 'Theme', render: (r) => r.theme_label },
    { key: 'product_area', header: 'Area', render: (r) => r.product_area ?? '—' },
    { key: 'alert_severity', header: 'Severity', render: (r) => (
      <span className={
        r.alert_severity === 'code_red' ? 'text-red-700 font-bold' :
        r.alert_severity === 'urgent' ? 'text-orange-700 font-semibold' :
        r.alert_severity === 'warning' ? 'text-yellow-700' :
        'text-slate-600'
      }>{r.alert_severity}</span>
    ) },
    { key: 'mention_count_7d', header: '7d', render: (r) => r.mention_count_7d },
    { key: 'mention_count_30d', header: '30d', render: (r) => r.mention_count_30d },
    { key: 'spike_ratio', header: 'Spike', render: (r) => `${Number(r.spike_ratio ?? 1).toFixed(2)}x` },
    { key: 'avg_sentiment', header: 'Sentiment', render: (r) => (r.avg_sentiment ?? 0).toFixed(2) },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'last_seen_at', header: 'Last seen', render: (r) => r.last_seen_at ? new Date(r.last_seen_at).toLocaleDateString() : '—' },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const areaCols: Column<any>[] = [
    { key: 'product_area', header: 'Product area', render: (r) => String(r.product_area).replace(/_/g, ' ') },
    { key: 'item_count', header: 'Items', render: (r) => r.item_count },
    { key: 'avg_sentiment', header: 'Avg sentiment', render: (r) => (
      <span className={
        Number(r.avg_sentiment) < -0.5 ? 'text-red-700 font-semibold' :
        Number(r.avg_sentiment) < 0 ? 'text-orange-700' :
        'text-emerald-700'
      }>{(r.avg_sentiment ?? 0).toFixed(2)}</span>
    ) },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
    { key: 'actionable_count', header: 'Actionable', render: (r) => r.actionable_count },
  ];

  const actionableCols: Column<any>[] = [
    { key: 'urgency_level', header: 'Urgency', render: (r) => (
      <span className={
        r.urgency_level === 'critical' ? 'text-red-700 font-bold' :
        r.urgency_level === 'high' ? 'text-orange-700 font-semibold' :
        'text-slate-600'
      }>{r.urgency_level}</span>
    ) },
    { key: 'source_channel', header: 'Channel', render: (r) => String(r.source_channel).replace(/_/g, ' ') },
    { key: 'reporter_role', header: 'Role', render: (r) => r.reporter_role ?? '—' },
    { key: 'raw_text', header: 'Verbatim', render: (r) => (
      <span className="text-sm text-slate-700">{r.raw_text}</span>
    ) },
    { key: 'product_area', header: 'Area', render: (r) => r.product_area ?? '—' },
    { key: 'sentiment_score', header: 'Sentiment', render: (r) => (r.sentiment_score ?? 0).toFixed(2) },
    { key: 'captured_at', header: 'Captured', render: (r) => new Date(r.captured_at).toLocaleDateString() },
  ];

  const themeCols: Column<any>[] = [
    { key: 'theme', header: 'Theme', render: (r) => r.theme },
    { key: 'mention_count', header: 'Mentions', render: (r) => r.mention_count },
    { key: 'avg_sentiment', header: 'Avg sentiment', render: (r) => (r.avg_sentiment ?? 0).toFixed(2) },
    { key: 'channels_seen', header: 'Channels', render: (r) => Array.isArray(r.channels_seen) ? r.channels_seen.length : 0 },
    { key: 'last_seen', header: 'Last seen', render: (r) => r.last_seen ? new Date(r.last_seen).toLocaleDateString() : '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold text-slate-900">Customer Voice-of-Customer Aggregator</h1>
        <p className="text-sm text-slate-600">
          Cross-channel complaint & feedback intake, theme clustering, recurring-issue alerts
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-slate-500">Items (30d)</div>
          <div className="text-2xl font-bold text-slate-900">{overview.total_items_30d}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-slate-500">Critical items (30d)</div>
          <div className="text-2xl font-bold text-red-700">{overview.critical_items_30d}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-slate-500">Open theme alerts</div>
          <div className="text-2xl font-bold text-orange-700">{overview.open_alerts}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-slate-500">Code-red alerts</div>
          <div className="text-2xl font-bold text-red-700">{overview.code_red_alerts}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-slate-500">Avg sentiment (30d)</div>
          <div className="text-2xl font-bold text-slate-900">{Number(overview.avg_sentiment_30d ?? 0).toFixed(2)}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-slate-500">Unique themes (30d)</div>
          <div className="text-2xl font-bold text-slate-900">{overview.unique_themes_30d}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-slate-500">Actionable pending</div>
          <div className="text-2xl font-bold text-orange-700">{overview.actionable_pending}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">Recurring-issue alerts</h2>
        <p className="text-xs text-slate-500">
          Themes flagged when 7-day mention count spikes &gt;= 2x baseline
        </p>
        <DataTable columns={alertCols} rows={alerts} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">Top recurring themes (30d)</h2>
        <DataTable columns={themeCols} rows={themes} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">Product-area sentiment</h2>
        <DataTable columns={areaCols} rows={areas} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">Channel breakdown (30d)</h2>
        <DataTable columns={channelCols} rows={channels} rowKey={(_, i) => String(i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">Untriaged actionable verbatims</h2>
        <DataTable columns={actionableCols} rows={actionable} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}