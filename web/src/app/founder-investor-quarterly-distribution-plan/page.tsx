import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [plansRes, upcomingRes, recentRes] = await Promise.all([
    sb.rpc('list_plans_r2025'),
    sb.rpc('upcoming_plans_r2025'),
    sb.rpc('recent_actions_r2025'),
  ]);

  const plans: any[] = Array.isArray(plansRes.data) ? plansRes.data : [];
  const upcoming: any[] = Array.isArray(upcomingRes.data) ? upcomingRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const planCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'planned_total_rupees', header: 'Planned rupees', render: (r: any) => String(r.planned_total_rupees ?? 0) },
    { key: 'executed_total_rupees', header: 'Executed rupees', render: (r: any) => String(r.executed_total_rupees ?? 0) },
    { key: 'planned_date', header: 'Planned date', render: (r: any) => String(r.planned_date ?? '') },
    { key: 'executed_date', header: 'Executed date', render: (r: any) => String(r.executed_date ?? '') },
    { key: 'captured_at', header: 'Captured at', render: (r: any) => String(r.captured_at ?? '') },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'planned_date', header: 'Planned date', render: (r: any) => String(r.planned_date ?? '') },
    { key: 'planned_total_rupees', header: 'Planned rupees', render: (r: any) => String(r.planned_total_rupees ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'plan_id', header: 'Plan', render: (r: any) => String(r.plan_id ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'amount_rupees', header: 'Amount rupees', render: (r: any) => String(r.amount_rupees ?? 0) },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => String(r.taken_at ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Quarterly Distribution Plan</h1>
        <p className="text-sm text-gray-600">Plan and track quarterly investor distributions. Founder only.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All plans</h2>
        <DataTable rows={plans} columns={planCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming plans</h2>
        <DataTable rows={upcoming} columns={upcomingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
