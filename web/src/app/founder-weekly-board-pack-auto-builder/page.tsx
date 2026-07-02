import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [overview, metrics, owners, dueToday, log, critical, kpis] = await Promise.all([
    sb.rpc('board_pack_overview_r2285'),
    sb.rpc('board_pack_metrics_list_r2285'),
    sb.rpc('board_pack_owner_load_r2285'),
    sb.rpc('board_pack_due_today_r2285'),
    sb.rpc('board_pack_finalize_log_r2285'),
    sb.rpc('board_pack_critical_status_r2285'),
    sb.rpc('board_pack_kpis_r2285'),
  ]);

  const k = (kpis.data ?? [])[0] ?? {};

  const overviewCols: Column<any>[] = [
    { key: 'metric_section', header: 'Section', render: (r) => r.metric_section },
    { key: 'metric_count', header: 'Metrics', render: (r) => r.metric_count },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
    { key: 'finalized_this_week', header: 'Finalized (week)', render: (r) => r.finalized_this_week },
  ];

  const metricsCols: Column<any>[] = [
    { key: 'metric_code', header: 'Code', render: (r) => r.metric_code },
    { key: 'metric_label', header: 'Metric', render: (r) => r.metric_label },
    { key: 'metric_section', header: 'Section', render: (r) => r.metric_section },
    { key: 'owner_email', header: 'Owner', render: (r) => r.owner_email },
    { key: 'draft_day', header: 'Draft Due', render: (r) => r.draft_day },
    { key: 'target_value_text', header: 'Target', render: (r) => r.target_value_text ?? '-' },
    { key: 'current_value_text', header: 'Current', render: (r) => r.current_value_text ?? '-' },
    { key: 'trend_arrow', header: 'Trend', render: (r) => r.trend_arrow ?? '-' },
    { key: 'is_critical', header: 'Critical', render: (r) => (r.is_critical ? 'YES' : '') },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r) => r.owner_email },
    { key: 'metric_count', header: 'Metrics', render: (r) => r.metric_count },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
    { key: 'pending_this_week', header: 'Pending (week)', render: (r) => r.pending_this_week },
  ];

  const dueCols: Column<any>[] = [
    { key: 'metric_code', header: 'Code', render: (r) => r.metric_code },
    { key: 'metric_label', header: 'Metric', render: (r) => r.metric_label },
    { key: 'owner_email', header: 'Owner', render: (r) => r.owner_email },
    { key: 'draft_due_hour', header: 'Hour', render: (r) => String(r.draft_due_hour).padStart(2, '0') + ':00' },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const logCols: Column<any>[] = [
    { key: 'pack_week_start', header: 'Week Start', render: (r) => r.pack_week_start },
    { key: 'metric_label', header: 'Metric', render: (r) => r.metric_label },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'finalized_at', header: 'Finalized At', render: (r) => r.finalized_at ?? '-' },
    { key: 'delay_hours', header: 'Delay (hrs)', render: (r) => r.delay_hours ?? '-' },
  ];

  const critCols: Column<any>[] = [
    { key: 'metric_label', header: 'Metric', render: (r) => r.metric_label },
    { key: 'current_value_text', header: 'Current', render: (r) => r.current_value_text ?? '-' },
    { key: 'target_value_text', header: 'Target', render: (r) => r.target_value_text ?? '-' },
    { key: 'trend_arrow', header: 'Trend', render: (r) => r.trend_arrow ?? '-' },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder Weekly Board-Pack Auto-Builder</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Catalog of metrics that go into the weekly board pack — owner, draft due day & hour, target vs current, and finalize log.
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Metrics</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{k.total_metrics ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Critical Metrics</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{k.critical_metrics ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Finalized This Week</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{k.finalized_this_week ?? 0}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Pending This Week</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{k.pending_this_week ?? 0}</div>
        </div>
      </div>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Section Overview</h2>
        <DataTable columns={overviewCols} rows={overview.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Critical Metric Status</h2>
        <DataTable columns={critCols} rows={critical.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Due Today</h2>
        <DataTable columns={dueCols} rows={dueToday.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner Load</h2>
        <DataTable columns={ownerCols} rows={owners.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Metrics</h2>
        <DataTable columns={metricsCols} rows={metrics.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Finalize Log</h2>
        <DataTable columns={logCols} rows={log.data ?? []} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
