import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder weekly investor update tracker — r2289" };
export const dynamic = "force-dynamic";

type DraftRow = {
  id: string;
  week_start: string;
  subject: string;
  status: string;
  drafted_at: string;
  sent_at: string | null;
  recipient_count: number;
  open_rate_pct: number | null;
  reply_count: number;
  has_changed_since_last_week: boolean;
};

type SendLogRow = {
  week_start: string;
  subject: string;
  sent_at: string | null;
  recipient_count: number;
  open_rate_pct: number | null;
  reply_count: number;
  response_count: number;
  action_required_count: number;
};

type ResponseRow = {
  id: string;
  week_start: string;
  investor_email: string;
  investor_name: string | null;
  response_type: string;
  sentiment: string | null;
  action_required: boolean;
  action_resolved: boolean;
  received_at: string;
  body_preview: string;
};

type ChangesRow = {
  week_start: string;
  subject: string;
  status: string;
  changed_since_last_week_md: string | null;
  highlights_md: string | null;
  lowlights_md: string | null;
};

type BreakdownRow = {
  response_type: string;
  total_count: number;
  action_required_count: number;
  action_resolved_count: number;
  positive_count: number;
  negative_count: number;
};

type PendingActionRow = {
  id: string;
  week_start: string;
  investor_email: string;
  investor_name: string | null;
  response_type: string;
  body_preview: string;
  age_days: number;
  sentiment: string | null;
};

type OverviewRow = {
  total_drafts: number;
  sent_drafts: number;
  draft_in_progress: number;
  total_responses: number;
  pending_actions: number;
  avg_open_rate_pct: number | null;
  avg_reply_count: number | null;
  positive_response_pct: number | null;
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
  if (status === "sent") return "text-emerald-700";
  if (status === "reviewed") return "text-blue-700";
  if (status === "draft") return "text-amber-700";
  if (status === "archived") return "text-gray-500";
  return "";
}

function sentimentBadge(s: string | null): string {
  if (s === "positive") return "text-emerald-700";
  if (s === "negative") return "text-rose-700";
  if (s === "neutral") return "text-gray-600";
  return "";
}

export default async function FounderWeeklyInvestorUpdateTrackerPage() {
  const sb = await getSupabaseServerClient();
  const [draftsRes, sendLogRes, responsesRes, changesRes, breakdownRes, pendingRes, overviewRes] = await Promise.all([
    sb.rpc("list_investor_update_drafts_r2289"),
    sb.rpc("investor_update_send_log_r2289"),
    sb.rpc("investor_responses_recent_r2289"),
    sb.rpc("investor_update_changes_log_r2289"),
    sb.rpc("investor_update_response_breakdown_r2289"),
    sb.rpc("investor_update_pending_actions_r2289"),
    sb.rpc("investor_update_overview_r2289"),
  ]);

  if (draftsRes.error) throw new Error(`list_investor_update_drafts_r2289: ${draftsRes.error.message}`);
  if (sendLogRes.error) throw new Error(`investor_update_send_log_r2289: ${sendLogRes.error.message}`);
  if (responsesRes.error) throw new Error(`investor_responses_recent_r2289: ${responsesRes.error.message}`);
  if (changesRes.error) throw new Error(`investor_update_changes_log_r2289: ${changesRes.error.message}`);
  if (breakdownRes.error) throw new Error(`investor_update_response_breakdown_r2289: ${breakdownRes.error.message}`);
  if (pendingRes.error) throw new Error(`investor_update_pending_actions_r2289: ${pendingRes.error.message}`);
  if (overviewRes.error) throw new Error(`investor_update_overview_r2289: ${overviewRes.error.message}`);

  const drafts = (draftsRes.data ?? []) as DraftRow[];
  const sendLog = (sendLogRes.data ?? []) as SendLogRow[];
  const responses = (responsesRes.data ?? []) as ResponseRow[];
  const changes = (changesRes.data ?? []) as ChangesRow[];
  const breakdown = (breakdownRes.data ?? []) as BreakdownRow[];
  const pending = (pendingRes.data ?? []) as PendingActionRow[];
  const overview = ((overviewRes.data ?? [])[0] ?? null) as OverviewRow | null;

  const draftCols: Column<DraftRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "subject", header: "Subject", render: (r: any) => <span className="font-medium">{r.subject}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "sent_at", header: "Sent", render: (r: any) => fmtDate(r.sent_at) },
    { key: "recipient_count", header: "Recipients", render: (r: any) => String(r.recipient_count) },
    { key: "open_rate_pct", header: "Open %", render: (r: any) => (r.open_rate_pct == null ? "—" : `${r.open_rate_pct}%`) },
    { key: "reply_count", header: "Replies", render: (r: any) => String(r.reply_count) },
    { key: "has_changed_since_last_week", header: "Changes noted", render: (r: any) => (r.has_changed_since_last_week ? "yes" : "—") },
  ];

  const sendLogCols: Column<SendLogRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "subject", header: "Subject", render: (r: any) => <span className="font-medium">{r.subject}</span> },
    { key: "sent_at", header: "Sent at", render: (r: any) => fmtDate(r.sent_at) },
    { key: "recipient_count", header: "Recipients", render: (r: any) => String(r.recipient_count) },
    { key: "open_rate_pct", header: "Open %", render: (r: any) => (r.open_rate_pct == null ? "—" : `${r.open_rate_pct}%`) },
    { key: "reply_count", header: "Replies", render: (r: any) => String(r.reply_count) },
    { key: "response_count", header: "Logged responses", render: (r: any) => String(r.response_count) },
    { key: "action_required_count", header: "Pending actions", render: (r: any) => (r.action_required_count > 0 ? <span className="text-rose-700 font-semibold">{r.action_required_count}</span> : "0") },
  ];

  const responseCols: Column<ResponseRow>[] = [
    { key: "received_at", header: "When", render: (r: any) => fmtDate(r.received_at) },
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "investor_name", header: "Investor", render: (r: any) => <span className="font-medium">{r.investor_name ?? r.investor_email}</span> },
    { key: "response_type", header: "Type", render: (r: any) => r.response_type },
    { key: "sentiment", header: "Sentiment", render: (r: any) => <span className={sentimentBadge(r.sentiment)}>{r.sentiment ?? "—"}</span> },
    { key: "action_required", header: "Action?", render: (r: any) => (r.action_required ? (r.action_resolved ? "resolved" : <span className="text-rose-700 font-semibold">open</span>) : "—") },
    { key: "body_preview", header: "Body", render: (r: any) => <span className="text-xs text-gray-600">{r.body_preview}</span> },
  ];

  const changesCols: Column<ChangesRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "subject", header: "Subject", render: (r: any) => <span className="font-medium">{r.subject}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "changed_since_last_week_md", header: "What changed", render: (r: any) => <span className="text-xs">{r.changed_since_last_week_md ?? "—"}</span> },
    { key: "highlights_md", header: "Highlights", render: (r: any) => <span className="text-xs text-emerald-700">{r.highlights_md ?? "—"}</span> },
    { key: "lowlights_md", header: "Lowlights", render: (r: any) => <span className="text-xs text-rose-700">{r.lowlights_md ?? "—"}</span> },
  ];

  const breakdownCols: Column<BreakdownRow>[] = [
    { key: "response_type", header: "Type", render: (r: any) => <span className="font-medium">{r.response_type}</span> },
    { key: "total_count", header: "Total", render: (r: any) => String(r.total_count) },
    { key: "action_required_count", header: "Action required", render: (r: any) => String(r.action_required_count) },
    { key: "action_resolved_count", header: "Resolved", render: (r: any) => String(r.action_resolved_count) },
    { key: "positive_count", header: "Positive", render: (r: any) => <span className="text-emerald-700">{String(r.positive_count)}</span> },
    { key: "negative_count", header: "Negative", render: (r: any) => <span className="text-rose-700">{String(r.negative_count)}</span> },
  ];

  const pendingCols: Column<PendingActionRow>[] = [
    { key: "age_days", header: "Age (d)", render: (r: any) => (r.age_days >= 3 ? <span className="text-rose-700 font-semibold">{r.age_days}</span> : String(r.age_days)) },
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "investor_name", header: "Investor", render: (r: any) => <span className="font-medium">{r.investor_name ?? r.investor_email}</span> },
    { key: "response_type", header: "Type", render: (r: any) => r.response_type },
    { key: "sentiment", header: "Sentiment", render: (r: any) => <span className={sentimentBadge(r.sentiment)}>{r.sentiment ?? "—"}</span> },
    { key: "body_preview", header: "Body", render: (r: any) => <span className="text-xs text-gray-600">{r.body_preview}</span> },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder weekly investor update tracker — r2289</h1>
        <p className="mt-1 text-xs text-gray-500">
          Weekly investor update email: draft, send log, response & feedback log, and what changed each week. Keep
          LPs informed and track follow-on signals & intro offers.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total drafts</div>
          <div className="mt-1 text-lg font-semibold">{overview?.total_drafts ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Sent</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{overview?.sent_drafts ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Draft in progress</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{overview?.draft_in_progress ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total responses</div>
          <div className="mt-1 text-lg font-semibold">{overview?.total_responses ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Pending actions</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{overview?.pending_actions ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg open rate</div>
          <div className="mt-1 text-lg font-semibold">{overview?.avg_open_rate_pct == null ? "—" : `${overview.avg_open_rate_pct}%`}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg replies / week</div>
          <div className="mt-1 text-lg font-semibold">{overview?.avg_reply_count ?? "—"}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Positive sentiment %</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{overview?.positive_response_pct == null ? "—" : `${overview.positive_response_pct}%`}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All drafts</h2>
        <p className="text-xs text-gray-500">
          Every weekly update — draft, reviewed, sent, or archived. "Changes noted" flags drafts that
          captured what shifted since last week.
        </p>
        <DataTable
          rows={drafts}
          columns={draftCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No drafts yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Send log</h2>
        <p className="text-xs text-gray-500">
          Sent updates with delivery & engagement metrics. Pending actions column = unresolved investor asks.
        </p>
        <DataTable
          rows={sendLog}
          columns={sendLogCols}
          rowKey={(r: any, i: number) => `${r.week_start}-${i}`}
          emptyMessage="No updates sent yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Pending investor actions</h2>
        <p className="text-xs text-gray-500">
          Investor responses that need a follow-up. Items aged &gt;= 3 days highlighted red — answer fast to keep trust.
        </p>
        <DataTable
          rows={pending}
          columns={pendingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No pending actions — inbox zero."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Recent responses & feedback</h2>
        <p className="text-xs text-gray-500">
          Latest 100 investor responses across all sent updates. Type, sentiment, and whether an action is required.
        </p>
        <DataTable
          rows={responses}
          columns={responseCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No responses logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Response type breakdown</h2>
        <p className="text-xs text-gray-500">
          Mix of response types across all weeks. High follow_on_interest &amp; intro_offer counts =&gt; warm
          fundraising signal.
        </p>
        <DataTable
          rows={breakdown}
          columns={breakdownCols}
          rowKey={(r: any, i: number) => String(r.response_type ?? i)}
          emptyMessage="No response breakdown yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">What changed each week</h2>
        <p className="text-xs text-gray-500">
          Narrative log of week-over-week shifts. Captures the "delta" investors care about: what moved,
          what slipped, what is now critical-path.
        </p>
        <DataTable
          rows={changes}
          columns={changesCols}
          rowKey={(r: any, i: number) => `${r.week_start}-${i}`}
          emptyMessage="No change notes captured yet."
        />
      </section>
    </div>
  );
}
