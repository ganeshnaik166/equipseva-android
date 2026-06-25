import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [tracks, logs, focus, dist, funnel, trend, summary] = await Promise.all([
    supabase.rpc('list_loyalty_track_r2644'),
    supabase.rpc('list_promotion_log_r2644'),
    supabase.rpc('top_points_focus_r2644'),
    supabase.rpc('tier_distribution_r2644'),
    supabase.rpc('status_funnel_r2644'),
    supabase.rpc('monthly_promotion_trend_r2644'),
    supabase.rpc('projected_promotions_30d_summary_r2644'),
  ]);

  const trackRows = (tracks.data ?? []) as any[];
  const logRows = (logs.data ?? []) as any[];
  const focusRows = (focus.data ?? []) as any[];
  const distRows = (dist.data ?? []) as any[];
  const funnelRows = (funnel.data ?? []) as any[];
  const trendRows = (trend.data ?? []) as any[];
  const summaryRow = (summary.data ?? [])[0] as any | undefined;

  const trackCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'current_tier', header: 'Current', render: (r: any) => r.current_tier },
    { key: 'next_tier', header: 'Next', render: (r: any) => r.next_tier },
    { key: 'points_total', header: 'Points', render: (r: any) => String(r.points_total) },
    { key: 'points_to_next', header: 'To Next', render: (r: any) => String(r.points_to_next) },
    { key: 'projected_promotion_at', header: 'Projected', render: (r: any) => r.projected_promotion_at ? new Date(r.projected_promotion_at).toLocaleDateString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const logCols: Column<any>[] = [
    { key: 'promoted_at', header: 'Promoted At', render: (r: any) => new Date(r.promoted_at).toLocaleString() },
    { key: 'from_tier', header: 'From', render: (r: any) => r.from_tier },
    { key: 'to_tier', header: 'To', render: (r: any) => r.to_tier },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'current_tier', header: 'Current', render: (r: any) => r.current_tier },
    { key: 'next_tier', header: 'Next', render: (r: any) => r.next_tier },
    { key: 'points_to_next', header: 'To Next', render: (r: any) => String(r.points_to_next) },
    { key: 'points_total', header: 'Points', render: (r: any) => String(r.points_total) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const distCols: Column<any>[] = [
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier },
    { key: 'track_count', header: 'Tracks', render: (r: any) => String(r.track_count) },
    { key: 'total_points', header: 'Total Points', render: (r: any) => String(r.total_points) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'track_count', header: 'Count', render: (r: any) => String(r.track_count) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_bucket', header: 'Month', render: (r: any) => r.month_bucket },
    { key: 'promotions', header: 'Promotions', render: (r: any) => String(r.promotions) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Customer Monthly Loyalty Tier Promotion Track</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>Founder view > track per-hospital monthly loyalty tier progression & promotion log.</p>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>30-Day Projection Summary</h2>
        {summaryRow ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Projected (30d)</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{String(summaryRow.total_projected ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Progressing</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{String(summaryRow.progressing_count ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Stalled</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{String(summaryRow.stalled_count ?? 0)}</div>
            </div>
            <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Avg Pts To Next</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{Number(summaryRow.avg_points_to_next ?? 0).toFixed(0)}</div>
            </div>
          </div>
        ) : (
          <p style={{ color: '#888' }}>No summary.</p>
        )}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Top Focus (Closest to Next Tier)</h2>
        <DataTable
          rows={focusRows}
          columns={focusCols}
          emptyMessage="No focus rows."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Tier Distribution</h2>
        <DataTable
          rows={distRows}
          columns={distCols}
          emptyMessage="No tier distribution."
          rowKey={(r: any, i: number) => String(r.tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Status Funnel</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Monthly Promotion Trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>All Tracks</h2>
        <DataTable
          rows={trackRows}
          columns={trackCols}
          emptyMessage="No tracks."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Promotion Log</h2>
        <DataTable
          rows={logRows}
          columns={logCols}
          emptyMessage="No promotion log entries."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
