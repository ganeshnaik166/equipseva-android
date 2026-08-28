import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Meeting = {
  meeting_code: string;
  quarter_label: string;
  meeting_date: string;
  location: string;
  chair_name: string;
  attendees_count: number;
  quorum_met: boolean;
  status: string;
  notes: string | null;
};

type ActionItem = {
  meeting_code: string;
  topic: string;
  decision: string;
  action_item: string;
  owner_name: string;
  due_date: string;
  done: boolean;
  follow_up_required: boolean;
  priority: string;
};

type Kpi = {
  total_meetings: number;
  ratified_meetings: number;
  total_actions: number;
  completed_actions: number;
  overdue_actions: number;
  follow_ups_pending: number;
};

type Overdue = {
  meeting_code: string;
  topic: string;
  action_item: string;
  owner_name: string;
  due_date: string;
  priority: string;
  days_overdue: number;
};

type Owner = {
  owner_name: string;
  total_actions: number;
  completed: number;
  open: number;
  overdue: number;
};

type FollowUp = {
  meeting_code: string;
  topic: string;
  action_item: string;
  owner_name: string;
  follow_up_notes: string | null;
  priority: string;
};

type Completion = {
  meeting_code: string;
  quarter_label: string;
  total_actions: number;
  done_count: number;
  completion_pct: number;
};

type Priority = {
  priority: string;
  total: number;
  done_count: number;
  open_count: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [meetingsRes, actionsRes, kpiRes, overdueRes, ownerRes, followRes, completionRes, priorityRes] = await Promise.all([
    supabase.rpc('founder_r2857_meetings_list'),
    supabase.rpc('founder_r2857_action_items_list'),
    supabase.rpc('founder_r2857_kpi_overview'),
    supabase.rpc('founder_r2857_overdue_actions'),
    supabase.rpc('founder_r2857_owner_workload'),
    supabase.rpc('founder_r2857_follow_ups'),
    supabase.rpc('founder_r2857_completion_rate_by_meeting'),
    supabase.rpc('founder_r2857_priority_breakdown'),
  ]);

  const meetings = (meetingsRes.data ?? []) as Meeting[];
  const actions = (actionsRes.data ?? []) as ActionItem[];
  const kpi = (kpiRes.data?.[0] ?? null) as Kpi | null;
  const overdue = (overdueRes.data ?? []) as Overdue[];
  const owners = (ownerRes.data ?? []) as Owner[];
  const followUps = (followRes.data ?? []) as FollowUp[];
  const completion = (completionRes.data ?? []) as Completion[];
  const priorities = (priorityRes.data ?? []) as Priority[];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Board Meeting Minutes Tracker</h1>
        <p className="text-sm text-gray-600">Round 2857 · meetings, decisions, action items & follow-ups</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <KpiCard label="Total Meetings" value={kpi?.total_meetings ?? 0} />
        <KpiCard label="Ratified" value={kpi?.ratified_meetings ?? 0} />
        <KpiCard label="Total Actions" value={kpi?.total_actions ?? 0} />
        <KpiCard label="Completed" value={kpi?.completed_actions ?? 0} />
        <KpiCard label="Overdue" value={kpi?.overdue_actions ?? 0} tone="danger" />
        <KpiCard label="Follow-ups Pending" value={kpi?.follow_ups_pending ?? 0} tone="warn" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Board Meetings</h2>
        <DataTable
          rows={meetings}
          columns={[
            { key: 'meeting_code', header: 'Code', render: (r: Meeting) => <span className="font-mono text-xs">{r.meeting_code}</span> },
            { key: 'quarter_label', header: 'Quarter', render: (r: Meeting) => <span>{r.quarter_label}</span> },
            { key: 'meeting_date', header: 'Date', render: (r: Meeting) => <span>{r.meeting_date}</span> },
            { key: 'location', header: 'Location', render: (r: Meeting) => <span>{r.location}</span> },
            { key: 'chair_name', header: 'Chair', render: (r: Meeting) => <span>{r.chair_name}</span> },
            { key: 'attendees_count', header: 'Attendees', render: (r: Meeting) => <span>{r.attendees_count}</span> },
            { key: 'quorum_met', header: 'Quorum', render: (r: Meeting) => <span>{r.quorum_met ? 'Yes' : 'No'}</span> },
            { key: 'status', header: 'Status', render: (r: Meeting) => <span className="text-xs uppercase">{r.status}</span> },
            { key: 'notes', header: 'Notes', render: (r: Meeting) => <span className="text-xs">{r.notes ?? ''}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Meeting, i: number) => String(r.meeting_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action Items</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'meeting_code', header: 'Meeting', render: (r: ActionItem) => <span className="font-mono text-xs">{r.meeting_code}</span> },
            { key: 'topic', header: 'Topic', render: (r: ActionItem) => <span>{r.topic}</span> },
            { key: 'decision', header: 'Decision', render: (r: ActionItem) => <span className="text-xs">{r.decision}</span> },
            { key: 'action_item', header: 'Action', render: (r: ActionItem) => <span className="text-xs">{r.action_item}</span> },
            { key: 'owner_name', header: 'Owner', render: (r: ActionItem) => <span>{r.owner_name}</span> },
            { key: 'due_date', header: 'Due', render: (r: ActionItem) => <span>{r.due_date}</span> },
            { key: 'done', header: 'Done', render: (r: ActionItem) => <span>{r.done ? 'Yes' : 'No'}</span> },
            { key: 'follow_up_required', header: 'Follow-up', render: (r: ActionItem) => <span>{r.follow_up_required ? 'Yes' : 'No'}</span> },
            { key: 'priority', header: 'Priority', render: (r: ActionItem) => <span className="text-xs uppercase">{r.priority}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionItem, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue Actions (due date &lt; today)</h2>
        <DataTable
          rows={overdue}
          columns={[
            { key: 'meeting_code', header: 'Meeting', render: (r: Overdue) => <span className="font-mono text-xs">{r.meeting_code}</span> },
            { key: 'topic', header: 'Topic', render: (r: Overdue) => <span>{r.topic}</span> },
            { key: 'action_item', header: 'Action', render: (r: Overdue) => <span className="text-xs">{r.action_item}</span> },
            { key: 'owner_name', header: 'Owner', render: (r: Overdue) => <span>{r.owner_name}</span> },
            { key: 'due_date', header: 'Due', render: (r: Overdue) => <span>{r.due_date}</span> },
            { key: 'priority', header: 'Priority', render: (r: Overdue) => <span className="text-xs uppercase">{r.priority}</span> },
            { key: 'days_overdue', header: 'Days Overdue', render: (r: Overdue) => <span className="text-red-600 font-semibold">{r.days_overdue}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Overdue, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Workload</h2>
        <DataTable
          rows={owners}
          columns={[
            { key: 'owner_name', header: 'Owner', render: (r: Owner) => <span>{r.owner_name}</span> },
            { key: 'total_actions', header: 'Total', render: (r: Owner) => <span>{r.total_actions}</span> },
            { key: 'completed', header: 'Completed', render: (r: Owner) => <span>{r.completed}</span> },
            { key: 'open', header: 'Open', render: (r: Owner) => <span>{r.open}</span> },
            { key: 'overdue', header: 'Overdue', render: (r: Owner) => <span className="text-red-600">{r.overdue}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Owner, i: number) => String(r.owner_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-ups Pending</h2>
        <DataTable
          rows={followUps}
          columns={[
            { key: 'meeting_code', header: 'Meeting', render: (r: FollowUp) => <span className="font-mono text-xs">{r.meeting_code}</span> },
            { key: 'topic', header: 'Topic', render: (r: FollowUp) => <span>{r.topic}</span> },
            { key: 'action_item', header: 'Action', render: (r: FollowUp) => <span className="text-xs">{r.action_item}</span> },
            { key: 'owner_name', header: 'Owner', render: (r: FollowUp) => <span>{r.owner_name}</span> },
            { key: 'follow_up_notes', header: 'Notes', render: (r: FollowUp) => <span className="text-xs">{r.follow_up_notes}</span> },
            { key: 'priority', header: 'Priority', render: (r: FollowUp) => <span className="text-xs uppercase">{r.priority}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: FollowUp, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Completion Rate by Meeting</h2>
        <DataTable
          rows={completion}
          columns={[
            { key: 'meeting_code', header: 'Meeting', render: (r: Completion) => <span className="font-mono text-xs">{r.meeting_code}</span> },
            { key: 'quarter_label', header: 'Quarter', render: (r: Completion) => <span>{r.quarter_label}</span> },
            { key: 'total_actions', header: 'Total', render: (r: Completion) => <span>{r.total_actions}</span> },
            { key: 'done_count', header: 'Done', render: (r: Completion) => <span>{r.done_count}</span> },
            { key: 'completion_pct', header: 'Completion %', render: (r: Completion) => <span>{r.completion_pct}%</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Completion, i: number) => String(r.meeting_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Priority Breakdown</h2>
        <DataTable
          rows={priorities}
          columns={[
            { key: 'priority', header: 'Priority', render: (r: Priority) => <span className="uppercase text-xs">{r.priority}</span> },
            { key: 'total', header: 'Total', render: (r: Priority) => <span>{r.total}</span> },
            { key: 'done_count', header: 'Done', render: (r: Priority) => <span>{r.done_count}</span> },
            { key: 'open_count', header: 'Open', render: (r: Priority) => <span>{r.open_count}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Priority, i: number) => String(r.priority ?? i)}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: number; tone?: 'danger' | 'warn' }) {
  const toneClass = tone === 'danger' ? 'text-red-700' : tone === 'warn' ? 'text-amber-700' : 'text-gray-900';
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className={`mt-1 text-2xl font-semibold ${toneClass}`}>{value}</div>
    </div>
  );
}
