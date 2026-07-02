import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summary, recent, byArea, direction, movers, impact, trend] = await Promise.all([
    sb.rpc('founder_priority_shift_summary_r2261'),
    sb.rpc('founder_priority_shift_recent_r2261'),
    sb.rpc('founder_priority_shift_by_area_r2261'),
    sb.rpc('founder_priority_shift_direction_breakdown_r2261'),
    sb.rpc('founder_priority_shift_top_movers_r2261'),
    sb.rpc('founder_priority_shift_impact_summary_r2261'),
    sb.rpc('founder_priority_shift_weekly_trend_r2261'),
  ]);

  const s = (summary.data ?? [])[0] ?? {};
  const recentRows = recent.data ?? [];
  const areaRows = byArea.data ?? [];
  const dirRows = direction.data ?? [];
  const moverRows = movers.data ?? [];
  const impactRows = impact.data ?? [];
  const trendRows = trend.data ?? [];

  const recentCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r) => r.week_start },
    { key: 'priority_area', header: 'Area', render: (r) => r.priority_area },
    { key: 'prior_rank', header: 'Prior Rank', render: (r) => r.prior_rank },
    { key: 'current_rank', header: 'Now Rank', render: (r) => r.current_rank },
    { key: 'shift_direction', header: 'Dir', render: (r) => r.shift_direction },
    { key: 'shift_magnitude', header: 'Mag', render: (r) => r.shift_magnitude },
    { key: 'rationale', header: 'Rationale', render: (r) => r.rationale },
  ];

  const areaCols: Column<any>[] = [
    { key: 'priority_area', header: 'Area', render: (r) => r.priority_area },
    { key: 'shift_count', header: 'Shifts', render: (r) => r.shift_count },
    { key: 'avg_magnitude', header: 'Avg Mag', render: (r) => r.avg_magnitude },
    { key: 'up_moves', header: 'Up', render: (r) => r.up_moves },
    { key: 'down_moves', header: 'Down', render: (r) => r.down_moves },
  ];

  const dirCols: Column<any>[] = [
    { key: 'shift_direction', header: 'Direction', render: (r) => r.shift_direction },
    { key: 'count_shifts', header: 'Count', render: (r) => r.count_shifts },
    { key: 'pct_share', header: 'Share %', render: (r) => r.pct_share },
  ];

  const moverCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r) => r.week_start },
    { key: 'priority_area', header: 'Area', render: (r) => r.priority_area },
    { key: 'shift_direction', header: 'Dir', render: (r) => r.shift_direction },
    { key: 'shift_magnitude', header: 'Magnitude', render: (r) => r.shift_magnitude },
    { key: 'rationale', header: 'Rationale', render: (r) => r.rationale },
  ];

  const impactCols: Column<any>[] = [
    { key: 'impact_area', header: 'Impact Area', render: (r) => r.impact_area },
    { key: 'total_impacts', header: 'Total', render: (r) => r.total_impacts },
    { key: 'positive_outcomes', header: 'Positive', render: (r) => r.positive_outcomes },
    { key: 'negative_outcomes', header: 'Negative', render: (r) => r.negative_outcomes },
    { key: 'pending_outcomes', header: 'Pending', render: (r) => r.pending_outcomes },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r) => r.week_start },
    { key: 'shifts_count', header: 'Shifts', render: (r) => r.shifts_count },
    { key: 'avg_magnitude', header: 'Avg Mag', render: (r) => r.avg_magnitude },
    { key: 'new_priorities', header: 'New', render: (r) => r.new_priorities },
    { key: 'dropped_priorities', header: 'Dropped', render: (r) => r.dropped_priorities },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui' }}>
      <h1>Founder Weekly Priority-Shift Log</h1>
      <p>Track what changed in founder priorities week-over-week, rationale & downstream impact.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginTop: 16 }}>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Shifts</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{s.total_shifts ?? 0}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Weeks Logged</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{s.weeks_logged ?? 0}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Areas Tracked</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{s.areas_tracked ?? 0}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg Magnitude</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{s.avg_magnitude ?? 0}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Last Logged</div>
          <div style={{ fontSize: 16, fontWeight: 600 }}>{s.last_logged_week ?? '—'}</div>
        </div>
      </section>

      <h2 style={{ marginTop: 24 }}>Recent shifts (top 50)</h2>
      <DataTable columns={recentCols} rows={recentRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ marginTop: 24 }}>By priority area</h2>
      <DataTable columns={areaCols} rows={areaRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ marginTop: 24 }}>Direction breakdown</h2>
      <DataTable columns={dirCols} rows={dirRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ marginTop: 24 }}>Top movers (magnitude &gt;= 1)</h2>
      <DataTable columns={moverCols} rows={moverRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ marginTop: 24 }}>Downstream impact</h2>
      <DataTable columns={impactCols} rows={impactRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ marginTop: 24 }}>Weekly trend (last 12 weeks)</h2>
      <DataTable columns={trendCols} rows={trendRows} rowKey={(_, i) => String(i)} />
    </main>
  );
}
