import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder escalation root-cause taxonomy — r2318" };
export const dynamic = "force-dynamic";

type RootCauseRow = {
  id: string;
  escalation_ref: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  hospital_user_id: string | null;
  hospital_email: string | null;
  root_cause: string;
  sub_cause: string | null;
  severity: string;
  preventable: boolean;
  resolved: boolean;
  resolved_at: string | null;
  classified_at: string;
  notes: string | null;
};

type DistributionRow = {
  root_cause: string;
  total_count: number;
  resolved_count: number;
  preventable_count: number;
  critical_count: number;
  avg_resolution_hours: number | null;
};

type TrendRow = {
  week_start: string;
  root_cause: string;
  weekly_count: number;
};

type LeaderboardRow = {
  engineer_user_id: string | null;
  engineer_email: string | null;
  total_escalations: number;
  engineer_fault_count: number;
  critical_count: number;
  resolved_count: number;
};

type UnresolvedRow = {
  id: string;
  escalation_ref: string;
  root_cause: string;
  severity: string;
  engineer_email: string | null;
  hospital_email: string | null;
  classified_at: string;
  age_days: number;
};

type ActionOutcomeRow = {
  action_type: string;
  total_actions: number;
  resolved_count: number;
  failed_count: number;
  pending_count: number;
  total_cost_rupees: number;
};

type PreventableRow = {
  root_cause: string;
  preventable_count: number;
  total_count: number;
  preventable_pct: number | null;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function severityColor(sev: string): string {
  if (sev === "critical") return "text-red-700 font-semibold";
  if (sev === "high") return "text-orange-700";
  if (sev === "medium") return "text-amber-700";
  return "text-gray-600";
}

function rootCauseColor(rc: string): string {
  if (rc === "engineer") return "text-red-700";
  if (rc === "customer") return "text-blue-700";
  if (rc === "part") return "text-purple-700";
  if (rc === "schedule") return "text-amber-700";
  if (rc === "equipment") return "text-orange-700";
  if (rc === "process") return "text-indigo-700";
  if (rc === "communication") return "text-pink-700";
  return "text-gray-700";
}

export default async function FounderEscalationRootCauseTaxonomyPage() {
  const sb = await getSupabaseServerClient();
  const [listRes, distRes, trendRes, leaderRes, unresolvedRes, actionRes, preventRes] = await Promise.all([
    sb.rpc("list_escalation_root_causes_r2318"),
    sb.rpc("root_cause_distribution_r2318"),
    sb.rpc("root_cause_trend_r2318", { p_weeks: 12 }),
    sb.rpc("engineer_escalation_leaderboard_r2318"),
    sb.rpc("unresolved_escalations_r2318"),
    sb.rpc("action_outcome_summary_r2318"),
    sb.rpc("preventable_escalations_summary_r2318"),
  ]);

  if (listRes.error) throw new Error(`list_escalation_root_causes_r2318: ${listRes.error.message}`);
  if (distRes.error) throw new Error(`root_cause_distribution_r2318: ${distRes.error.message}`);
  if (trendRes.error) throw new Error(`root_cause_trend_r2318: ${trendRes.error.message}`);
  if (leaderRes.error) throw new Error(`engineer_escalation_leaderboard_r2318: ${leaderRes.error.message}`);
  if (unresolvedRes.error) throw new Error(`unresolved_escalations_r2318: ${unresolvedRes.error.message}`);
  if (actionRes.error) throw new Error(`action_outcome_summary_r2318: ${actionRes.error.message}`);
  if (preventRes.error) throw new Error(`preventable_escalations_summary_r2318: ${preventRes.error.message}`);

  const rows = (listRes.data ?? []) as RootCauseRow[];
  const dist = (distRes.data ?? []) as DistributionRow[];
  const trend = (trendRes.data ?? []) as TrendRow[];
  const leader = (leaderRes.data ?? []) as LeaderboardRow[];
  const unresolved = (unresolvedRes.data ?? []) as UnresolvedRow[];
  const actions = (actionRes.data ?? []) as ActionOutcomeRow[];
  const preventable = (preventRes.data ?? []) as PreventableRow[];

  const totalEscalations = rows.length;
  const resolvedCount = rows.filter((r) => r.resolved).length;
  const criticalCount = rows.filter((r) => r.severity === "critical").length;
  const preventableTotal = rows.filter((r) => r.preventable).length;
  const engineerFaultCount = rows.filter((r) => r.root_cause === "engineer").length;
  const customerFaultCount = rows.filter((r) => r.root_cause === "customer").length;

  const rootCauseColumns: Column<RootCauseRow>[] = [
    { key: "escalation_ref", header: "Ref", render: (r: any) => <span className="font-mono text-xs">{r.escalation_ref}</span> },
    { key: "root_cause", header: "Root cause", render: (r: any) => <span className={rootCauseColor(r.root_cause)}>{r.root_cause}</span> },
    { key: "sub_cause", header: "Sub-cause", render: (r: any) => r.sub_cause ?? "—" },
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityColor(r.severity)}>{r.severity}</span> },
    { key: "engineer_email", header: "Engineer", render: (r: any) => r.engineer_email ?? "—" },
    { key: "hospital_email", header: "Hospital", render: (r: any) => r.hospital_email ?? "—" },
    { key: "preventable", header: "Preventable", render: (r: any) => (r.preventable ? "yes" : "no") },
    { key: "resolved", header: "Resolved", render: (r: any) => (r.resolved ? "yes" : "no") },
    { key: "classified_at", header: "Classified", render: (r: any) => fmtDate(r.classified_at) },
  ];

  const distColumns: Column<DistributionRow>[] = [
    { key: "root_cause", header: "Root cause", render: (r: any) => <span className={rootCauseColor(r.root_cause)}>{r.root_cause}</span> },
    { key: "total_count", header: "Total", render: (r: any) => String(r.total_count) },
    { key: "resolved_count", header: "Resolved", render: (r: any) => String(r.resolved_count) },
    { key: "preventable_count", header: "Preventable", render: (r: any) => String(r.preventable_count) },
    { key: "critical_count", header: "Critical", render: (r: any) => String(r.critical_count) },
    { key: "avg_resolution_hours", header: "Avg hours to resolve", render: (r: any) => (r.avg_resolution_hours !== null ? String(r.avg_resolution_hours) : "—") },
  ];

  const trendColumns: Column<TrendRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "root_cause", header: "Root cause", render: (r: any) => <span className={rootCauseColor(r.root_cause)}>{r.root_cause}</span> },
    { key: "weekly_count", header: "Count", render: (r: any) => String(r.weekly_count) },
  ];

  const leaderColumns: Column<LeaderboardRow>[] = [
    { key: "engineer_email", header: "Engineer", render: (r: any) => r.engineer_email ?? "—" },
    { key: "total_escalations", header: "Total", render: (r: any) => String(r.total_escalations) },
    { key: "engineer_fault_count", header: "Engineer-fault", render: (r: any) => <span className="text-red-700">{String(r.engineer_fault_count)}</span> },
    { key: "critical_count", header: "Critical", render: (r: any) => String(r.critical_count) },
    { key: "resolved_count", header: "Resolved", render: (r: any) => String(r.resolved_count) },
  ];

  const unresolvedColumns: Column<UnresolvedRow>[] = [
    { key: "escalation_ref", header: "Ref", render: (r: any) => <span className="font-mono text-xs">{r.escalation_ref}</span> },
    { key: "root_cause", header: "Root cause", render: (r: any) => <span className={rootCauseColor(r.root_cause)}>{r.root_cause}</span> },
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityColor(r.severity)}>{r.severity}</span> },
    { key: "engineer_email", header: "Engineer", render: (r: any) => r.engineer_email ?? "—" },
    { key: "hospital_email", header: "Hospital", render: (r: any) => r.hospital_email ?? "—" },
    { key: "age_days", header: "Age (days)", render: (r: any) => <span className={r.age_days > 7 ? "text-red-700 font-semibold" : ""}>{String(r.age_days)}</span> },
    { key: "classified_at", header: "Classified", render: (r: any) => fmtDate(r.classified_at) },
  ];

  const actionColumns: Column<ActionOutcomeRow>[] = [
    { key: "action_type", header: "Action type", render: (r: any) => <span className="font-medium">{r.action_type}</span> },
    { key: "total_actions", header: "Total", render: (r: any) => String(r.total_actions) },
    { key: "resolved_count", header: "Resolved", render: (r: any) => <span className="text-emerald-700">{String(r.resolved_count)}</span> },
    { key: "failed_count", header: "Failed", render: (r: any) => <span className="text-red-700">{String(r.failed_count)}</span> },
    { key: "pending_count", header: "Pending", render: (r: any) => String(r.pending_count) },
    { key: "total_cost_rupees", header: "Total cost (₹)", render: (r: any) => String(r.total_cost_rupees) },
  ];

  const preventColumns: Column<PreventableRow>[] = [
    { key: "root_cause", header: "Root cause", render: (r: any) => <span className={rootCauseColor(r.root_cause)}>{r.root_cause}</span> },
    { key: "preventable_count", header: "Preventable", render: (r: any) => String(r.preventable_count) },
    { key: "total_count", header: "Total", render: (r: any) => String(r.total_count) },
    { key: "preventable_pct", header: "Preventable %", render: (r: any) => (r.preventable_pct !== null ? `${r.preventable_pct}%` : "—") },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder escalation root-cause taxonomy — r2318</h1>
        <p className="mt-1 text-xs text-gray-500">
          Classify every customer escalation by root cause (engineer, customer, part, schedule, equipment, process,
          communication, external). Trend over time. Preventable share. Engineer-fault leaderboard. Action outcomes &
          cost recovery. Catch systemic causes before they recur.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total escalations</div>
          <div className="mt-1 text-2xl font-semibold">{totalEscalations}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Resolved</div>
          <div className="mt-1 text-2xl font-semibold text-emerald-700">{resolvedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Critical</div>
          <div className="mt-1 text-2xl font-semibold text-red-700">{criticalCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Preventable</div>
          <div className="mt-1 text-2xl font-semibold text-amber-700">{preventableTotal}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Engineer-fault</div>
          <div className="mt-1 text-2xl font-semibold">{engineerFaultCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Customer-fault</div>
          <div className="mt-1 text-2xl font-semibold">{customerFaultCount}</div>
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold text-gray-800">Distribution by root cause</h2>
        <p className="mt-1 text-xs text-gray-500">
          Where do escalations come from? Spot the biggest bucket and attack the systemic cause.
        </p>
        <div className="mt-2">
          <DataTable<DistributionRow>
            rows={dist}
            columns={distColumns}
            rowKey={(r: DistributionRow) => r.root_cause}
            emptyMessage="No escalations classified yet."
          />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold text-gray-800">Weekly trend (last 12 weeks)</h2>
        <p className="mt-1 text-xs text-gray-500">
          Watch causes that are climbing week-over-week — that's where systemic drift is hiding.
        </p>
        <div className="mt-2">
          <DataTable<TrendRow>
            rows={trend}
            columns={trendColumns}
            rowKey={(r: TrendRow) => `${r.week_start}-${r.root_cause}`}
            emptyMessage="No trend data yet."
          />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold text-gray-800">Preventable share by cause</h2>
        <p className="mt-1 text-xs text-gray-500">
          High preventable % means tighter process & training would have caught these.
        </p>
        <div className="mt-2">
          <DataTable<PreventableRow>
            rows={preventable}
            columns={preventColumns}
            rowKey={(r: PreventableRow) => r.root_cause}
            emptyMessage="No data yet."
          />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold text-gray-800">Engineer leaderboard (top 50)</h2>
        <p className="mt-1 text-xs text-gray-500">
          High engineer-fault count =&gt; coaching candidate. High total without engineer-fault =&gt; high-stakes route.
        </p>
        <div className="mt-2">
          <DataTable<LeaderboardRow>
            rows={leader}
            columns={leaderColumns}
            rowKey={(r: LeaderboardRow) => r.engineer_user_id ?? r.engineer_email ?? "unknown"}
            emptyMessage="No engineer data yet."
          />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold text-gray-800">Unresolved queue (severity-first)</h2>
        <p className="mt-1 text-xs text-gray-500">
          Critical &amp; high first. Age &gt; 7 days highlighted — those have stalled.
        </p>
        <div className="mt-2">
          <DataTable<UnresolvedRow>
            rows={unresolved}
            columns={unresolvedColumns}
            rowKey={(r: UnresolvedRow) => r.id}
            emptyMessage="No unresolved escalations."
          />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold text-gray-800">Action outcomes & cost</h2>
        <p className="mt-1 text-xs text-gray-500">
          Which interventions work? Track resolved vs failed per action type & total ₹ spent.
        </p>
        <div className="mt-2">
          <DataTable<ActionOutcomeRow>
            rows={actions}
            columns={actionColumns}
            rowKey={(r: ActionOutcomeRow) => r.action_type}
            emptyMessage="No actions logged yet."
          />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold text-gray-800">All classified escalations</h2>
        <p className="mt-1 text-xs text-gray-500">
          Full taxonomy log — classified, severity, preventable flag, resolution status.
        </p>
        <div className="mt-2">
          <DataTable<RootCauseRow>
            rows={rows}
            columns={rootCauseColumns}
            rowKey={(r: RootCauseRow) => r.id}
            emptyMessage="No classified escalations yet."
          />
        </div>
      </section>
    </div>
  );
}
