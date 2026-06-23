import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    narrativesRes,
    arcRes,
    trendRes,
    themeRes,
    pivotRes,
    alignmentRes,
    consistencyRes,
  ] = await Promise.all([
    supabase.rpc('list_narratives_r2541'),
    supabase.rpc('list_arc_evolution_r2541'),
    supabase.rpc('quarterly_confidence_trend_r2541'),
    supabase.rpc('narrative_theme_breakdown_r2541'),
    supabase.rpc('pivot_focus_r2541'),
    supabase.rpc('board_alignment_summary_r2541'),
    supabase.rpc('consistency_score_distribution_r2541'),
  ]);

  const narratives = (narrativesRes.data ?? []) as any[];
  const arc = (arcRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const themes = (themeRes.data ?? []) as any[];
  const pivots = (pivotRes.data ?? []) as any[];
  const alignment = (alignmentRes.data ?? []) as any[];
  const consistency = (consistencyRes.data ?? []) as any[];

  const narrativeCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'narrative_theme', header: 'Theme', render: (r: any) => r.narrative_theme },
    { key: 'confidence_score', header: 'Confidence', render: (r: any) => `${r.confidence_score}%` },
    { key: 'consistency_with_prior_quarter', header: 'Consistency', render: (r: any) => `${r.consistency_with_prior_quarter}%` },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const arcCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'prior_quarter_label', header: 'Prior', render: (r: any) => r.prior_quarter_label ?? '-' },
    { key: 'theme_continuity_kind', header: 'Continuity', render: (r: any) => r.theme_continuity_kind },
    { key: 'change_summary_md', header: 'Change Summary', render: (r: any) => r.change_summary_md ?? '-' },
    { key: 'founder_confidence_delta_pct', header: 'Conf Delta', render: (r: any) => `${r.founder_confidence_delta_pct > 0 ? '+' : ''}${r.founder_confidence_delta_pct}%` },
    { key: 'board_received_kind', header: 'Board Received', render: (r: any) => r.board_received_kind },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'confidence_score', header: 'Confidence', render: (r: any) => `${r.confidence_score}%` },
    { key: 'consistency_with_prior_quarter', header: 'Consistency', render: (r: any) => `${r.consistency_with_prior_quarter}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const themeCols: Column<any>[] = [
    { key: 'narrative_theme', header: 'Theme', render: (r: any) => r.narrative_theme },
    { key: 'narrative_count', header: 'Count', render: (r: any) => r.narrative_count },
    { key: 'avg_confidence', header: 'Avg Confidence', render: (r: any) => `${r.avg_confidence}%` },
  ];

  const pivotCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'prior_quarter_label', header: 'Prior', render: (r: any) => r.prior_quarter_label ?? '-' },
    { key: 'theme_continuity_kind', header: 'Kind', render: (r: any) => r.theme_continuity_kind },
    { key: 'change_summary_md', header: 'Summary', render: (r: any) => r.change_summary_md ?? '-' },
    { key: 'founder_confidence_delta_pct', header: 'Delta', render: (r: any) => `${r.founder_confidence_delta_pct > 0 ? '+' : ''}${r.founder_confidence_delta_pct}%` },
  ];

  const alignmentCols: Column<any>[] = [
    { key: 'board_received_kind', header: 'Board Reception', render: (r: any) => r.board_received_kind },
    { key: 'evolution_count', header: 'Count', render: (r: any) => r.evolution_count },
    { key: 'avg_confidence_delta', header: 'Avg Delta', render: (r: any) => `${r.avg_confidence_delta}%` },
  ];

  const consistencyCols: Column<any>[] = [
    { key: 'consistency_band', header: 'Consistency Band', render: (r: any) => r.consistency_band },
    { key: 'narrative_count', header: 'Count', render: (r: any) => r.narrative_count },
    { key: 'avg_confidence', header: 'Avg Confidence', render: (r: any) => `${r.avg_confidence}%` },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Board Deck & Narrative Arc</h1>
        <p className="text-sm text-gray-500">
          Track quarter-by-quarter board narratives, theme continuity & board reception across time.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Quarterly Narratives</h2>
        <DataTable
          rows={narratives}
          columns={narrativeCols}
          emptyMessage="No narratives yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Narrative Arc Evolution</h2>
        <DataTable
          rows={arc}
          columns={arcCols}
          emptyMessage="No arc transitions tracked"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Confidence Trend (ASC)</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Theme Breakdown</h2>
        <DataTable
          rows={themes}
          columns={themeCols}
          emptyMessage="No theme data"
          rowKey={(r: any, i: number) => String(r.narrative_theme ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Pivot & New-Thread Focus</h2>
        <DataTable
          rows={pivots}
          columns={pivotCols}
          emptyMessage="No pivots logged"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Board Alignment Summary</h2>
        <DataTable
          rows={alignment}
          columns={alignmentCols}
          emptyMessage="No alignment data"
          rowKey={(r: any, i: number) => String(r.board_received_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Consistency Score Distribution</h2>
        <DataTable
          rows={consistency}
          columns={consistencyCols}
          emptyMessage="No consistency data"
          rowKey={(r: any, i: number) => String(r.consistency_band ?? i)}
        />
      </section>
    </div>
  );
}
