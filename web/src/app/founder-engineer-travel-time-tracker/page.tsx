import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [travelsRes, delayedRes, recentRes] = await Promise.all([
    sb.rpc('list_travels_r2004'),
    sb.rpc('delayed_travels_r2004'),
    sb.rpc('recent_actions_r2004'),
  ]);

  const travels: any[] = Array.isArray(travelsRes.data) ? travelsRes.data : [];
  const delayed: any[] = Array.isArray(delayedRes.data) ? delayedRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const travelCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'expected_travel_minutes', header: 'Expected min', render: (r: any) => String(r.expected_travel_minutes ?? 0) },
    { key: 'actual_travel_minutes', header: 'Actual min', render: (r: any) => String(r.actual_travel_minutes ?? 0) },
    { key: 'variance_minutes', header: 'Variance', render: (r: any) => String(r.variance_minutes ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const delayedCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'expected_travel_minutes', header: 'Expected min', render: (r: any) => String(r.expected_travel_minutes ?? 0) },
    { key: 'actual_travel_minutes', header: 'Actual min', render: (r: any) => String(r.actual_travel_minutes ?? 0) },
    { key: 'variance_minutes', header: 'Variance', render: (r: any) => String(r.variance_minutes ?? 0) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'travel_id', header: 'Travel', render: (r: any) => String(r.travel_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 8 }}>Engineer Travel Time Tracker</h1>
      <p style={{ marginBottom: 16, color: '#555' }}>
        Track engineer travel time to jobs. Variance equals actual minus expected minutes.
      </p>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent travels</h2>
        <DataTable rows={travels} columns={travelCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Delayed travels</h2>
        <DataTable rows={delayed} columns={delayedCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
