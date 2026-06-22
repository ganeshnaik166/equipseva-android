import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    predictionsRes,
    statsRes,
    byClassRes,
    upcomingRes,
    eventsRes,
    bandsRes,
    topHospitalsRes,
  ] = await Promise.all([
    sb.rpc('r2232_list_predictions'),
    sb.rpc('r2232_summary_stats'),
    sb.rpc('r2232_by_equipment_class'),
    sb.rpc('r2232_upcoming_cycles', { p_days: 60 }),
    sb.rpc('r2232_recent_events'),
    sb.rpc('r2232_confidence_bands'),
    sb.rpc('r2232_top_hospitals'),
  ]);

  const predictions = (predictionsRes.data ?? []) as any[];
  const stats = ((statsRes.data ?? [])[0] ?? {}) as any;
  const byClass = (byClassRes.data ?? []) as any[];
  const upcoming = (upcomingRes.data ?? []) as any[];
  const events = (eventsRes.data ?? []) as any[];
  const bands = (bandsRes.data ?? []) as any[];
  const topHospitals = (topHospitalsRes.data ?? []) as any[];

  const predictionCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'predicted_cycle_start', header: 'Cycle Start', render: (r: any) => String(r.predicted_cycle_start ?? '') },
    { key: 'predicted_cycle_end', header: 'Cycle End', render: (r: any) => String(r.predicted_cycle_end ?? '') },
    { key: 'predicted_equipment_class', header: 'Equipment', render: (r: any) => String(r.predicted_equipment_class ?? '') },
    { key: 'predicted_value_rupees', header: 'Value ₹', render: (r: any) => String(r.predicted_value_rupees ?? 0) },
    { key: 'founder_confidence_pct', header: 'Confidence %', render: (r: any) => String(r.founder_confidence_pct ?? 0) },
    { key: 'historical_buy_count', header: 'Hist Buys', render: (r: any) => String(r.historical_buy_count ?? 0) },
    { key: 'cycle_days_observed', header: 'Cycle Days', render: (r: any) => String(r.cycle_days_observed ?? 0) },
  ];

  const classCols: Column<any>[] = [
    { key: 'equipment_class', header: 'Class', render: (r: any) => String(r.equipment_class ?? '') },
    { key: 'prediction_count', header: 'Count', render: (r: any) => String(r.prediction_count ?? 0) },
    { key: 'total_value_rupees', header: 'Total ₹', render: (r: any) => String(r.total_value_rupees ?? 0) },
    { key: 'avg_confidence_pct', header: 'Avg Conf %', render: (r: any) => String(r.avg_confidence_pct ?? 0) },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'predicted_cycle_start', header: 'Start', render: (r: any) => String(r.predicted_cycle_start ?? '') },
    { key: 'days_until_cycle', header: 'Days', render: (r: any) => String(r.days_until_cycle ?? 0) },
    { key: 'predicted_equipment_class', header: 'Equipment', render: (r: any) => String(r.predicted_equipment_class ?? '') },
    { key: 'predicted_value_rupees', header: 'Value ₹', render: (r: any) => String(r.predicted_value_rupees ?? 0) },
    { key: 'founder_confidence_pct', header: 'Conf %', render: (r: any) => String(r.founder_confidence_pct ?? 0) },
  ];

  const eventCols: Column<any>[] = [
    { key: 'event_at', header: 'At', render: (r: any) => String(r.event_at ?? '') },
    { key: 'event_type', header: 'Type', render: (r: any) => String(r.event_type ?? '') },
    { key: 'equipment_class', header: 'Class', render: (r: any) => String(r.equipment_class ?? '') },
    { key: 'value_rupees', header: 'Value ₹', render: (r: any) => String(r.value_rupees ?? 0) },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  const bandCols: Column<any>[] = [
    { key: 'band', header: 'Confidence Band', render: (r: any) => String(r.band ?? '') },
    { key: 'prediction_count', header: 'Count', render: (r: any) => String(r.prediction_count ?? 0) },
    { key: 'total_value_rupees', header: 'Total ₹', render: (r: any) => String(r.total_value_rupees ?? 0) },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'prediction_count', header: 'Cycles', render: (r: any) => String(r.prediction_count ?? 0) },
    { key: 'total_value_rupees', header: 'Total ₹', render: (r: any) => String(r.total_value_rupees ?? 0) },
    { key: 'avg_confidence_pct', header: 'Avg Conf %', render: (r: any) => String(r.avg_confidence_pct ?? 0) },
  ];

  return (
    <main style={{ padding: 24 }}>
      <h1>Hospital Procurement Cycle Predictor</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Predict next purchase cycle, value & equipment class for each hospital — founder confidence rating attached.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 12, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total predictions</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{String(stats.total_predictions ?? 0)}</div>
        </div>
        <div style={{ padding: 12, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>High confidence (&gt;=70)</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{String(stats.high_confidence_count ?? 0)}</div>
        </div>
        <div style={{ padding: 12, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Upcoming &lt;=30d</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{String(stats.upcoming_30d_count ?? 0)}</div>
        </div>
        <div style={{ padding: 12, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Predicted pipeline ₹</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{String(stats.total_predicted_value_rupees ?? 0)}</div>
        </div>
        <div style={{ padding: 12, background: '#f4f4f5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg confidence %</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{String(stats.avg_confidence_pct ?? 0)}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2>All predictions</h2>
        <DataTable columns={predictionCols} rows={predictions} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2>Upcoming cycles (next 60 days)</h2>
        <DataTable columns={upcomingCols} rows={upcoming} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2>By equipment class</h2>
        <DataTable columns={classCols} rows={byClass} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2>Confidence bands</h2>
        <DataTable columns={bandCols} rows={bands} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2>Top hospitals by pipeline</h2>
        <DataTable columns={topCols} rows={topHospitals} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2>Recent cycle events</h2>
        <DataTable columns={eventCols} rows={events} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
