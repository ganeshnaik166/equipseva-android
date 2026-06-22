import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [checklistsRes, completionsRes, topCompletionsRes, failedItemsRes, topEngineersRes] = await Promise.all([
    sb.rpc('list_checklists_r1892'),
    sb.rpc('list_completions_r1892', { p_limit: 100 }),
    sb.rpc('top_completions_r1892'),
    sb.rpc('failed_items_analysis_r1892'),
    sb.rpc('top_engineers_r1892'),
  ]);

  const checklists: any[] = Array.isArray(checklistsRes.data) ? checklistsRes.data : [];
  const completions: any[] = Array.isArray(completionsRes.data) ? completionsRes.data : [];
  const topCompletions: any[] = Array.isArray(topCompletionsRes.data) ? topCompletionsRes.data : [];
  const failedItems: any[] = Array.isArray(failedItemsRes.data) ? failedItemsRes.data : [];
  const topEngineers: any[] = Array.isArray(topEngineersRes.data) ? topEngineersRes.data : [];

  const totalChecklists = checklists.length;
  const activeChecklists = checklists.filter((c) => c.status === 'active').length;
  const totalCompletions = completions.length;
  const passedCount = completions.filter((c) => c.all_passed).length;
  const passRate = totalCompletions > 0 ? Math.round((100 * passedCount) / totalCompletions) : 0;

  const checklistColumns: Column<any>[] = [
    { key: 'label', header: 'Checklist', render: (r: any) => <span className="font-medium">{r.checklist_label ?? '-'}</span> },
    { key: 'category', header: 'Equipment Category', render: (r: any) => <span>{r.equipment_category ?? '-'}</span> },
    { key: 'items', header: 'Items', render: (r: any) => <span>{r.item_count ?? 0}</span> },
    { key: 'minutes', header: 'Required (min)', render: (r: any) => <span>{r.required_minutes ?? 0}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="capitalize">{(r.status ?? '-').replace('_', ' ')}</span> },
    { key: 'updated', header: 'Updated', render: (r: any) => <span>{r.updated_at ? new Date(r.updated_at).toLocaleString() : '-'}</span> },
  ];

  const completionColumns: Column<any>[] = [
    { key: 'label', header: 'Checklist', render: (r: any) => <span>{r.checklist_label ?? '-'}</span> },
    { key: 'category', header: 'Category', render: (r: any) => <span>{r.equipment_category ?? '-'}</span> },
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id ?? '').slice(0, 8)}</span> },
    { key: 'job', header: 'Repair Job', render: (r: any) => <span className="font-mono text-xs">{r.repair_job_id ? String(r.repair_job_id).slice(0, 8) : '-'}</span> },
    { key: 'time', header: 'Time (min)', render: (r: any) => <span>{r.completion_time_min ?? 0}</span> },
    { key: 'passed', header: 'Passed', render: (r: any) => <span>{r.all_passed ? 'Yes' : 'No'}</span> },
    { key: 'failed', header: 'Failed Items', render: (r: any) => <span>{r.failed_count ?? 0}</span> },
    { key: 'when', header: 'Completed', render: (r: any) => <span>{r.completed_at ? new Date(r.completed_at).toLocaleString() : '-'}</span> },
  ];

  const topCompletionColumns: Column<any>[] = [
    { key: 'label', header: 'Checklist', render: (r: any) => <span className="font-medium">{r.checklist_label ?? '-'}</span> },
    { key: 'category', header: 'Category', render: (r: any) => <span>{r.equipment_category ?? '-'}</span> },
    { key: 'completions', header: 'Completions', render: (r: any) => <span>{r.completions ?? 0}</span> },
    { key: 'pass', header: 'Passed', render: (r: any) => <span>{r.pass_count ?? 0}</span> },
    { key: 'fail', header: 'Failed', render: (r: any) => <span>{r.fail_count ?? 0}</span> },
    { key: 'rate', header: 'Pass Rate %', render: (r: any) => <span>{r.pass_rate_pct ?? '-'}</span> },
    { key: 'avg', header: 'Avg Time (min)', render: (r: any) => <span>{r.avg_time_min ?? '-'}</span> },
  ];

  const failedItemColumns: Column<any>[] = [
    { key: 'item', header: 'Failed Item', render: (r: any) => <span>{r.failed_item ?? '-'}</span> },
    { key: 'count', header: 'Fail Count', render: (r: any) => <span className="font-medium">{r.fail_count ?? 0}</span> },
    { key: 'last', header: 'Last Failed', render: (r: any) => <span>{r.last_failed_at ? new Date(r.last_failed_at).toLocaleString() : '-'}</span> },
  ];

  const topEngineerColumns: Column<any>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id ?? '').slice(0, 12)}</span> },
    { key: 'completions', header: 'Completions', render: (r: any) => <span>{r.completions ?? 0}</span> },
    { key: 'pass', header: 'Passed', render: (r: any) => <span>{r.pass_count ?? 0}</span> },
    { key: 'rate', header: 'Pass Rate %', render: (r: any) => <span>{r.pass_rate_pct ?? '-'}</span> },
    { key: 'avg', header: 'Avg Time (min)', render: (r: any) => <span>{r.avg_time_min ?? '-'}</span> },
    { key: 'last', header: 'Last Completed', render: (r: any) => <span>{r.last_completed_at ? new Date(r.last_completed_at).toLocaleString() : '-'}</span> },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Pre-Service Checklist</h1>
        <p className="text-sm text-gray-600 mt-1">
          Per-equipment pre-service checklists that engineers must pass before each repair. Track completions, failed items, and engineer compliance.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Checklists</div>
          <div className="text-2xl font-bold mt-1">{totalChecklists}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Active</div>
          <div className="text-2xl font-bold mt-1">{activeChecklists}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Recent Completions</div>
          <div className="text-2xl font-bold mt-1">{totalCompletions}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Pass Rate</div>
          <div className="text-2xl font-bold mt-1">{passRate}%</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Checklists Library</h2>
        <DataTable rows={checklists} columns={checklistColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Completions</h2>
        <DataTable rows={completions} columns={completionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Completions by Checklist</h2>
        <DataTable rows={topCompletions} columns={topCompletionColumns} rowKey={(r: any, i: number) => String(r.checklist_label ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Failed Items Analysis</h2>
        <DataTable rows={failedItems} columns={failedItemColumns} rowKey={(r: any, i: number) => String(r.failed_item ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Engineers by Completions</h2>
        <DataTable rows={topEngineers} columns={topEngineerColumns} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />
      </section>
    </div>
  );
}
