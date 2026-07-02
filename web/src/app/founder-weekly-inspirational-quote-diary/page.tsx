import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RecentEntry = {
  id: string;
  week_starting: string;
  quote_text: string;
  quote_author: string;
  source_type: string;
  source_title: string;
  theme_tag: string;
  impact_score: number | null;
  is_pinned: boolean;
  action_count: number;
};

type ThemeRow = {
  theme_tag: string;
  entry_count: number;
  avg_impact: number | null;
  pinned_count: number;
};

type SourceRow = {
  source_type: string;
  entry_count: number;
  distinct_authors: number;
  avg_impact: number | null;
};

type PinnedRow = {
  id: string;
  week_starting: string;
  quote_text: string;
  quote_author: string;
  theme_tag: string;
  impact_score: number | null;
  founder_reflection: string;
};

type AuthorRow = {
  quote_author: string;
  quote_count: number;
  avg_impact: number | null;
  themes_touched: number;
};

type ActionRow = {
  action_id: string;
  entry_id: string;
  week_starting: string;
  quote_author: string;
  theme_tag: string;
  action_text: string;
  action_status: string;
  due_date: string | null;
  days_until_due: number | null;
};

type CadenceRow = {
  week_starting: string;
  entries_logged: number;
  themes_explored: number;
  avg_impact: number | null;
  has_pinned: boolean;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? null;

  const [entriesRes, themesRes, sourcesRes, pinnedRes, authorsRes, actionsRes, cadenceRes] = await Promise.all([
    supabase.rpc('fqde_r2337_recent_entries', { p_limit: 20 }),
    supabase.rpc('fqde_r2337_theme_breakdown'),
    supabase.rpc('fqde_r2337_source_breakdown'),
    supabase.rpc('fqde_r2337_pinned_entries'),
    supabase.rpc('fqde_r2337_top_authors', { p_limit: 15 }),
    supabase.rpc('fqde_r2337_open_actions'),
    supabase.rpc('fqde_r2337_cadence_12w'),
  ]);

  const entries: RecentEntry[] = (entriesRes.data as RecentEntry[]) ?? [];
  const themes: ThemeRow[] = (themesRes.data as ThemeRow[]) ?? [];
  const sources: SourceRow[] = (sourcesRes.data as SourceRow[]) ?? [];
  const pinned: PinnedRow[] = (pinnedRes.data as PinnedRow[]) ?? [];
  const authors: AuthorRow[] = (authorsRes.data as AuthorRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const cadence: CadenceRow[] = (cadenceRes.data as CadenceRow[]) ?? [];

  const totalEntries = entries.length;
  const pinnedCount = pinned.length;
  const openActions = actions.length;
  const avgImpact = entries.length
    ? (entries.filter((e) => e.impact_score != null).reduce((s, e) => s + (e.impact_score ?? 0), 0) /
        Math.max(1, entries.filter((e) => e.impact_score != null).length)).toFixed(2)
    : '—';

  const entryCols: Column<RecentEntry>[] = [
    { key: 'week_starting', header: 'Week', render: (r) => r.week_starting },
    { key: 'quote_author', header: 'Author', render: (r) => r.quote_author },
    { key: 'quote_text', header: 'Quote', render: (r) => <span className="italic">“{r.quote_text}”</span> },
    { key: 'source_title', header: 'Source', render: (r) => `${r.source_title} (${r.source_type})` },
    { key: 'theme_tag', header: 'Theme', render: (r) => r.theme_tag },
    { key: 'impact_score', header: 'Impact', render: (r) => r.impact_score ?? '—' },
    { key: 'is_pinned', header: 'Pinned', render: (r) => (r.is_pinned ? 'yes' : '') },
    { key: 'action_count', header: 'Actions', render: (r) => r.action_count },
  ];

  const themeCols: Column<ThemeRow>[] = [
    { key: 'theme_tag', header: 'Theme', render: (r) => r.theme_tag },
    { key: 'entry_count', header: 'Entries', render: (r) => r.entry_count },
    { key: 'avg_impact', header: 'Avg impact', render: (r) => r.avg_impact ?? '—' },
    { key: 'pinned_count', header: 'Pinned', render: (r) => r.pinned_count },
  ];

  const sourceCols: Column<SourceRow>[] = [
    { key: 'source_type', header: 'Source type', render: (r) => r.source_type },
    { key: 'entry_count', header: 'Entries', render: (r) => r.entry_count },
    { key: 'distinct_authors', header: 'Authors', render: (r) => r.distinct_authors },
    { key: 'avg_impact', header: 'Avg impact', render: (r) => r.avg_impact ?? '—' },
  ];

  const pinnedCols: Column<PinnedRow>[] = [
    { key: 'week_starting', header: 'Week', render: (r) => r.week_starting },
    { key: 'quote_author', header: 'Author', render: (r) => r.quote_author },
    { key: 'quote_text', header: 'Quote', render: (r) => <span className="italic">“{r.quote_text}”</span> },
    { key: 'theme_tag', header: 'Theme', render: (r) => r.theme_tag },
    { key: 'impact_score', header: 'Impact', render: (r) => r.impact_score ?? '—' },
    { key: 'founder_reflection', header: 'Reflection', render: (r) => r.founder_reflection },
  ];

  const authorCols: Column<AuthorRow>[] = [
    { key: 'quote_author', header: 'Author', render: (r) => r.quote_author },
    { key: 'quote_count', header: 'Quotes', render: (r) => r.quote_count },
    { key: 'avg_impact', header: 'Avg impact', render: (r) => r.avg_impact ?? '—' },
    { key: 'themes_touched', header: 'Themes', render: (r) => r.themes_touched },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'week_starting', header: 'From week', render: (r) => r.week_starting },
    { key: 'quote_author', header: 'Author', render: (r) => r.quote_author },
    { key: 'theme_tag', header: 'Theme', render: (r) => r.theme_tag },
    { key: 'action_text', header: 'Action', render: (r) => r.action_text },
    { key: 'action_status', header: 'Status', render: (r) => r.action_status },
    { key: 'due_date', header: 'Due', render: (r) => r.due_date ?? '—' },
    {
      key: 'days_until_due',
      header: 'Days left',
      render: (r) => {
        if (r.days_until_due == null) return '—';
        if (r.days_until_due < 0) return `overdue ${Math.abs(r.days_until_due)}d`;
        return `${r.days_until_due}d`;
      },
    },
  ];

  const cadenceCols: Column<CadenceRow>[] = [
    { key: 'week_starting', header: 'Week', render: (r) => r.week_starting },
    { key: 'entries_logged', header: 'Entries', render: (r) => r.entries_logged },
    { key: 'themes_explored', header: 'Themes', render: (r) => r.themes_explored },
    { key: 'avg_impact', header: 'Avg impact', render: (r) => r.avg_impact ?? '—' },
    { key: 'has_pinned', header: 'Pinned?', render: (r) => (r.has_pinned ? 'yes' : '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Weekly Inspirational Quote Diary</h1>
        <p className="text-sm text-gray-600">
          Quote of the week from books & talks, founder reflection, and what got applied this week. Signed in as {email ?? 'anonymous'}.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Recent entries</div>
          <div className="text-2xl font-semibold">{totalEntries}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Pinned</div>
          <div className="text-2xl font-semibold">{pinnedCount}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Open actions</div>
          <div className="text-2xl font-semibold">{openActions}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Avg impact</div>
          <div className="text-2xl font-semibold">{avgImpact}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent diary entries</h2>
        <DataTable
          rows={entries}
          columns={entryCols}
          rowKey={(r) => r.id}
          emptyMessage="No diary entries yet. Pick a quote that hit hard this week."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pinned for the long run</h2>
        <DataTable
          rows={pinned}
          columns={pinnedCols}
          rowKey={(r) => r.id}
          emptyMessage="Nothing pinned yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open applied-this-week actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r) => r.action_id}
          emptyMessage="No open actions. Quotes are inspiration only until acted on."
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Theme breakdown</h2>
          <DataTable
            rows={themes}
            columns={themeCols}
            rowKey={(r) => r.theme_tag}
            emptyMessage="No themes tracked yet."
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Source breakdown</h2>
          <DataTable
            rows={sources}
            columns={sourceCols}
            rowKey={(r) => r.source_type}
            emptyMessage="No sources logged."
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Most-quoted authors</h2>
        <DataTable
          rows={authors}
          columns={authorCols}
          rowKey={(r) => r.quote_author}
          emptyMessage="No authors yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">12-week cadence</h2>
        <DataTable
          rows={cadence}
          columns={cadenceCols}
          rowKey={(r) => r.week_starting}
          emptyMessage="No cadence data yet — log a quote this week."
        />
      </section>

      <footer className="text-xs text-gray-500 pt-6 border-t">
        Round r2337 · founder-only · 2 tables & 7 RPCs · is_founder() gated.
      </footer>
    </div>
  );
}
