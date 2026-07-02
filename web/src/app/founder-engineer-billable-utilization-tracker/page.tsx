import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [list, top, bottom, agg, actions] = await Promise.all([
    sb.rpc('list_engineer_utilization_r2218'),
    sb.rpc('top_engineer_utilization_r2218'),
    sb.rpc('bottom_engineer_utilization_r2218'),
    sb.rpc('aggregate_engineer_utilization_r2218'),
    sb.rpc('recent_actions_engineer_utilization_r2218'),
  ]);

  const rows = (list.data ?? []) as any[];
  const topRows = (top.data ?? []) as any[];
  const bottomRows = (bottom.data ?? []) as any[];
  const aggRow = ((agg.data ?? [])[0] ?? {}) as any;
  const actionRows = (actions.data ?? []) as any[];

  const listCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => String(r.engineer_name ?? '') },
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'billable_hours', header: 'Billable h', render: (r: any) => String(r.billable_hours ?? '0') },
    { key: 'available_hours', header: 'Avail h', render: (r: any) => String(r.available_hours ?? '0') },
    { key: 'utilization_pct', header: 'Util %', render: (r: any) => `${Number(r.utilization_pct ?? 0).toFixed(1)}%` },
    { key: 'meets_target', header: 'Target 70%+', render: (r: any) => r.meets_target ? 'YES' : 'no' },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => String(r.jobs_completed ?? 0) },
  ];

  const rankCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => String(r.engineer_name ?? '') },
    { key: 'utilization_pct', header: 'Util %', render: (r: any) => `${Number(r.utilization_pct ?? 0).toFixed(1)}%` },
    { key: 'billable_hours', header: 'Billable', render: (r: any) => String(r.billable_hours ?? '0') },
    { key: 'available_hours', header: 'Avail', render: (r: any) => String(r.available_hours ?? '0') },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => String(r.jobs_completed ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Type', render: (r: any) => String(r.action_type ?? '') },
    { key: 'action_note', header: 'Note', render: (r: any) => String(r.action_note ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => String(r.taken_at ?? '') },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1>Engineer Billable Utilization Tracker</h1>
      <p>Billable hours vs available hours per engineer per week. Target 70%+ utilization.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12, margin: '16px 0' }}>
        <div><strong>Engineers</strong><div>{String(aggRow.total_engineers ?? 0)}</div></div>
        <div><strong>Meeting target</strong><div>{String(aggRow.meeting_target ?? 0)}</div></div>
        <div><strong>Below target</strong><div>{String(aggRow.below_target ?? 0)}</div></div>
        <div><strong>Avg util</strong><div>{`${Number(aggRow.avg_utilization ?? 0).toFixed(1)}%`}</div></div>
        <div><strong>Billable h</strong><div>{Number(aggRow.total_billable_hours ?? 0).toFixed(0)}</div></div>
        <div><strong>Avail h</strong><div>{Number(aggRow.total_available_hours ?? 0).toFixed(0)}</div></div>
      </section>

      <h2>Top 10 (this week)</h2>
      <DataTable<any> columns={rankCols} rows={topRows} rowKey={(_, i) => String(i)} />

      <h2>Bottom 10 (this week)</h2>
      <DataTable<any> columns={rankCols} rows={bottomRows} rowKey={(_, i) => String(i)} />

      <h2>All weekly records</h2>
      <DataTable<any> columns={listCols} rows={rows} rowKey={(_, i) => String(i)} />

      <h2>Recent actions</h2>
      <DataTable<any> columns={actionCols} rows={actionRows} rowKey={(_, i) => String(i)} />
    </div>
  );
}
