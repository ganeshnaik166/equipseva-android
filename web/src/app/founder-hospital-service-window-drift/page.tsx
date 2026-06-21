import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [drifts, topHospitals, trend, critical] = await Promise.all([
    sb.rpc('list_drifts_r1807', { p_limit: 200 }),
    sb.rpc('top_drift_hospitals_r1807', { p_limit: 20 }),
    sb.rpc('drift_trend_monthly_r1807', { p_months: 12 }),
    sb.rpc('critical_drift_queue_r1807', { p_limit: 100 }),
  ]);

  const driftRows: any[] = (drifts.data as any[]) ?? [];
  const topRows: any[] = (topHospitals.data as any[]) ?? [];
  const trendRows: any[] = (trend.data as any[]) ?? [];
  const criticalRows: any[] = (critical.data as any[]) ?? [];

  const driftCols: Column<any>[] = [
    { key: 'recorded_at', header: 'Date', render: (r: any) => String(r.recorded_at ?? '') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '—') },
    { key: 'sla_type', header: 'SLA Type', render: (r: any) => String(r.sla_type ?? '') },
    { key: 'contracted_minutes', header: 'Contracted (min)', render: (r: any) => String(r.contracted_minutes ?? 0) },
    { key: 'actual_minutes', header: 'Actual (min)', render: (r: any) => String(r.actual_minutes ?? 0) },
    { key: 'drift_minutes', header: 'Drift (min)', render: (r: any) => String(r.drift_minutes ?? 0) },
    { key: 'drift_severity', header: 'Severity', render: (r: any) => String(r.drift_severity ?? '') },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '—') },
    { key: 'drift_count', header: 'Drift Count', render: (r: any) => String(r.drift_count ?? 0) },
    { key: 'total_drift_minutes', header: 'Total Drift (min)', render: (r: any) => String(r.total_drift_minutes ?? 0) },
    { key: 'critical_count', header: 'Critical', render: (r: any) => String(r.critical_count ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start ?? '') },
    { key: 'drift_count', header: 'Drifts', render: (r: any) => String(r.drift_count ?? 0) },
    { key: 'avg_drift_minutes', header: 'Avg Drift (min)', render: (r: any) => String(Number(r.avg_drift_minutes ?? 0).toFixed(1)) },
    { key: 'critical_count', header: 'Critical', render: (r: any) => String(r.critical_count ?? 0) },
  ];

  const criticalCols: Column<any>[] = [
    { key: 'recorded_at', header: 'Date', render: (r: any) => String(r.recorded_at ?? '') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '—') },
    { key: 'sla_type', header: 'SLA Type', render: (r: any) => String(r.sla_type ?? '') },
    { key: 'drift_minutes', header: 'Drift (min)', render: (r: any) => String(r.drift_minutes ?? 0) },
    { key: 'has_action', header: 'Action Taken', render: (r: any) => (r.has_action ? 'Yes' : 'No') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Service Window Drift</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track when hospital service windows drift from contractual SLA targets (response &gt; resolution &gt; escalation).
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Critical Drift Queue</h2>
        <DataTable
          rows={criticalRows}
          columns={criticalCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Drift Hospitals</h2>
        <DataTable
          rows={topRows}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Drift Trend (last 12 months)</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Drift Log</h2>
        <DataTable
          rows={driftRows}
          columns={driftCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
