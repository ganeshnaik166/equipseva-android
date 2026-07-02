import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Build = {
  id: string;
  quarter: string;
  channel: string;
  content_type: string;
  title: string;
  reach_count: number;
  follower_delta: number;
  engagement_rate: number;
  commercial_signal: string;
  signal_count: number;
  verdict: string;
  effort_hours: number;
  published_at: string;
  notes: string | null;
};

type Rollup = {
  quarter: string;
  channel: string;
  total_reach: number;
  total_follower_delta: number;
  total_signals: number;
  total_effort_hours: number;
  signals_per_hour: number;
  channel_verdict: string;
};

type TopBuild = {
  title: string;
  channel: string;
  reach_count: number;
  signal_count: number;
  verdict: string;
};

type VerdictRow = {
  verdict: string;
  build_count: number;
  total_reach: number;
  total_signals: number;
};

type SignalRow = {
  commercial_signal: string;
  build_count: number;
  total_signal_count: number;
};

function fmt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, buildsRes, rollupRes, topRes, verdictRes, signalRes] = await Promise.all([
    supabase.rpc('rpc_r2837_kpis'),
    supabase.rpc('rpc_r2837_builds'),
    supabase.rpc('rpc_r2837_channel_rollup'),
    supabase.rpc('rpc_r2837_top_builds'),
    supabase.rpc('rpc_r2837_verdict_breakdown'),
    supabase.rpc('rpc_r2837_signal_breakdown'),
  ]);

  const kpis = (kpisRes.data?.[0] ?? {
    total_builds: 0,
    total_reach: 0,
    total_follower_delta: 0,
    total_signals: 0,
    total_effort_hours: 0,
    avg_engagement: 0,
  }) as {
    total_builds: number;
    total_reach: number;
    total_follower_delta: number;
    total_signals: number;
    total_effort_hours: number;
    avg_engagement: number;
  };

  const builds = (buildsRes.data ?? []) as Build[];
  const rollup = (rollupRes.data ?? []) as Rollup[];
  const top = (topRes.data ?? []) as TopBuild[];
  const verdicts = (verdictRes.data ?? []) as VerdictRow[];
  const signals = (signalRes.data ?? []) as SignalRow[];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Founder Quarterly Strategic Personal Branding Builds</h1>
        <p className="text-sm text-gray-600">
          Track channel x content x reach x follower delta x commercial signal x verdict. Kill what does not move pipeline.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Builds</div>
          <div className="text-xl font-semibold">{fmt(kpis.total_builds)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Total reach</div>
          <div className="text-xl font-semibold">{fmt(kpis.total_reach)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Follower delta</div>
          <div className="text-xl font-semibold">{fmt(kpis.total_follower_delta)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Commercial signals</div>
          <div className="text-xl font-semibold">{fmt(kpis.total_signals)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Effort hours</div>
          <div className="text-xl font-semibold">{fmt(kpis.total_effort_hours)}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Avg engagement %</div>
          <div className="text-xl font-semibold">{Number(kpis.avg_engagement ?? 0).toFixed(2)}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Channel rollup (signals per hour ranks scale vs kill)</h2>
        <DataTable
          rows={rollup}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as Rollup).channel ?? i)}
          columns={[
            { key: 'channel', header: 'Channel', render: (r: Rollup) => r.channel },
            { key: 'total_reach', header: 'Reach', render: (r: Rollup) => fmt(r.total_reach) },
            { key: 'total_follower_delta', header: 'Follower delta', render: (r: Rollup) => fmt(r.total_follower_delta) },
            { key: 'total_signals', header: 'Signals', render: (r: Rollup) => fmt(r.total_signals) },
            { key: 'total_effort_hours', header: 'Effort hrs', render: (r: Rollup) => fmt(r.total_effort_hours) },
            { key: 'signals_per_hour', header: 'Signals / hr', render: (r: Rollup) => Number(r.signals_per_hour ?? 0).toFixed(2) },
            { key: 'channel_verdict', header: 'Verdict', render: (r: Rollup) => r.channel_verdict },
          ]}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Top builds by commercial signal</h2>
        <DataTable
          rows={top}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
          columns={[
            { key: 'title', header: 'Title', render: (r: TopBuild) => r.title },
            { key: 'channel', header: 'Channel', render: (r: TopBuild) => r.channel },
            { key: 'reach_count', header: 'Reach', render: (r: TopBuild) => fmt(r.reach_count) },
            { key: 'signal_count', header: 'Signals', render: (r: TopBuild) => fmt(r.signal_count) },
            { key: 'verdict', header: 'Verdict', render: (r: TopBuild) => r.verdict },
          ]}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Verdict breakdown</h2>
          <DataTable
            rows={verdicts}
            emptyMessage="No data"
            rowKey={(r, i) => String((r as VerdictRow).verdict ?? i)}
            columns={[
              { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
              { key: 'build_count', header: 'Builds', render: (r: VerdictRow) => fmt(r.build_count) },
              { key: 'total_reach', header: 'Reach', render: (r: VerdictRow) => fmt(r.total_reach) },
              { key: 'total_signals', header: 'Signals', render: (r: VerdictRow) => fmt(r.total_signals) },
            ]}
          />
        </div>
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Commercial signal mix</h2>
          <DataTable
            rows={signals}
            emptyMessage="No data"
            rowKey={(r, i) => String((r as SignalRow).commercial_signal ?? i)}
            columns={[
              { key: 'commercial_signal', header: 'Signal', render: (r: SignalRow) => r.commercial_signal },
              { key: 'build_count', header: 'Builds', render: (r: SignalRow) => fmt(r.build_count) },
              { key: 'total_signal_count', header: 'Total count', render: (r: SignalRow) => fmt(r.total_signal_count) },
            ]}
          />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All builds this quarter</h2>
        <DataTable
          rows={builds}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as Build).id ?? i)}
          columns={[
            { key: 'published_at', header: 'Published', render: (r: Build) => r.published_at },
            { key: 'channel', header: 'Channel', render: (r: Build) => r.channel },
            { key: 'content_type', header: 'Type', render: (r: Build) => r.content_type },
            { key: 'title', header: 'Title', render: (r: Build) => r.title },
            { key: 'reach_count', header: 'Reach', render: (r: Build) => fmt(r.reach_count) },
            { key: 'follower_delta', header: 'Follower delta', render: (r: Build) => fmt(r.follower_delta) },
            { key: 'engagement_rate', header: 'Eng %', render: (r: Build) => Number(r.engagement_rate ?? 0).toFixed(2) },
            { key: 'commercial_signal', header: 'Signal', render: (r: Build) => r.commercial_signal },
            { key: 'signal_count', header: 'Count', render: (r: Build) => fmt(r.signal_count) },
            { key: 'effort_hours', header: 'Hrs', render: (r: Build) => fmt(r.effort_hours) },
            { key: 'verdict', header: 'Verdict', render: (r: Build) => r.verdict },
          ]}
        />
      </section>
    </div>
  );
}
