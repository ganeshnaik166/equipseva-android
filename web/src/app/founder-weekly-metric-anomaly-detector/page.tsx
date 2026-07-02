import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [anomaliesRes, actionsRes, severityRes, aggRes] = await Promise.all([
    sb.rpc('list_anomalies_r2203'),
    sb.rpc('recent_actions_r2203'),
    sb.rpc('top_severity_r2203'),
    sb.rpc('aggregate_metric_r2203'),
  ]);

  const anomalies: any[] = Array.isArray(anomaliesRes.data) ? anomaliesRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const severity: any[] = Array.isArray(severityRes.data) ? severityRes.data : [];
  const agg: any[] = Array.isArray(aggRes.data) ? aggRes.data : [];

  const criticalCount = anomalies.filter((a) => a.severity === 'critical').length;
  const warnCount = anomalies.filter((a) => a.severity === 'warn').length;
  const openReviews = actions.filter((a) => a.review_status === 'open' || a.review_status === 'investigating').length;

  const anomalyCols: Column<any>[] = [
    { key: 'metric_label', header: 'Metric', render: (r: any) => String(r.metric_label ?? r.metric_key ?? '') },
    { key: 'week_start', header: 'Week', render: (r: any) => `${String(r.week_start ?? '')} to ${String(r.week_end ?? '')}` },
    { key: 'prior_value', header: 'Prior', render: (r: any) => String(r.prior_value ?? '') },
    { key: 'current_value', header: 'Current', render: (r: any) => String(r.current_value ?? '') },
    { key: 'delta_pct', header: 'Delta %', render: (r: any) => `${Number(r.delta_pct ?? 0).toFixed(2)}%` },
    { key: 'direction', header: 'Dir', render: (r: any) => String(r.direction ?? '') },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 19) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'metric_key', header: 'Metric', render: (r: any) => String(r.metric_key ?? '') },
    { key: 'review_status', header: 'Status', render: (r: any) => String(r.review_status ?? '') },
    { key: 'root_cause', header: 'Root Cause', render: (r: any) => String(r.root_cause ?? '') },
    { key: 'action_taken', header: 'Action', render: (r: any) => String(r.action_taken ?? '') },
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => String(r.reviewed_at ?? '').slice(0, 19) },
  ];

  const severityCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count ?? 0) },
    { key: 'critical_count', header: 'Critical', render: (r: any) => String(r.critical_count ?? 0) },
    { key: 'warn_count', header: 'Warn', render: (r: any) => String(r.warn_count ?? 0) },
    { key: 'avg_delta', header: 'Avg Delta', render: (r: any) => `${Number(r.avg_delta ?? 0).toFixed(2)}%` },
  ];

  const aggCols: Column<any>[] = [
    { key: 'metric_label', header: 'Metric', render: (r: any) => String(r.metric_label ?? r.metric_key ?? '') },
    { key: 'snapshot_count', header: 'Snapshots', render: (r: any) => String(r.snapshot_count ?? 0) },
    { key: 'critical_count', header: 'Critical', render: (r: any) => String(r.critical_count ?? 0) },
    { key: 'warn_count', header: 'Warn', render: (r: any) => String(r.warn_count ?? 0) },
    { key: 'avg_abs_delta', header: 'Avg |Δ|', render: (r: any) => `${Number(r.avg_abs_delta ?? 0).toFixed(2)}%` },
    { key: 'latest_delta', header: 'Latest Δ', render: (r: any) => `${Number(r.latest_delta ?? 0).toFixed(2)}%` },
    { key: 'latest_week', header: 'Last Week', render: (r: any) => String(r.latest_week ?? '') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>Weekly Metric Anomaly Detector</h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Week-over-week sudden jumps & drops across revenue, jobs, NPS & churn flagged for founder review.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <div style={{ padding: '16px', border: '1px solid #eee', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#888' }}>Critical Anomalies</div>
          <div style={{ fontSize: '28px', fontWeight: 700, color: '#c00' }}>{criticalCount}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #eee', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#888' }}>Warning Anomalies</div>
          <div style={{ fontSize: '28px', fontWeight: 700, color: '#d80' }}>{warnCount}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #eee', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#888' }}>Open Reviews</div>
          <div style={{ fontSize: '28px', fontWeight: 700 }}>{openReviews}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #eee', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#888' }}>Total Snapshots</div>
          <div style={{ fontSize: '28px', fontWeight: 700 }}>{anomalies.length}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Anomaly Snapshots</h2>
        <DataTable columns={anomalyCols} rows={anomalies} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Per-Metric Aggregate</h2>
        <DataTable columns={aggCols} rows={agg} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Severity Breakdown</h2>
        <DataTable columns={severityCols} rows={severity} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent Review Actions</h2>
        <DataTable columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
