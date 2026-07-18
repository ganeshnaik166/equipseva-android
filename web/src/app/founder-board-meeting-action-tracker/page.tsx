import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderBoardMeetingActionTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    meetingsRes,
    actionsRes,
    overdueRes,
    roleBreakdownRes,
    completionRes,
    topOpenRes,
    recentDecisionsRes,
  ] = await Promise.all([
    supabase.rpc('list_meetings_r2453'),
    supabase.rpc('list_actions_r2453'),
    supabase.rpc('overdue_actions_r2453'),
    supabase.rpc('owner_role_breakdown_r2453'),
    supabase.rpc('completion_rate_r2453'),
    supabase.rpc('top_open_actions_r2453'),
    supabase.rpc('recent_decisions_r2453'),
  ]);

  const meetings = (meetingsRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const overdue = (overdueRes.data ?? []) as any[];
  const roleBreakdown = (roleBreakdownRes.data ?? []) as any[];
  const completion = (completionRes.data ?? []) as any[];
  const topOpen = (topOpenRes.data ?? []) as any[];
  const recentDecisions = (recentDecisionsRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '-');

  const meetingCols: Column<any>[] = [
    { key: 'meeting_label', header: 'Meeting', render: (r: any) => r.meeting_label },
    { key: 'held_at', header: 'Held / Scheduled', render: (r: any) => fmtDate(r.held_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'attendees_md', header: 'Attendees', render: (r: any) => (r.attendees_md ?? '-').slice(0, 80) },
    { key: 'decisions_md', header: 'Decisions', render: (r: any) => (r.decisions_md ?? '-').slice(0, 80) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'meeting_label', header: 'Meeting', render: (r: any) => r.meeting_label },
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'owner_role', header: 'Role', render: (r: any) => r.owner_role },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority },
    { key: 'due_at', header: 'Due', render: (r: any) => fmtDate(r.due_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDate(r.closed_at) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'meeting_label', header: 'Meeting', render: (r: any) => r.meeting_label },
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'owner_role', header: 'Role', render: (r: any) => r.owner_role },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority },
    { key: 'due_at', header: 'Due', render: (r: any) => fmtDate(r.due_at) },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const roleCols: Column<any>[] = [
    { key: 'owner_role', header: 'Role', render: (r: any) => r.owner_role },
    { key: 'total_actions', header: 'Total', render: (r: any) => String(r.total_actions ?? 0) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
    { key: 'in_progress_count', header: 'In Progress', render: (r: any) => String(r.in_progress_count ?? 0) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count ?? 0) },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => String(r.dropped_count ?? 0) },
  ];

  const completionCols: Column<any>[] = [
    { key: 'total_actions', header: 'Total Actions', render: (r: any) => String(r.total_actions ?? 0) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count ?? 0) },
    { key: 'in_progress_count', header: 'In Progress', render: (r: any) => String(r.in_progress_count ?? 0) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => String(r.dropped_count ?? 0) },
    { key: 'completion_pct', header: 'Completion %', render: (r: any) => `${r.completion_pct ?? 0}%` },
  ];

  const topOpenCols: Column<any>[] = [
    { key: 'meeting_label', header: 'Meeting', render: (r: any) => r.meeting_label },
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'owner_role', header: 'Role', render: (r: any) => r.owner_role },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority },
    { key: 'due_at', header: 'Due', render: (r: any) => fmtDate(r.due_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'meeting_label', header: 'Meeting', render: (r: any) => r.meeting_label },
    { key: 'held_at', header: 'Held', render: (r: any) => fmtDate(r.held_at) },
    { key: 'decisions_md', header: 'Decisions', render: (r: any) => (r.decisions_md ?? '-').slice(0, 120) },
    { key: 'key_resolutions_md', header: 'Key Resolutions', render: (r: any) => (r.key_resolutions_md ?? '-').slice(0, 120) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Board Meeting & Action Tracker</h1>
        <p className="text-sm text-gray-600">
          Meeting decisions =&gt; action items =&gt; owner =&gt; due date =&gt; completion
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Completion Rate</h2>
        <DataTable
          rows={completion}
          columns={completionCols}
          emptyMessage="No actions tracked yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Role Breakdown</h2>
        <DataTable
          rows={roleBreakdown}
          columns={roleCols}
          emptyMessage="No role data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue Actions</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No overdue actions"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Open Actions</h2>
        <DataTable
          rows={topOpen}
          columns={topOpenCols}
          emptyMessage="No open actions"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Decisions</h2>
        <DataTable
          rows={recentDecisions}
          columns={decisionCols}
          emptyMessage="No recent decisions"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Meetings</h2>
        <DataTable
          rows={meetings}
          columns={meetingCols}
          emptyMessage="No meetings"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No actions"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
