import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [itemsRes, outcomesRes, skippedRes, kindDistRes, statusRes, dayTrendRes, ownerLoadRes] = await Promise.all([
    sb.rpc('list_onboarding_r2630'),
    sb.rpc('list_outcomes_r2630'),
    sb.rpc('top_skipped_focus_r2630'),
    sb.rpc('checklist_kind_distribution_r2630'),
    sb.rpc('status_funnel_r2630'),
    sb.rpc('daily_completion_trend_r2630'),
    sb.rpc('owner_load_r2630'),
  ]);

  const items: any[] = (itemsRes.data ?? []) as any[];
  const outcomes: any[] = (outcomesRes.data ?? []) as any[];
  const skipped: any[] = (skippedRes.data ?? []) as any[];
  const kindDist: any[] = (kindDistRes.data ?? []) as any[];
  const statuses: any[] = (statusRes.data ?? []) as any[];
  const dayTrend: any[] = (dayTrendRes.data ?? []) as any[];
  const ownerLoad: any[] = (ownerLoadRes.data ?? []) as any[];

  const totalItems = items.length;
  const doneItems = items.filter((r: any) => r.status === 'done').length;
  const pendingItems = items.filter((r: any) => r.status === 'pending' || r.status === 'in_progress').length;
  const skippedItems = items.filter((r: any) => r.status === 'skipped').length;
  const donePct = totalItems > 0 ? Math.round((doneItems / totalItems) * 100) : 0;

  const itemCols: Column<any>[] = [
    { key: 'start', header: 'Start', render: (r: any) => new Date(r.onboarding_start_at).toLocaleDateString() },
    { key: 'engineer', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'hospital', header: 'Hospital', render: (r: any) => String(r.hospital_user_id).slice(0, 8) },
    { key: 'day', header: 'Day', render: (r: any) => `D${r.day_offset}` },
    { key: 'kind', header: 'Checklist kind', render: (r: any) => r.checklist_kind },
    { key: 'completed', header: 'Completed', render: (r: any) => (r.completed ? 'yes' : 'no') },
    { key: 'completed_at', header: 'Completed at', render: (r: any) => (r.completed_at ? new Date(r.completed_at).toLocaleDateString() : '—') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'observed', header: 'Observed', render: (r: any) => new Date(r.observed_at).toLocaleDateString() },
    { key: 'kind', header: 'Checklist kind', render: (r: any) => r.checklist_kind ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'feedback', header: 'Customer feedback', render: (r: any) => r.customer_feedback_md ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const skippedCols: Column<any>[] = [
    { key: 'kind', header: 'Checklist kind', render: (r: any) => r.checklist_kind },
    { key: 'skipped', header: 'Skipped', render: (r: any) => String(r.skipped_count) },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total_count) },
    { key: 'rate', header: 'Skip rate %', render: (r: any) => `${Number(r.skip_rate ?? 0).toFixed(1)}%` },
  ];

  const kindDistCols: Column<any>[] = [
    { key: 'kind', header: 'Checklist kind', render: (r: any) => r.checklist_kind },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total_count) },
    { key: 'done', header: 'Done', render: (r: any) => String(r.done_count) },
    { key: 'rate', header: 'Done %', render: (r: any) => `${Number(r.done_rate ?? 0).toFixed(1)}%` },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'count', header: 'Entries', render: (r: any) => String(r.entry_count) },
    { key: 'avg_day', header: 'Avg day offset', render: (r: any) => Number(r.avg_day_offset ?? 0).toFixed(2) },
  ];

  const dayTrendCols: Column<any>[] = [
    { key: 'day', header: 'Day offset', render: (r: any) => `D${r.day_offset}` },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total_count) },
    { key: 'done', header: 'Done', render: (r: any) => String(r.done_count) },
    { key: 'rate', header: 'Done %', render: (r: any) => `${Number(r.done_rate ?? 0).toFixed(1)}%` },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'items', header: 'Items', render: (r: any) => String(r.item_count) },
    { key: 'done', header: 'Done', render: (r: any) => String(r.done_count) },
    { key: 'pending', header: 'Pending', render: (r: any) => String(r.pending_count) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Customer Onboarding Week Checklist</h1>
        <p className="text-sm text-gray-500">r2630 · 7-day onboarding checklist per engineer-hospital pair</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total items</div>
          <div className="text-2xl font-semibold">{totalItems}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Done</div>
          <div className="text-2xl font-semibold text-green-600">{doneItems}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Pending / In progress</div>
          <div className="text-2xl font-semibold text-blue-600">{pendingItems}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Skipped</div>
          <div className="text-2xl font-semibold text-red-600">{skippedItems}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Done %</div>
          <div className="text-2xl font-semibold">{donePct}%</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All checklist items</h2>
        <DataTable rows={items} columns={itemCols} emptyMessage="No checklist items yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Checklist outcomes</h2>
        <DataTable rows={outcomes} columns={outcomeCols} emptyMessage="No outcomes logged yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top skipped focus</h2>
        <DataTable rows={skipped} columns={skippedCols} emptyMessage="No skipped data" rowKey={(r: any, i: number) => String(r.checklist_kind ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Checklist kind distribution</h2>
        <DataTable rows={kindDist} columns={kindDistCols} emptyMessage="No distribution data" rowKey={(r: any, i: number) => String(r.checklist_kind ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status funnel</h2>
        <DataTable rows={statuses} columns={statusCols} emptyMessage="No status data" rowKey={(r: any, i: number) => String(r.status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Daily completion trend</h2>
        <DataTable rows={dayTrend} columns={dayTrendCols} emptyMessage="No daily trend data" rowKey={(r: any, i: number) => String(r.day_offset ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner load</h2>
        <DataTable rows={ownerLoad} columns={ownerCols} emptyMessage="No owner data" rowKey={(r: any, i: number) => String(r.owner_email ?? i)} />
      </section>
    </main>
  );
}
