import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Pattern = {
  id: string;
  pattern_rank: number;
  pattern_name: string;
  pattern_category: string;
  batches_observed_in: number;
  bugs_prevented_count: number;
  evidence_summary: string;
  remediation_codified_in: string | null;
  noted_at: string;
};

type Direction = {
  id: string;
  direction_rank: number;
  direction_title: string;
  strategic_theme: string;
  target_batch_window: string;
  expected_ship_count: number;
  rationale: string;
  success_metric: string;
};

type PatternRollup = {
  pattern_category: string;
  patterns_count: number;
  total_bugs_prevented: number;
  total_batches_observed: number;
};

type ThemeRollup = {
  strategic_theme: string;
  directions_count: number;
  total_expected_ships: number;
};

type Stats = {
  patterns_logged: number;
  total_bugs_prevented: number;
  directions_logged: number;
  total_expected_ships: number;
  avg_bugs_per_pattern: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [patternsRes, directionsRes, patternRollupRes, themeRollupRes, statsRes] =
    await Promise.all([
      supabase.rpc('founder_r2385_list_patterns'),
      supabase.rpc('founder_r2385_list_directions'),
      supabase.rpc('founder_r2385_pattern_category_rollup'),
      supabase.rpc('founder_r2385_direction_theme_rollup'),
      supabase.rpc('founder_r2385_milestone_stats'),
    ]);

  const patterns: Pattern[] = (patternsRes.data ?? []) as Pattern[];
  const directions: Direction[] = (directionsRes.data ?? []) as Direction[];
  const patternRollup: PatternRollup[] = (patternRollupRes.data ?? []) as PatternRollup[];
  const themeRollup: ThemeRollup[] = (themeRollupRes.data ?? []) as ThemeRollup[];
  const stats: Stats | null =
    Array.isArray(statsRes.data) && statsRes.data.length > 0
      ? (statsRes.data[0] as Stats)
      : null;

  const patternColumns: Column<any>[] = [
    { key: 'pattern_rank', header: '#', render: (r: Pattern) => <span>{r.pattern_rank}</span> },
    { key: 'pattern_name', header: 'Pattern', render: (r: Pattern) => <span>{r.pattern_name}</span> },
    { key: 'pattern_category', header: 'Category', render: (r: Pattern) => <span>{r.pattern_category}</span> },
    { key: 'batches_observed_in', header: 'Batches', render: (r: Pattern) => <span>{r.batches_observed_in}</span> },
    { key: 'bugs_prevented_count', header: 'Bugs Prevented', render: (r: Pattern) => <span>{r.bugs_prevented_count}</span> },
    { key: 'evidence_summary', header: 'Evidence', render: (r: Pattern) => <span>{r.evidence_summary}</span> },
    { key: 'remediation_codified_in', header: 'Codified In', render: (r: Pattern) => <span>{r.remediation_codified_in ?? '—'}</span> },
  ];

  const directionColumns: Column<any>[] = [
    { key: 'direction_rank', header: '#', render: (r: Direction) => <span>{r.direction_rank}</span> },
    { key: 'direction_title', header: 'Direction', render: (r: Direction) => <span>{r.direction_title}</span> },
    { key: 'strategic_theme', header: 'Theme', render: (r: Direction) => <span>{r.strategic_theme}</span> },
    { key: 'target_batch_window', header: 'Batch Window', render: (r: Direction) => <span>{r.target_batch_window}</span> },
    { key: 'expected_ship_count', header: 'Expected Ships', render: (r: Direction) => <span>{r.expected_ship_count}</span> },
    { key: 'rationale', header: 'Rationale', render: (r: Direction) => <span>{r.rationale}</span> },
    { key: 'success_metric', header: 'Success Metric', render: (r: Direction) => <span>{r.success_metric}</span> },
  ];

  const patternRollupColumns: Column<any>[] = [
    { key: 'pattern_category', header: 'Category', render: (r: PatternRollup) => <span>{r.pattern_category}</span> },
    { key: 'patterns_count', header: 'Patterns', render: (r: PatternRollup) => <span>{r.patterns_count}</span> },
    { key: 'total_bugs_prevented', header: 'Bugs Prevented', render: (r: PatternRollup) => <span>{r.total_bugs_prevented}</span> },
    { key: 'total_batches_observed', header: 'Batches Observed', render: (r: PatternRollup) => <span>{r.total_batches_observed}</span> },
  ];

  const themeRollupColumns: Column<any>[] = [
    { key: 'strategic_theme', header: 'Theme', render: (r: ThemeRollup) => <span>{r.strategic_theme}</span> },
    { key: 'directions_count', header: 'Directions', render: (r: ThemeRollup) => <span>{r.directions_count}</span> },
    { key: 'total_expected_ships', header: 'Expected Ships', render: (r: ThemeRollup) => <span>{r.total_expected_ships}</span> },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">270-Batch Milestone Reflection</h1>
        <p className="text-sm text-gray-600">
          Top 10 system-level patterns learned across 270 batches & the next-270 strategic direction.
        </p>
      </header>

      {stats && (
        <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Patterns Logged</div>
            <div className="text-xl font-semibold">{stats.patterns_logged}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Bugs Prevented</div>
            <div className="text-xl font-semibold">{stats.total_bugs_prevented}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Directions Logged</div>
            <div className="text-xl font-semibold">{stats.directions_logged}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Expected Next-270 Ships</div>
            <div className="text-xl font-semibold">{stats.total_expected_ships}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Avg Bugs / Pattern</div>
            <div className="text-xl font-semibold">{stats.avg_bugs_per_pattern}</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Top 10 Patterns Learned</h2>
        <DataTable
          rows={patterns}
          columns={patternColumns}
          rowKey={(r: Pattern) => r.id}
          emptyMessage="No patterns logged yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pattern Category Rollup</h2>
        <DataTable
          rows={patternRollup}
          columns={patternRollupColumns}
          rowKey={(r: PatternRollup) => r.pattern_category}
          emptyMessage="No category rollup yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Next-270 Strategic Directions</h2>
        <DataTable
          rows={directions}
          columns={directionColumns}
          rowKey={(r: Direction) => r.id}
          emptyMessage="No directions logged yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Direction Theme Rollup</h2>
        <DataTable
          rows={themeRollup}
          columns={themeRollupColumns}
          rowKey={(r: ThemeRollup) => r.strategic_theme}
          emptyMessage="No theme rollup yet."
        />
      </section>
    </div>
  );
}
