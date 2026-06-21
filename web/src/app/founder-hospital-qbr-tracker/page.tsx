import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type SessionRow = {
  id: string;
  hospital_user_id: string;
  hospital_name: string;
  quarter: string;
  scheduled_at: string;
  completed_at: string | null;
  attendees: string[] | null;
  summary_md: string | null;
  satisfaction_score: number | null;
  open_actions: number;
  total_actions: number;
};

type ActionRow = {
  id: string;
  session_id: string;
  quarter: string;
  hospital_name: string;
  action_text: string;
  owner_email: string;
  due_date: string | null;
  status: string;
  completed_at: string | null;
  days_overdue: number;
};

type Summary = {
  total_sessions: number;
  completed_sessions: number;
  upcoming_sessions: number;
  avg_satisfaction: number | null;
  open_actions: number;
  overdue_actions: number;
  done_actions: number;
  unique_hospitals: number;
};

function fmtDate(s: string | null) {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleString("en-IN", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return s;
  }
}

function fmtDay(s: string | null) {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleDateString("en-IN", {
      day: "2-digit",
      month: "short",
      year: "numeric",
    });
  } catch {
    return s;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [sessionsRes, actionsRes, summaryRes] = await Promise.all([
    sb.rpc("list_sessions_r1671"),
    sb.rpc("list_actions_r1671", { p_session_id: null }),
    sb.rpc("qbr_summary_r1671"),
  ]);

  const sessions: SessionRow[] = (sessionsRes.data as SessionRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];
  const summaryRow: Summary | null =
    Array.isArray(summaryRes.data) && summaryRes.data.length > 0
      ? (summaryRes.data[0] as Summary)
      : null;

  const sessionCols: Column<SessionRow>[] = [
    { key: "hospital_name", header: "Hospital", render: (r) => <span className="font-medium">{r.hospital_name}</span> },
    { key: "quarter", header: "Quarter", render: (r) => <span className="font-mono text-sm">{r.quarter}</span> },
    { key: "scheduled_at", header: "Scheduled", render: (r) => <span>{fmtDate(r.scheduled_at)}</span> },
    {
      key: "completed_at",
      header: "Status",
      render: (r) =>
        r.completed_at ? (
          <span className="text-green-700">Completed {fmtDate(r.completed_at)}</span>
        ) : new Date(r.scheduled_at) < new Date() ? (
          <span className="text-red-700">Overdue</span>
        ) : (
          <span className="text-blue-700">Upcoming</span>
        ),
    },
    {
      key: "satisfaction_score",
      header: "CSAT",
      render: (r) =>
        r.satisfaction_score == null ? (
          <span className="text-gray-400">—</span>
        ) : (
          <span className={r.satisfaction_score >= 8 ? "text-green-700 font-semibold" : r.satisfaction_score >= 5 ? "text-amber-700" : "text-red-700"}>
            {r.satisfaction_score}/10
          </span>
        ),
    },
    {
      key: "attendees",
      header: "Attendees",
      render: (r) => <span className="text-xs text-gray-600">{(r.attendees ?? []).length} person(s)</span>,
    },
    {
      key: "open_actions",
      header: "Actions",
      render: (r) => (
        <span className="text-xs">
          <span className="text-red-700 font-semibold">{r.open_actions}</span>
          <span className="text-gray-500"> open / {r.total_actions} total</span>
        </span>
      ),
    },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: "hospital_name", header: "Hospital", render: (r) => <span className="font-medium">{r.hospital_name}</span> },
    { key: "quarter", header: "Quarter", render: (r) => <span className="font-mono text-xs">{r.quarter}</span> },
    { key: "action_text", header: "Action", render: (r) => <span className="text-sm">{r.action_text}</span> },
    { key: "owner_email", header: "Owner", render: (r) => <span className="text-xs">{r.owner_email}</span> },
    {
      key: "due_date",
      header: "Due",
      render: (r) => (
        <span className={r.days_overdue > 0 ? "text-red-700 font-semibold" : "text-gray-700"}>
          {fmtDay(r.due_date)}
          {r.days_overdue > 0 && <span className="ml-1 text-xs">({r.days_overdue}d late)</span>}
        </span>
      ),
    },
    {
      key: "status",
      header: "Status",
      render: (r) => (
        <span
          className={
            r.status === "done"
              ? "px-2 py-0.5 rounded text-xs bg-green-100 text-green-800"
              : r.status === "cancelled"
                ? "px-2 py-0.5 rounded text-xs bg-gray-100 text-gray-700"
                : r.days_overdue > 0
                  ? "px-2 py-0.5 rounded text-xs bg-red-100 text-red-800"
                  : "px-2 py-0.5 rounded text-xs bg-blue-100 text-blue-800"
          }
        >
          {r.status}
        </span>
      ),
    },
  ];

  const openActions = actions.filter((a) => a.status === "open");
  const overdueActions = openActions.filter((a) => a.days_overdue > 0);

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Hospital Quarterly Review Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          QBR cadence per hospital — schedule, complete, track action items, measure satisfaction.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Summary KPIs</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="border rounded-lg p-4 bg-white">
            <div className="text-xs text-gray-500 uppercase tracking-wide">Total Sessions</div>
            <div className="text-2xl font-bold mt-1">{summaryRow?.total_sessions ?? 0}</div>
            <div className="text-xs text-gray-500 mt-1">{summaryRow?.unique_hospitals ?? 0} hospitals</div>
          </div>
          <div className="border rounded-lg p-4 bg-white">
            <div className="text-xs text-gray-500 uppercase tracking-wide">Completed</div>
            <div className="text-2xl font-bold mt-1 text-green-700">{summaryRow?.completed_sessions ?? 0}</div>
            <div className="text-xs text-gray-500 mt-1">{summaryRow?.upcoming_sessions ?? 0} upcoming</div>
          </div>
          <div className="border rounded-lg p-4 bg-white">
            <div className="text-xs text-gray-500 uppercase tracking-wide">Avg CSAT</div>
            <div className="text-2xl font-bold mt-1 text-blue-700">
              {summaryRow?.avg_satisfaction != null ? `${summaryRow.avg_satisfaction}/10` : "—"}
            </div>
            <div className="text-xs text-gray-500 mt-1">across rated sessions</div>
          </div>
          <div className="border rounded-lg p-4 bg-white">
            <div className="text-xs text-gray-500 uppercase tracking-wide">Action Backlog</div>
            <div className="text-2xl font-bold mt-1 text-amber-700">{summaryRow?.open_actions ?? 0}</div>
            <div className="text-xs text-red-700 mt-1">{summaryRow?.overdue_actions ?? 0} overdue</div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">QBR Sessions</h2>
        {sessions.length === 0 ? (
          <div className="border rounded-lg p-8 text-center text-gray-500 text-sm bg-white">
            No QBR sessions scheduled yet. Use schedule_session_r1671 RPC to begin.
          </div>
        ) : (
          <DataTable rows={sessions} columns={sessionCols} rowKey={(r, i) => String(r.id ?? i)} />
        )}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">
          Open Action Queue
          <span className="ml-2 text-sm font-normal text-gray-600">
            ({openActions.length} open, {overdueActions.length} overdue)
          </span>
        </h2>
        {openActions.length === 0 ? (
          <div className="border rounded-lg p-8 text-center text-gray-500 text-sm bg-white">
            No open action items. All QBR commitments closed out.
          </div>
        ) : (
          <DataTable rows={openActions} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
        )}
      </section>

      <section className="text-xs text-gray-500 border-t pt-4">
        <p>
          Round r1671 · Hospital QBR Tracker · Tables: hospital_qbr_sessions_r1671,
          hospital_qbr_action_items_r1671 · 7 RPCs, all founder-gated via is_founder().
        </p>
      </section>
    </div>
  );
}
