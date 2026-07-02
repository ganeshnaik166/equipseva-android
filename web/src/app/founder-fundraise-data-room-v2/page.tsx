import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import { formatRupees } from '@/lib/format';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: any }) {
  return (
    <div className="rounded-lg border border-slate-200 bg-white p-3">
      <div className="text-xs uppercase tracking-wide text-slate-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-slate-900">{value ?? "—"}</div>
    </div>
  );
}

function fmtSecs(s: any) {
  const n = Number(s ?? 0);
  if (!n) return "0s";
  if (n < 60) return `${n}s`;
  if (n < 3600) return `${Math.round(n / 60)}m`;
  return `${(n / 3600).toFixed(1)}h`;
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpisRes, eventsRes, rankRes, fileRes, trendRes, reaperRes, sessRes] = await Promise.all([
    sb.rpc('founder_dataroom_v2_kpis'),
    sb.rpc('founder_dataroom_v2_recent_events', { p_limit: 50 }),
    sb.rpc('founder_dataroom_v2_investor_ranking', { p_days: 30, p_limit: 25 }),
    sb.rpc('founder_dataroom_v2_file_analytics', { p_days: 30, p_limit: 25 }),
    sb.rpc('founder_dataroom_v2_daily_trend', { p_days: 30 }),
    sb.rpc('founder_dataroom_v2_reaper_recent', { p_limit: 25 }),
    sb.rpc('founder_dataroom_v2_session_summary', { p_days: 14, p_limit: 25 }),
  ]);

  const k: any = kpisRes.data ?? {};
  const events: any[] = eventsRes.data ?? [];
  const ranking: any[] = rankRes.data ?? [];
  const files: any[] = fileRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const reaper: any[] = reaperRes.data ?? [];
  const sessions: any[] = sessRes.data ?? [];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-4 sm:p-6">
      <header>
        <h1 className="text-2xl font-semibold text-slate-900">Fundraise Data Room v2</h1>
        <p className="mt-1 text-sm text-slate-600">File-level granular access logs, per-investor ranking, view-time analytics, expired-link reaper. r1466.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kpi label="Events 30d" value={k.total_events_30d ?? 0} />
        <Kpi label="Events 7d" value={k.total_events_7d ?? 0} />
        <Kpi label="Events 24h" value={k.total_events_24h ?? 0} />
        <Kpi label="Sessions 24h" value={k.sessions_24h ?? 0} />
        <Kpi label="Unique investors 30d" value={k.unique_investors_30d ?? 0} />
        <Kpi label="Unique investors 7d" value={k.unique_investors_7d ?? 0} />
        <Kpi label="Engaged investors 7d" value={k.engaged_investors_7d ?? 0} />
        <Kpi label="Unique files 30d" value={k.unique_files_30d ?? 0} />
        <Kpi label="Views 30d" value={k.view_events_30d ?? 0} />
        <Kpi label="Downloads 30d" value={k.download_events_30d ?? 0} />
        <Kpi label="Total view time 30d" value={fmtSecs(k.total_view_seconds_30d)} />
        <Kpi label="Avg view secs 30d" value={k.avg_view_seconds_30d ?? 0} />
        <Kpi label="P95 view secs 30d" value={k.p95_view_seconds_30d ?? 0} />
        <Kpi label="Links reaped 30d" value={k.links_reaped_30d ?? 0} />
        <Kpi label="Expired reaped 30d" value={k.links_reaped_expired_30d ?? 0} />
        <Kpi label="Revoked reaped 30d" value={k.links_reaped_revoked_30d ?? 0} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-900">Per-investor activity ranking (30d)</h2>
        <DataTable
          rows={ranking}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'investor', header: 'Investor', render: (r: any) => r.investor_name ?? r.investor_email ?? "—" },
            { key: 'email',    header: 'Email',    render: (r: any) => r.investor_email ?? "—" },
            { key: 'events',   header: 'Events',   render: (r: any) => r.total_events ?? 0 },
            { key: 'files',    header: 'Files',    render: (r: any) => r.unique_files ?? 0 },
            { key: 'time',     header: 'View time',render: (r: any) => fmtSecs(r.total_view_seconds) },
            { key: 'dl',       header: 'Downloads',render: (r: any) => r.downloads ?? 0 },
            { key: 'score',    header: 'Score',    render: (r: any) => r.engagement_score ?? 0 },
            { key: 'last',     header: 'Last seen',render: (r: any) => r.last_seen_at ? new Date(r.last_seen_at).toLocaleString() : "—" },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-900">File viewing-time analytics (30d)</h2>
        <DataTable
          rows={files}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'label',    header: 'File',         render: (r: any) => r.file_label ?? r.file_path ?? "—" },
            { key: 'path',     header: 'Path',         render: (r: any) => <span className="font-mono text-xs text-slate-500">{r.file_path}</span> },
            { key: 'events',   header: 'Events',       render: (r: any) => r.total_events ?? 0 },
            { key: 'investors',header: 'Investors',    render: (r: any) => r.unique_investors ?? 0 },
            { key: 'time',     header: 'Total time',   render: (r: any) => fmtSecs(r.total_view_seconds) },
            { key: 'avg',      header: 'Avg secs',     render: (r: any) => r.avg_view_seconds ?? 0 },
            { key: 'dl',       header: 'Downloads',    render: (r: any) => r.downloads ?? 0 },
            { key: 'last',     header: 'Last seen',    render: (r: any) => r.last_seen_at ? new Date(r.last_seen_at).toLocaleString() : "—" },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-900">Recent file events (latest 50)</h2>
        <DataTable
          rows={events}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'when',     header: 'When',     render: (r: any) => new Date(r.occurred_at).toLocaleString() },
            { key: 'investor',header: 'Investor', render: (r: any) => r.investor_name ?? r.investor_email ?? "—" },
            { key: 'file',    header: 'File',     render: (r: any) => r.file_label ?? r.file_path ?? "—" },
            { key: 'event',   header: 'Event',    render: (r: any) => r.event_type ?? "—" },
            { key: 'secs',    header: 'Secs',     render: (r: any) => r.view_seconds ?? 0 },
            { key: 'ip',      header: 'IP',       render: (r: any) => <span className="font-mono text-xs text-slate-500">{r.ip_address ?? "—"}</span> },
            { key: 'token',   header: 'Token',    render: (r: any) => <span className="font-mono text-xs text-slate-500">{(r.share_token ?? '').slice(0, 10)}</span> },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-900">Session summary (14d)</h2>
        <DataTable
          rows={sessions}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'session',  header: 'Session',  render: (r: any) => <span className="font-mono text-xs text-slate-500">{(r.session_id ?? '').slice(0, 12)}</span> },
            { key: 'investor',header: 'Investor', render: (r: any) => r.investor_email ?? "—" },
            { key: 'start',   header: 'Started',  render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleString() : "—" },
            { key: 'end',     header: 'Ended',    render: (r: any) => r.ended_at ? new Date(r.ended_at).toLocaleString() : "—" },
            { key: 'events',  header: 'Events',   render: (r: any) => r.events ?? 0 },
            { key: 'time',    header: 'View time',render: (r: any) => fmtSecs(r.view_seconds) },
            { key: 'files',   header: 'Files',    render: (r: any) => r.unique_files ?? 0 },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-900">Expired-link reaper log (latest 25)</h2>
        <DataTable
          rows={reaper}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'reaped',  header: 'Reaped at', render: (r: any) => new Date(r.reaped_at).toLocaleString() },
            { key: 'reason',  header: 'Reason',    render: (r: any) => r.reason ?? "—" },
            { key: 'token',   header: 'Token',     render: (r: any) => <span className="font-mono text-xs text-slate-500">{(r.share_token ?? '').slice(0, 12)}</span> },
            { key: 'investor',header: 'Investor',  render: (r: any) => r.investor_email ?? "—" },
            { key: 'expired', header: 'Expired at',render: (r: any) => r.expired_at ? new Date(r.expired_at).toLocaleString() : "—" },
            { key: 'notes',   header: 'Notes',     render: (r: any) => r.notes ?? "—" },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-900">Daily trend (30d)</h2>
        <DataTable
          rows={trend}
          rowKey={(r: any) => r.id}
          columns={[
            { key: 'day',       header: 'Day',        render: (r: any) => r.id ?? "—" },
            { key: 'events',    header: 'Events',     render: (r: any) => r.events ?? 0 },
            { key: 'investors', header: 'Investors',  render: (r: any) => r.unique_investors ?? 0 },
            { key: 'time',      header: 'View time',  render: (r: any) => fmtSecs(r.view_seconds) },
            { key: 'dl',        header: 'Downloads',  render: (r: any) => r.downloads ?? 0 },
          ]}
        />
      </section>

      <p className="text-xs text-slate-400">r1466 fundraise data room v2 -- founder only</p>
    </div>
  );
}
