import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer feedback loop closure — r2432" };
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

function rootCauseClass(kind: string): string {
  if (kind === "product") return "text-indigo-700";
  if (kind === "process") return "text-sky-700";
  if (kind === "people") return "text-violet-700";
  if (kind === "policy") return "text-amber-700";
  return "text-gray-500";
}

function shortId(s: string | null | undefined): string {
  if (!s) return "—";
  return s.slice(0, 8);
}

export default async function FounderCustomerFeedbackLoopClosurePage() {
  const sb = await getSupabaseServerClient();

  const [
    feedbackRes,
    metricsRes,
    topCausesRes,
    npsRes,
    velocityRes,
    impactedRes,
    openCritRes,
  ] = await Promise.all([
    sb.rpc("list_feedback_r2432"),
    sb.rpc("list_metrics_r2432"),
    sb.rpc("top_root_causes_r2432"),
    sb.rpc("nps_recovery_summary_r2432"),
    sb.rpc("closure_velocity_r2432"),
    sb.rpc("top_impacted_hospitals_r2432"),
    sb.rpc("open_critical_focus_r2432"),
  ]);

  if (feedbackRes.error) throw new Error(`list_feedback_r2432: ${feedbackRes.error.message}`);
  if (metricsRes.error) throw new Error(`list_metrics_r2432: ${metricsRes.error.message}`);
  if (topCausesRes.error) throw new Error(`top_root_causes_r2432: ${topCausesRes.error.message}`);
  if (npsRes.error) throw new Error(`nps_recovery_summary_r2432: ${npsRes.error.message}`);
  if (velocityRes.error) throw new Error(`closure_velocity_r2432: ${velocityRes.error.message}`);
  if (impactedRes.error) throw new Error(`top_impacted_hospitals_r2432: ${impactedRes.error.message}`);
  if (openCritRes.error) throw new Error(`open_critical_focus_r2432: ${openCritRes.error.message}`);

  const feedback = (feedbackRes.data ?? []) as any[];
  const metrics = (metricsRes.data ?? []) as any[];
  const topCauses = (topCausesRes.data ?? []) as any[];
  const npsRows = (npsRes.data ?? []) as any[];
  const velocity = (velocityRes.data ?? []) as any[];
  const impacted = (impactedRes.data ?? []) as any[];
  const openCrit = (openCritRes.data ?? []) as any[];

  const nps = npsRows[0] ?? {};

  const totalItems = feedback.length;
  const closedItems = feedback.filter((f) => f.loop_closed_at).length;
  const openItems = totalItems - closedItems;
  const criticalOpen = feedback.filter((f) => !f.loop_closed_at && f.severity === "critical").length;
  const closureRate = totalItems === 0 ? 0 : Math.round((closedItems / totalItems) * 100);

  const feedbackColumns: Column<any>[] = [
    { key: "submitted_at", header: "Submitted", render: (r: any) => fmtDate(r.submitted_at) },
    { key: "feedback_kind", header: "Kind", render: (r: any) => r.feedback_kind },
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityClass(r.severity)}>{r.severity}</span> },
    { key: "root_cause_kind", header: "Root cause", render: (r: any) => <span className={rootCauseClass(r.root_cause_kind)}>{r.root_cause_kind}</span> },
    { key: "root_cause_notes", header: "Notes", render: (r: any) => r.root_cause_notes ?? "—" },
    { key: "fix_shipped_at", header: "Fix shipped", render: (r: any) => fmtDate(r.fix_shipped_at) },
    { key: "fix_pr_ref", header: "PR", render: (r: any) => r.fix_pr_ref ?? "—" },
    { key: "loop_closed_at", header: "Loop closed", render: (r: any) => fmtDate(r.loop_closed_at) },
    { key: "loop_closure_kind", header: "Closure", render: (r: any) => r.loop_closure_kind ?? "—" },
    { key: "nps_before", header: "NPS before", render: (r: any) => (r.nps_before ?? "—") },
    { key: "nps_after", header: "NPS after", render: (r: any) => (r.nps_after ?? "—") },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const metricsColumns: Column<any>[] = [
    { key: "period", header: "Period", render: (r: any) => `${fmtDate(r.period_start)} → ${fmtDate(r.period_end)}` },
    { key: "root_cause_kind", header: "Root cause", render: (r: any) => <span className={rootCauseClass(r.root_cause_kind)}>{r.root_cause_kind}</span> },
    { key: "item_count", header: "Items", render: (r: any) => String(r.item_count) },
    { key: "closed_count", header: "Closed", render: (r: any) => String(r.closed_count) },
    { key: "open_count", header: "Open", render: (r: any) => String(r.open_count) },
    { key: "avg_close_days", header: "Avg close (days)", render: (r: any) => String(r.avg_close_days) },
    { key: "total_nps_recovery", header: "NPS lift", render: (r: any) => String(r.total_nps_recovery) },
    { key: "action_plan", header: "Action plan", render: (r: any) => r.action_plan ?? "—" },
  ];

  const topCausesColumns: Column<any>[] = [
    { key: "root_cause_kind", header: "Root cause", render: (r: any) => <span className={rootCauseClass(r.root_cause_kind)}>{r.root_cause_kind}</span> },
    { key: "item_count", header: "Items", render: (r: any) => String(r.item_count) },
    { key: "closed_count", header: "Closed", render: (r: any) => String(r.closed_count) },
    { key: "open_count", header: "Open", render: (r: any) => String(r.open_count) },
    { key: "critical_count", header: "Critical", render: (r: any) => <span className={r.critical_count > 0 ? "text-rose-700 font-semibold" : ""}>{String(r.critical_count)}</span> },
    { key: "avg_close_days", header: "Avg close (days)", render: (r: any) => String(r.avg_close_days) },
  ];

  const velocityColumns: Column<any>[] = [
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityClass(r.severity)}>{r.severity}</span> },
    { key: "item_count", header: "Items", render: (r: any) => String(r.item_count) },
    { key: "closed_count", header: "Closed", render: (r: any) => String(r.closed_count) },
    { key: "avg_fix_days", header: "Avg fix (days)", render: (r: any) => String(r.avg_fix_days) },
    { key: "avg_close_days", header: "Avg close (days)", render: (r: any) => String(r.avg_close_days) },
    { key: "fastest_close_days", header: "Fastest (days)", render: (r: any) => String(r.fastest_close_days) },
    { key: "slowest_close_days", header: "Slowest (days)", render: (r: any) => String(r.slowest_close_days) },
  ];

  const impactedColumns: Column<any>[] = [
    { key: "hospital_user_id", header: "Hospital", render: (r: any) => shortId(r.hospital_user_id) },
    { key: "feedback_count", header: "Items", render: (r: any) => String(r.feedback_count) },
    { key: "critical_count", header: "Critical", render: (r: any) => <span className={r.critical_count > 0 ? "text-rose-700 font-semibold" : ""}>{String(r.critical_count)}</span> },
    { key: "open_count", header: "Open", render: (r: any) => String(r.open_count) },
    { key: "avg_nps_lift", header: "Avg NPS lift", render: (r: any) => String(r.avg_nps_lift) },
    { key: "last_submitted_at", header: "Last submitted", render: (r: any) => fmtDate(r.last_submitted_at) },
  ];

  const openCritColumns: Column<any>[] = [
    { key: "submitted_at", header: "Submitted", render: (r: any) => fmtDate(r.submitted_at) },
    { key: "days_open", header: "Days open", render: (r: any) => <span className="font-semibold">{String(r.days_open)}</span> },
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityClass(r.severity)}>{r.severity}</span> },
    { key: "feedback_kind", header: "Kind", render: (r: any) => r.feedback_kind },
    { key: "root_cause_kind", header: "Root cause", render: (r: any) => <span className={rootCauseClass(r.root_cause_kind)}>{r.root_cause_kind}</span> },
    { key: "root_cause_notes", header: "Notes", render: (r: any) => r.root_cause_notes ?? "—" },
    { key: "hospital_user_id", header: "Hospital", render: (r: any) => shortId(r.hospital_user_id) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder customer feedback loop closure — r2432</h1>
        <p className="mt-1 text-xs text-gray-500">
          Every complaint, bug, and feature request tracked through root cause => fix shipped => loop closed =>
          NPS recovery. Founder-only. Closing the loop turns detractors into promoters.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total items</div>
          <div className="mt-1 text-lg font-semibold">{totalItems}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Closed</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{closedItems}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{openItems}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Critical open</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{criticalOpen}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Closure rate</div>
          <div className="mt-1 text-lg font-semibold">{closureRate}%</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total NPS lift</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{String(nps.total_nps_lift ?? 0)}</div>
        </div>
      </section>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Items with NPS pair</div>
          <div className="mt-1 text-lg font-semibold">{String(nps.items_with_nps ?? 0)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg NPS before</div>
          <div className="mt-1 text-lg font-semibold">{String(nps.avg_nps_before ?? 0)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg NPS after</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{String(nps.avg_nps_after ?? 0)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Recovered / regressed</div>
          <div className="mt-1 text-lg font-semibold">
            <span className="text-emerald-700">{String(nps.recovered_count ?? 0)}</span>
            {" / "}
            <span className="text-rose-700">{String(nps.regressed_count ?? 0)}</span>
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Open critical & high focus</h2>
        <p className="text-xs text-gray-500">
          Founder action list. Anything critical-or-high without a closed loop sits here until handled. Sorted by
          severity then oldest-first.
        </p>
        <DataTable
          rows={openCrit}
          columns={openCritColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No open critical or high feedback. All loops closed."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top root causes</h2>
        <p className="text-xs text-gray-500">
          Where the most pain comes from. Product & process dominate fixable volume; people & policy hint at
          deeper investment.
        </p>
        <DataTable
          rows={topCauses}
          columns={topCausesColumns}
          rowKey={(r: any, i: number) => String(r.root_cause_kind ?? i)}
          emptyMessage="No feedback classified yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Closure velocity by severity</h2>
        <p className="text-xs text-gray-500">
          Time from submission to fix shipped and to loop closed. Critical items must beat the high bar; slowest-close
          surfaces stuck items.
        </p>
        <DataTable
          rows={velocity}
          columns={velocityColumns}
          rowKey={(r: any, i: number) => String(r.severity ?? i)}
          emptyMessage="No velocity data."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top impacted hospitals</h2>
        <p className="text-xs text-gray-500">
          Customers who submit the most feedback are also the most engaged. Track open count & NPS lift to spot
          churn risk vs. champion candidates.
        </p>
        <DataTable
          rows={impacted}
          columns={impactedColumns}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
          emptyMessage="No hospital feedback recorded."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Root-cause metrics (periodic)</h2>
        <p className="text-xs text-gray-500">
          Periodic snapshot of root-cause distribution & action plans. Use to brief the team on where the next
          investment goes.
        </p>
        <DataTable
          rows={metrics}
          columns={metricsColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No metrics snapshots yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All feedback items</h2>
        <p className="text-xs text-gray-500">
          Complete log of every complaint, bug, feature request, praise & suggestion. NPS before-vs-after pair
          measures whether the loop closure actually moved the customer.
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
