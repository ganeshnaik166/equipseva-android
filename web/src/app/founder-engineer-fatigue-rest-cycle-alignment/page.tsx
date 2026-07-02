import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [cycles, actions, topFatigued, statusDist, peerShare, weeklyTrend, autoBlockRate] = await Promise.all([
    supabase.rpc('list_fatigue_cycles_r2538'),
    supabase.rpc('list_block_actions_r2538'),
    supabase.rpc('top_fatigued_engineers_r2538'),
    supabase.rpc('status_distribution_r2538'),
    supabase.rpc('peer_share_summary_r2538'),
    supabase.rpc('weekly_fatigue_trend_r2538'),
    supabase.rpc('auto_block_rate_r2538'),
  ]);

  const cycleCols: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r: any) => r.week_start ? String(r.week_start).slice(0, 10) : '' },
    { key: 'work_hours', header: 'Work (h)', render: (r: any) => Number(r.work_hours ?? 0).toFixed(2) },
    { key: 'rest_days', header: 'Rest Days', render: (r: any) => String(r.rest_days ?? 0) },
    { key: 'fatigue_score', header: 'Fatigue', render: (r: any) => `${Number(r.fatigue_score ?? 0)}/100` },
    { key: 'consent_for_extra_hours', header: 'Consent', render: (r: any) => r.consent_for_extra_hours ? 'yes' : 'no' },
    { key: 'auto_blocked', header: 'Auto-Blocked', render: (r: any) => r.auto_blocked ? 'yes' : 'no' },
    { key: 'peer_share_pct', header: 'Peer Share %', render: (r: any) => `${Number(r.peer_share_pct ?? 0).toFixed(2)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => r.action_at ? String(r.action_at).slice(0, 16).replace('T', ' ') : '' },
    { key: 'action_kind', header: 'Action', render: (r: any) => String(r.action_kind ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const topCols: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r: any) => r.week_start ? String(r.week_start).slice(0, 10) : '' },
    { key: 'fatigue_score', header: 'Fatigue', render: (r: any) => `${Number(r.fatigue_score ?? 0)}/100` },
    { key: 'work_hours', header: 'Work (h)', render: (r: any) => Number(r.work_hours ?? 0).toFixed(2) },
    { key: 'rest_days', header: 'Rest Days', render: (r: any) => String(r.rest_days ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'auto_blocked', header: 'Auto-Blocked', render: (r: any) => r.auto_blocked ? 'yes' : 'no' },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'cycles_count', header: 'Cycles', render: (r: any) => String(r.cycles_count ?? 0) },
    { key: 'avg_fatigue', header: 'Avg Fatigue', render: (r: any) => `${Number(r.avg_fatigue ?? 0).toFixed(2)}/100` },
    { key: 'avg_work_hours', header: 'Avg Work (h)', render: (r: any) => Number(r.avg_work_hours ?? 0).toFixed(2) },
    { key: 'auto_blocked_count', header: 'Auto-Blocked', render: (r: any) => String(r.auto_blocked_count ?? 0) },
  ];

  const peerCols: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r: any) => r.week_start ? String(r.week_start).slice(0, 10) : '' },
    { key: 'cycles_count', header: 'Cycles', render: (r: any) => String(r.cycles_count ?? 0) },
    { key: 'avg_peer_share', header: 'Avg Peer Share', render: (r: any) => `${Number(r.avg_peer_share ?? 0).toFixed(2)}%` },
    { key: 'max_peer_share', header: 'Max Peer Share', render: (r: any) => `${Number(r.max_peer_share ?? 0).toFixed(2)}%` },
    { key: 'total_work_hours', header: 'Total Work (h)', render: (r: any) => Number(r.total_work_hours ?? 0).toFixed(2) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r: any) => r.week_start ? String(r.week_start).slice(0, 10) : '' },
    { key: 'cycles_count', header: 'Cycles', render: (r: any) => String(r.cycles_count ?? 0) },
    { key: 'avg_fatigue', header: 'Avg Fatigue', render: (r: any) => `${Number(r.avg_fatigue ?? 0).toFixed(2)}/100` },
    { key: 'total_work_hours', header: 'Total Work (h)', render: (r: any) => Number(r.total_work_hours ?? 0).toFixed(2) },
    { key: 'total_rest_days', header: 'Rest Days', render: (r: any) => String(r.total_rest_days ?? 0) },
    { key: 'red_or_black_count', header: 'Red/Black', render: (r: any) => String(r.red_or_black_count ?? 0) },
  ];

  const summaryRow = Array.isArray(autoBlockRate.data) && autoBlockRate.data.length > 0 ? autoBlockRate.data[0] : null;

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>Engineer Fatigue & Rest Cycle Alignment</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-week > work hours > rest days > fatigue score > consent > auto-block > peer share.
      </p>

      {summaryRow && (
        <section style={{ background: '#f8fafc', padding: 16, borderRadius: 8, marginBottom: 24, border: '1px solid #e2e8f0' }}>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Auto-Block & Consent Summary</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <div><strong>Total Cycles:</strong> {String(summaryRow.total_cycles ?? 0)}</div>
            <div><strong>Auto-Blocked:</strong> {String(summaryRow.auto_blocked_count ?? 0)}</div>
            <div><strong>Auto-Block Rate:</strong> {Number(summaryRow.auto_block_rate ?? 0).toFixed(2)}%</div>
            <div><strong>Consented:</strong> {String(summaryRow.consented_count ?? 0)}</div>
            <div><strong>Consent Rate:</strong> {Number(summaryRow.consent_rate ?? 0).toFixed(2)}%</div>
            <div><strong>Avg Fatigue:</strong> {Number(summaryRow.avg_fatigue_overall ?? 0).toFixed(2)}/100</div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Fatigue Cycles</h2>
        <DataTable
          rows={cycles.data ?? []}
          columns={cycleCols}
          emptyMessage="No fatigue cycles recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Block Actions</h2>
        <DataTable
          rows={actions.data ?? []}
          columns={actionCols}
          emptyMessage="No block actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Fatigued Engineers</h2>
        <DataTable
          rows={topFatigued.data ?? []}
          columns={topCols}
          emptyMessage="No engineers ranked."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i) + '-' + String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status Distribution</h2>
        <DataTable
          rows={statusDist.data ?? []}
          columns={statusCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Peer Share Summary</h2>
        <DataTable
          rows={peerShare.data ?? []}
          columns={peerCols}
          emptyMessage="No peer-share data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Weekly Fatigue Trend</h2>
        <DataTable
          rows={weeklyTrend.data ?? []}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>
    </main>
  );
}
