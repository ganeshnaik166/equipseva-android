import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ReelRow = {
  id: string;
  captured_at: string;
  investor_name: string;
  investor_firm: string | null;
  investor_stage: string;
  quote_text: string;
  theme: string;
  sentiment: string;
  worth_remembering_score: number;
  founder_learning: string;
  pinned_to_board_deck: boolean;
};

type ThemeRow = {
  theme: string;
  quote_count: number;
  avg_score: number;
  positive_count: number;
  concern_count: number;
  pinned_count: number;
};

type TopRow = {
  id: string;
  captured_at: string;
  investor_name: string;
  quote_text: string;
  theme: string;
  worth_remembering_score: number;
  founder_learning: string;
};

type TrendRow = {
  week_starting: string;
  total_quotes: number;
  signal_count: number;
  concern_count: number;
  net_score: number;
};

type PinnedRow = {
  id: string;
  captured_at: string;
  investor_name: string;
  investor_firm: string | null;
  quote_text: string;
  theme: string;
  founder_learning: string;
};

type StageRow = {
  investor_stage: string;
  quote_count: number;
  avg_score: number;
  unique_investors: number;
};

type ChangedRow = {
  id: string;
  captured_at: string;
  investor_name: string;
  quote_text: string;
  founder_learning: string;
  action_implication: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [reel, themes, top, trend, pinned, stages, changed] = await Promise.all([
    supabase.rpc('fn_iqh_r2325_weekly_reel', { p_week_starting: null }),
    supabase.rpc('fn_iqh_r2325_theme_rollup', { p_week_starting: null }),
    supabase.rpc('fn_iqh_r2325_top_quotes', { p_limit: 20 }),
    supabase.rpc('fn_iqh_r2325_sentiment_trend', { p_weeks: 8 }),
    supabase.rpc('fn_iqh_r2325_board_pinned'),
    supabase.rpc('fn_iqh_r2325_stage_breakdown'),
    supabase.rpc('fn_iqh_r2325_changed_thinking'),
  ]);

  const reelRows: ReelRow[] = (reel.data as ReelRow[] | null) ?? [];
  const themeRows: ThemeRow[] = (themes.data as ThemeRow[] | null) ?? [];
  const topRows: TopRow[] = (top.data as TopRow[] | null) ?? [];
  const trendRows: TrendRow[] = (trend.data as TrendRow[] | null) ?? [];
  const pinnedRows: PinnedRow[] = (pinned.data as PinnedRow[] | null) ?? [];
  const stageRows: StageRow[] = (stages.data as StageRow[] | null) ?? [];
  const changedRows: ChangedRow[] = (changed.data as ChangedRow[] | null) ?? [];

  const reelCols: Column<ReelRow>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: ReelRow) => new Date(r.captured_at).toLocaleDateString() },
    { key: 'investor_name', header: 'Investor', render: (r: ReelRow) => `${r.investor_name}${r.investor_firm ? ' / ' + r.investor_firm : ''}` },
    { key: 'investor_stage', header: 'Stage', render: (r: ReelRow) => r.investor_stage },
    { key: 'quote_text', header: 'Quote', render: (r: ReelRow) => <span style={{ fontStyle: 'italic' }}>“{r.quote_text}”</span> },
    { key: 'theme', header: 'Theme', render: (r: ReelRow) => r.theme },
    { key: 'sentiment', header: 'Sentiment', render: (r: ReelRow) => r.sentiment },
    { key: 'worth_remembering_score', header: 'Score', render: (r: ReelRow) => `${r.worth_remembering_score}/5` },
    { key: 'founder_learning', header: 'Learning', render: (r: ReelRow) => r.founder_learning },
    { key: 'pinned_to_board_deck', header: 'Pinned', render: (r: ReelRow) => (r.pinned_to_board_deck ? 'yes' : '-') },
  ];

  const themeCols: Column<ThemeRow>[] = [
    { key: 'theme', header: 'Theme', render: (r: ThemeRow) => r.theme },
    { key: 'quote_count', header: 'Quotes', render: (r: ThemeRow) => r.quote_count },
    { key: 'avg_score', header: 'Avg score', render: (r: ThemeRow) => r.avg_score },
    { key: 'positive_count', header: 'Positive', render: (r: ThemeRow) => r.positive_count },
    { key: 'concern_count', header: 'Concern', render: (r: ThemeRow) => r.concern_count },
    { key: 'pinned_count', header: 'Pinned', render: (r: ThemeRow) => r.pinned_count },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'captured_at', header: 'When', render: (r: TopRow) => new Date(r.captured_at).toLocaleDateString() },
    { key: 'investor_name', header: 'Investor', render: (r: TopRow) => r.investor_name },
    { key: 'quote_text', header: 'Quote', render: (r: TopRow) => <span style={{ fontStyle: 'italic' }}>“{r.quote_text}”</span> },
    { key: 'theme', header: 'Theme', render: (r: TopRow) => r.theme },
    { key: 'worth_remembering_score', header: 'Score', render: (r: TopRow) => `${r.worth_remembering_score}/5` },
    { key: 'founder_learning', header: 'Learning', render: (r: TopRow) => r.founder_learning },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'week_starting', header: 'Week', render: (r: TrendRow) => new Date(r.week_starting).toLocaleDateString() },
    { key: 'total_quotes', header: 'Quotes', render: (r: TrendRow) => r.total_quotes },
    { key: 'signal_count', header: 'Signal', render: (r: TrendRow) => r.signal_count },
    { key: 'concern_count', header: 'Concern', render: (r: TrendRow) => r.concern_count },
    { key: 'net_score', header: 'Net score', render: (r: TrendRow) => r.net_score },
  ];

  const pinnedCols: Column<PinnedRow>[] = [
    { key: 'captured_at', header: 'When', render: (r: PinnedRow) => new Date(r.captured_at).toLocaleDateString() },
    { key: 'investor_name', header: 'Investor', render: (r: PinnedRow) => `${r.investor_name}${r.investor_firm ? ' / ' + r.investor_firm : ''}` },
    { key: 'quote_text', header: 'Quote', render: (r: PinnedRow) => <span style={{ fontStyle: 'italic' }}>“{r.quote_text}”</span> },
    { key: 'theme', header: 'Theme', render: (r: PinnedRow) => r.theme },
    { key: 'founder_learning', header: 'Learning', render: (r: PinnedRow) => r.founder_learning },
  ];

  const stageCols: Column<StageRow>[] = [
    { key: 'investor_stage', header: 'Stage', render: (r: StageRow) => r.investor_stage },
    { key: 'quote_count', header: 'Quotes', render: (r: StageRow) => r.quote_count },
    { key: 'avg_score', header: 'Avg score', render: (r: StageRow) => r.avg_score },
    { key: 'unique_investors', header: 'Investors', render: (r: StageRow) => r.unique_investors },
  ];

  const changedCols: Column<ChangedRow>[] = [
    { key: 'captured_at', header: 'When', render: (r: ChangedRow) => new Date(r.captured_at).toLocaleDateString() },
    { key: 'investor_name', header: 'Investor', render: (r: ChangedRow) => r.investor_name },
    { key: 'quote_text', header: 'Quote', render: (r: ChangedRow) => <span style={{ fontStyle: 'italic' }}>“{r.quote_text}”</span> },
    { key: 'founder_learning', header: 'Learning', render: (r: ChangedRow) => r.founder_learning },
    { key: 'action_implication', header: 'Action', render: (r: ChangedRow) => r.action_implication ?? '-' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Quote Highlight Reel</h1>
      <p style={{ color: '#6b7280', marginBottom: 24 }}>
        Quotes from investor conversations worth remembering — theme tagged, learning extracted, pinned to board deck when useful.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>This week's reel</h2>
        <DataTable<ReelRow>
          columns={reelCols}
          rows={reelRows}
          rowKey={(r: ReelRow) => r.id}
          emptyMessage="No quotes captured this week yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Theme rollup — this week</h2>
        <DataTable<ThemeRow>
          columns={themeCols}
          rows={themeRows}
          rowKey={(r: ThemeRow) => r.theme}
          emptyMessage="No themes this week."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top quotes all-time (score &gt;= 4)</h2>
        <DataTable<TopRow>
          columns={topCols}
          rows={topRows}
          rowKey={(r: TopRow) => r.id}
          emptyMessage="No top quotes recorded yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Sentiment trend — last 8 weeks</h2>
        <DataTable<TrendRow>
          columns={trendCols}
          rows={trendRows}
          rowKey={(r: TrendRow) => r.week_starting}
          emptyMessage="No sentiment history yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pinned to board deck</h2>
        <DataTable<PinnedRow>
          columns={pinnedCols}
          rows={pinnedRows}
          rowKey={(r: PinnedRow) => r.id}
          emptyMessage="No board-pinned quotes."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Stage breakdown</h2>
        <DataTable<StageRow>
          columns={stageCols}
          rows={stageRows}
          rowKey={(r: StageRow) => r.investor_stage}
          emptyMessage="No investor-stage data yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Quotes that changed founder thinking</h2>
        <DataTable<ChangedRow>
          columns={changedCols}
          rows={changedRows}
          rowKey={(r: ChangedRow) => r.id}
          emptyMessage="No thinking-changing quotes recorded."
        />
      </section>
    </div>
  );
}
