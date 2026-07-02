import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder engineer supervisor feedback loop — r2602" };
export const dynamic = "force-dynamic";

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function severityClass(sev: string): string {
  if (sev === "critical") return "text-rose-700 font-semibold";
  if (sev === "high") return "text-orange-700";
  if (sev === "medium") return "text-amber-700";
  if (sev === "low") return "text-gray-500";
  return "";
}

function signalClass(kind: string): string {
  if (kind === "praise") return "text-emerald-700";
  if (kind === "recognition") return "text-emerald-700 font-semibold";
  if (kind === "concern") return "text-amber-700";
  if (kind === "coachable_moment") return "text-sky-700";
  if (kind === "escalation") return "text-rose-700 font-semibold";
  return "text-gray-500";
}

function outcomeClass(kind: string): string {
  if (kind === "improved") return "text-emerald-700 font-semibold";
  if (kind === "regressed") return "text-rose-700 font-semibold";
  if (kind === "no_change") return "text-amber-700";
  if (kind === "dropped") return "text-gray-500";
  return "";
}

function statusClass(status: string): string {
  if (status === "open") return "text-amber-700";
  if (status === "in_progress") return "text-sky-700";
  if (status === "closed") return "text-emerald-700";
  if (status === "done") return "text-emerald-700";
  if (status === "dropped") return "text-gray-500";
  return "";
}

function shortId(s: string | null | undefined): string {
  if (!s) return "—";
  return s.slice(0, 8);
}

export default async function FounderEngineerSupervisorFeedbackLoopPage() {
  const sb = await getSupabaseServerClient();

  const [
    feedbackRes,
    outcomesRes,
    focusRes,
    signalRes,
    statusRes,
    trendRes,
    supervisorRes,
  ] = await Promise.all([
    sb.rpc("list_feedback_r2602"),
    sb.rpc("list_growth_outcomes_r2602"),
    sb.rpc("top_concern_focus_r2602"),
    sb.rpc("signal_kind_breakdown_r2602"),
    sb.rpc("status_funnel_r2602"),
    sb.rpc("monthly_feedback_trend_r2602"),
    sb.rpc("supervisor_load_r2602"),
  ]);

  if (feedbackRes.error) throw new Error(`list_feedback_r2602: ${feedbackRes.error.message}`);
  if (outcomesRes.error) throw new Error(`list_growth_outcomes_r2602: ${outcomesRes.error.message}`);
  if (focusRes.error) throw new Error(`top_concern_focus_r2602: ${focusRes.error.message}`);
  if (signalRes.error) throw new Error(`signal_kind_breakdown_r2602: ${signalRes.error.message}`);
  if (statusRes.error) throw new Error(`status_funnel_r2602: ${statusRes.error.message}`);
  if (trendRes.error) throw new Error(`monthly_feedback_trend_r2602: ${trendRes.error.message}`);
  if (supervisorRes.error) throw new Error(`supervisor_load_r2602: ${supervisorRes.error.message}`);

  const feedback = (feedbackRes.data ?? []) as any[];
  const outcomes = (outcomesRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const signals = (signalRes.data ?? []) as any[];
  const statuses = (statusRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const supervisors = (supervisorRes.data ?? []) as any[];

  const totalItems = feedback.length;
  const openItems = feedback.filter((f) => f.status === "open" || f.status === "in_progress").length;
  const closedItems = feedback.filter((f) => f.status === "closed").length;
  const criticalOpen = feedback.filter((f) => (f.status === "open" || f.status === "in_progress") && f.severity === "critical").length;
  const improvedCount = outcomes.filter((o) => o.outcome_kind === "improved").length;
  const regressedCount = outcomes.filter((o) => o.outcome_kind === "regressed").length;

  const feedbackColumns: Column<any>[] = [
    { key: "feedback_at", header: "Date", render: (r: any) => fmtDate(r.feedback_at) },
    { key: "engineer_user_id", header: "Engineer", render: (r: any) => shortId(r.engineer_user_id) },
    { key: "supervisor_email", header: "Supervisor", render: (r: any) => r.supervisor_email },
    { key: "signal_kind", header: "Signal", render: (r: any) => <span className={signalClass(r.signal_kind)}>{r.signal_kind}</span> },
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityClass(r.severity)}>{r.severity}</span> },
    { key: "feedback_md", header: "Feedback", render: (r: any) => r.feedback_md },
    { key: "growth_action_md", header: "Growth action", render: (r: any) => r.growth_action_md ?? "—" },
    { key: "status", header: "Status", render: (r: any) => <span className={statusClass(r.status)}>{r.status}</span> },
    { key: "days_open", header: "Days", render: (r: any) => String(r.days_open) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const outcomesColumns: Column<any>[] = [
    { key: "outcome_at", header: "Date", render: (r: any) => fmtDate(r.outcome_at) },
    { key: "feedback_id", header: "Feedback", render: (r: any) => shortId(r.feedback_id) },
    { key: "signal_kind", header: "Signal", render: (r: any) => <span className={signalClass(r.signal_kind)}>{r.signal_kind}</span> },
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityClass(r.severity)}>{r.severity}</span> },
    { key: "feedback_excerpt", header: "Feedback excerpt", render: (r: any) => r.feedback_excerpt ?? "—" },
    { key: "outcome_kind", header: "Outcome", render: (r: any) => <span className={outcomeClass(r.outcome_kind)}>{r.outcome_kind}</span> },
    { key: "measurement_md", header: "Measurement", render: (r: any) => r.measurement_md ?? "—" },
    { key: "status", header: "Status", render: (r: any) => <span className={statusClass(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const focusColumns: Column<any>[] = [
    { key: "feedback_at", header: "Date", render: (r: any) => fmtDate(r.feedback_at) },
    { key: "days_open", header: "Days open", render: (r: any) => <span className="font-semibold">{String(r.days_open)}</span> },
    { key: "engineer_user_id", header: "Engineer", render: (r: any) => shortId(r.engineer_user_id) },
    { key: "signal_kind", header: "Signal", render: (r: any) => <span className={signalClass(r.signal_kind)}>{r.signal_kind}</span> },
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityClass(r.severity)}>{r.severity}</span> },
    { key: "feedback_md", header: "Feedback", render: (r: any) => r.feedback_md },
    { key: "growth_action_md", header: "Growth action", render: (r: any) => r.growth_action_md ?? "—" },
    { key: "status", header: "Status", render: (r: any) => <span className={statusClass(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const signalColumns: Column<any>[] = [
    { key: "signal_kind", header: "Signal", render: (r: any) => <span className={signalClass(r.signal_kind)}>{r.signal_kind}</span> },
    { key: "total_count", header: "Total", render: (r: any) => String(r.total_count) },
    { key: "critical_count", header: "Critical", render: (r: any) => <span className={r.critical_count > 0 ? "text-rose-700 font-semibold" : ""}>{String(r.critical_count)}</span> },
    { key: "high_count", header: "High", render: (r: any) => String(r.high_count) },
    { key: "open_count", header: "Open", render: (r: any) => <span className="text-amber-700">{String(r.open_count)}</span> },
    { key: "closed_count", header: "Closed", render: (r: any) => <span className="text-emerald-700">{String(r.closed_count)}</span> },
    { key: "improved_count", header: "Improved", render: (r: any) => <span className="text-emerald-700 font-semibold">{String(r.improved_count)}</span> },
  ];

  const statusColumns: Column<any>[] = [
    { key: "status", header: "Status", render: (r: any) => <span className={statusClass(r.status)}>{r.status}</span> },
    { key: "feedback_count", header: "Count", render: (r: any) => String(r.feedback_count) },
    { key: "critical_count", header: "Critical", render: (r: any) => <span className={r.critical_count > 0 ? "text-rose-700 font-semibold" : ""}>{String(r.critical_count)}</span> },
    { key: "high_count", header: "High", render: (r: any) => String(r.high_count) },
    { key: "oldest_days", header: "Oldest (days)", render: (r: any) => String(r.oldest_days) },
    { key: "newest_days", header: "Newest (days)", render: (r: any) => String(r.newest_days) },
  ];

  const trendColumns: Column<any>[] = [
    { key: "month_start", header: "Month", render: (r: any) => fmtDate(r.month_start) },
    { key: "feedback_count", header: "Total", render: (r: any) => String(r.feedback_count) },
    { key: "praise_count", header: "Praise", render: (r: any) => <span className="text-emerald-700">{String(r.praise_count)}</span> },
    { key: "concern_count", header: "Concern", render: (r: any) => <span className="text-amber-700">{String(r.concern_count)}</span> },
    { key: "escalation_count", header: "Escalation", render: (r: any) => <span className={r.escalation_count > 0 ? "text-rose-700 font-semibold" : ""}>{String(r.escalation_count)}</span> },
    { key: "critical_count", header: "Critical", render: (r: any) => <span className={r.critical_count > 0 ? "text-rose-700 font-semibold" : ""}>{String(r.critical_count)}</span> },
    { key: "improved_outcomes", header: "Improved", render: (r: any) => <span className="text-emerald-700 font-semibold">{String(r.improved_outcomes)}</span> },
  ];

  const supervisorColumns: Column<any>[] = [
    { key: "supervisor_email", header: "Supervisor", render: (r: any) => r.supervisor_email },
    { key: "feedback_count", header: "Items", render: (r: any) => String(r.feedback_count) },
    { key: "praise_count", header: "Praise", render: (r: any) => <span className="text-emerald-700">{String(r.praise_count)}</span> },
    { key: "concern_count", header: "Concern", render: (r: any) => <span className="text-amber-700">{String(r.concern_count)}</span> },
    { key: "escalation_count", header: "Escalation", render: (r: any) => <span className={r.escalation_count > 0 ? "text-rose-700 font-semibold" : ""}>{String(r.escalation_count)}</span> },
    { key: "open_count", header: "Open", render: (r: any) => <span className="text-amber-700">{String(r.open_count)}</span> },
    { key: "closed_count", header: "Closed", render: (r: any) => <span className="text-emerald-700">{String(r.closed_count)}</span> },
    { key: "improved_outcomes", header: "Improved", render: (r: any) => <span className="text-emerald-700 font-semibold">{String(r.improved_outcomes)}</span> },
    { key: "last_feedback_at", header: "Last", render: (r: any) => fmtDate(r.last_feedback_at) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder engineer supervisor feedback loop — r2602</h1>
        <p className="mt-1 text-xs text-gray-500">
          Every weekly supervisor signal on every engineer tracked from praise => concern => coachable moment =>
          growth action => measured outcome. Founder-only. Coaching at scale is the moat.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total items</div>
          <div className="mt-1 text-lg font-semibold">{totalItems}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open / in-progress</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{openItems}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Closed</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{closedItems}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Critical open</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{criticalOpen}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Improved outcomes</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{improvedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Regressed outcomes</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{regressedCount}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top concern focus</h2>
        <p className="text-xs text-gray-500">
          Open concerns, coachable moments & escalations sorted by severity then age. Founder action queue —
          critical-severity escalations get skip-level today.
        </p>
        <DataTable
          rows={focus}
          columns={focusColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No open concerns. All clear."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Signal kind breakdown</h2>
        <p className="text-xs text-gray-500">
          Praise-to-concern ratio per signal. Healthy team = praise > concern by 3x. Escalations should be rare;
          improved-outcome rate should rise quarter-over-quarter.
        </p>
        <DataTable
          rows={signals}
          columns={signalColumns}
          rowKey={(r: any, i: number) => String(r.signal_kind ?? i)}
          emptyMessage="No signals yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Status funnel</h2>
        <p className="text-xs text-gray-500">
          Items by status with oldest-open days. Anything open more than 14 days means coaching has stalled —
          re-assign owner or drop.
        </p>
        <DataTable
          rows={statuses}
          columns={statusColumns}
          rowKey={(r: any, i: number) => String(r.status ?? i)}
          emptyMessage="No status data."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Monthly feedback trend</h2>
        <p className="text-xs text-gray-500">
          Monthly volume + signal mix + improved-outcome count. Rising escalations + falling improved = systemic
          supervision quality problem.
        </p>
        <DataTable
          rows={trend}
          columns={trendColumns}
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
          emptyMessage="No trend data."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Supervisor load</h2>
        <p className="text-xs text-gray-500">
          Per-supervisor feedback volume + improved-outcome rate. Supervisors with high concern & low improved are
          themselves coachable — promote the ones who grow people.
        </p>
        <DataTable
          rows={supervisors}
          columns={supervisorColumns}
          rowKey={(r: any, i: number) => String(r.supervisor_email ?? i)}
          emptyMessage="No supervisor data."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Growth outcomes</h2>
        <p className="text-xs text-gray-500">
          Did the coaching actually work? Improved => behaviour stuck. Regressed => coaching failed, escalate.
          No-change => need a different lever.
        </p>
        <DataTable
          rows={outcomes}
          columns={outcomesColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No outcomes recorded yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All feedback items</h2>
        <p className="text-xs text-gray-500">
          Complete log of every supervisor => engineer signal. Praise & recognition build culture;
          concern & coachable_moment build growth; escalation gates founder attention.
        </p>
        <DataTable
          rows={feedback}
          columns={feedbackColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No feedback recorded."
        />
      </section>
    </div>
  );
}
