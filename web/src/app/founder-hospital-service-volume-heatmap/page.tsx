import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [heatmapRes, anomaliesRes, peakRes, criticalRes] = await Promise.all([
    sb.rpc('list_heatmap_r1779'),
    sb.rpc('list_anomalies_r1779'),
    sb.rpc('peak_hours_per_hospital_r1779'),
    sb.rpc('critical_anomalies_r1779'),
  ]);

  const heatmap = (heatmapRes.data ?? []) as any[];
  const anomalies = (anomaliesRes.data ?? []) as any[];
  const peaks = (peakRes.data ?? []) as any[];
  const criticals = (criticalRes.data ?? []) as any[];

  const dayName = (d: number) => ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][d] ?? String(d);

  const heatmapCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id },
    { key: 'day_of_week', header: 'Day', render: (r: any) => dayName(r.day_of_week) },
    { key: 'hour_of_day', header: 'Hour', render: (r: any) => `${String(r.hour_of_day).padStart(2,'0')}:00` },
    { key: 'avg_service_count', header: 'Avg Volume', render: (r: any) => Number(r.avg_service_count ?? 0).toFixed(2) },
    { key: 'recorded_window_start', header: 'Window Start', render: (r: any) => r.recorded_window_start ?? '' },
    { key: 'recorded_window_end', header: 'Window End', render: (r: any) => r.recorded_window_end ?? '' },
  ];

  const anomaliesCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id },
    { key: 'window_start', header: 'Window', render: (r: any) => r.window_start ?? '' },
    { key: 'anomaly_type', header: 'Type', render: (r: any) => r.anomaly_type ?? '' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '' },
    { key: 'anomaly_text', header: 'Detail', render: (r: any) => r.anomaly_text ?? '' },
    { key: 'detected_at', header: 'Detected', render: (r: any) => r.detected_at ? new Date(r.detected_at).toLocaleString() : '' },
    { key: 'ack', header: 'Ack', render: (r: any) => r.ack ? 'yes' : 'no' },
  ];

  const peakCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id },
    { key: 'peak_day_of_week', header: 'Peak Day', render: (r: any) => dayName(r.peak_day_of_week) },
    { key: 'peak_hour_of_day', header: 'Peak Hour', render: (r: any) => `${String(r.peak_hour_of_day).padStart(2,'0')}:00` },
    { key: 'peak_avg_service_count', header: 'Peak Volume', render: (r: any) => Number(r.peak_avg_service_count ?? 0).toFixed(2) },
  ];

  const criticalCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id },
    { key: 'window_start', header: 'Window', render: (r: any) => r.window_start ?? '' },
    { key: 'anomaly_type', header: 'Type', render: (r: any) => r.anomaly_type ?? '' },
    { key: 'anomaly_text', header: 'Detail', render: (r: any) => r.anomaly_text ?? '' },
    { key: 'detected_at', header: 'Detected', render: (r: any) => r.detected_at ? new Date(r.detected_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Service Volume Heatmap</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-hospital service volume by day-of-week and hour. Surfaces peaks and anomalies (spike, drop, flatline).
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Heatmap Cells</h2>
        <DataTable rows={heatmap} columns={heatmapCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Peak Hour Per Hospital</h2>
        <DataTable rows={peaks} columns={peakCols} rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Anomalies</h2>
        <DataTable rows={anomalies} columns={anomaliesCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Critical Unacked Anomalies</h2>
        <DataTable rows={criticals} columns={criticalCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
