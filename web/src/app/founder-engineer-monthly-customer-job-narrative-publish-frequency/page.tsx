import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_engineers: number;
  total_narratives: number;
  published_count: number;
  draft_count: number;
  total_views: number;
  exceptional_count: number;
  at_risk_count: number;
  on_pace_pct: number | null;
};

type CadenceRow = {
  engineer_handle: string;
  narratives_target: number;
  narratives_published: number;
  total_views: number;
  primary_audience: string;
  streak_months: number;
  verdict: string;
  coach_note: string;
};

type StatusRow = {
  publish_status: string;
  narrative_count: number;
  avg_word_count: number;
  total_views: number;
};

type AudienceRow = {
  audience_segment: string;
  narrative_count: number;
  published_count: number;
  total_engagement: number;
};

type TopRow = {
  engineer_handle: string;
  narrative_title: string;
  narrative_kind: string;
  customer_org: string;
  publish_channel: string;
  engagement_views: number;
  engagement_reactions: number;
  verdict: string;
};

type BehindRow = {
  engineer_handle: string;
  narratives_target: number;
  narratives_published: number;
  gap: number;
  verdict: string;
  coach_note: string;
};

type ChannelRow = {
  publish_channel: string;
  total_published: number;
  avg_views: number;
  avg_reactions: number;
  total_replies: number;
};

type RecentRow = {
  engineer_handle: string;
  engineer_tier: string;
  narrative_title: string;
  narrative_kind: string;
  customer_org: string;
  word_count: number;
  publish_status: string;
  audience_segment: string;
  verdict: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, cadenceRes, statusRes, audienceRes, topRes, behindRes, channelRes, recentRes] = await Promise.all([
    supabase.rpc('founder_r2862_kpi_snapshot'),
    supabase.rpc('founder_r2862_engineer_cadence'),
    supabase.rpc('founder_r2862_narratives_by_status'),
    supabase.rpc('founder_r2862_audience_split'),
    supabase.rpc('founder_r2862_top_published'),
    supabase.rpc('founder_r2862_behind_engineers'),
    supabase.rpc('founder_r2862_channel_performance'),
    supabase.rpc('founder_r2862_recent_narratives'),
  ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] as Kpi) ?? null;
  const cadence: CadenceRow[] = (cadenceRes.data as CadenceRow[]) ?? [];
  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const audience: AudienceRow[] = (audienceRes.data as AudienceRow[]) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[]) ?? [];
  const behind: BehindRow[] = (behindRes.data as BehindRow[]) ?? [];
  const channel: ChannelRow[] = (channelRes.data as ChannelRow[]) ?? [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[]) ?? [];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Narrative Publish Frequency</h1>
        <p className="text-sm text-gray-600 mt-1">
          Round r2862 — engineer × narratives × cadence × engagement × audience × verdict
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Engineers</div>
          <div className="text-2xl font-semibold mt-1">{kpi?.total_engineers ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Narratives</div>
          <div className="text-2xl font-semibold mt-1">{kpi?.total_narratives ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Published</div>
          <div className="text-2xl font-semibold mt-1">{kpi?.published_count ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Drafts</div>
          <div className="text-2xl font-semibold mt-1">{kpi?.draft_count ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total Views</div>
          <div className="text-2xl font-semibold mt-1">{(kpi?.total_views ?? 0).toLocaleString()}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Exceptional</div>
          <div className="text-2xl font-semibold mt-1">{kpi?.exceptional_count ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">At Risk</div>
          <div className="text-2xl font-semibold mt-1">{kpi?.at_risk_count ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">On-Pace %</div>
          <div className="text-2xl font-semibold mt-1">{kpi?.on_pace_pct ?? 0}%</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Engineer Cadence Rollup</h2>
        <p className="text-sm text-gray-600 mb-2">
          Target vs published per engineer — streaks &gt;= 4 months mark sustained voice.
        </p>
        <DataTable
          rows={cadence}
          rowKey={(r, i) => String(r.engineer_handle ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_handle', header: 'Engineer', render: (r: CadenceRow) => r.engineer_handle },
            { key: 'narratives_target', header: 'Target', render: (r: CadenceRow) => r.narratives_target },
            { key: 'narratives_published', header: 'Published', render: (r: CadenceRow) => r.narratives_published },
            { key: 'total_views', header: 'Views', render: (r: CadenceRow) => r.total_views.toLocaleString() },
            { key: 'primary_audience', header: 'Audience', render: (r: CadenceRow) => r.primary_audience },
            { key: 'streak_months', header: 'Streak (mo)', render: (r: CadenceRow) => r.streak_months },
            { key: 'verdict', header: 'Verdict', render: (r: CadenceRow) => r.verdict },
            { key: 'coach_note', header: 'Coach Note', render: (r: CadenceRow) => r.coach_note },
          ]}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-3">Narratives by Status</h2>
          <DataTable
            rows={statusRows}
            rowKey={(r, i) => String(r.publish_status ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'publish_status', header: 'Status', render: (r: StatusRow) => r.publish_status },
              { key: 'narrative_count', header: 'Count', render: (r: StatusRow) => r.narrative_count },
              { key: 'avg_word_count', header: 'Avg Words', render: (r: StatusRow) => r.avg_word_count },
              { key: 'total_views', header: 'Views', render: (r: StatusRow) => r.total_views.toLocaleString() },
            ]}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-3">Audience Split</h2>
          <DataTable
            rows={audience}
            rowKey={(r, i) => String(r.audience_segment ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'audience_segment', header: 'Segment', render: (r: AudienceRow) => r.audience_segment },
              { key: 'narrative_count', header: 'Total', render: (r: AudienceRow) => r.narrative_count },
              { key: 'published_count', header: 'Published', render: (r: AudienceRow) => r.published_count },
              { key: 'total_engagement', header: 'Engagement', render: (r: AudienceRow) => r.total_engagement.toLocaleString() },
            ]}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Published Narratives</h2>
        <DataTable
          rows={top}
          rowKey={(r, i) => String(r.narrative_title ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_handle', header: 'Engineer', render: (r: TopRow) => r.engineer_handle },
            { key: 'narrative_title', header: 'Title', render: (r: TopRow) => r.narrative_title },
            { key: 'narrative_kind', header: 'Kind', render: (r: TopRow) => r.narrative_kind },
            { key: 'customer_org', header: 'Customer', render: (r: TopRow) => r.customer_org },
            { key: 'publish_channel', header: 'Channel', render: (r: TopRow) => r.publish_channel },
            { key: 'engagement_views', header: 'Views', render: (r: TopRow) => r.engagement_views.toLocaleString() },
            { key: 'engagement_reactions', header: 'Reactions', render: (r: TopRow) => r.engagement_reactions },
            { key: 'verdict', header: 'Verdict', render: (r: TopRow) => r.verdict },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Behind / At-Risk Engineers</h2>
        <p className="text-sm text-gray-600 mb-2">
          Gap = target minus published. Larger gap =&gt; higher coaching priority.
        </p>
        <DataTable
          rows={behind}
          rowKey={(r, i) => String(r.engineer_handle ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_handle', header: 'Engineer', render: (r: BehindRow) => r.engineer_handle },
            { key: 'narratives_target', header: 'Target', render: (r: BehindRow) => r.narratives_target },
            { key: 'narratives_published', header: 'Published', render: (r: BehindRow) => r.narratives_published },
            { key: 'gap', header: 'Gap', render: (r: BehindRow) => r.gap },
            { key: 'verdict', header: 'Verdict', render: (r: BehindRow) => r.verdict },
            { key: 'coach_note', header: 'Coach Note', render: (r: BehindRow) => r.coach_note },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Channel Performance</h2>
        <DataTable
          rows={channel}
          rowKey={(r, i) => String(r.publish_channel ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'publish_channel', header: 'Channel', render: (r: ChannelRow) => r.publish_channel },
            { key: 'total_published', header: 'Published', render: (r: ChannelRow) => r.total_published },
            { key: 'avg_views', header: 'Avg Views', render: (r: ChannelRow) => r.avg_views },
            { key: 'avg_reactions', header: 'Avg Reactions', render: (r: ChannelRow) => r.avg_reactions },
            { key: 'total_replies', header: 'Replies', render: (r: ChannelRow) => r.total_replies },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Narratives</h2>
        <DataTable
          rows={recent}
          rowKey={(r, i) => String(r.narrative_title ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_handle', header: 'Engineer', render: (r: RecentRow) => r.engineer_handle },
            { key: 'engineer_tier', header: 'Tier', render: (r: RecentRow) => r.engineer_tier },
            { key: 'narrative_title', header: 'Title', render: (r: RecentRow) => r.narrative_title },
            { key: 'narrative_kind', header: 'Kind', render: (r: RecentRow) => r.narrative_kind },
            { key: 'customer_org', header: 'Customer', render: (r: RecentRow) => r.customer_org },
            { key: 'word_count', header: 'Words', render: (r: RecentRow) => r.word_count },
            { key: 'publish_status', header: 'Status', render: (r: RecentRow) => r.publish_status },
            { key: 'audience_segment', header: 'Audience', render: (r: RecentRow) => r.audience_segment },
            { key: 'verdict', header: 'Verdict', render: (r: RecentRow) => r.verdict },
          ]}
        />
      </section>
    </div>
  );
}
