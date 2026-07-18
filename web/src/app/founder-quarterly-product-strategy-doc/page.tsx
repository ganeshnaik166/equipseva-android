import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlyProductStrategyDocPage() {
  const supabase = await getSupabaseServerClient();

  const [
    docsRes,
    pivotsRes,
    alignTrendRes,
    pivotBreakdownRes,
    boardResponseRes,
    confidenceTrendRes,
    latestLockedRes,
  ] = await Promise.all([
    supabase.rpc('list_strategy_docs_r2561'),
    supabase.rpc('list_pivot_events_r2561'),
    supabase.rpc('alignment_score_trend_r2561'),
    supabase.rpc('pivot_kind_breakdown_r2561'),
    supabase.rpc('board_response_summary_r2561'),
    supabase.rpc('quarterly_confidence_trend_r2561'),
    supabase.rpc('latest_locked_strategy_r2561'),
  ]);

  const docs = (docsRes.data ?? []) as any[];
  const pivots = (pivotsRes.data ?? []) as any[];
  const alignTrend = (alignTrendRes.data ?? []) as any[];
  const pivotBreakdown = (pivotBreakdownRes.data ?? []) as any[];
  const boardResponse = (boardResponseRes.data ?? []) as any[];
  const confidenceTrend = (confidenceTrendRes.data ?? []) as any[];
  const latestLocked = (latestLockedRes.data ?? []) as any[];

  const docCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'board_alignment_score', header: 'Board align', render: (r: any) => `${r.board_alignment_score}/100` },
    { key: 'founder_self_confidence_score', header: 'Founder conf', render: (r: any) => `${r.founder_self_confidence_score}/100` },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    {
      key: 'created_at',
      header: 'Created',
      render: (r: any) => (r.created_at ? new Date(r.created_at).toLocaleDateString() : '-'),
    },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const pivotCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    {
      key: 'pivot_at',
      header: 'Pivot at',
      render: (r: any) => (r.pivot_at ? new Date(r.pivot_at).toLocaleDateString() : '-'),
    },
    { key: 'pivot_kind', header: 'Kind', render: (r: any) => r.pivot_kind },
    { key: 'pivot_summary_md', header: 'Summary', render: (r: any) => r.pivot_summary_md ?? '-' },
    { key: 'board_response_kind', header: 'Board response', render: (r: any) => r.board_response_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const alignTrendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    { key: 'board_alignment_score', header: 'Board align', render: (r: any) => `${r.board_alignment_score}/100` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    {
      key: 'created_at',
      header: 'Created',
      render: (r: any) => (r.created_at ? new Date(r.created_at).toLocaleDateString() : '-'),
    },
  ];

  const pivotBreakdownCols: Column<any>[] = [
    { key: 'pivot_kind', header: 'Pivot kind', render: (r: any) => r.pivot_kind },
    { key: 'event_count', header: 'Events', render: (r: any) => r.event_count },
  ];

  const boardResponseCols: Column<any>[] = [
    { key: 'board_response_kind', header: 'Board response', render: (r: any) => r.board_response_kind },
    { key: 'event_count', header: 'Events', render: (r: any) => r.event_count },
  ];

  const confidenceCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    { key: 'founder_self_confidence_score', header: 'Founder conf', render: (r: any) => `${r.founder_self_confidence_score}/100` },
    { key: 'board_alignment_score', header: 'Board align', render: (r: any) => `${r.board_alignment_score}/100` },
    { key: 'confidence_gap', header: 'Gap', render: (r: any) => r.confidence_gap },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const lockedCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'version_label', header: 'Version', render: (r: any) => r.version_label },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'board_alignment_score', header: 'Board align', render: (r: any) => `${r.board_alignment_score}/100` },
    { key: 'founder_self_confidence_score', header: 'Founder conf', render: (r: any) => `${r.founder_self_confidence_score}/100` },
    { key: 'greenlights_md', header: 'Greenlights', render: (r: any) => r.greenlights_md ?? '-' },
    { key: 'kill_candidates_md', header: 'Kills', render: (r: any) => r.kill_candidates_md ?? '-' },
    { key: 'pivots_md', header: 'Pivots', render: (r: any) => r.pivots_md ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder &gt; Quarterly Product Strategy Doc</h1>
        <p className="text-sm text-gray-600 mt-1">
          Quarter & version &gt; pivots & kill candidates & greenlights &gt; board alignment & founder confidence.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Latest locked strategy</h2>
        <DataTable
          rows={latestLocked}
          columns={lockedCols}
          emptyMessage="No locked strategy yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Strategy docs</h2>
        <DataTable
          rows={docs}
          columns={docCols}
          emptyMessage="No strategy docs yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Pivot events</h2>
        <DataTable
          rows={pivots}
          columns={pivotCols}
          emptyMessage="No pivot events yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Alignment score trend</h2>
        <DataTable
          rows={alignTrend}
          columns={alignTrendCols}
          emptyMessage="No alignment data yet."
          rowKey={(r: any, i: number) => String(`${r.quarter_label}-${r.version_label}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Quarterly confidence trend</h2>
        <DataTable
          rows={confidenceTrend}
          columns={confidenceCols}
          emptyMessage="No confidence data yet."
          rowKey={(r: any, i: number) => String(`${r.quarter_label}-${r.version_label}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Pivot kind breakdown</h2>
        <DataTable
          rows={pivotBreakdown}
          columns={pivotBreakdownCols}
          emptyMessage="No pivots yet."
          rowKey={(r: any, i: number) => String(r.pivot_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Board response summary</h2>
        <DataTable
          rows={boardResponse}
          columns={boardResponseCols}
          emptyMessage="No board responses yet."
          rowKey={(r: any, i: number) => String(r.board_response_kind ?? i)}
        />
      </section>
    </main>
  );
}