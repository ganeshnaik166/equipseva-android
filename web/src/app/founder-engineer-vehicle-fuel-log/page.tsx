import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [tripsRes, outliersRes, topCostRes, zoneRes, weeklyRes, vehicleRes, topOpenRes] = await Promise.all([
    supabase.rpc('list_trips_r2426'),
    supabase.rpc('list_outliers_r2426'),
    supabase.rpc('top_cost_engineers_r2426'),
    supabase.rpc('zone_benchmark_summary_r2426'),
    supabase.rpc('weekly_fuel_trend_r2426'),
    supabase.rpc('vehicle_utilization_r2426'),
    supabase.rpc('top_outliers_open_r2426'),
  ]);

  const trips = tripsRes.data ?? [];
  const outliers = outliersRes.data ?? [];
  const topCost = topCostRes.data ?? [];
  const zone = zoneRes.data ?? [];
  const weekly = weeklyRes.data ?? [];
  const vehicle = vehicleRes.data ?? [];
  const topOpen = topOpenRes.data ?? [];

  const tripCols: Column<any>[] = [
    { key: 'trip_started_at', header: 'Started', render: (r: any) => String(r.trip_started_at ?? '') },
    { key: 'trip_ended_at', header: 'Ended', render: (r: any) => String(r.trip_ended_at ?? '') },
    { key: 'vehicle_label', header: 'Vehicle', render: (r: any) => String(r.vehicle_label ?? '') },
    { key: 'zone_label', header: 'Zone', render: (r: any) => String(r.zone_label ?? '') },
    { key: 'start_km', header: 'Start KM', render: (r: any) => String(r.start_km ?? 0) },
    { key: 'end_km', header: 'End KM', render: (r: any) => String(r.end_km ?? 0) },
    { key: 'km_driven', header: 'KM Driven', render: (r: any) => String(r.km_driven ?? 0) },
    { key: 'fuel_litres', header: 'Fuel (L)', render: (r: any) => String(r.fuel_litres ?? 0) },
    { key: 'fuel_cost_rupees', header: 'Fuel (Rs)', render: (r: any) => String(r.fuel_cost_rupees ?? 0) },
    { key: 'jobs_count', header: 'Jobs', render: (r: any) => String(r.jobs_count ?? 0) },
    { key: 'cost_per_km', header: 'Rs/KM', render: (r: any) => String(r.cost_per_km ?? 0) },
  ];

  const outlierCols: Column<any>[] = [
    { key: 'flag_period_start', header: 'Period Start', render: (r: any) => String(r.flag_period_start ?? '') },
    { key: 'flag_period_end', header: 'Period End', render: (r: any) => String(r.flag_period_end ?? '') },
    { key: 'vehicle_label', header: 'Vehicle', render: (r: any) => String(r.vehicle_label ?? '') },
    { key: 'flag_kind', header: 'Flag', render: (r: any) => String(r.flag_kind ?? '') },
    { key: 'observed_value', header: 'Observed', render: (r: any) => String(r.observed_value ?? 0) },
    { key: 'benchmark_value', header: 'Benchmark', render: (r: any) => String(r.benchmark_value ?? 0) },
    { key: 'delta_pct', header: 'Delta %', render: (r: any) => String(r.delta_pct ?? 0) },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'action_taken', header: 'Action', render: (r: any) => String(r.action_taken ?? '') },
  ];

  const topCostCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer ID', render: (r: any) => String(r.engineer_user_id ?? '') },
    { key: 'trip_count', header: 'Trips', render: (r: any) => String(r.trip_count ?? 0) },
    { key: 'total_km', header: 'Total KM', render: (r: any) => String(r.total_km ?? 0) },
    { key: 'total_litres', header: 'Total L', render: (r: any) => String(r.total_litres ?? 0) },
    { key: 'total_fuel_cost_rupees', header: 'Fuel (Rs)', render: (r: any) => String(r.total_fuel_cost_rupees ?? 0) },
    { key: 'avg_cost_per_km', header: 'Avg Rs/KM', render: (r: any) => String(r.avg_cost_per_km ?? 0) },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
  ];

  const zoneCols: Column<any>[] = [
    { key: 'zone_label', header: 'Zone', render: (r: any) => String(r.zone_label ?? '') },
    { key: 'trip_count', header: 'Trips', render: (r: any) => String(r.trip_count ?? 0) },
    { key: 'total_km', header: 'KM', render: (r: any) => String(r.total_km ?? 0) },
    { key: 'total_litres', header: 'Litres', render: (r: any) => String(r.total_litres ?? 0) },
    { key: 'total_fuel_cost_rupees', header: 'Fuel (Rs)', render: (r: any) => String(r.total_fuel_cost_rupees ?? 0) },
    { key: 'avg_cost_per_km', header: 'Avg Rs/KM', render: (r: any) => String(r.avg_cost_per_km ?? 0) },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'km_per_job', header: 'KM/Job', render: (r: any) => String(r.km_per_job ?? 0) },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'trip_count', header: 'Trips', render: (r: any) => String(r.trip_count ?? 0) },
    { key: 'total_km', header: 'KM', render: (r: any) => String(r.total_km ?? 0) },
    { key: 'total_litres', header: 'Litres', render: (r: any) => String(r.total_litres ?? 0) },
    { key: 'total_fuel_cost_rupees', header: 'Fuel (Rs)', render: (r: any) => String(r.total_fuel_cost_rupees ?? 0) },
    { key: 'avg_cost_per_km', header: 'Avg Rs/KM', render: (r: any) => String(r.avg_cost_per_km ?? 0) },
  ];

  const vehicleCols: Column<any>[] = [
    { key: 'vehicle_label', header: 'Vehicle', render: (r: any) => String(r.vehicle_label ?? '') },
    { key: 'trip_count', header: 'Trips', render: (r: any) => String(r.trip_count ?? 0) },
    { key: 'total_km', header: 'KM', render: (r: any) => String(r.total_km ?? 0) },
    { key: 'total_litres', header: 'Litres', render: (r: any) => String(r.total_litres ?? 0) },
    { key: 'total_fuel_cost_rupees', header: 'Fuel (Rs)', render: (r: any) => String(r.total_fuel_cost_rupees ?? 0) },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'km_per_job', header: 'KM/Job', render: (r: any) => String(r.km_per_job ?? 0) },
    { key: 'avg_cost_per_km', header: 'Avg Rs/KM', render: (r: any) => String(r.avg_cost_per_km ?? 0) },
  ];

  const topOpenCols: Column<any>[] = [
    { key: 'flag_period_start', header: 'Period Start', render: (r: any) => String(r.flag_period_start ?? '') },
    { key: 'flag_period_end', header: 'Period End', render: (r: any) => String(r.flag_period_end ?? '') },
    { key: 'vehicle_label', header: 'Vehicle', render: (r: any) => String(r.vehicle_label ?? '') },
    { key: 'flag_kind', header: 'Flag', render: (r: any) => String(r.flag_kind ?? '') },
    { key: 'observed_value', header: 'Observed', render: (r: any) => String(r.observed_value ?? 0) },
    { key: 'benchmark_value', header: 'Benchmark', render: (r: any) => String(r.benchmark_value ?? 0) },
    { key: 'delta_pct', header: 'Delta %', render: (r: any) => String(r.delta_pct ?? 0) },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '') },
  ];

  return (
    <main style={{ padding: '24px', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '6px' }}>
        Engineer Vehicle Fuel Log
      </h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Per-engineer vehicle x km x fuel L x Rs/km x outlier kms x cost vs zone benchmark.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Open Outlier Flags</h2>
        <DataTable
          rows={topOpen}
          columns={topOpenCols}
          emptyMessage="No open outlier flags."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Top Cost Engineers</h2>
        <DataTable
          rows={topCost}
          columns={topCostCols}
          emptyMessage="No engineer cost data."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Zone Benchmark Summary</h2>
        <DataTable
          rows={zone}
          columns={zoneCols}
          emptyMessage="No zone data."
          rowKey={(r: any, i: number) => String(r.zone_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Vehicle Utilization</h2>
        <DataTable
          rows={vehicle}
          columns={vehicleCols}
          emptyMessage="No vehicle data."
          rowKey={(r: any, i: number) => String(r.vehicle_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Weekly Fuel Trend</h2>
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          emptyMessage="No weekly trend."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>All Trips</h2>
        <DataTable
          rows={trips}
          columns={tripCols}
          emptyMessage="No trips recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>All Outlier Flags</h2>
        <DataTable
          rows={outliers}
          columns={outlierCols}
          emptyMessage="No outlier flags."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
