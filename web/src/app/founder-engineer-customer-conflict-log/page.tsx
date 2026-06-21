import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder engineer customer conflict log — r1764" };
export const dynamic = "force-dynamic";

type ConflictRow = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  hospital_user_id: string;
  hospital_email: string | null;
  occurred_at: string;
  severity: string;
  conflict_summary: string;
  status: string;
  resolved_at: string | null;
  step_count: number;
  created_at: string;
};

type StepRow = {
  id: string;
  conflict_id: string;
  step_type: string;
  taken_at: string;
  by_email: string | null;
  outcome: string | null;
  conflict_severity: string;
  conflict_status: string;
};

type SeverityRow = {
  severity: string;
  total_count: number;
  open_count: number;
  in_mediation_count: number;
  resolved_count: number;
  escalated_legal_count: number;
  avg_resolution_hours: number | null;
};

type SummaryRow = {
  total_open: number;
  total_in_mediation: number;
  total_resolved: number;
  total_escalated_legal: number;
  oldest_open_hours: number | null;
  serious_or_escalated_open: number;
  conflicts_last_7d: number;
  resolved_last_7d: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 16).replace("T", " ");
  } catch {
    return "—";
  }
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toLocaleString();
}

function severityBadge(sev: string): string {
  if (sev === "escalated") return "text-red-700 font-semibold";
  if (sev === "serious") return "text-orange-700 font-semibold";
  if (sev === "moderate") return "text-amber-700";
  if (sev === "minor") return "text-gray-600";
  return "";
}

function statusBadge(st: string): string {
  if (st === "open") return "text-red-700";
  if (st === "in_mediation") return "text-amber-700";
  if (st === "resolved") return "text-emerald-700";
  if (st === "escalated_to_legal") return "text-purple-700 font-semibold";
  return "";
}

function shortId(s: string): string {
  if (!s) return "—";
  return s.slice(0, 8);
}

export default async function FounderEngineerCustomerConflictLogPage() {
  const sb = await getSupabaseServerClient();
  const [conflictsRes, stepsRes, severityRes, summaryRes] = await Promise.all([
    sb.rpc("list_conflicts_r1764"),
    sb.rpc("list_resolution_steps_r1764", { p_conflict_id: null }),
    sb.rpc("severity_distribution_r1764"),
    sb.rpc("open_conflicts_summary_r1764"),
  ]);

  if (conflictsRes.error) throw new Error(`list_conflicts_r1764: ${conflictsRes.error.message}`);
  if (stepsRes.error) throw new Error(`list_resolution_steps_r1764: ${stepsRes.error.message}`);
  if (severityRes.error) throw new Error(`severity_distribution_r1764: ${severityRes.error.message}`);
  if (summaryRes.error) throw new Error(`open_conflicts_summary_r1764: ${summaryRes.error.message}`);

  const conflicts = (conflictsRes.data ?? []) as ConflictRow[];
  const steps = (stepsRes.data ?? []) as StepRow[];
  const severity = (severityRes.data ?? []) as SeverityRow[];
  const summaryArr = (summaryRes.data ?? []) as SummaryRow[];
  const summary: SummaryRow = summaryArr[0] ?? {
    total_open: 0,
    total_in_mediation: 0,
    total_resolved: 0,
    total_escalated_legal: 0,
    oldest_open_hours: null,
    serious_or_escalated_open: 0,
    conflicts_last_7d: 0,
    resolved_last_7d: 0,
  };

  const conflictColumns: Column<ConflictRow>[] = [
    { key: "occurred_at", header: "Occurred", render: (r: any) => fmtDate(r.occurred_at) },
    { key: "engineer_email", header: "Engineer", render: (r: any) => r.engineer_email ?? shortId(r.engineer_user_id) },
    { key: "hospital_email", header: "Hospital", render: (r: any) => r.hospital_email ?? shortId(r.hospital_user_id) },
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityBadge(r.severity)}>{r.severity}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "conflict_summary", header: "Summary", render: (r: any) => <span className="text-sm">{(r.conflict_summary ?? "").slice(0, 80)}</span> },
    { key: "step_count", header: "Steps", render: (r: any) => fmtNum(r.step_count) },
    { key: "resolved_at", header: "Resolved", render: (r: any) => fmtDate(r.resolved_at) },
  ];

  const stepColumns: Column<StepRow>[] = [
    { key: "taken_at", header: "Taken", render: (r: any) => fmtDate(r.taken_at) },
    { key: "step_type", header: "Step", render: (r: any) => <span className="font-medium">{r.step_type}</span> },
    { key: "by_email", header: "By", render: (r: any) => r.by_email ?? "—" },
    { key: "outcome", header: "Outcome", render: (r: any) => <span className="text-sm">{(r.outcome ?? "—").slice(0, 80)}</span> },
    { key: "conflict_severity", header: "Conflict severity", render: (r: any) => <span className={severityBadge(r.conflict_severity)}>{r.conflict_severity}</span> },
    { key: "conflict_status", header: "Conflict status", render: (r: any) => <span className={statusBadge(r.conflict_status)}>{r.conflict_status}</span> },
    { key: "conflict_id", header: "Conflict", render: (r: any) => <span className="font-mono text-xs">{shortId(r.conflict_id)}</span> },
  ];

  const severityColumns: Column<SeverityRow>[] = [
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityBadge(r.severity)}>{r.severity}</span> },
    { key: "total_count", header: "Total", render: (r: any) => fmtNum(r.total_count) },
    { key: "open_count", header: "Open", render: (r: any) => <span className="text-red-700">{fmtNum(r.open_count)}</span> },
    { key: "in_mediation_count", header: "In mediation", render: (r: any) => <span className="text-amber-700">{fmtNum(r.in_mediation_count)}</span> },
    { key: "resolved_count", header: "Resolved", render: (r: any) => <span className="text-emerald-700">{fmtNum(r.resolved_count)}</span> },
    { key: "escalated_legal_count", header: "Legal", render: (r: any) => <span className="text-purple-700">{fmtNum(r.escalated_legal_count)}</span> },
    { key: "avg_resolution_hours", header: "Avg resolve (hrs)", render: (r: any) => r.avg_resolution_hours === null ? "—" : fmtNum(r.avg_resolution_hours) },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer customer conflict log</h1>
        <p className="text-sm text-gray-600">
          Track engineer-hospital conflicts and resolution path. Severities range from minor to escalated; statuses cover open through escalated-to-legal. Resolution steps include apology, refund, reassign, training, legal review, and founder call.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Open</div>
            <div className="text-2xl font-semibold text-red-700">{fmtNum(summary.total_open)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">In mediation</div>
            <div className="text-2xl font-semibold text-amber-700">{fmtNum(summary.total_in_mediation)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Resolved</div>
            <div className="text-2xl font-semibold text-emerald-700">{fmtNum(summary.total_resolved)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Escalated to legal</div>
            <div className="text-2xl font-semibold text-purple-700">{fmtNum(summary.total_escalated_legal)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Oldest open (hours)</div>
            <div className="text-2xl font-semibold">{summary.oldest_open_hours === null ? "—" : fmtNum(summary.oldest_open_hours)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Serious or escalated open</div>
            <div className="text-2xl font-semibold text-orange-700">{fmtNum(summary.serious_or_escalated_open)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">New conflicts (last 7d)</div>
            <div className="text-2xl font-semibold">{fmtNum(summary.conflicts_last_7d)}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Resolved (last 7d)</div>
            <div className="text-2xl font-semibold text-emerald-700">{fmtNum(summary.resolved_last_7d)}</div>
          </div>
        </div>
        <p className="text-xs text-gray-500">
          Watch oldest-open: anything aged &gt;= 72 hours at serious or escalated severity warrants a founder call within the next business day.
        </p>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Severity distribution</h2>
        <p className="text-sm text-gray-600">
          Mix across severities with status splits and average resolution hours. A spike in serious or escalated rows &gt; 5% of total is a sign engineer screening or hospital onboarding needs attention.
        </p>
        <DataTable rows={severity} columns={severityColumns} rowKey={(r: any, i: number) => String(r.severity ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Conflicts ({conflicts.length})</h2>
        <p className="text-sm text-gray-600">
          Most recent first. Click into a conflict id (via shortId) to cross-reference resolution steps below. Anything still open after &gt; 7 days should trigger mediation.
        </p>
        <DataTable rows={conflicts} columns={conflictColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Resolution steps ({steps.length})</h2>
        <p className="text-sm text-gray-600">
          Recent steps across all conflicts. A founder_call step on a conflict &lt; 24 hours old is a strong signal of seriousness; legal_review steps require board notification.
        </p>
        <DataTable rows={steps} columns={stepColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
