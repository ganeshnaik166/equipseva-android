import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [plansRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_recovery_plans_r2160'),
    sb.rpc('active_recovery_plans_r2160'),
    sb.rpc('recent_recovery_milestones_r2160'),
  ]);

  const plans: any[] = Array.isArray(plansRes.data) ? plansRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const planCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'recovery_focus', header: 'Focus', render: (r: any) => String(r.recovery_focus ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'target_completion_date', header: 'Target', render: (r: any) => r.target_completion_date ? String(r.target_completion_date) : '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'recovery_focus', header: 'Focus', render: (r: any) => String(r.recovery_focus ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'target_completion_date', header: 'Target', render: (r: any) => r.target_completion_date ? String(r.target_completion_date) : '' },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'plan_id', header: 'Plan', render: (r: any) => String(r.plan_id ?? '').slice(0, 8) },
    { key: 'milestone_type', header: 'Type', render: (r: any) => String(r.milestone_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600 }}>Engineer Quality Recovery Plan</h1>
      <p style={{ color: '#555', marginTop: 8 }}>Recovery plans for engineers with quality issues. Track focus areas, milestones, and outcomes.</p>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Active Plans</h2>
        <DataTable rows={active} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>All Plans</h2>
        <DataTable rows={plans} columns={planCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Recent Milestones</h2>
        <DataTable rows={recent} columns={milestoneCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
