import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-2xl border border-neutral-200 bg-white p-4 shadow-sm">
      <div className="text-xs font-medium uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums text-neutral-900">{value}</div>
    </div>
  );
}

function fmtInt(n: any): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!Number.isFinite(v)) return "—";
  return v.toLocaleString('en-IN');
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!Number.isFinite(v)) return "—";
  return `${v.toFixed(1)}%`;
}

function fmtDate(s: any): string {
  if (!s) return "—";
  try { return new Date(s).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }); }
  catch { return String(s); }
}

function fmtDateTime(s: any): string {
  if (!s) return "—";
  try { return new Date(s).toLocaleString('en-IN', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }); }
  catch { return String(s); }
}

function fmtDuration(sec: any): string {
  if (sec === null || sec === undefined) return "—";
  const s = Number(sec);
  if (!Number.isFinite(s) || s <= 0) return "—";
  const m = Math.floor(s / 60);
  const r = Math.floor(s % 60);
  return `${m}m ${r}s`;
}

function sevPill(sev: string) {
  const map: Record<string, string> = {
    ok: 'bg-emerald-50 text-emerald-700 ring-emerald-200',
    stale: 'bg-amber-50 text-amber-700 ring-amber-200',
    warning: 'bg-orange-50 text-orange-700 ring-orange-200',
    critical: 'bg-rose-50 text-rose-700 ring-rose-200',
  };
  const cls = map[sev] ?? 'bg-neutral-50 text-neutral-700 ring-neutral-200';
  return <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ring-1 ${cls}`}>{sev}</span>;
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpiR, recentR, audR, cadenceR, staleR, topR, eventsR] = await Promise.all([
    supabase.rpc('fwll_kpi_snapshot'),
    supabase.rpc('fwll_recent_videos_30d'),
    supabase.rpc('fwll_audience_breakdown_90d'),
    supabase.rpc('fwll_weekly_cadence_12wk'),
    supabase.rpc('fwll_stale_audience_alerts'),
    supabase.rpc('fwll_top_videos_by_views', { p_limit: 20 }),
    supabase.rpc('fwll_recent_view_events_50'),
  ]);

  const k: any = Array.isArray(kpiR.data) ? (kpiR.data[0] ?? {}) : (kpiR.data ?? {});
  const recent: any[] = Array.isArray(recentR.data) ? recentR.data : [];
  const audience: any[] = Array.isArray(audR.data) ? audR.data : [];
  const cadence: any[] = Array.isArray(cadenceR.data) ? cadenceR.data : [];
  const stale: any[] = Array.isArray(staleR.data) ? staleR.data : [];
  const top: any[] = Array.isArray(topR.data) ? topR.data : [];
  const events: any[] = Array.isArray(eventsR.data) ? eventsR.data : [];

  const recentCols: Column<any>[] = [
    { key: 'iso_week', header: 'Week', render: (r: any) => fmtDate(r.iso_week) },
    { key: 'topic', header: 'Topic', render: (r: any) => <span className="font-medium text-neutral-900">{r.topic ?? "—"}</span> },
    { key: 'audience', header: 'Audience', render: (r: any) => <span className="inline-flex items-center rounded-full bg-indigo-50 px-2 py-0.5 text-xs font-medium text-indigo-700 ring-1 ring-indigo-200">{r.audience ?? "—"}</span> },
    { key: 'duration_seconds', header: 'Duration', render: (r: any) => fmtDuration(r.duration_seconds) },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtDateTime(r.recorded_at) },
    { key: 'view_count', header: 'Views', render: (r: any) => <span className="tabular-nums">{fmtInt(r.view_count)}</span> },
    { key: 'unique_viewers', header: 'Unique', render: (r: any) => <span className="tabular-nums">{fmtInt(r.unique_viewers)}</span> },
    { key: 'completion_rate', header: 'Completion', render: (r: any) => fmtPct(r.completion_rate) },
    { key: 'loom_url', header: 'Link', render: (r: any) => r.loom_url ? <a href={r.loom_url} target="_blank" rel="noreferrer" className="text-indigo-600 underline">open</a> : "—" },
  ];

  const audCols: Column<any>[] = [
    { key: 'audience', header: 'Audience', render: (r: any) => <span className="font-medium text-neutral-900">{r.audience ?? "—"}</span> },
    { key: 'video_count', header: 'Videos', render: (r: any) => fmtInt(r.video_count) },
    { key: 'total_views', header: 'Views', render: (r: any) => fmtInt(r.total_views) },
    { key: 'avg_views_per_video', header: 'Avg Views/Video', render: (r: any) => fmtInt(r.avg_views_per_video) },
    { key: 'avg_completion_rate', header: 'Avg Completion', render: (r: any) => fmtPct(r.avg_completion_rate) },
  ];

  const cadCols: Column<any>[] = [
    { key: 'iso_week', header: 'Week', render: (r: any) => fmtDate(r.iso_week) },
    { key: 'video_count', header: 'Videos', render: (r: any) => fmtInt(r.video_count) },
    { key: 'audiences_covered', header: 'Audiences', render: (r: any) => fmtInt(r.audiences_covered) },
    { key: 'total_views', header: 'Views', render: (r: any) => fmtInt(r.total_views) },
    { key: 'stale', header: 'Status', render: (r: any) => r.stale ? <span className="inline-flex items-center rounded-full bg-rose-50 px-2 py-0.5 text-xs font-medium text-rose-700 ring-1 ring-rose-200">no loom this week</span> : <span className="inline-flex items-center rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-700 ring-1 ring-emerald-200">shipped</span> },
  ];

  const staleCols: Column<any>[] = [
    { key: 'audience', header: 'Audience', render: (r: any) => <span className="font-medium text-neutral-900">{r.audience ?? "—"}</span> },
    { key: 'last_video_at', header: 'Last Video', render: (r: any) => fmtDateTime(r.last_video_at) },
    { key: 'days_since_last', header: 'Days Since', render: (r: any) => <span className="tabular-nums">{fmtInt(r.days_since_last)}</span> },
    { key: 'severity', header: 'Severity', render: (r: any) => sevPill(r.severity ?? 'ok') },
  ];

  const topCols: Column<any>[] = [
    { key: 'topic', header: 'Topic', render: (r: any) => <span className="font-medium text-neutral-900">{r.topic ?? "—"}</span> },
    { key: 'audience', header: 'Audience', render: (r: any) => r.audience ?? "—" },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtDate(r.recorded_at) },
    { key: 'view_count', header: 'Views', render: (r: any) => <span className="tabular-nums font-semibold">{fmtInt(r.view_count)}</span> },
    { key: 'unique_viewers', header: 'Unique', render: (r: any) => fmtInt(r.unique_viewers) },
    { key: 'loom_url', header: 'Link', render: (r: any) => r.loom_url ? <a href={r.loom_url} target="_blank" rel="noreferrer" className="text-indigo-600 underline">open</a> : "—" },
  ];

  const eventCols: Column<any>[] = [
    { key: 'viewed_at', header: 'Viewed', render: (r: any) => fmtDateTime(r.viewed_at) },
    { key: 'topic', header: 'Topic', render: (r: any) => r.topic ?? "—" },
    { key: 'viewer_label', header: 'Viewer', render: (r: any) => <span className="font-medium text-neutral-900">{r.viewer_label ?? "—"}</span> },
    { key: 'viewer_audience', header: 'Audience', render: (r: any) => r.viewer_audience ?? "—" },
    { key: 'watch_seconds', header: 'Watch', render: (r: any) => fmtDuration(r.watch_seconds) },
    { key: 'completed', header: 'Completed', render: (r: any) => r.completed ? <span className="text-emerald-700">yes</span> : <span className="text-neutral-500">no</span> },
    { key: 'source', header: 'Source', render: (r: any) => r.source ?? "—" },
  ];

  const thisWeekShipped = Number(k.videos_this_week ?? 0) > 0;

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight text-neutral-900">Founder Weekly Loom Log</h1>
          <p className="mt-1 text-sm text-neutral-600">Track weekly Loom videos by topic + audience, monitor views, and surface stale-no-loom alerts.</p>
        </div>
        <div>
          {thisWeekShipped
            ? <span className="inline-flex items-center rounded-full bg-emerald-50 px-3 py-1 text-sm font-medium text-emerald-700 ring-1 ring-emerald-200">this week: shipped {fmtInt(k.videos_this_week)}</span>
            : <span className="inline-flex items-center rounded-full bg-rose-50 px-3 py-1 text-sm font-medium text-rose-700 ring-1 ring-rose-200">no loom this week</span>}
        </div>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Kpi label="Total Videos" value={fmtInt(k.total_videos)} />
        <Kpi label="This Week" value={fmtInt(k.videos_this_week)} />
        <Kpi label="Last Week" value={fmtInt(k.videos_last_week)} />
        <Kpi label="Last 30d" value={fmtInt(k.videos_30d)} />
        <Kpi label="Last 90d" value={fmtInt(k.videos_90d)} />
        <Kpi label="Total Views" value={fmtInt(k.total_views)} />
        <Kpi label="Views 30d" value={fmtInt(k.views_30d)} />
        <Kpi label="Unique Viewers 30d" value={fmtInt(k.unique_viewers_30d)} />
        <Kpi label="Avg Duration" value={fmtDuration(k.avg_duration_seconds)} />
        <Kpi label="Avg Completion" value={fmtPct(k.avg_completion_rate)} />
        <Kpi label="Stale Audiences" value={fmtInt(k.stale_audience_count)} />
        <Kpi label="Days Since Last" value={fmtInt(k.days_since_last_video)} />
        <Kpi label="Last Video" value={fmtDate(k.last_video_at)} />
        <Kpi label="Audiences Tracked" value={5} />
        <Kpi label="Cadence Window" value={"12 wk"} />
        <Kpi label="Snapshot" value={fmtDate(new Date().toISOString())} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-neutral-900">Stale-No-Loom Alerts by Audience</h2>
        <DataTable
          columns={staleCols}
          rows={stale}
          rowKey={(r: any) => r.audience}
          emptyMessage="No audiences tracked yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-neutral-900">Weekly Cadence (last 12 weeks)</h2>
        <DataTable
          columns={cadCols}
          rows={cadence}
          rowKey={(r: any) => r.iso_week}
          emptyMessage="No weeks captured yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-neutral-900">Recent Videos (30d)</h2>
        <DataTable
          columns={recentCols}
          rows={recent}
          rowKey={(r: any) => r.id}
          emptyMessage="No Loom videos logged in the last 30 days."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-neutral-900">Audience Breakdown (90d)</h2>
        <DataTable
          columns={audCols}
          rows={audience}
          rowKey={(r: any) => r.audience}
          emptyMessage="No audience data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-neutral-900">Top Videos by Views</h2>
        <DataTable
          columns={topCols}
          rows={top}
          rowKey={(r: any) => r.id}
          emptyMessage="No videos to rank yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold text-neutral-900">Recent View Events</h2>
        <DataTable
          columns={eventCols}
          rows={events}
          rowKey={(r: any) => r.id}
          emptyMessage="No view events captured yet."
        />
      </section>
    </div>
  );
}
