import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [stickyRes, actionsRes, weakRes, gradesRes, statusRes, trendRes, ownerRes] = await Promise.all([
    supabase.rpc('list_stickiness_r2656'),
    supabase.rpc('list_improvement_actions_r2656'),
    supabase.rpc('top_weak_focus_r2656'),
    supabase.rpc('grade_distribution_r2656'),
    supabase.rpc('status_funnel_r2656'),
    supabase.rpc('quarterly_stickiness_trend_r2656'),
    supabase.rpc('owner_load_r2656'),
  ]);

  const sticky = (stickyRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const weak = (weakRes.data ?? []) as any[];
  const grades = (gradesRes.data ?? []) as any[];
  const statuses = (statusRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const owners = (ownerRes.data ?? []) as any[];

  const fmtRupees = (v: any) =>
    typeof v === 'number' || typeof v === 'string'
      ? `₹${Number(v).toLocaleString('en-IN')}`
      : '—';

  const stickyCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'stickiness_grade', header: 'Grade', render: (r: any) => r.stickiness_grade },
    { key: 'integration_depth_score', header: 'Integration', render: (r: any) => `${r.integration_depth_score}/100` },
    { key: 'equipment_count', header: 'Equip', render: (r: any) => r.equipment_count },
    { key: 'switching_cost_rupees', header: 'Switch Cost', render: (r: any) => fmtRupees(r.switching_cost_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const weakCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'stickiness_grade', header: 'Grade', render: (r: any) => r.stickiness_grade },
    { key: 'integration_depth_score', header: 'Integration', render: (r: any) => `${r.integration_depth_score}/100` },
    { key: 'switching_cost_rupees', header: 'Switch Cost', render: (r: any) => fmtRupees(r.switching_cost_rupees) },
    { key: 'equipment_count', header: 'Equip', render: (r: any) => r.equipment_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const gradeCols: Column<any>[] = [
    { key: 'stickiness_grade', header: 'Grade', render: (r: any) => r.stickiness_grade },
    { key: 'customer_count', header: 'Customers', render: (r: any) => r.customer_count },
    { key: 'avg_integration_depth', header: 'Avg Integration', render: (r: any) => `${r.avg_integration_depth}/100` },
    { key: 'total_switching_cost_rupees', header: 'Total Switch Cost', render: (r: any) => fmtRupees(r.total_switching_cost_rupees) },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'customer_count', header: 'Customers', render: (r: any) => r.customer_count },
    { key: 'total_switching_cost_rupees', header: 'Total Switch Cost', render: (r: any) => fmtRupees(r.total_switching_cost_rupees) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'customer_count', header: 'Customers', render: (r: any) => r.customer_count },
    { key: 'avg_integration_depth', header: 'Avg Integration', render: (r: any) => `${r.avg_integration_depth}/100` },
    { key: 'total_switching_cost_rupees', header: 'Total Switch Cost', render: (r: any) => fmtRupees(r.total_switching_cost_rupees) },
    { key: 'grade_a_count', header: 'Grade A', render: (r: any) => r.grade_a_count },
    { key: 'grade_f_count', header: 'Grade F', render: (r: any) => r.grade_f_count },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'account_count', header: 'Accounts', render: (r: any) => r.account_count },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => r.open_actions },
    { key: 'total_switching_cost_rupees', header: 'Total Switch Cost', render: (r: any) => fmtRupees(r.total_switching_cost_rupees) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Quarterly Stickiness Grade Card</h1>
        <p className="text-sm text-gray-600">
          Grade each hospital A => F on equipment count, integration depth & switching cost; track improvement actions per quarter.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Weak Accounts (focus list)</h2>
        <DataTable
          rows={weak}
          columns={weakCols}
          emptyMessage="No weak accounts — every customer is grade A or B."
          rowKey={(r: any, i: number) => String(r.id ?? `${r.hospital_email}-${r.quarter_label}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Grade Distribution</h2>
        <DataTable
          rows={grades}
          columns={gradeCols}
          emptyMessage="No grades recorded yet."
          rowKey={(r: any, i: number) => String(r.stickiness_grade ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Funnel</h2>
        <DataTable
          rows={statuses}
          columns={statusCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No quarterly data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={owners}
          columns={ownerCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Stickiness Records</h2>
        <DataTable
          rows={sticky}
          columns={stickyCols}
          emptyMessage="No stickiness records yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Improvement Actions Log</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No improvement actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
