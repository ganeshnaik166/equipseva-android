import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type WeeklySummary = {
  week_start: string;
  conversation_count: number;
  unique_contacts: number;
  total_minutes: number;
  avg_energy_after: number | null;
  work_mention_rate: number | null;
  family_count: number;
  friend_count: number;
};

type CurrentWeek = {
  week_start: string;
  target_conversations: number;
  actual_conversations: number;
  target_family: number;
  actual_family: number;
  target_non_work_minutes: number;
  actual_non_work_minutes: number;
  on_track: boolean;
};

type RelationshipRow = {
  relationship: string;
  conversation_count: number;
  total_minutes: number;
  avg_energy: number | null;
  share_pct: number | null;
};

type RecentRow = {
  id: string;
  week_start: string;
  logged_at: string;
  contact_name: string;
  relationship: string;
  channel: string;
  topic: string;
  duration_minutes: number;
  energy_after: number;
  work_mentioned: boolean;
};

type Streak = {
  current_streak_weeks: number;
  best_streak_weeks: number;
  weeks_with_data: number;
  weeks_on_target: number;
};

type ChannelRow = {
  channel: string;
  conversation_count: number;
  total_minutes: number;
  avg_energy: number | null;
};

type ContactRow = {
  contact_name: string;
  relationship: string;
  conversation_count: number;
  total_minutes: number;
  avg_energy: number | null;
  last_seen: string;
};

export default async function FounderWeeklyOutsideConversationsPage() {
  const supabase = await getSupabaseServerClient();

  const [weekly, current, rel, recent, streak, channel, contacts] = await Promise.all([
    supabase.rpc('rpc_r2377_weekly_summary', { weeks_back: 8 }),
    supabase.rpc('rpc_r2377_current_week_status'),
    supabase.rpc('rpc_r2377_relationship_breakdown', { weeks_back: 8 }),
    supabase.rpc('rpc_r2377_recent_conversations', { limit_n: 50 }),
    supabase.rpc('rpc_r2377_wellness_streak'),
    supabase.rpc('rpc_r2377_channel_mix', { weeks_back: 8 }),
    supabase.rpc('rpc_r2377_top_contacts', { weeks_back: 8, limit_n: 10 }),
  ]);

  const weeklyRows: WeeklySummary[] = (weekly.data ?? []) as WeeklySummary[];
  const currentRow: CurrentWeek | null = ((current.data ?? [])[0] ?? null) as CurrentWeek | null;
  const relRows: RelationshipRow[] = (rel.data ?? []) as RelationshipRow[];
  const recentRows: RecentRow[] = (recent.data ?? []) as RecentRow[];
  const streakRow: Streak | null = ((streak.data ?? [])[0] ?? null) as Streak | null;
  const channelRows: ChannelRow[] = (channel.data ?? []) as ChannelRow[];
  const contactRows: ContactRow[] = (contacts.data ?? []) as ContactRow[];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r) => r.week_start },
    { key: 'conversation_count', header: 'Convos', render: (r) => r.conversation_count },
    { key: 'unique_contacts', header: 'Unique', render: (r) => r.unique_contacts },
    { key: 'total_minutes', header: 'Minutes', render: (r) => r.total_minutes },
    { key: 'avg_energy_after', header: 'Avg energy (1-5)', render: (r) => r.avg_energy_after ?? '-' },
    { key: 'work_mention_rate', header: 'Work mention %', render: (r) => (r.work_mention_rate ?? 0) + '%' },
    { key: 'family_count', header: 'Family', render: (r) => r.family_count },
    { key: 'friend_count', header: 'Friends', render: (r) => r.friend_count },
  ];

  const relCols: Column<any>[] = [
    { key: 'relationship', header: 'Relationship', render: (r) => r.relationship },
    { key: 'conversation_count', header: 'Convos', render: (r) => r.conversation_count },
    { key: 'total_minutes', header: 'Minutes', render: (r) => r.total_minutes },
    { key: 'avg_energy', header: 'Avg energy', render: (r) => r.avg_energy ?? '-' },
    { key: 'share_pct', header: 'Share %', render: (r) => (r.share_pct ?? 0) + '%' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'logged_at', header: 'Logged', render: (r) => new Date(r.logged_at).toLocaleString() },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name },
    { key: 'relationship', header: 'Relationship', render: (r) => r.relationship },
    { key: 'channel', header: 'Channel', render: (r) => r.channel },
    { key: 'topic', header: 'Topic', render: (r) => r.topic },
    { key: 'duration_minutes', header: 'Min', render: (r) => r.duration_minutes },
    { key: 'energy_after', header: 'Energy', render: (r) => r.energy_after },
    { key: 'work_mentioned', header: 'Work?', render: (r) => (r.work_mentioned ? 'yes' : 'no') },
  ];

  const channelCols: Column<any>[] = [
    { key: 'channel', header: 'Channel', render: (r) => r.channel },
    { key: 'conversation_count', header: 'Convos', render: (r) => r.conversation_count },
    { key: 'total_minutes', header: 'Minutes', render: (r) => r.total_minutes },
    { key: 'avg_energy', header: 'Avg energy', render: (r) => r.avg_energy ?? '-' },
  ];

  const contactCols: Column<any>[] = [
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name },
    { key: 'relationship', header: 'Relationship', render: (r) => r.relationship },
    { key: 'conversation_count', header: 'Convos', render: (r) => r.conversation_count },
    { key: 'total_minutes', header: 'Minutes', render: (r) => r.total_minutes },
    { key: 'avg_energy', header: 'Avg energy', render: (r) => r.avg_energy ?? '-' },
    { key: 'last_seen', header: 'Last week', render: (r) => r.last_seen },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder weekly outside-Equipseva conversations</h1>
        <p className="text-sm text-gray-600">
          Non-work conversations (family, friends, hobbies) logged each week as a founder wellness indicator. Target &gt;= 5 conversations/week, &gt;= 2 family, &gt;= 180 non-work minutes.
        </p>
      </header>

      {currentRow ? (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">This week</div>
            <div className="text-lg font-semibold">{currentRow.week_start}</div>
            <div className={currentRow.on_track ? 'text-green-600 text-sm' : 'text-amber-600 text-sm'}>
              {currentRow.on_track ? 'On track' : 'Behind target'}
            </div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Conversations</div>
            <div className="text-lg font-semibold">
              {currentRow.actual_conversations} / {currentRow.target_conversations}
            </div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Family</div>
            <div className="text-lg font-semibold">
              {currentRow.actual_family} / {currentRow.target_family}
            </div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Non-work minutes</div>
            <div className="text-lg font-semibold">
              {currentRow.actual_non_work_minutes} / {currentRow.target_non_work_minutes}
            </div>
          </div>
        </section>
      ) : (
        <p className="text-sm text-gray-500">No data for current week yet.</p>
      )}

      {streakRow ? (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Current streak</div>
            <div className="text-lg font-semibold">{streakRow.current_streak_weeks} weeks</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Best streak</div>
            <div className="text-lg font-semibold">{streakRow.best_streak_weeks} weeks</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Weeks logged</div>
            <div className="text-lg font-semibold">{streakRow.weeks_with_data}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Weeks on target</div>
            <div className="text-lg font-semibold">{streakRow.weeks_on_target}</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly summary (last 8 weeks)</h2>
        <DataTable
          rows={weeklyRows}
          columns={weeklyCols}
          rowKey={(r: WeeklySummary) => r.week_start}
          emptyMessage="No weekly conversation data yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Relationship breakdown</h2>
        <DataTable
          rows={relRows}
          columns={relCols}
          rowKey={(r: RelationshipRow) => r.relationship}
          emptyMessage="No relationship data yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Channel mix</h2>
        <DataTable
          rows={channelRows}
          columns={channelCols}
          rowKey={(r: ChannelRow) => r.channel}
          emptyMessage="No channel data yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top contacts (last 8 weeks)</h2>
        <DataTable
          rows={contactRows}
          columns={contactCols}
          rowKey={(r: ContactRow) => r.contact_name}
          emptyMessage="No contact data yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent conversations log</h2>
        <DataTable
          rows={recentRows}
          columns={recentCols}
          rowKey={(r: RecentRow) => r.id}
          emptyMessage="No conversations logged yet."
        />
      </section>
    </div>
  );
}
