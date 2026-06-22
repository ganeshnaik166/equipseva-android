import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [workloadsRes, overloadedRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_workloads_r2048'),
    sb.rpc('overloaded_r2048'),
    sb.rpc('recent_actions_r2048'),
  ]);

  const workloads: any[] = Array.isArray(workloadsRes.data) ? workloadsRes.data : [];
  const overloaded: any[] = Array.isArray(overloadedRes.data) ? overloadedRes.data : [];
  const recentActions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const workloadCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'hospitals_served', header: 'Hospitals', render: (r: any) => String(r.hospitals_served ?? 0) },
    { key: 'total_jobs', header: 'Total Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'avg_jobs_per_hospital', header: 'Avg per Hospital', render: (r: any) => String(r.avg_jobs_per_hospital ?? 0) },
    { key: 'workload_status', header: 'Status', render: (r: any) => String(r.workload_status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const overloadedCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'hospitals_served', header: 'Hospitals', render: (r: any) => String(r.hospitals_served ?? 0) },
    { key: 'total_jobs', header: 'Total Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'workload_status', header: 'Status', render: (r: any) => String(r.workload_status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'workload_id', header: 'Workload', render: (r: any) => String(r.workload_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Multi-Tenancy Workload</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track engineer workload across multiple hospitals. Spot overloaded engineers and rebalance assignments.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Workloads</h2>
        <DataTable rows={workloads} columns={workloadCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Overloaded Engineers</h2>
        <DataTable rows={overloaded} columns={overloadedCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Workload Actions</h2>
        <DataTable rows={recentActions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
