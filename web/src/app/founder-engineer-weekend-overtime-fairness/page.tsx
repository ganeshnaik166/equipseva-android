import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerWeekendOvertimeFairnessPage() {
  const supabase = await getSupabaseServerClient();

  const [
    logsRes,
    metricsRes,
    overQuotaRes,
    refusalRes,
    weeklyRes,
    distRes,
    peerRes,
  ] = await Promise.all([
    supabase.rpc('list_ot_logs_r2526'),
    supabase.rpc('list_fairness_metrics_r2526'),
    supabase.rpc('top_over_quota_engineers_r2526'),
    supabase.rpc('refusal_breakdown_r2526'),
    supabase.rpc('weekly_premium_trend_r2526'),
    supabase.rpc('fairness_distribution_r2526'),
    supabase.rpc('zone_peer_comparison_r2526'),
  ]);

  const logs = (logsRes.data ?? []) as any[];
  const metrics = (metricsRes.data ?? []) as any[];
  const overQuota = (overQuotaRes.data ?? []) as any[];
  const refusal = (refusalRes.data ?? []) as any[];
  const weekly = (weeklyRes.data ?? []) as any[];
  const dist = (distRes.data ?? []) as any[];
  const peer = (peerRes.data ?? []) as any[];

  const logsCols: Column<any>[] = [
    { key: 'weekend_date', header: 'Weekend', render: (r: any) => String(r.weekend_date ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hours_worked', header: 'Hours', render: (r: any) => String(r.hours_worked ?? 0) },
    { key: 'premium_rupees', header: 'Premium ₹', render: (r: any) => `₹${Number(r.premium_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'consent_given', header: 'Consent', render: (r: any) => (r.consent_given ? 'yes' : 'no') },
    { key: 'refusal_reason_kind', header: 'Refusal', render: (r: any) => String(r.refusal_reason_kind ?? '') },
    { key: 'peer_avg_hours', header: 'Peer Avg', render: (r: any) => String(r.peer_avg_hours ?? 0) },
    { key: 'fairness_delta_hours', header: 'Delta h', render: (r: any) => String(r.fairness_delta_hours ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const metricsCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'period_start', header: 'From', render: (r: any) => String(r.period_start ?? '') },
    { key: 'period_end', header: 'To', render: (r: any) => String(r.period_end ?? '') },
    { key: 'total_weekends_worked', header: 'Weekends', render: (r: any) => String(r.total_weekends_worked ?? 0) },
    { key: 'total_premium_rupees', header: 'Premium ₹', render: (r: any) => `₹${Number(r.total_premium_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'fairness_target_hours', header: 'Target h', render: (r: any) => String(r.fairness_target_hours ?? 0) },
    { key: 'fairness_actual_hours', header: 'Actual h', render: (r: any) => String(r.fairness_actual_hours ?? 0) },
    { key: 'fairness_status', header: 'Fairness', render: (r: any) => String(r.fairness_status ?? '') },
    { key: 'refusal_count', header: 'Refusals', render: (r: any) => String(r.refusal_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const overQuotaCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'total_weekends_worked', header: 'Weekends', render: (r: any) => String(r.total_weekends_worked ?? 0) },
    { key: 'fairness_actual_hours', header: 'Actual h', render: (r: any) => String(r.fairness_actual_hours ?? 0) },
    { key: 'fairness_target_hours', header: 'Target h', render: (r: any) => String(r.fairness_target_hours ?? 0) },
    { key: 'delta_hours', header: 'Delta', render: (r: any) => String(r.delta_hours ?? 0) },
    { key: 'fairness_status', header: 'Fairness', render: (r: any) => String(r.fairness_status ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const refusalCols: Column<any>[] = [
    { key: 'refusal_reason_kind', header: 'Reason', render: (r: any) => String(r.refusal_reason_kind ?? '') },
    { key: 'refusal_count', header: 'Count', render: (r: any) => String(r.refusal_count ?? 0) },
    { key: 'pct_of_refusals', header: '% of refusals', render: (r: any) => `${r.pct_of_refusals ?? 0}%` },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'total_premium_rupees', header: 'Premium ₹', render: (r: any) => `₹${Number(r.total_premium_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_hours', header: 'Hours', render: (r: any) => String(r.total_hours ?? 0) },
    { key: 'log_count', header: 'Logs', render: (r: any) => String(r.log_count ?? 0) },
  ];

  const distCols: Column<any>[] = [
    { key: 'fairness_status', header: 'Fairness', render: (r: any) => String(r.fairness_status ?? '') },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => String(r.engineer_count ?? 0) },
    { key: 'avg_actual_hours', header: 'Avg Actual h', render: (r: any) => String(r.avg_actual_hours ?? 0) },
    { key: 'avg_target_hours', header: 'Avg Target h', render: (r: any) => String(r.avg_target_hours ?? 0) },
  ];

  const peerCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'avg_hours_worked', header: 'Avg Hours', render: (r: any) => String(r.avg_hours_worked ?? 0) },
    { key: 'avg_peer_hours', header: 'Avg Peer Hours', render: (r: any) => String(r.avg_peer_hours ?? 0) },
    { key: 'avg_delta_hours', header: 'Avg Delta', render: (r: any) => String(r.avg_delta_hours ?? 0) },
    { key: 'log_count', header: 'Logs', render: (r: any) => String(r.log_count ?? 0) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Weekend Overtime Fairness</h1>
        <p className="text-sm text-gray-600">
          Weekend OT & consent & distribution fairness & premium & peer comparison & refusal log => balanced rota.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekend OT Logs</h2>
        <DataTable
          rows={logs}
          columns={logsCols}
          emptyMessage="No OT logs."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Fairness Metrics (per engineer)</h2>
        <DataTable
          rows={metrics}
          columns={metricsCols}
          emptyMessage="No metrics."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Over-Quota Engineers</h2>
        <DataTable
          rows={overQuota}
          columns={overQuotaCols}
          emptyMessage="No over-quota engineers."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Refusal Breakdown</h2>
        <DataTable
          rows={refusal}
          columns={refusalCols}
          emptyMessage="No refusals logged."
          rowKey={(r: any, i: number) => String(r.refusal_reason_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Premium Trend</h2>
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          emptyMessage="No weekly premium data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Fairness Distribution</h2>
        <DataTable
          rows={dist}
          columns={distCols}
          emptyMessage="No distribution data."
          rowKey={(r: any, i: number) => String(r.fairness_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Zone Peer Comparison</h2>
        <DataTable
          rows={peer}
          columns={peerCols}
          emptyMessage="No peer data."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>
    </main>
  );
}
