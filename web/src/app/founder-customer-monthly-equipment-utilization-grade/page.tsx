import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [grades, actions, focus, dist, funnel, trend, owners] = await Promise.all([
    supabase.rpc('list_grades_r2664'),
    supabase.rpc('list_actions_r2664'),
    supabase.rpc('top_under_utilized_focus_r2664'),
    supabase.rpc('grade_distribution_r2664'),
    supabase.rpc('status_funnel_r2664'),
    supabase.rpc('monthly_grade_trend_r2664'),
    supabase.rpc('owner_load_r2664'),
  ]);

  const gradeRows = (grades.data ?? []) as any[];
  const actionRows = (actions.data ?? []) as any[];
  const focusRows = (focus.data ?? []) as any[];
  const distRows = (dist.data ?? []) as any[];
  const funnelRows = (funnel.data ?? []) as any[];
  const trendRows = (trend.data ?? []) as any[];
  const ownerRows = (owners.data ?? []) as any[];

  const fmtPct = (v: any) => (v === null || v === undefined ? '-' : `${Number(v).toFixed(2)}%`);
  const fmtDate = (v: any) => (v ? new Date(v).toLocaleString() : '-');

  const gradeCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'utilization_pct', header: 'Utilization', render: (r: any) => fmtPct(r.utilization_pct) },
    { key: 'target_pct', header: 'Target', render: (r: any) => fmtPct(r.target_pct) },
    { key: 'utilization_grade', header: 'Grade', render: (r: any) => r.utilization_grade },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => fmtDate(r.action_at) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const focusCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'utilization_pct', header: 'Utilization', render: (r: any) => fmtPct(r.utilization_pct) },
    { key: 'target_pct', header: 'Target', render: (r: any) => fmtPct(r.target_pct) },
    { key: 'gap_pct', header: 'Gap', render: (r: any) => fmtPct(r.gap_pct) },
    { key: 'utilization_grade', header: 'Grade', render: (r: any) => r.utilization_grade },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
  ];

  const distCols: Column<any>[] = [
    { key: 'utilization_grade', header: 'Grade', render: (r: any) => r.utilization_grade },
    { key: 'total', header: 'Count', render: (r: any) => String(r.total) },
    { key: 'avg_utilization', header: 'Avg Utilization', render: (r: any) => fmtPct(r.avg_utilization) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'total', header: 'Count', render: (r: any) => String(r.total) },
    { key: 'avg_utilization', header: 'Avg Utilization', render: (r: any) => fmtPct(r.avg_utilization) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'total', header: 'Total Lines', render: (r: any) => String(r.total) },
    { key: 'avg_utilization', header: 'Avg Utilization', render: (r: any) => fmtPct(r.avg_utilization) },
    { key: 'under_count', header: 'Under-utilized', render: (r: any) => String(r.under_count) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'grade_count', header: 'Equipment Lines', render: (r: any) => String(r.grade_count) },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => String(r.open_actions) },
    { key: 'under_utilized', header: 'Under-utilized', render: (r: any) => String(r.under_utilized) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Equipment Utilization Grade</h1>
        <p className="text-sm text-gray-600">
          Per-equipment monthly utilization grades (A &gt;= 85%, B 70-84%, C 55-69%, D 40-54%, F &lt; 40%) and
          improvement actions taken to lift under-utilized assets.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Under-utilized Focus</h2>
        <DataTable
          rows={focusRows}
          columns={focusCols}
          emptyMessage="No under-utilized equipment this period."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Grade Distribution</h2>
          <DataTable
            rows={distRows}
            columns={distCols}
            emptyMessage="No grade data."
            rowKey={(r: any, i: number) => String(r.utilization_grade ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Status Funnel</h2>
          <DataTable
            rows={funnelRows}
            columns={funnelCols}
            emptyMessage="No status data."
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Grade Trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={ownerRows}
          columns={ownerCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Equipment Grades</h2>
        <DataTable
          rows={gradeRows}
          columns={gradeCols}
          emptyMessage="No equipment grade rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Improvement Actions</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No improvement actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
