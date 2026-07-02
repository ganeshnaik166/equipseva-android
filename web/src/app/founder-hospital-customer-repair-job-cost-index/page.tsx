import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [indices, expensive, recent] = await Promise.all([
    sb.rpc('list_indices_r2171'),
    sb.rpc('expensive_r2171'),
    sb.rpc('recent_actions_r2171'),
  ]);

  const indexCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'total_cost_rupees', header: 'Total Cost', render: (r: any) => '₹' + Number(r.total_cost_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'avg_cost_per_job_rupees', header: 'Avg per Job', render: (r: any) => '₹' + Number(r.avg_cost_per_job_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'cost_index_pct', header: 'Index %', render: (r: any) => String(r.cost_index_pct ?? 0) + '%' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const expensiveCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'avg_cost_per_job_rupees', header: 'Avg/Job', render: (r: any) => '₹' + Number(r.avg_cost_per_job_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'cost_index_pct', header: 'Index %', render: (r: any) => String(r.cost_index_pct ?? 0) + '%' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'index_id', header: 'Index', render: (r: any) => String(r.index_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Repair Job Cost Index</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Cost per repair job indexed across hospitals. Spot expensive outliers and act.</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Cost Indices</h2>
        <DataTable rows={(indices.data as any[]) ?? []} columns={indexCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Expensive Outliers</h2>
        <DataTable rows={(expensive.data as any[]) ?? []} columns={expensiveCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable rows={(recent.data as any[]) ?? []} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
