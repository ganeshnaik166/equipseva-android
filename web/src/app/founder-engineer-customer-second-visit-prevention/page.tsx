import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [rootCauses, actions, topFocus, kindDist, monthlyTrend, costSummary, ownerLoad] = await Promise.all([
    supabase.rpc('list_root_causes_r2618'),
    supabase.rpc('list_prevention_actions_r2618'),
    supabase.rpc('top_preventable_focus_r2618'),
    supabase.rpc('root_cause_kind_distribution_r2618'),
    supabase.rpc('monthly_second_visit_trend_r2618'),
    supabase.rpc('cost_summary_r2618'),
    supabase.rpc('owner_load_r2618'),
  ]);

  const rootCols: Column<any>[] = [
    { key: 'second_visit_at', header: 'Second Visit', render: (r: any) => new Date(r.second_visit_at).toLocaleDateString() },
    { key: 'root_cause_kind', header: 'Root Cause', render: (r: any) => r.root_cause_kind },
    { key: 'preventable', header: 'Preventable', render: (r: any) => (r.preventable ? 'yes' : 'no') },
    { key: 'cost_rupees', header: 'Cost (Rs)', render: (r: any) => r.cost_rupees },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'Action At', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'root_cause_kind', header: 'Kind', render: (r: any) => r.root_cause_kind },
    { key: 'preventable_count', header: 'Preventable #', render: (r: any) => r.preventable_count },
    { key: 'total_cost_rupees', header: 'Cost (Rs)', render: (r: any) => r.total_cost_rupees },
  ];

  const kindCols: Column<any>[] = [
    { key: 'root_cause_kind', header: 'Kind', render: (r: any) => r.root_cause_kind },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => new Date(r.month_start).toLocaleDateString() },
    { key: 'cnt', header: 'Visits', render: (r: any) => r.cnt },
    { key: 'total_cost', header: 'Cost (Rs)', render: (r: any) => r.total_cost },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'open_root_causes', header: 'Open Causes', render: (r: any) => r.open_root_causes },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => r.open_actions },
  ];

  const cs = (costSummary.data ?? [])[0] ?? { total_cost: 0, preventable_cost: 0, open_count: 0, closed_count: 0 };

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-bold">Engineer & Customer Second-Visit Prevention</h1>
      <p className="text-sm text-gray-600">Track second-visit root causes & prevention actions to cut repeat visits =&gt; lower cost.</p>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="border rounded p-3"><div className="text-xs text-gray-500">Total Cost</div><div className="text-xl font-bold">Rs {cs.total_cost}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-gray-500">Preventable Cost</div><div className="text-xl font-bold">Rs {cs.preventable_cost}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-gray-500">Open</div><div className="text-xl font-bold">{cs.open_count}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-gray-500">Closed</div><div className="text-xl font-bold">{cs.closed_count}</div></div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Root Causes</h2>
        <DataTable rows={rootCauses.data ?? []} columns={rootCols} emptyMessage="No root causes" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Prevention Actions</h2>
        <DataTable rows={actions.data ?? []} columns={actionCols} emptyMessage="No actions" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Preventable Focus</h2>
        <DataTable rows={topFocus.data ?? []} columns={focusCols} emptyMessage="No focus rows" rowKey={(r: any, i: number) => String(r.root_cause_kind ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Kind Distribution</h2>
        <DataTable rows={kindDist.data ?? []} columns={kindCols} emptyMessage="No distribution" rowKey={(r: any, i: number) => String(r.root_cause_kind ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Trend</h2>
        <DataTable rows={monthlyTrend.data ?? []} columns={trendCols} emptyMessage="No trend" rowKey={(r: any, i: number) => String(r.month_start ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable rows={ownerLoad.data ?? []} columns={ownerCols} emptyMessage="No owners" rowKey={(r: any, i: number) => String(r.owner_email ?? i)} />
      </section>
    </div>
  );
}
