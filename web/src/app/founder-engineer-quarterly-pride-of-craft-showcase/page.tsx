import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_entries: number;
  finalists: number;
  winners: number;
  promoted: number;
  total_peer_votes: number;
  avg_judge_score: number;
  total_promote_actions: number;
  total_reach: number;
};

type Entry = {
  id: string;
  engineer_name: string;
  engineer_tier: string;
  craft_moment: string;
  hospital_name: string;
  device_category: string;
  award_category: string;
  peer_votes: number;
  judge_score: number;
  status: string;
  quarter: string;
};

type AwardRow = {
  award_category: string;
  entry_count: number;
  total_votes: number;
  avg_score: number;
  top_engineer: string;
};

type TierRow = {
  engineer_tier: string;
  entries: number;
  votes: number;
  avg_score: number;
};

type PromoteRow = {
  id: string;
  engineer_name: string;
  action_type: string;
  reach_count: number;
  notes: string;
  acted_by: string;
  acted_at: string;
};

type StoryRow = {
  engineer_name: string;
  story: string;
  hospital_name: string;
  award_category: string;
  judge_score: number;
};

type ChannelRow = {
  action_type: string;
  action_count: number;
  total_reach: number;
  avg_reach: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, entriesRes, awardsRes, tiersRes, promotesRes, storiesRes, channelsRes] = await Promise.all([
    supabase.rpc('founder_craft_showcase_kpis_r2714'),
    supabase.rpc('founder_craft_showcase_entries_r2714'),
    supabase.rpc('founder_craft_award_breakdown_r2714'),
    supabase.rpc('founder_craft_tier_leaderboard_r2714'),
    supabase.rpc('founder_craft_promote_actions_r2714'),
    supabase.rpc('founder_craft_top_stories_r2714'),
    supabase.rpc('founder_craft_channel_mix_r2714'),
  ]);

  const kpis: Kpis = (Array.isArray(kpisRes.data) ? kpisRes.data[0] : kpisRes.data) ?? {
    total_entries: 0,
    finalists: 0,
    winners: 0,
    promoted: 0,
    total_peer_votes: 0,
    avg_judge_score: 0,
    total_promote_actions: 0,
    total_reach: 0,
  };

  const entries: Entry[] = entriesRes.data ?? [];
  const awards: AwardRow[] = awardsRes.data ?? [];
  const tiers: TierRow[] = tiersRes.data ?? [];
  const promotes: PromoteRow[] = promotesRes.data ?? [];
  const stories: StoryRow[] = storiesRes.data ?? [];
  const channels: ChannelRow[] = channelsRes.data ?? [];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-3xl font-bold">Engineer Quarterly Pride of Craft Showcase</h1>
        <p className="text-sm text-gray-600 mt-1">
          Celebrate the engineer craft moments worth bragging about. Score, vote, and promote
          stories across newsletter, LinkedIn, townhall & press.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Entries" value={kpis.total_entries} />
        <KpiCard label="Finalists" value={kpis.finalists} />
        <KpiCard label="Winners" value={kpis.winners} />
        <KpiCard label="Promoted" value={kpis.promoted} />
        <KpiCard label="Peer Votes" value={kpis.total_peer_votes} />
        <KpiCard label="Avg Judge Score" value={kpis.avg_judge_score} />
        <KpiCard label="Promote Actions" value={kpis.total_promote_actions} />
        <KpiCard label="Total Reach" value={kpis.total_reach} />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Quarterly Entries (score &gt;= peer votes)</h2>
        <DataTable
          rows={entries}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Entry) => <strong>{r.engineer_name}</strong> },
            { key: 'engineer_tier', header: 'Tier', render: (r: Entry) => <span>{r.engineer_tier}</span> },
            { key: 'craft_moment', header: 'Craft Moment', render: (r: Entry) => <span>{r.craft_moment}</span> },
            { key: 'hospital_name', header: 'Hospital', render: (r: Entry) => <span>{r.hospital_name}</span> },
            { key: 'device_category', header: 'Device', render: (r: Entry) => <span>{r.device_category}</span> },
            { key: 'award_category', header: 'Award', render: (r: Entry) => <span>{r.award_category}</span> },
            { key: 'peer_votes', header: 'Peer Votes', render: (r: Entry) => <span>{r.peer_votes}</span> },
            { key: 'judge_score', header: 'Judge', render: (r: Entry) => <span>{r.judge_score}</span> },
            { key: 'status', header: 'Status', render: (r: Entry) => <span>{r.status}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Entry, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Award Category Breakdown</h2>
        <DataTable
          rows={awards}
          columns={[
            { key: 'award_category', header: 'Category', render: (r: AwardRow) => <strong>{r.award_category}</strong> },
            { key: 'entry_count', header: 'Entries', render: (r: AwardRow) => <span>{r.entry_count}</span> },
            { key: 'total_votes', header: 'Votes', render: (r: AwardRow) => <span>{r.total_votes}</span> },
            { key: 'avg_score', header: 'Avg Score', render: (r: AwardRow) => <span>{r.avg_score}</span> },
            { key: 'top_engineer', header: 'Top Engineer', render: (r: AwardRow) => <span>{r.top_engineer}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: AwardRow, i: number) => String(r.award_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Tier Leaderboard</h2>
        <DataTable
          rows={tiers}
          columns={[
            { key: 'engineer_tier', header: 'Tier', render: (r: TierRow) => <strong>{r.engineer_tier}</strong> },
            { key: 'entries', header: 'Entries', render: (r: TierRow) => <span>{r.entries}</span> },
            { key: 'votes', header: 'Peer Votes', render: (r: TierRow) => <span>{r.votes}</span> },
            { key: 'avg_score', header: 'Avg Judge', render: (r: TierRow) => <span>{r.avg_score}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRow, i: number) => String(r.engineer_tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Top Stories (judge score &gt;= 8)</h2>
        <DataTable
          rows={stories}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: StoryRow) => <strong>{r.engineer_name}</strong> },
            { key: 'hospital_name', header: 'Hospital', render: (r: StoryRow) => <span>{r.hospital_name}</span> },
            { key: 'award_category', header: 'Award', render: (r: StoryRow) => <span>{r.award_category}</span> },
            { key: 'judge_score', header: 'Score', render: (r: StoryRow) => <span>{r.judge_score}</span> },
            { key: 'story', header: 'Story', render: (r: StoryRow) => <span>{r.story}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: StoryRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Promote Actions Feed</h2>
        <DataTable
          rows={promotes}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: PromoteRow) => <strong>{r.engineer_name}</strong> },
            { key: 'action_type', header: 'Channel', render: (r: PromoteRow) => <span>{r.action_type}</span> },
            { key: 'reach_count', header: 'Reach', render: (r: PromoteRow) => <span>{r.reach_count}</span> },
            { key: 'notes', header: 'Notes', render: (r: PromoteRow) => <span>{r.notes}</span> },
            { key: 'acted_by', header: 'By', render: (r: PromoteRow) => <span>{r.acted_by}</span> },
            { key: 'acted_at', header: 'When', render: (r: PromoteRow) => <span>{new Date(r.acted_at).toLocaleString()}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: PromoteRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Channel Mix (reach & cost)</h2>
        <DataTable
          rows={channels}
          columns={[
            { key: 'action_type', header: 'Channel', render: (r: ChannelRow) => <strong>{r.action_type}</strong> },
            { key: 'action_count', header: 'Actions', render: (r: ChannelRow) => <span>{r.action_count}</span> },
            { key: 'total_reach', header: 'Total Reach', render: (r: ChannelRow) => <span>{r.total_reach}</span> },
            { key: 'avg_reach', header: 'Avg Reach', render: (r: ChannelRow) => <span>{r.avg_reach}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChannelRow, i: number) => String(r.action_type ?? i)}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
    </div>
  );
}