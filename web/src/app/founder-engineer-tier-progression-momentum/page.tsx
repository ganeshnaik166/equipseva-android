import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerTierProgressionMomentumPage() {
  const supabase = await getSupabaseServerClient();

  const [momentum, pipeline, stagnant, distribution, expected, tierDist, weekly] = await Promise.all([
    supabase.rpc('list_momentum_r2506'),
    supabase.rpc('list_promotion_pipeline_r2506'),
    supabase.rpc('top_stagnant_engineers_r2506'),
    supabase.rpc('momentum_distribution_r2506'),
    supabase.rpc('expected_promotions_this_quarter_r2506'),
    supabase.rpc('tier_distribution_r2506'),
    supabase.rpc('weekly_promotion_trend_r2506'),
  ]);

  const momentumRows = (momentum.data ?? []) as any[];
  const pipelineRows = (pipeline.data ?? []) as any[];
  const stagnantRows = (stagnant.data ?? []) as any[];
  const distributionRows = (distribution.data ?? []) as any[];
  const expectedRows = (expected.data ?? []) as any[];
  const tierDistRows = (tierDist.data ?? []) as any[];
  const weeklyRows = (weekly.data ?? []) as any[];

  const momentumCols: Column<any>[] = [
    { key: 'current_tier', header: 'Tier', render: (r: any) => r.current_tier },
    { key: 'days_at_tier', header: 'Days at Tier', render: (r: any) => r.days_at_tier },
    { key: 'points_this_month', header: 'Points (Month)', render: (r: any) => r.points_this_month },
    { key: 'points_to_next', header: 'Points to Next', render: (r: any) => r.points_to_next },
    { key: 'momentum_kind', header: 'Momentum', render: (r: any) => r.momentum_kind },
    { key: 'stagnation_risk', header: 'Risk', render: (r: any) => r.stagnation_risk },
    { key: 'top_blocker', header: 'Top Blocker', render: (r: any) => r.top_blocker ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'target_tier', header: 'Target Tier', render: (r: any) => r.target_tier },
    { key: 'expected_promotion_at', header: 'Expected', render: (r: any) => r.expected_promotion_at ? new Date(r.expected_promotion_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'promoted_at', header: 'Promoted', render: (r: any) => r.promoted_at ? new Date(r.promoted_at).toLocaleDateString() : '-' },
    { key: 'blockers_md', header: 'Blockers', render: (r: any) => r.blockers_md ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const stagnantCols: Column<any>[] = [
    { key: 'current_tier', header: 'Tier', render: (r: any) => r.current_tier },
    { key: 'days_at_tier', header: 'Days at Tier', render: (r: any) => r.days_at_tier },
    { key: 'stagnation_risk', header: 'Risk', render: (r: any) => r.stagnation_risk },
    { key: 'top_blocker', header: 'Blocker', render: (r: any) => r.top_blocker ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const distributionCols: Column<any>[] = [
    { key: 'momentum_kind', header: 'Momentum', render: (r: any) => r.momentum_kind },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
    { key: 'avg_days_at_tier', header: 'Avg Days at Tier', render: (r: any) => r.avg_days_at_tier },
  ];

  const expectedCols: Column<any>[] = [
    { key: 'target_tier', header: 'Target Tier', render: (r: any) => r.target_tier },
    { key: 'expected_count', header: 'Expected (Quarter)', render: (r: any) => r.expected_count },
    { key: 'in_progress_count', header: 'In Progress', render: (r: any) => r.in_progress_count },
    { key: 'planned_count', header: 'Planned', render: (r: any) => r.planned_count },
  ];

  const tierDistCols: Column<any>[] = [
    { key: 'current_tier', header: 'Tier', render: (r: any) => r.current_tier },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
    { key: 'avg_points_this_month', header: 'Avg Points (Month)', render: (r: any) => r.avg_points_this_month },
    { key: 'high_risk_count', header: 'High Risk', render: (r: any) => r.high_risk_count },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => new Date(r.week_start).toLocaleDateString() },
    { key: 'promoted_count', header: 'Promoted', render: (r: any) => r.promoted_count },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => r.dropped_count },
    { key: 'net_progress', header: 'Net Progress', render: (r: any) => r.net_progress },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Tier Progression & Momentum</h1>
        <p className="text-sm text-gray-600 mt-1">
          Tier velocity, stagnation risk, and promotion pipeline across the engineer base.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier Distribution</h2>
        <DataTable
          rows={tierDistRows}
          columns={tierDistCols}
          emptyMessage="No tier distribution data."
          rowKey={(r: any, i: number) => String(r.current_tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Momentum Distribution</h2>
        <DataTable
          rows={distributionRows}
          columns={distributionCols}
          emptyMessage="No momentum data."
          rowKey={(r: any, i: number) => String(r.momentum_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Momentum (All)</h2>
        <DataTable
          rows={momentumRows}
          columns={momentumCols}
          emptyMessage="No momentum records yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Stagnant Engineers</h2>
        <DataTable
          rows={stagnantRows}
          columns={stagnantCols}
          emptyMessage="No stagnant engineers - all moving."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Promotion Pipeline</h2>
        <DataTable
          rows={pipelineRows}
          columns={pipelineCols}
          emptyMessage="No pipeline entries."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Expected Promotions This Quarter</h2>
        <DataTable
          rows={expectedRows}
          columns={expectedCols}
          emptyMessage="No expected promotions."
          rowKey={(r: any, i: number) => String(r.target_tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Promotion Trend</h2>
        <DataTable
          rows={weeklyRows}
          columns={weeklyCols}
          emptyMessage="No weekly trend data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>
    </div>
  );
}
