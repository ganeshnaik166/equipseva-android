import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [blocks, devices, weeklyTrend, stealers, topDays, deviceRate, summary] = await Promise.all([
    supabase.rpc('list_blocks_r2537'),
    supabase.rpc('list_commitment_devices_r2537'),
    supabase.rpc('weekly_deep_work_trend_r2537'),
    supabase.rpc('stealer_kind_breakdown_r2537'),
    supabase.rpc('top_quality_days_r2537'),
    supabase.rpc('device_success_rate_r2537'),
    supabase.rpc('monthly_summary_r2537'),
  ]);

  const blockCols: Column<any>[] = [
    { key: 'day', header: 'Day', render: (r: any) => r.day ? String(r.day).slice(0, 10) : '' },
    { key: 'hours_planned', header: 'Planned (h)', render: (r: any) => Number(r.hours_planned ?? 0).toFixed(2) },
    { key: 'hours_actual', header: 'Actual (h)', render: (r: any) => Number(r.hours_actual ?? 0).toFixed(2) },
    { key: 'interruption_count', header: 'Interruptions', render: (r: any) => String(r.interruption_count ?? 0) },
    { key: 'top_stealer_kind', header: 'Top Stealer', render: (r: any) => String(r.top_stealer_kind ?? '') },
    { key: 'block_quality_score', header: 'Quality', render: (r: any) => `${Number(r.block_quality_score ?? 0)}/100` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const deviceCols: Column<any>[] = [
    { key: 'device_kind', header: 'Device', render: (r: any) => String(r.device_kind ?? '') },
    { key: 'success_count', header: 'Wins', render: (r: any) => String(r.success_count ?? 0) },
    { key: 'failure_count', header: 'Fails', render: (r: any) => String(r.failure_count ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r: any) => r.week_start ? String(r.week_start).slice(0, 10) : '' },
    { key: 'blocks_count', header: 'Blocks', render: (r: any) => String(r.blocks_count ?? 0) },
    { key: 'total_planned', header: 'Planned (h)', render: (r: any) => Number(r.total_planned ?? 0).toFixed(2) },
    { key: 'total_actual', header: 'Actual (h)', render: (r: any) => Number(r.total_actual ?? 0).toFixed(2) },
    { key: 'avg_quality', header: 'Avg Quality', render: (r: any) => `${Number(r.avg_quality ?? 0).toFixed(2)}/100` },
    { key: 'total_interruptions', header: 'Interruptions', render: (r: any) => String(r.total_interruptions ?? 0) },
  ];

  const stealerCols: Column<any>[] = [
    { key: 'top_stealer_kind', header: 'Stealer', render: (r: any) => String(r.top_stealer_kind ?? '') },
    { key: 'blocks_count', header: 'Blocks', render: (r: any) => String(r.blocks_count ?? 0) },
    { key: 'avg_quality', header: 'Avg Quality', render: (r: any) => `${Number(r.avg_quality ?? 0).toFixed(2)}/100` },
    { key: 'total_interruptions', header: 'Interruptions', render: (r: any) => String(r.total_interruptions ?? 0) },
    { key: 'total_hours_lost', header: 'Hours Lost', render: (r: any) => Number(r.total_hours_lost ?? 0).toFixed(2) },
  ];

  const topDayCols: Column<any>[] = [
    { key: 'day', header: 'Day', render: (r: any) => r.day ? String(r.day).slice(0, 10) : '' },
    { key: 'hours_actual', header: 'Actual (h)', render: (r: any) => Number(r.hours_actual ?? 0).toFixed(2) },
    { key: 'block_quality_score', header: 'Quality', render: (r: any) => `${Number(r.block_quality_score ?? 0)}/100` },
    { key: 'top_stealer_kind', header: 'Top Stealer', render: (r: any) => String(r.top_stealer_kind ?? '') },
    { key: 'interruption_count', header: 'Interruptions', render: (r: any) => String(r.interruption_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const deviceRateCols: Column<any>[] = [
    { key: 'device_kind', header: 'Device', render: (r: any) => String(r.device_kind ?? '') },
    { key: 'success_count', header: 'Wins', render: (r: any) => String(r.success_count ?? 0) },
    { key: 'failure_count', header: 'Fails', render: (r: any) => String(r.failure_count ?? 0) },
    { key: 'success_rate', header: 'Success Rate', render: (r: any) => `${Number(r.success_rate ?? 0).toFixed(2)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const summaryRow = Array.isArray(summary.data) && summary.data.length > 0 ? summary.data[0] : null;

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>Founder Weekly Deep-Work Block Protection</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Day > planned hours > actual > interruptions > top stealer > commitment device.
      </p>

      {summaryRow && (
        <section style={{ background: '#f8fafc', padding: 16, borderRadius: 8, marginBottom: 24, border: '1px solid #e2e8f0' }}>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Summary</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <div><strong>Total Blocks:</strong> {String(summaryRow.total_blocks ?? 0)}</div>
            <div><strong>Done:</strong> {String(summaryRow.done_count ?? 0)}</div>
            <div><strong>Missed:</strong> {String(summaryRow.missed_count ?? 0)}</div>
            <div><strong>Planned (h):</strong> {Number(summaryRow.total_hours_planned ?? 0).toFixed(2)}</div>
            <div><strong>Actual (h):</strong> {Number(summaryRow.total_hours_actual ?? 0).toFixed(2)}</div>
            <div><strong>Avg Quality:</strong> {Number(summaryRow.avg_quality ?? 0).toFixed(2)}/100</div>
            <div><strong>Interruptions:</strong> {String(summaryRow.total_interruptions ?? 0)}</div>
            <div><strong>Active Devices:</strong> {String(summaryRow.active_devices ?? 0)}</div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Deep-Work Blocks</h2>
        <DataTable
          rows={blocks.data ?? []}
          columns={blockCols}
          emptyMessage="No deep-work blocks recorded"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Commitment Devices</h2>
        <DataTable
          rows={devices.data ?? []}
          columns={deviceCols}
          emptyMessage="No commitment devices"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Weekly Deep-Work Trend</h2>
        <DataTable
          rows={weeklyTrend.data ?? []}
          columns={weeklyCols}
          emptyMessage="No weekly trend data"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Stealer Breakdown</h2>
        <DataTable
          rows={stealers.data ?? []}
          columns={stealerCols}
          emptyMessage="No stealer data"
          rowKey={(r: any, i: number) => String(r.top_stealer_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Quality Days</h2>
        <DataTable
          rows={topDays.data ?? []}
          columns={topDayCols}
          emptyMessage="No completed deep-work days"
          rowKey={(r: any, i: number) => String(`${r.day ?? ''}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Device Success Rate</h2>
        <DataTable
          rows={deviceRate.data ?? []}
          columns={deviceRateCols}
          emptyMessage="No device data"
          rowKey={(r: any, i: number) => String(r.device_kind ?? i)}
        />
      </section>
    </main>
  );
}
