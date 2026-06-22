import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [logsRes, actionsRes, topRes, aggRes] = await Promise.all([
    sb.rpc('list_mileage_logs_r2206'),
    sb.rpc('recent_actions_r2206'),
    sb.rpc('top_engineers_r2206'),
    sb.rpc('aggregate_mileage_r2206'),
  ]);

  const logs = (logsRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];
  const agg = (aggRes.data ?? [])[0] ?? {};

  const logCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'job_ref', header: 'Job', render: (r: any) => r.job_ref },
    { key: 'trip_date', header: 'Date', render: (r: any) => r.trip_date },
    { key: 'route', header: 'Route', render: (r: any) => `${r.origin_label} -> ${r.destination_label}` },
    { key: 'distance_km', header: 'Km', render: (r: any) => Number(r.distance_km).toFixed(1) },
    { key: 'travel_minutes', header: 'Mins', render: (r: any) => r.travel_minutes },
    { key: 'billable_km', header: 'Billable Km', render: (r: any) => Number(r.billable_km).toFixed(1) },
    { key: 'reimbursement_rupees', header: 'Reimb ₹', render: (r: any) => `₹${r.reimbursement_rupees}` },
    { key: 'outlier_flag', header: 'Outlier', render: (r: any) => (r.outlier_flag ? 'YES' : '-') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'trip_count', header: 'Trips', render: (r: any) => r.trip_count },
    { key: 'total_km', header: 'Total Km', render: (r: any) => Number(r.total_km).toFixed(1) },
    { key: 'total_reimbursement_rupees', header: 'Total Reimb', render: (r: any) => `₹${r.total_reimbursement_rupees}` },
    { key: 'outlier_count', header: 'Outliers', render: (r: any) => r.outlier_count },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action', header: 'Action', render: (r: any) => r.action },
    { key: 'detail', header: 'Detail', render: (r: any) => r.detail ?? '-' },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '-' },
    { key: 'created_at', header: 'When', render: (r: any) => new Date(r.created_at).toLocaleString() },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1>Engineer Mileage & Travel Tracker</h1>
      <p>Capture per-job mileage, travel hours & billable distance. Flag outliers. Reimbursement queue.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, margin: '16px 0' }}>
        <div><b>Trips</b><div>{agg.total_trips ?? 0}</div></div>
        <div><b>Total Km</b><div>{Number(agg.total_km ?? 0).toFixed(1)}</div></div>
        <div><b>Total Reimb</b><div>₹{agg.total_reimbursement_rupees ?? 0}</div></div>
        <div><b>Pending</b><div>{agg.pending_count ?? 0}</div></div>
        <div><b>Outliers</b><div>{agg.outlier_count ?? 0}</div></div>
      </div>

      <h2>Mileage Log Queue</h2>
      <DataTable<any> columns={logCols} rows={logs} rowKey={(_, i) => String(i)} />

      <h2>Top Engineers by Reimbursement</h2>
      <DataTable<any> columns={topCols} rows={top} rowKey={(_, i) => String(i)} />

      <h2>Recent Actions</h2>
      <DataTable<any> columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />
    </div>
  );
}
