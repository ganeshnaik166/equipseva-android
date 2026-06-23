import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyStrategicPrioritizationGridPage() {
  const supabase = await getSupabaseServerClient();

  const [
    gridRes,
    reviewsRes,
    topIceRes,
    kindDistRes,
    killRes,
    monthlyTrendRes,
    leverageRes,
  ] = await Promise.all([
    supabase.rpc('list_grid_r2565'),
    supabase.rpc('list_decision_reviews_r2565'),
    supabase.rpc('top_ice_priorities_r2565'),
    supabase.rpc('kind_distribution_r2565'),
    supabase.rpc('kill_pipeline_r2565'),
    supabase.rpc('monthly_grid_trend_r2565'),
    supabase.rpc('leverage_score_summary_r2565'),
  ]);

  const grid = (gridRes.data ?? []) as any[];
  const reviews = (reviewsRes.data ?? []) as any[];
  const topIce = (topIceRes.data ?? []) as any[];
  const kindDist = (kindDistRes.data ?? []) as any[];
  const kills = (killRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const leverage = (leverageRes.data ?? []) as any[];

  const gridCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'priority_title', header: 'Priority', render: (r: any) => r.priority_title },
    { key: 'ice_score', header: 'ICE', render: (r: any) => r.ice_score },
    { key: 'effort_hours', header: 'Effort (h)', render: (r: any) => r.effort_hours },
    { key: 'leverage_score', header: 'Leverage', render: (r: any) => r.leverage_score },
    { key: 'kind', header: 'Kind', render: (r: any) => r.kind },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => new Date(r.reviewed_at).toLocaleString() },
    { key: 'priority_title', header: 'Priority', render: (r: any) => r.priority_title },
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'review_kind', header: 'Review Kind', render: (r: any) => r.review_kind },
    { key: 'outcome_md', header: 'Outcome', render: (r: any) => r.outcome_md ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const topIceCols: Column<any>[] = [
    { key: 'priority_title', header: 'Priority', render: (r: any) => r.priority_title },
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'ice_score', header: 'ICE', render: (r: any) => r.ice_score },
    { key: 'effort_hours', header: 'Effort (h)', render: (r: any) => r.effort_hours },
    { key: 'leverage_score', header: 'Leverage', render: (r: any) => r.leverage_score },
    { key: 'kind', header: 'Kind', render: (r: any) => r.kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindDistCols: Column<any>[] = [
    { key: 'kind', header: 'Kind', render: (r: any) => r.kind },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
    { key: 'avg_ice', header: 'Avg ICE', render: (r: any) => r.avg_ice },
    { key: 'avg_leverage', header: 'Avg Leverage', render: (r: any) => r.avg_leverage },
    { key: 'total_effort_hours', header: 'Total Effort (h)', render: (r: any) => r.total_effort_hours },
  ];

  const killCols: Column<any>[] = [
    { key: 'priority_title', header: 'Priority', render: (r: any) => r.priority_title },
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'ice_score', header: 'ICE', render: (r: any) => r.ice_score },
    { key: 'effort_hours', header: 'Effort (h)', render: (r: any) => r.effort_hours },
    { key: 'decision_kind', header: 'Decision', render: (r: any) => r.decision_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'total_items', header: 'Total', render: (r: any) => r.total_items },
    { key: 'ship_count', header: 'Ship', render: (r: any) => r.ship_count },
    { key: 'kill_count', header: 'Kill', render: (r: any) => r.kill_count },
    { key: 'delegate_count', header: 'Delegate', render: (r: any) => r.delegate_count },
    { key: 'explore_count', header: 'Explore', render: (r: any) => r.explore_count },
    { key: 'avg_ice', header: 'Avg ICE', render: (r: any) => r.avg_ice },
    { key: 'total_effort_hours', header: 'Total Effort (h)', render: (r: any) => r.total_effort_hours },
  ];

  const leverageCols: Column<any>[] = [
    { key: 'leverage_band', header: 'Leverage Band', render: (r: any) => r.leverage_band },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
    { key: 'avg_ice', header: 'Avg ICE', render: (r: any) => r.avg_ice },
    { key: 'avg_effort_hours', header: 'Avg Effort (h)', render: (r: any) => r.avg_effort_hours },
    { key: 'ship_count', header: 'Ship Count', render: (r: any) => r.ship_count },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Founder Monthly Strategic Prioritization Grid
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        ICE-scored priorities & leverage scoring across kill / ship / delegate / explore.
        Round 2565.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Priority grid</h2>
        <DataTable
          rows={grid}
          columns={gridCols}
          emptyMessage="No priorities yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top ICE priorities</h2>
        <DataTable
          rows={topIce}
          columns={topIceCols}
          emptyMessage="No top priorities"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Kind distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindDistCols}
          emptyMessage="No kind distribution"
          rowKey={(r: any, i: number) => String(r.kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Kill pipeline</h2>
        <DataTable
          rows={kills}
          columns={killCols}
          emptyMessage="No kills"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Monthly grid trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyTrendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Leverage score summary</h2>
        <DataTable
          rows={leverage}
          columns={leverageCols}
          emptyMessage="No leverage data"
          rowKey={(r: any, i: number) => String(r.leverage_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Decision reviews</h2>
        <DataTable
          rows={reviews}
          columns={reviewCols}
          emptyMessage="No reviews yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
