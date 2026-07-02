import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type JournalRow = {
  id: string;
  week_start: string;
  wins_md: string | null;
  losses_md: string | null;
  learnings_md: string | null;
  next_focus_md: string | null;
  mood_rating: number | null;
  gratitude_md: string | null;
  tag_count: number | null;
  created_at: string;
};

type TagFreqRow = {
  tag: string;
  occurrences: number;
  total_weight: number;
  last_seen: string | null;
};

type ThemeRow = {
  tag: string;
  recent_occurrences: number;
  recent_weight: number;
  first_week: string | null;
  last_week: string | null;
};

type MoodRow = {
  week_start: string;
  mood_rating: number | null;
  rolling_avg: number | null;
  has_entry: boolean;
};

function snip(s: string | null, n = 80): string {
  if (!s) return '—';
  const t = s.replace(/\s+/g, ' ').trim();
  return t.length > n ? t.slice(0, n) + '…' : t;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [journalsRes, tagsRes, themesRes, moodRes] = await Promise.all([
    sb.rpc('list_journals_r1698'),
    sb.rpc('tag_frequency_r1698'),
    sb.rpc('recent_themes_r1698', { p_weeks: 8 }),
    sb.rpc('mood_trend_r1698', { p_weeks: 26 }),
  ]);

  const journals: JournalRow[] = (journalsRes.data as JournalRow[]) ?? [];
  const tagFreq: TagFreqRow[] = (tagsRes.data as TagFreqRow[]) ?? [];
  const themes: ThemeRow[] = (themesRes.data as ThemeRow[]) ?? [];
  const mood: MoodRow[] = (moodRes.data as MoodRow[]) ?? [];

  const totalEntries = journals.length;
  const withMood = journals.filter(j => j.mood_rating != null).length;
  const avgMood = withMood
    ? (journals.reduce((s, j) => s + (j.mood_rating ?? 0), 0) / withMood).toFixed(2)
    : '—';
  const uniqueTags = tagFreq.length;
  const latestWeek = journals[0]?.week_start ?? '—';

  const journalCols: Column<JournalRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => <span className="font-mono text-xs">{r.week_start}</span> },
    { key: 'mood_rating', header: 'Mood (1-5)', render: (r: any) => r.mood_rating != null ? <span>{r.mood_rating}/5</span> : <span className="text-neutral-500">—</span> },
    { key: 'wins_md', header: 'Wins', render: (r: any) => <span className="text-xs">{snip(r.wins_md)}</span> },
    { key: 'losses_md', header: 'Losses', render: (r: any) => <span className="text-xs">{snip(r.losses_md)}</span> },
    { key: 'learnings_md', header: 'Learnings', render: (r: any) => <span className="text-xs">{snip(r.learnings_md)}</span> },
    { key: 'next_focus_md', header: 'Next Focus', render: (r: any) => <span className="text-xs">{snip(r.next_focus_md)}</span> },
    { key: 'gratitude_md', header: 'Gratitude', render: (r: any) => <span className="text-xs">{snip(r.gratitude_md, 60)}</span> },
    { key: 'tag_count', header: 'Tags', render: (r: any) => <span className="font-mono text-xs">{r.tag_count ?? 0}</span> },
  ];

  const tagCols: Column<TagFreqRow>[] = [
    { key: 'tag', header: 'Tag', render: (r: any) => <span className="font-mono text-xs">{r.tag}</span> },
    { key: 'occurrences', header: 'Occurrences', render: (r: any) => <span className="font-mono">{r.occurrences}</span> },
    { key: 'total_weight', header: 'Total Weight', render: (r: any) => <span className="font-mono">{r.total_weight}</span> },
    { key: 'last_seen', header: 'Last Seen', render: (r: any) => <span className="font-mono text-xs">{r.last_seen ?? '—'}</span> },
  ];

  const themeCols: Column<ThemeRow>[] = [
    { key: 'tag', header: 'Theme', render: (r: any) => <span className="font-mono text-xs">{r.tag}</span> },
    { key: 'recent_occurrences', header: 'Recent Count', render: (r: any) => <span className="font-mono">{r.recent_occurrences}</span> },
    { key: 'recent_weight', header: 'Recent Weight', render: (r: any) => <span className="font-mono">{r.recent_weight}</span> },
    { key: 'first_week', header: 'First Week', render: (r: any) => <span className="font-mono text-xs">{r.first_week ?? '—'}</span> },
    { key: 'last_week', header: 'Last Week', render: (r: any) => <span className="font-mono text-xs">{r.last_week ?? '—'}</span> },
  ];

  const moodCols: Column<MoodRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => <span className="font-mono text-xs">{r.week_start}</span> },
    { key: 'mood_rating', header: 'Mood', render: (r: any) => r.mood_rating != null ? <span>{r.mood_rating}/5</span> : <span className="text-neutral-500">no entry</span> },
    { key: 'rolling_avg', header: '4-wk Rolling Avg', render: (r: any) => <span className="font-mono text-xs">{r.rolling_avg != null ? Number(r.rolling_avg).toFixed(2) : '—'}</span> },
    { key: 'has_entry', header: 'Entry?', render: (r: any) => r.has_entry ? <span className="text-emerald-600">yes</span> : <span className="text-neutral-500">missing</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Founder Weekly Reflection Journal</h1>
        <p className="text-sm text-neutral-600">
          Weekly entries: wins / losses / learnings / next-week focus. Mood rating 1-5. Tag frequency surfaces recurring themes (mood &gt;= 4 = good week, mood &lt;= 2 = tough week).
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-5">
        <div className="rounded-lg border border-neutral-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-neutral-500">Total Entries</div>
          <div className="mt-1 text-2xl font-semibold">{totalEntries}</div>
        </div>
        <div className="rounded-lg border border-neutral-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-neutral-500">Latest Week</div>
          <div className="mt-1 text-lg font-mono">{latestWeek}</div>
        </div>
        <div className="rounded-lg border border-neutral-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-neutral-500">Avg Mood</div>
          <div className="mt-1 text-2xl font-semibold">{avgMood}</div>
        </div>
        <div className="rounded-lg border border-neutral-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-neutral-500">Mood Entries</div>
          <div className="mt-1 text-2xl font-semibold">{withMood}</div>
        </div>
        <div className="rounded-lg border border-neutral-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-neutral-500">Unique Tags</div>
          <div className="mt-1 text-2xl font-semibold">{uniqueTags}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Weekly Journal Entries</h2>
        <p className="text-xs text-neutral-500">Most recent first. Text columns truncated to ~80 chars. Use record_journal_r1698 RPC to add/update entries.</p>
        <DataTable rows={journals} columns={journalCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Themes (last 8 weeks)</h2>
        <p className="text-xs text-neutral-500">Tags appearing in recent journals — surfaces what is dominating focus right now.</p>
        <DataTable rows={themes} columns={themeCols} rowKey={(r: any, i: number) => String(r.tag ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All-Time Tag Frequency</h2>
        <p className="text-xs text-neutral-500">Top 100 tags. High occurrences = recurring patterns. Tags with weight &gt;= 3 are emphasized themes.</p>
        <DataTable rows={tagFreq} columns={tagCols} rowKey={(r: any, i: number) => String(r.tag ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Mood Trend (last 26 weeks)</h2>
        <p className="text-xs text-neutral-500">Weekly mood with 4-week rolling average. Watch for sustained dips (rolling avg &lt; 3.0) — signal to take action.</p>
        <DataTable rows={mood} columns={moodCols} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
      </section>
    </div>
  );
}
