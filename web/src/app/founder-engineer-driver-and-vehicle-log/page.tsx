import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtINR(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  return new Date(s).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function fmtDateTime(s: string | null | undefined): string {
  if (!s) return '-';
  return new Date(s).toLocaleString('en-IN', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [vehiclesRes, downtimeRes, mixRes, alertsRes, byTypeRes, kpisRes, recentRes] = await Promise.all([
    sb.rpc('r2278_list_vehicles'),
    sb.rpc('r2278_list_downtime'),
    sb.rpc('r2278_vehicle_type_mix'),
    sb.rpc('r2278_compliance_alerts'),
    sb.rpc('r2278_downtime_by_type'),
    sb.rpc('r2278_kpis'),
    sb.rpc('r2278_recent_downtime'),
  ]);

  const vehicles = (vehiclesRes.data ?? []) as any[];
  const downtime = (downtimeRes.data ?? []) as any[];
  const mix = (mixRes.data ?? []) as any[];
  const alerts = (alertsRes.data ?? []) as any[];
  const byType = (byTypeRes.data ?? []) as any[];
  const kpis = (kpisRes.data?.[0] ?? {}) as any;
  const recent = (recentRes.data ?? []) as any[];

  const vehicleCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'vehicle_reg_no', header: 'Reg No', render: (r) => r.vehicle_reg_no },
    { key: 'vehicle_make_model', header: 'Make / Model', render: (r) => r.vehicle_make_model },
    { key: 'vehicle_type', header: 'Type', render: (r) => r.vehicle_type },
    { key: 'ownership', header: 'Ownership', render: (r) => r.ownership },
    { key: 'driver_name', header: 'Driver', render: (r) => r.has_dedicated_driver ? (r.driver_name ?? '-') : 'Self' },
    { key: 'monthly_kms', header: 'Km/mo', render: (r) => (r.monthly_kms ?? 0).toLocaleString('en-IN') },
    { key: 'monthly_fuel_cost_rupees', header: 'Fuel/mo', render: (r) => fmtINR(r.monthly_fuel_cost_rupees) },
    { key: 'monthly_driver_cost_rupees', header: 'Driver/mo', render: (r) => fmtINR(r.monthly_driver_cost_rupees) },
    { key: 'next_service_due_at', header: 'Next Svc', render: (r) => fmtDate(r.next_service_due_at) },
    { key: 'insurance_expiry', header: 'Ins Exp', render: (r) => fmtDate(r.insurance_expiry) },
    { key: 'puc_expiry', header: 'PUC Exp', render: (r) => fmtDate(r.puc_expiry) },
    { key: 'status', header: 'Status', render: (r) => r.status },
  ];

  const downtimeCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'vehicle_reg_no', header: 'Reg No', render: (r) => r.vehicle_reg_no },
    { key: 'event_type', header: 'Event', render: (r) => r.event_type },
    { key: 'started_at', header: 'Started', render: (r) => fmtDateTime(r.started_at) },
    { key: 'ended_at', header: 'Ended', render: (r) => r.ended_at ? fmtDateTime(r.ended_at) : 'open' },
    { key: 'downtime_hours', header: 'Hours', render: (r) => Number(r.downtime_hours ?? 0).toFixed(1) },
    { key: 'cost_rupees', header: 'Cost', render: (r) => fmtINR(r.cost_rupees) },
    { key: 'jobs_missed', header: 'Jobs Missed', render: (r) => r.jobs_missed ?? 0 },
    { key: 'revenue_impact_rupees', header: 'Rev Impact', render: (r) => fmtINR(r.revenue_impact_rupees) },
    { key: 'vendor_name', header: 'Vendor', render: (r) => r.vendor_name ?? '-' },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '-' },
  ];

  const mixCols: Column<any>[] = [
    { key: 'vehicle_type', header: 'Type', render: (r) => r.vehicle_type },
    { key: 'vehicle_count', header: 'Count', render: (r) => r.vehicle_count },
    { key: 'with_dedicated_driver', header: 'With Driver', render: (r) => r.with_dedicated_driver },
    { key: 'total_monthly_kms', header: 'Total Km/mo', render: (r) => (r.total_monthly_kms ?? 0).toLocaleString('en-IN') },
    { key: 'total_monthly_fuel_rupees', header: 'Fuel/mo', render: (r) => fmtINR(r.total_monthly_fuel_rupees) },
    { key: 'total_monthly_driver_rupees', header: 'Driver/mo', render: (r) => fmtINR(r.total_monthly_driver_rupees) },
  ];

  const alertCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'vehicle_reg_no', header: 'Reg No', render: (r) => r.vehicle_reg_no },
    { key: 'alert_type', header: 'Alert', render: (r) => r.alert_type },
    { key: 'due_date', header: 'Due', render: (r) => fmtDate(r.due_date) },
    { key: 'days_remaining', header: 'Days Left', render: (r) => {
      const d = r.days_remaining ?? 0;
      return d < 0 ? `OVERDUE ${Math.abs(d)}d` : `${d}d`;
    } },
  ];

  const byTypeCols: Column<any>[] = [
    { key: 'event_type', header: 'Event', render: (r) => r.event_type },
    { key: 'event_count', header: 'Count', render: (r) => r.event_count },
    { key: 'total_downtime_hours', header: 'Hours', render: (r) => Number(r.total_downtime_hours ?? 0).toFixed(1) },
    { key: 'total_cost_rupees', header: 'Cost', render: (r) => fmtINR(r.total_cost_rupees) },
    { key: 'total_jobs_missed', header: 'Jobs Missed', render: (r) => r.total_jobs_missed },
    { key: 'total_revenue_impact_rupees', header: 'Rev Impact', render: (r) => fmtINR(r.total_revenue_impact_rupees) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'vehicle_reg_no', header: 'Reg No', render: (r) => r.vehicle_reg_no },
    { key: 'event_type', header: 'Event', render: (r) => r.event_type },
    { key: 'started_at', header: 'When', render: (r) => fmtDateTime(r.started_at) },
    { key: 'downtime_hours', header: 'Hours', render: (r) => Number(r.downtime_hours ?? 0).toFixed(1) },
    { key: 'jobs_missed', header: 'Jobs Missed', render: (r) => r.jobs_missed },
    { key: 'revenue_impact_rupees', header: 'Rev Impact', render: (r) => fmtINR(r.revenue_impact_rupees) },
  ];

  return (
    <main style={{ padding: '1.5rem', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '1.5rem', fontWeight: 700, marginBottom: '0.25rem' }}>
        Engineer Driver & Vehicle Log
      </h1>
      <p style={{ color: '#666', marginBottom: '1.5rem' }}>
        Field-engineer vehicles, dedicated drivers, servicing schedule, and downtime impact on revenue.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.75rem', marginBottom: '1.5rem' }}>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Total vehicles</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{kpis.total_vehicles ?? 0}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>With dedicated driver</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{kpis.with_dedicated_drivers ?? 0}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Active</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{kpis.active_vehicles ?? 0}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>In service</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{kpis.vehicles_in_service ?? 0}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Fuel / month</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{fmtINR(kpis.total_monthly_fuel_rupees)}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Driver pay / month</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{fmtINR(kpis.total_monthly_driver_rupees)}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Downtime 90d (hrs)</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{Number(kpis.downtime_hours_90d ?? 0).toFixed(1)}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Rev impact 90d</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{fmtINR(kpis.revenue_impact_90d_rupees)}</div>
        </div>
        <div style={{ padding: '0.75rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: '0.75rem', color: '#666' }}>Jobs missed 90d</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{kpis.jobs_missed_90d ?? 0}</div>
        </div>
      </section>

      <h2 style={{ fontSize: '1.1rem', fontWeight: 600, margin: '1rem 0 0.5rem' }}>Compliance alerts (next 30 days)</h2>
      <DataTable columns={alertCols} rows={alerts} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '1.1rem', fontWeight: 600, margin: '1.5rem 0 0.5rem' }}>Vehicles & drivers</h2>
      <DataTable columns={vehicleCols} rows={vehicles} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '1.1rem', fontWeight: 600, margin: '1.5rem 0 0.5rem' }}>Vehicle type mix</h2>
      <DataTable columns={mixCols} rows={mix} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '1.1rem', fontWeight: 600, margin: '1.5rem 0 0.5rem' }}>Downtime by event type</h2>
      <DataTable columns={byTypeCols} rows={byType} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '1.1rem', fontWeight: 600, margin: '1.5rem 0 0.5rem' }}>Recent downtime (last 180d)</h2>
      <DataTable columns={recentCols} rows={recent} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '1.1rem', fontWeight: 600, margin: '1.5rem 0 0.5rem' }}>All downtime events</h2>
      <DataTable columns={downtimeCols} rows={downtime} rowKey={(_, i) => String(i)} />
    </main>
  );
}
