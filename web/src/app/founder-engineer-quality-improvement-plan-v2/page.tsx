import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [plansRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_qip_v2_plans_r2184'),
    sb.rpc('active_qip_v2_plans_r2184'),
    sb.rpc('recent_qip_v2_milestones_r2184'),
  ]);

  const plans: any[] = (plansRes.data as any[]) ?? [];
  const active: any[] = (activeRes.data as any[]) ?? [];
  const recent: any[] = (recentRes.data as any[]) ?? [];

  const planCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'improvement_focus', header: 'Focus', render: (r: any) => r.improvement_focus ?? '' },
    { key: 'baseline_score', header: 'Baseline', render: (r: any) => r.baseline_score ?? '' },
    { key: 'current_score', header: 'Current', render: (r: any) => r.current_score ?? '' },
    { key: 'target_score', header: 'Target', render: (r: any) => r.target_score ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'improvement_focus', header: 'Focus', render: (r: any) => r.improvement_focus ?? '' },
    { key: 'current_score', header: 'Current', render: (r: any) => r.current_score ?? '' },
    { key: 'target_score', header: 'Target', render: (r: any) => r.target_score ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'plan_id', header: 'Plan', render: (r: any) => String(r.plan_id ?? '').slice(0, 8) },
    { key: 'milestone_type', header: 'Type', render: (r: any) => r.milestone_type ?? '' },
    { key: 'score', header: 'Score', render: (r: any) => r.score ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Quality Improvement Plan v2</h1>
        <p className="text-sm text-gray-600">V2 quality improvement plans for engineer development tracking.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Active plans</h2>
        <DataTable rows={active} columns={activeCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All plans</h2>
        <DataTable rows={plans} columns={planCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent milestones</h2>
        <DataTable rows={recent} columns={milestoneCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
