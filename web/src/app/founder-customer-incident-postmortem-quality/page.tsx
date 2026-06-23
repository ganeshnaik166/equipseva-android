import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Customer incident postmortem quality — r2548" };
export const dynamic = "force-dynamic";

type PostmortemRow = {
  id: string;
  hospital_user_id: string | null;
  incident_kind: string;
  incident_at: string;
  postmortem_started_at: string | null;
  postmortem_completed_at: string | null;
  root_cause_depth_score: number;
  action_items_count: number;
  follow_through_rate_pct: number;
  no_repeat_track_record_months: number;
  owner_email: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type ActionItemRow = {
  id: string;
  postmortem_id: string;
  action_text: string;
  owner_email: string | null;
  due_at: string | null;
  status: string;
  outcome: string;
  closed_at: string | null;
  notes: string | null;
  created_at: string;
};

type RepeatKindRow = {
  incident_kind: string;
  incident_count: number;
  avg_depth_score: number;
  avg_follow_through_pct: number;
  min_no_repeat_months: number;
};

type FollowThroughRow = {
  status: string;
  postmortem_count: number;
  avg_follow_through_pct: number;
  avg_depth_score: number;
};

type NoRepeatTopRow = {
  postmortem_id: string;
  incident_kind: string;
  incident_at: string;
  no_repeat_track_record_months: number;
  follow_through_rate_pct: number;
  root_cause_depth_score: number;
  status: string;
};

type ActionCompletionRow = {
  status: string;
  item_count: number;
  positive_outcomes: number;
  negative_outcomes: number;
  pending_outcomes: number;
};

type MonthlyTrendRow = {
  month_label: string;
  incident_count: number;
  completed_count: number;
  skipped_count: number;
  avg_depth_score: number;
  avg_follow_through_pct: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function statusBadge(status: string): string {
  if (status === "completed" || status === "done") return "text-emerald-700";
  if (status === "in_progress") return "text-blue-700";
  if (status === "scheduled" || status === "open") return "text-amber-700";
  if (status === "skipped" || status === "dropped") return "text-gray-500";
  return "";
}

function outcomeBadge(outcome: string): string {
  if (outcome === "positive") return "text-emerald-700";
  if (outcome === "negative") return "text-rose-700";
  if (outcome === "neutral") return "text-gray-600";
  if (outcome === "pending") return "text-amber-700";
  return "";
}

export default async function CustomerIncidentPostmortemQualityPage() {
  const sb = await getSupabaseServerClient();
  const [pmRes, aiRes, repeatRes, followRes, noRepeatRes, completionRes, trendRes] = await Promise.all([
    sb.rpc("list_postmortems_r2548"),
    sb.rpc("list_action_items_r2548"),
    sb.rpc("top_repeat_offender_kinds_r2548"),
    sb.rpc("follow_through_rate_summary_r2548"),
    sb.rpc("no_repeat_record_top_hospitals_r2548"),
    sb.rpc("action_completion_rate_r2548"),
    sb.rpc("monthly_postmortem_trend_r2548"),
  ]);

  if (pmRes.error) throw new Error(`list_postmortems_r2548: ${pmRes.error.message}`);
  if (aiRes.error) throw new Error(`list_action_items_r2548: ${aiRes.error.message}`);
  if (repeatRes.error) throw new Error(`top_repeat_offender_kinds_r2548: ${repeatRes.error.message}`);
  if (followRes.error) throw new Error(`follow_through_rate_summary_r2548: ${followRes.error.message}`);
  if (noRepeatRes.error) throw new Error(`no_repeat_record_top_hospitals_r2548: ${noRepeatRes.error.message}`);
  if (completionRes.error) throw new Error(`action_completion_rate_r2548: ${completionRes.error.message}`);
  if (trendRes.error) throw new Error(`monthly_postmortem_trend_r2548: ${trendRes.error.message}`);

  const postmortems = (pmRes.data ?? []) as PostmortemRow[];
  const actionItems = (aiRes.data ?? []) as ActionItemRow[];
  const repeatKinds = (repeatRes.data ?? []) as RepeatKindRow[];
  const followThrough = (followRes.data ?? []) as FollowThroughRow[];
  const noRepeatTop = (noRepeatRes.data ?? []) as NoRepeatTopRow[];
  const actionCompletion = (completionRes.data ?? []) as ActionCompletionRow[];
  const monthlyTrend = (trendRes.data ?? []) as MonthlyTrendRow[];

  const totalIncidents = postmortems.length;
  const completedCount = postmortems.filter((p) => p.status === "completed").length;
  const inProgressCount = postmortems.filter((p) => p.status === "in_progress").length;
  const skippedCount = postmortems.filter((p) => p.status === "skipped").length;
  const avgDepth =
    totalIncidents > 0
      ? Math.round(postmortems.reduce((a, p) => a + (p.root_cause_depth_score ?? 0), 0) / totalIncidents)
      : 0;
  const avgFollow =
    totalIncidents > 0
      ? Math.round(postmortems.reduce((a, p) => a + Number(p.follow_through_rate_pct ?? 0), 0) / totalIncidents)
      : 0;

  const postmortemColumns: Column<PostmortemRow>[] = [
    { key: "incident_kind", header: "Kind", render: (r: any) => <span className="font-medium">{r.incident_kind}</span> },
    { key: "incident_at", header: "Incident", render: (r: any) => fmtDate(r.incident_at) },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "root_cause_depth_score", header: "Depth", render: (r: any) => `${r.root_cause_depth_score}/100` },
    { key: "action_items_count", header: "Actions", render: (r: any) => String(r.action_items_count) },
    { key: "follow_through_rate_pct", header: "Follow-through", render: (r: any) => `${Number(r.follow_through_rate_pct).toFixed(1)}%` },
    { key: "no_repeat_track_record_months", header: "No-repeat (mo)", render: (r: any) => String(r.no_repeat_track_record_months) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "postmortem_completed_at", header: "Closed", render: (r: any) => fmtDate(r.postmortem_completed_at) },
  ];

  const actionItemColumns: Column<ActionItemRow>[] = [
    { key: "action_text", header: "Action", render: (r: any) => <span className="font-medium">{r.action_text}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "due_at", header: "Due", render: (r: any) => fmtDate(r.due_at) },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "outcome", header: "Outcome", render: (r: any) => <span className={outcomeBadge(r.outcome)}>{r.outcome}</span> },
    { key: "closed_at", header: "Closed", render: (r: any) => fmtDate(r.closed_at) },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const repeatKindColumns: Column<RepeatKindRow>[] = [
    { key: "incident_kind", header: "Kind", render: (r: any) => <span className="font-medium">{r.incident_kind}</span> },
    { key: "incident_count", header: "Incidents", render: (r: any) => String(r.incident_count) },
    { key: "avg_depth_score", header: "Avg depth", render: (r: any) => `${Number(r.avg_depth_score).toFixed(1)}/100` },
    { key: "avg_follow_through_pct", header: "Avg follow-through", render: (r: any) => `${Number(r.avg_follow_through_pct).toFixed(1)}%` },
    { key: "min_no_repeat_months", header: "Min no-repeat (mo)", render: (r: any) => String(r.min_no_repeat_months) },
  ];

  const followThroughColumns: Column<FollowThroughRow>[] = [
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "postmortem_count", header: "Postmortems", render: (r: any) => String(r.postmortem_count) },
    { key: "avg_follow_through_pct", header: "Avg follow-through", render: (r: any) => `${Number(r.avg_follow_through_pct).toFixed(1)}%` },
    { key: "avg_depth_score", header: "Avg depth", render: (r: any) => `${Number(r.avg_depth_score).toFixed(1)}/100` },
  ];

  const noRepeatColumns: Column<NoRepeatTopRow>[] = [
    { key: "incident_kind", header: "Kind", render: (r: any) => <span className="font-medium">{r.incident_kind}</span> },
    { key: "incident_at", header: "Incident", render: (r: any) => fmtDate(r.incident_at) },
    { key: "no_repeat_track_record_months", header: "No-repeat (mo)", render: (r: any) => String(r.no_repeat_track_record_months) },
    { key: "follow_through_rate_pct", header: "Follow-through", render: (r: any) => `${Number(r.follow_through_rate_pct).toFixed(1)}%` },
    { key: "root_cause_depth_score", header: "Depth", render: (r: any) => `${r.root_cause_depth_score}/100` },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
  ];

  const actionCompletionColumns: Column<ActionCompletionRow>[] = [
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "item_count", header: "Items", render: (r: any) => String(r.item_count) },
    { key: "positive_outcomes", header: "Positive", render: (r: any) => <span className="text-emerald-700">{String(r.positive_outcomes)}</span> },
    { key: "negative_outcomes", header: "Negative", render: (r: any) => <span className="text-rose-700">{String(r.negative_outcomes)}</span> },
    { key: "pending_outcomes", header: "Pending", render: (r: any) => <span className="text-amber-700">{String(r.pending_outcomes)}</span> },
  ];

  const monthlyTrendColumns: Column<MonthlyTrendRow>[] = [
    { key: "month_label", header: "Month", render: (r: any) => <span className="font-medium">{r.month_label}</span> },
    { key: "incident_count", header: "Incidents", render: (r: any) => String(r.incident_count) },
    { key: "completed_count", header: "Completed", render: (r: any) => <span className="text-emerald-700">{String(r.completed_count)}</span> },
    { key: "skipped_count", header: "Skipped", render: (r: any) => <span className="text-gray-500">{String(r.skipped_count)}</span> },
    { key: "avg_depth_score", header: "Avg depth", render: (r: any) => `${Number(r.avg_depth_score).toFixed(1)}/100` },
    { key: "avg_follow_through_pct", header: "Avg follow-through", render: (r: any) => `${Number(r.avg_follow_through_pct).toFixed(1)}%` },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Customer incident postmortem quality — r2548</h1>
        <p className="mt-1 text-xs text-gray-500">
          Track every hospital incident => did we run a postmortem, how deep did we go, how many action items
          shipped, and did the same problem stay dead? Founder-only.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Incidents</div>
          <div className="mt-1 text-lg font-semibold">{totalIncidents}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Completed</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{completedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">In progress</div>
          <div className="mt-1 text-lg font-semibold text-blue-700">{inProgressCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Skipped</div>
          <div className="mt-1 text-lg font-semibold text-gray-500">{skippedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg depth</div>
          <div className="mt-1 text-lg font-semibold">{avgDepth}/100</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg follow-through</div>
          <div className="mt-1 text-lg font-semibold">{avgFollow}%</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All postmortems</h2>
        <p className="text-xs text-gray-500">
          Every hospital incident logged. Depth score >= 70 => deep RCA. Follow-through < 50% => risk of repeat.
        </p>
        <DataTable
          rows={postmortems}
          columns={postmortemColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No postmortems logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Repeat-offender incident kinds</h2>
        <p className="text-xs text-gray-500">
          Which incident kinds keep happening & how rigorously did we postmortem them?
        </p>
        <DataTable
          rows={repeatKinds}
          columns={repeatKindColumns}
          rowKey={(r: any, i: number) => String(r.incident_kind ?? i)}
          emptyMessage="No incident kinds yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Follow-through by postmortem status</h2>
        <p className="text-xs text-gray-500">
          Completed postmortems should have high follow-through. Skipped => zero by definition.
        </p>
        <DataTable
          rows={followThrough}
          columns={followThroughColumns}
          rowKey={(r: any, i: number) => String(r.status ?? i)}
          emptyMessage="No postmortem statuses yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">No-repeat track record — top postmortems</h2>
        <p className="text-xs text-gray-500">
          Longest stretches where the same incident kind did NOT recur after the postmortem. Best-in-class signal.
        </p>
        <DataTable
          rows={noRepeatTop}
          columns={noRepeatColumns}
          rowKey={(r: any, i: number) => String(r.postmortem_id ?? i)}
          emptyMessage="No no-repeat data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All action items</h2>
        <p className="text-xs text-gray-500">
          Every line item from every postmortem. Owner + due date + outcome => this is the accountability layer.
        </p>
        <DataTable
          rows={actionItems}
          columns={actionItemColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No action items yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Action-item completion funnel</h2>
        <p className="text-xs text-gray-500">
          Where action items sit by status & outcome. Many open + pending => backlog risk.
        </p>
        <DataTable
          rows={actionCompletion}
          columns={actionCompletionColumns}
          rowKey={(r: any, i: number) => String(r.status ?? i)}
          emptyMessage="No action items yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Monthly postmortem trend</h2>
        <p className="text-xs text-gray-500">
          Incident volume & postmortem rigor over time. Avg depth & follow-through should trend up as we mature.
        </p>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyTrendColumns}
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
          emptyMessage="No monthly trend data yet."
        />
      </section>
    </div>
  );
}
