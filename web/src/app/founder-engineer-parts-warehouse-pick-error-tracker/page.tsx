import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, recentRes, byTypeRes, topEngRes, byWhRes, trainRes, trainEffRes] = await Promise.all([
    supabase.rpc('founder_pick_error_summary_r2382'),
    supabase.rpc('founder_pick_error_recent_r2382'),
    supabase.rpc('founder_pick_error_by_type_r2382'),
    supabase.rpc('founder_pick_error_top_engineers_r2382'),
    supabase.rpc('founder_pick_error_by_warehouse_r2382'),
    supabase.rpc('founder_pick_error_training_recent_r2382'),
    supabase.rpc('founder_pick_error_training_effectiveness_r2382'),
  ]);

  const summary = (summaryRes.data?.[0] ?? {}) as Record<string, unknown>;
  const recent = (recentRes.data ?? []) as Array<Record<string, unknown>>;
  const byType = (byTypeRes.data ?? []) as Array<Record<string, unknown>>;
  const topEng = (topEngRes.data ?? []) as Array<Record<string, unknown>>;
  const byWh = (byWhRes.data ?? []) as Array<Record<string, unknown>>;
  const training = (trainRes.data ?? []) as Array<Record<string, unknown>>;
  const trainEff = (trainEffRes.data ?? []) as Array<Record<string, unknown>>;

  const recentCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => String(r.engineer_email ?? '') },
    { key: 'warehouse_code', header: 'Warehouse', render: (r) => String(r.warehouse_code ?? '') },
    { key: 'picked_at', header: 'Picked', render: (r) => r.picked_at ? new Date(String(r.picked_at)).toLocaleString() : '' },
    { key: 'requested_part_sku', header: 'Requested SKU', render: (r) => String(r.requested_part_sku ?? '') },
    { key: 'picked_part_sku', header: 'Picked SKU', render: (r) => String(r.picked_part_sku ?? '') },
    { key: 'error_type', header: 'Error', render: (r) => String(r.error_type ?? '') },
    { key: 'error_cost_rupees', header: 'Cost (₹)', render: (r) => `₹${Number(r.error_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'caused_revisit', header: 'Revisit', render: (r) => r.caused_revisit ? 'yes' : 'no' },
    { key: 'caused_delay_hours', header: 'Delay (h)', render: (r) => String(r.caused_delay_hours ?? 0) },
    { key: 'detected_by', header: 'Detected by', render: (r) => String(r.detected_by ?? '') },
  ];

  const typeCols: Column<any>[] = [
    { key: 'error_type', header: 'Error type', render: (r) => String(r.error_type ?? '') },
    { key: 'occurrences', header: 'Count', render: (r) => String(r.occurrences ?? 0) },
    { key: 'total_cost_rupees', header: 'Total cost (₹)', render: (r) => `₹${Number(r.total_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'revisits', header: 'Revisits', render: (r) => String(r.revisits ?? 0) },
    { key: 'avg_delay_hours', header: 'Avg delay (h)', render: (r) => String(r.avg_delay_hours ?? 0) },
  ];

  const engCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => String(r.engineer_email ?? '') },
    { key: 'errors_count', header: 'Errors', render: (r) => String(r.errors_count ?? 0) },
    { key: 'total_cost_rupees', header: 'Total cost (₹)', render: (r) => `₹${Number(r.total_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'revisits', header: 'Revisits', render: (r) => String(r.revisits ?? 0) },
    { key: 'open_training', header: 'Open training', render: (r) => String(r.open_training ?? 0) },
  ];

  const whCols: Column<any>[] = [
    { key: 'warehouse_code', header: 'Warehouse', render: (r) => String(r.warehouse_code ?? '') },
    { key: 'errors_count', header: 'Errors', render: (r) => String(r.errors_count ?? 0) },
    { key: 'total_cost_rupees', header: 'Total cost (₹)', render: (r) => `₹${Number(r.total_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'distinct_engineers', header: 'Engineers', render: (r) => String(r.distinct_engineers ?? 0) },
  ];

  const trainCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => String(r.engineer_email ?? '') },
    { key: 'training_module', header: 'Module', render: (r) => String(r.training_module ?? '') },
    { key: 'triggered_by_error_type', header: 'Trigger', render: (r) => String(r.triggered_by_error_type ?? '') },
    { key: 'assigned_at', header: 'Assigned', render: (r) => r.assigned_at ? new Date(String(r.assigned_at)).toLocaleDateString() : '' },
    { key: 'due_at', header: 'Due', render: (r) => r.due_at ? new Date(String(r.due_at)).toLocaleDateString() : '' },
    { key: 'completed_at', header: 'Completed', render: (r) => r.completed_at ? new Date(String(r.completed_at)).toLocaleDateString() : '—' },
    { key: 'quiz_score', header: 'Score', render: (r) => r.quiz_score == null ? '—' : `${r.quiz_score}` },
    { key: 'status', header: 'Status', render: (r) => String(r.status ?? '') },
  ];

  const effCols: Column<any>[] = [
    { key: 'triggered_by_error_type', header: 'Trigger', render: (r) => String(r.triggered_by_error_type ?? '') },
    { key: 'assigned_count', header: 'Assigned', render: (r) => String(r.assigned_count ?? 0) },
    { key: 'completed_count', header: 'Completed', render: (r) => String(r.completed_count ?? 0) },
    { key: 'avg_quiz_score', header: 'Avg score', render: (r) => String(r.avg_quiz_score ?? 0) },
    { key: 'completion_rate', header: 'Completion %', render: (r) => `${r.completion_rate ?? 0}%` },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Parts-Warehouse Pick-Error Tracker</h1>
        <p className="text-sm text-gray-600">Wrong-pick incidents, cost of error & prevention training rollouts.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total errors</div>
          <div className="text-xl font-semibold">{String(summary.total_errors ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Errors 30d</div>
          <div className="text-xl font-semibold">{String(summary.errors_30d ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total cost</div>
          <div className="text-xl font-semibold">₹{Number(summary.total_cost_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Cost 30d</div>
          <div className="text-xl font-semibold">₹{Number(summary.cost_30d_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Revisits caused</div>
          <div className="text-xl font-semibold">{String(summary.revisits_caused ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg delay (h)</div>
          <div className="text-xl font-semibold">{String(summary.avg_delay_hours ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Engineers w/ errors</div>
          <div className="text-xl font-semibold">{String(summary.distinct_engineers ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Open training</div>
          <div className="text-xl font-semibold">{String(summary.open_training ?? 0)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By error type</h2>
        <DataTable
          rows={byType}
          columns={typeCols}
          emptyMessage="No errors recorded yet."
          rowKey={(r) => String(r.error_type)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top offenders</h2>
        <DataTable
          rows={topEng}
          columns={engCols}
          emptyMessage="No engineer errors."
          rowKey={(r) => String(r.engineer_email)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By warehouse</h2>
        <DataTable
          rows={byWh}
          columns={whCols}
          emptyMessage="No warehouse rollups."
          rowKey={(r) => String(r.warehouse_code)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent pick errors</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          emptyMessage="No recent pick errors."
          rowKey={(r) => String(r.id)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Training effectiveness</h2>
        <DataTable
          rows={trainEff}
          columns={effCols}
          emptyMessage="No training data."
          rowKey={(r) => String(r.triggered_by_error_type)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent training assignments</h2>
        <DataTable
          rows={training}
          columns={trainCols}
          emptyMessage="No training assigned."
          rowKey={(r) => String(r.id)}
        />
      </section>
    </main>
  );
}
