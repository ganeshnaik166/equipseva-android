import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = {
  total_decisions: number;
  due_within_7d: number;
  due_within_30d: number;
  overdue_count: number;
  pending_count: number;
  prepping_count: number;
  ready_for_review_count: number;
  company_defining_count: number;
  blocked_count: number;
  avg_prep_hours: number;
};

type QueueRow = {
  id: string;
  decision_title: string;
  decision_category: string;
  blast_radius: string;
  reversibility: string;
  owner_email: string | null;
  owner_role: string | null;
  deadline_at: string;
  days_until_deadline: number;
  status: string;
  estimated_prep_hours: number | null;
  forecast_confidence: number | null;
  dependency_count: number;
  blocker_count: number;
};

type CategoryRow = {
  decision_category: string;
  total: number;
  due_within_7d: number;
  company_defining: number;
  one_way_count: number;
  avg_prep_hours: number;
};

type OwnerRow = {
  owner_user_id: string | null;
  owner_email: string | null;
  owner_role: string | null;
  open_decisions: number;
  due_within_7d: number;
  total_prep_hours: number;
  oldest_deadline: string | null;
};

type BlockedRow = {
  decision_id: string;
  decision_title: string;
  deadline_at: string;
  blast_radius: string;
  blocker_kind: string;
  blocker_status: string;
  external_blocker: string | null;
  upstream_decision_title: string | null;
  notes: string | null;
};

type TimelineRow = {
  deadline_day: string;
  decisions_due: number;
  company_defining: number;
  one_way: number;
  total_prep_hours: number;
};

export default async function FounderUpcomingDecisionQueuePage() {
  const supabase = await getSupabaseServerClient();

  const [overview, queue, category, owner, blocked, timeline] = await Promise.all([
    supabase.rpc('founder_decision_queue_overview_r2333'),
    supabase.rpc('founder_decision_queue_list_r2333', { p_status_filter: null, p_days_ahead: 30 }),
    supabase.rpc('founder_decision_category_breakdown_r2333'),
    supabase.rpc('founder_decision_owner_workload_r2333'),
    supabase.rpc('founder_decision_blocked_r2333'),
    supabase.rpc('founder_decision_timeline_r2333'),
  ]);

  const ov: OverviewRow | null = (overview.data?.[0] as OverviewRow) ?? null;
  const queueRows: QueueRow[] = (queue.data as QueueRow[]) ?? [];
  const categoryRows: CategoryRow[] = (category.data as CategoryRow[]) ?? [];
  const ownerRows: OwnerRow[] = (owner.data as OwnerRow[]) ?? [];
  const blockedRows: BlockedRow[] = (blocked.data as BlockedRow[]) ?? [];
  const timelineRows: TimelineRow[] = (timeline.data as TimelineRow[]) ?? [];

  const queueCols: Column<any>[] = [
    { key: 'decision_title', header: 'Decision', render: (r: QueueRow) => r.decision_title },
    { key: 'decision_category', header: 'Category', render: (r: QueueRow) => r.decision_category },
    {
      key: 'blast_radius',
      header: 'Blast',
      render: (r: QueueRow) => r.blast_radius,
    },
    {
      key: 'reversibility',
      header: 'Rev',
      render: (r: QueueRow) => r.reversibility,
    },
    { key: 'owner_email', header: 'Owner', render: (r: QueueRow) => r.owner_email ?? '—' },
    { key: 'owner_role', header: 'Role', render: (r: QueueRow) => r.owner_role ?? '—' },
    {
      key: 'deadline_at',
      header: 'Deadline',
      render: (r: QueueRow) => new Date(r.deadline_at).toLocaleDateString(),
    },
    {
      key: 'days_until_deadline',
      header: 'Days left',
      render: (r: QueueRow) => {
        const d = Number(r.days_until_deadline);
        if (d < 0) return `overdue ${Math.abs(d).toFixed(1)}d`;
        return `${d.toFixed(1)}d`;
      },
    },
    { key: 'status', header: 'Status', render: (r: QueueRow) => r.status },
    {
      key: 'estimated_prep_hours',
      header: 'Prep h',
      render: (r: QueueRow) => r.estimated_prep_hours?.toFixed(1) ?? '—',
    },
    {
      key: 'forecast_confidence',
      header: 'Conf',
      render: (r: QueueRow) =>
        r.forecast_confidence != null ? `${(r.forecast_confidence * 100).toFixed(0)}%` : '—',
    },
    {
      key: 'dependency_count',
      header: 'Deps',
      render: (r: QueueRow) =>
        r.blocker_count > 0
          ? `${r.dependency_count} (${r.blocker_count} blocked)`
          : String(r.dependency_count),
    },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'decision_category', header: 'Category', render: (r: CategoryRow) => r.decision_category },
    { key: 'total', header: 'Total', render: (r: CategoryRow) => r.total },
    { key: 'due_within_7d', header: 'Due <=7d', render: (r: CategoryRow) => r.due_within_7d },
    {
      key: 'company_defining',
      header: 'Company-defining',
      render: (r: CategoryRow) => r.company_defining,
    },
    { key: 'one_way_count', header: 'One-way', render: (r: CategoryRow) => r.one_way_count },
    {
      key: 'avg_prep_hours',
      header: 'Avg prep h',
      render: (r: CategoryRow) => Number(r.avg_prep_hours).toFixed(2),
    },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: OwnerRow) => r.owner_email ?? 'unassigned' },
    { key: 'owner_role', header: 'Role', render: (r: OwnerRow) => r.owner_role ?? '—' },
    { key: 'open_decisions', header: 'Open', render: (r: OwnerRow) => r.open_decisions },
    { key: 'due_within_7d', header: 'Due <=7d', render: (r: OwnerRow) => r.due_within_7d },
    {
      key: 'total_prep_hours',
      header: 'Prep h',
      render: (r: OwnerRow) => Number(r.total_prep_hours).toFixed(1),
    },
    {
      key: 'oldest_deadline',
      header: 'Next deadline',
      render: (r: OwnerRow) =>
        r.oldest_deadline ? new Date(r.oldest_deadline).toLocaleDateString() : '—',
    },
  ];

  const blockedCols: Column<any>[] = [
    { key: 'decision_title', header: 'Decision', render: (r: BlockedRow) => r.decision_title },
    {
      key: 'deadline_at',
      header: 'Deadline',
      render: (r: BlockedRow) => new Date(r.deadline_at).toLocaleDateString(),
    },
    { key: 'blast_radius', header: 'Blast', render: (r: BlockedRow) => r.blast_radius },
    { key: 'blocker_kind', header: 'Kind', render: (r: BlockedRow) => r.blocker_kind },
    { key: 'blocker_status', header: 'Status', render: (r: BlockedRow) => r.blocker_status },
    {
      key: 'upstream',
      header: 'Blocked by',
      render: (r: BlockedRow) => r.external_blocker ?? r.upstream_decision_title ?? '—',
    },
    { key: 'notes', header: 'Notes', render: (r: BlockedRow) => r.notes ?? '—' },
  ];

  const timelineCols: Column<any>[] = [
    {
      key: 'deadline_day',
      header: 'Day',
      render: (r: TimelineRow) => new Date(r.deadline_day).toLocaleDateString(),
    },
    { key: 'decisions_due', header: 'Due', render: (r: TimelineRow) => r.decisions_due },
    {
      key: 'company_defining',
      header: 'Company-defining',
      render: (r: TimelineRow) => r.company_defining,
    },
    { key: 'one_way', header: 'One-way', render: (r: TimelineRow) => r.one_way },
    {
      key: 'total_prep_hours',
      header: 'Prep h',
      render: (r: TimelineRow) => Number(r.total_prep_hours).toFixed(1),
    },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Upcoming-decision queue (30 days)</h1>
        <p className="text-sm text-gray-600">
          Forecasted decisions with dependencies, owners & deadlines visible to the whole team.
        </p>
      </header>

      {ov && (
        <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Open decisions</div>
            <div className="text-2xl font-semibold">{ov.total_decisions}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Due &lt;= 7d</div>
            <div className="text-2xl font-semibold">{ov.due_within_7d}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Due &lt;= 30d</div>
            <div className="text-2xl font-semibold">{ov.due_within_30d}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Overdue</div>
            <div className="text-2xl font-semibold text-red-600">{ov.overdue_count}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Blocked</div>
            <div className="text-2xl font-semibold text-amber-600">{ov.blocked_count}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Pending</div>
            <div className="text-2xl font-semibold">{ov.pending_count}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Prepping</div>
            <div className="text-2xl font-semibold">{ov.prepping_count}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Ready for review</div>
            <div className="text-2xl font-semibold">{ov.ready_for_review_count}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Company-defining</div>
            <div className="text-2xl font-semibold">{ov.company_defining_count}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Avg prep h</div>
            <div className="text-2xl font-semibold">{Number(ov.avg_prep_hours).toFixed(2)}</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Queue (next 30 days)</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          rowKey={(r: QueueRow) => r.id}
          emptyMessage="No upcoming decisions in the next 30 days."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">30-day timeline</h2>
        <DataTable
          rows={timelineRows}
          columns={timelineCols}
          rowKey={(r: TimelineRow) => r.deadline_day}
          emptyMessage="No decisions scheduled in the window."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By category</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          rowKey={(r: CategoryRow) => r.decision_category}
          emptyMessage="No open decisions."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner workload</h2>
        <DataTable
          rows={ownerRows}
          columns={ownerCols}
          rowKey={(r: OwnerRow) => r.owner_user_id ?? 'unassigned'}
          emptyMessage="No owners assigned."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Blocked / at-risk dependencies</h2>
        <DataTable
          rows={blockedRows}
          columns={blockedCols}
          rowKey={(r: BlockedRow, i: number) => `${r.decision_id}-${i}`}
          emptyMessage="No blocked dependencies."
        />
      </section>
    </div>
  );
}
