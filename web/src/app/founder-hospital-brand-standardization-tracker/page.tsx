import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder hospital brand standardization tracker — r1763" };
export const dynamic = "force-dynamic";

type StandardRow = {
  id: string;
  hospital_user_id: string;
  hospital_name: string | null;
  hospital_city: string | null;
  standard_type: string;
  compliance_score: number;
  last_audited_at: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type ActionRow = {
  id: string;
  standard_id: string;
  standard_type: string | null;
  hospital_name: string | null;
  action: string;
  owner_email: string | null;
  due_date: string | null;
  status: string;
  cost_rupees: number;
  completed_at: string | null;
  created_at: string;
};

type SummaryRow = {
  standard_type: string;
  total_count: number;
  compliant_count: number;
  partial_count: number;
  non_compliant_count: number;
  avg_score: number | null;
  open_actions: number;
  total_cost_rupees: number;
};

type TopRow = {
  hospital_user_id: string;
  hospital_name: string | null;
  hospital_city: string | null;
  audited_count: number;
  avg_score: number | null;
  non_compliant_count: number;
  open_actions: number;
  last_audited_at: string | null;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function statusColor(status: string): string {
  if (status === "compliant" || status === "done") return "text-emerald-700";
  if (status === "partial" || status === "open") return "text-amber-700";
  if (status === "non_compliant") return "text-red-700";
  if (status === "cancelled") return "text-gray-500";
  return "";
}

function scoreColor(score: number): string {
  if (score >= 80) return "text-emerald-700 font-medium";
  if (score >= 50) return "text-amber-700 font-medium";
  return "text-red-700 font-medium";
}

export default async function FounderHospitalBrandStandardizationTrackerPage() {
  const sb = await getSupabaseServerClient();
  const [standardsRes, actionsRes, summaryRes, topRes] = await Promise.all([
    sb.rpc("list_standards_r1763"),
    sb.rpc("list_actions_r1763"),
    sb.rpc("compliance_summary_r1763"),
    sb.rpc("top_non_compliant_r1763"),
  ]);

  if (standardsRes.error) throw new Error(`list_standards_r1763: ${standardsRes.error.message}`);
  if (actionsRes.error) throw new Error(`list_actions_r1763: ${actionsRes.error.message}`);
  if (summaryRes.error) throw new Error(`compliance_summary_r1763: ${summaryRes.error.message}`);
  if (topRes.error) throw new Error(`top_non_compliant_r1763: ${topRes.error.message}`);

  const standards = (standardsRes.data ?? []) as StandardRow[];
  const actions = (actionsRes.data ?? []) as ActionRow[];
  const summary = (summaryRes.data ?? []) as SummaryRow[];
  const top = (topRes.data ?? []) as TopRow[];

  const totalAudits = standards.length;
  const compliantCount = standards.filter((s) => s.status === "compliant").length;
  const partialCount = standards.filter((s) => s.status === "partial").length;
  const nonCompliantCount = standards.filter((s) => s.status === "non_compliant").length;
  const openActions = actions.filter((a) => a.status === "open").length;
  const doneActions = actions.filter((a) => a.status === "done").length;
  const totalCost = actions.reduce((s, a) => s + (a.cost_rupees || 0), 0);
  const avgScore =
    standards.length > 0
      ? Math.round(standards.reduce((s, r) => s + r.compliance_score, 0) / standards.length)
      : 0;

  const standardColumns: Column<StandardRow>[] = [
    {
      key: "hospital_name",
      header: "Hospital",
      render: (r: any) => (
        <div>
          <div className="font-medium">{r.hospital_name ?? "—"}</div>
          <div className="text-xs text-gray-500">{r.hospital_city ?? "—"}</div>
        </div>
      ),
    },
    { key: "standard_type", header: "Standard", render: (r: any) => r.standard_type },
    {
      key: "compliance_score",
      header: "Score",
      render: (r: any) => <span className={scoreColor(r.compliance_score)}>{r.compliance_score}</span>,
    },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusColor(r.status)}>{r.status}</span>,
    },
    { key: "last_audited_at", header: "Last audited", render: (r: any) => fmtDate(r.last_audited_at) },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
    { key: "created_at", header: "Created", render: (r: any) => fmtDate(r.created_at) },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: "hospital_name", header: "Hospital", render: (r: any) => r.hospital_name ?? "—" },
    { key: "standard_type", header: "Standard", render: (r: any) => r.standard_type ?? "—" },
    { key: "action", header: "Action", render: (r: any) => <span className="font-medium">{r.action}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "due_date", header: "Due", render: (r: any) => fmtDate(r.due_date) },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusColor(r.status)}>{r.status}</span>,
    },
    { key: "cost_rupees", header: "Cost (Rs)", render: (r: any) => String(r.cost_rupees ?? 0) },
    { key: "completed_at", header: "Completed", render: (r: any) => fmtDate(r.completed_at) },
  ];

  const summaryColumns: Column<SummaryRow>[] = [
    { key: "standard_type", header: "Standard", render: (r: any) => <span className="font-medium">{r.standard_type}</span> },
    { key: "total_count", header: "Audits", render: (r: any) => String(r.total_count) },
    { key: "compliant_count", header: "Compliant", render: (r: any) => <span className="text-emerald-700">{r.compliant_count}</span> },
    { key: "partial_count", header: "Partial", render: (r: any) => <span className="text-amber-700">{r.partial_count}</span> },
    { key: "non_compliant_count", header: "Non-compliant", render: (r: any) => <span className="text-red-700">{r.non_compliant_count}</span> },
    { key: "avg_score", header: "Avg score", render: (r: any) => (r.avg_score == null ? "—" : <span className={scoreColor(Number(r.avg_score))}>{r.avg_score}</span>) },
    { key: "open_actions", header: "Open actions", render: (r: any) => String(r.open_actions) },
    { key: "total_cost_rupees", header: "Cost (Rs)", render: (r: any) => String(r.total_cost_rupees) },
  ];

  const topColumns: Column<TopRow>[] = [
    {
      key: "hospital_name",
      header: "Hospital",
      render: (r: any) => (
        <div>
          <div className="font-medium">{r.hospital_name ?? "—"}</div>
          <div className="text-xs text-gray-500">{r.hospital_city ?? "—"}</div>
        </div>
      ),
    },
    { key: "audited_count", header: "Audits", render: (r: any) => String(r.audited_count) },
    { key: "avg_score", header: "Avg score", render: (r: any) => (r.avg_score == null ? "—" : <span className={scoreColor(Number(r.avg_score))}>{r.avg_score}</span>) },
    { key: "non_compliant_count", header: "Non-compliant", render: (r: any) => <span className="text-red-700">{r.non_compliant_count}</span> },
    { key: "open_actions", header: "Open actions", render: (r: any) => String(r.open_actions) },
    { key: "last_audited_at", header: "Last audited", render: (r: any) => fmtDate(r.last_audited_at) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder hospital brand standardization tracker — r1763</h1>
        <p className="mt-1 text-xs text-gray-500">
          Per-hospital adherence to brand standards: signage, uniforms, materials, equipment decals & website link.
          Audit scores 0–100, status compliant / partial / non_compliant, remediation actions with owners & due dates.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-8">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total audits</div>
          <div className="mt-1 text-lg font-semibold">{totalAudits}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg score</div>
          <div className={`mt-1 text-lg ${scoreColor(avgScore)}`}>{avgScore}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Compliant</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{compliantCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Partial</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{partialCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Non-compliant</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{nonCompliantCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open actions</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{openActions}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Done actions</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{doneActions}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total cost (Rs)</div>
          <div className="mt-1 text-lg font-semibold">{totalCost}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Compliance summary by standard type</h2>
        <p className="text-xs text-gray-500">
          Rolled-up scores across signage, uniform, materials, equipment_decals & website_link. Sorted by weakest avg
          score first (avg &lt; 50 = red, 50–79 = amber, &gt;= 80 = green).
        </p>
        <DataTable
          rows={summary}
          columns={summaryColumns}
          rowKey={(r: any, i: number) => String(r.standard_type ?? i)}
          emptyMessage="No audits logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top non-compliant hospitals</h2>
        <p className="text-xs text-gray-500">
          Worst-scoring hospitals across all standard types. These need on-site brand-team intervention first.
        </p>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
          emptyMessage="No hospitals audited yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All standard audits</h2>
        <p className="text-xs text-gray-500">
          Every per-hospital, per-standard-type audit record. Use audit_standard_r1763 to log a new audit or update
          score & status.
        </p>
        <DataTable
          rows={standards}
          columns={standardColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No standard audits yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Remediation actions</h2>
        <p className="text-xs text-gray-500">
          Open actions sorted first, then done & cancelled. Each action has an owner email, due date & cost in
          rupees. Mark done via complete_action_r1763.
        </p>
        <DataTable
          rows={actions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No remediation actions logged yet."
        />
      </section>
    </div>
  );
}
