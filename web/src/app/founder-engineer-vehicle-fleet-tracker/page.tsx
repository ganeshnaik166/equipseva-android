import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerVehicleFleetTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [vehiclesRes, maintRes, upcomingRes, summaryRes] = await Promise.all([
    sb.rpc('list_vehicles_r1716'),
    sb.rpc('list_maintenance_r1716', { p_vehicle_id: null }),
    sb.rpc('upcoming_maintenance_r1716'),
    sb.rpc('fleet_summary_r1716'),
  ]);

  const vehicles: any[] = Array.isArray(vehiclesRes.data) ? vehiclesRes.data : [];
  const maint: any[] = Array.isArray(maintRes.data) ? maintRes.data : [];
  const upcoming: any[] = Array.isArray(upcomingRes.data) ? upcomingRes.data : [];
  const summary: any =
    Array.isArray(summaryRes.data) && summaryRes.data.length > 0 ? summaryRes.data[0] : null;

  const vehicleCols: Column<any>[] = [
    { key: 'registration_number', header: 'Reg #', render: (r: any) => String(r.registration_number ?? '') },
    { key: 'vehicle_type', header: 'Type', render: (r: any) => String(r.vehicle_type ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'total_km', header: 'Total KM', render: (r: any) => Number(r.total_km ?? 0).toLocaleString() },
    { key: 'assigned_on', header: 'Assigned', render: (r: any) => String(r.assigned_on ?? '') },
    { key: 'retired_on', header: 'Retired', render: (r: any) => String(r.retired_on ?? '—') },
  ];

  const maintCols: Column<any>[] = [
    { key: 'registration_number', header: 'Vehicle', render: (r: any) => String(r.registration_number ?? '') },
    { key: 'maintenance_type', header: 'Type', render: (r: any) => String(r.maintenance_type ?? '') },
    {
      key: 'performed_at',
      header: 'Performed',
      render: (r: any) => (r.performed_at ? new Date(r.performed_at).toLocaleString() : '—'),
    },
    {
      key: 'cost_rupees',
      header: 'Cost',
      render: (r: any) => `₹${Number(r.cost_rupees ?? 0).toLocaleString()}`,
    },
    {
      key: 'next_due_at',
      header: 'Next Due',
      render: (r: any) => (r.next_due_at ? new Date(r.next_due_at).toLocaleDateString() : '—'),
    },
    { key: 'note', header: 'Note', render: (r: any) => String(r.note ?? '') },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'registration_number', header: 'Vehicle', render: (r: any) => String(r.registration_number ?? '') },
    { key: 'maintenance_type', header: 'Type', render: (r: any) => String(r.maintenance_type ?? '') },
    {
      key: 'next_due_at',
      header: 'Due',
      render: (r: any) => (r.next_due_at ? new Date(r.next_due_at).toLocaleDateString() : '—'),
    },
    {
      key: 'days_until',
      header: 'Days Until',
      render: (r: any) => {
        const d = Number(r.days_until ?? 0);
        return d <= 7 ? `${d} (urgent)` : String(d);
      },
    },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Engineer Vehicle Fleet Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-engineer vehicle log and maintenance schedule. Tracks active vs retired vehicles,
        cost-of-fleet, and upcoming service dates within 30 days.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Fleet Summary</h2>
        {summary ? (
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
              gap: 12,
            }}
          >
            <Stat label="Total Vehicles" value={String(summary.total_vehicles ?? 0)} />
            <Stat label="Active" value={String(summary.active_count ?? 0)} />
            <Stat label="In Maintenance" value={String(summary.maintenance_count ?? 0)} />
            <Stat label="Retired" value={String(summary.retired_count ?? 0)} />
            <Stat
              label="Total Maint Spend"
              value={`₹${Number(summary.total_maint_spend_rupees ?? 0).toLocaleString()}`}
            />
            <Stat
              label="Due in 30 Days"
              value={String(summary.upcoming_due_count ?? 0)}
            />
          </div>
        ) : (
          <p style={{ color: '#999' }}>No summary data.</p>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Upcoming Maintenance (next 30 days window)
        </h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Fleet (latest 200)</h2>
        <DataTable
          rows={vehicles}
          columns={vehicleCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Maintenance Log (latest 200)
        </h2>
        <DataTable
          rows={maint}
          columns={maintCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        padding: 16,
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        background: '#fafafa',
      }}
    >
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
