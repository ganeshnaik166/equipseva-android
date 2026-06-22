import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [listRes, actionsRes, topRes, aggRes] = await Promise.all([
    sb.rpc('list_training_videos_r2212'),
    sb.rpc('recent_actions_r2212'),
    sb.rpc('top_category_r2212'),
    sb.rpc('aggregate_training_r2212'),
  ]);

  const rows: any[] = Array.isArray(listRes.data) ? listRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const agg: any =
    Array.isArray(aggRes.data) && aggRes.data.length > 0 ? aggRes.data[0] : {};

  const rowsCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'video_code', header: 'Code', render: (r: any) => r.video_code ?? '—' },
    { key: 'video_title', header: 'Title', render: (r: any) => r.video_title ?? '—' },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    {
      key: 'required',
      header: 'Required',
      render: (r: any) => (r.required ? 'yes' : 'no'),
    },
    {
      key: 'watched_percent',
      header: 'Watched %',
      render: (r: any) =>
        r.watched_percent != null ? `${Number(r.watched_percent).toFixed(1)}%` : '—',
    },
    {
      key: 'quiz',
      header: 'Quiz',
      render: (r: any) =>
        r.quiz_score != null
          ? `${r.quiz_score} ${r.quiz_pass ? 'pass' : 'fail'}`
          : '—',
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    {
      key: 'recertify_due_on',
      header: 'Recert due',
      render: (r: any) => r.recertify_due_on ?? '—',
    },
    {
      key: 'last_activity_at',
      header: 'Last activity',
      render: (r: any) =>
        r.last_activity_at ? new Date(r.last_activity_at).toLocaleString() : '—',
    },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'action', header: 'Action', render: (r: any) => r.action ?? '—' },
    { key: 'detail', header: 'Detail', render: (r: any) => r.detail ?? '—' },
    {
      key: 'acted_at',
      header: 'When',
      render: (r: any) =>
        r.acted_at ? new Date(r.acted_at).toLocaleString() : '—',
    },
  ];

  const topCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'total', header: 'Total', render: (r: any) => r.total ?? 0 },
    { key: 'completed', header: 'Completed', render: (r: any) => r.completed ?? 0 },
    { key: 'overdue', header: 'Overdue', render: (r: any) => r.overdue ?? 0 },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Engineer training video watch tracker</h1>
        <p className="text-sm text-gray-600">
          Required training videos, watched %, quiz pass & recertification due dates.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Total assignments</div>
          <div className="text-2xl font-semibold">{agg.total ?? 0}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Completed</div>
          <div className="text-2xl font-semibold">{agg.completed ?? 0}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Overdue recert</div>
          <div className="text-2xl font-semibold">{agg.overdue_recert ?? 0}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Quiz pass rate</div>
          <div className="text-2xl font-semibold">
            {agg.quiz_pass_rate != null ? `${Number(agg.quiz_pass_rate).toFixed(1)}%` : '—'}
          </div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Training assignments</h2>
        <DataTable
          columns={rowsCols}
          rows={rows}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By category</h2>
        <DataTable
          columns={topCols}
          rows={top}
          rowKey={(_, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent actions</h2>
        <DataTable
          columns={actionsCols}
          rows={actions}
          rowKey={(_, i) => String(i)}
        />
      </section>
    </div>
  );
}
