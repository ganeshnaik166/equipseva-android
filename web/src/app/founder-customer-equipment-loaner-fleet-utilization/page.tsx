import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Customer equipment loaner fleet utilization — r2528" };
export const dynamic = "force-dynamic";

type DeploymentRow = {
  id: string;
  loaner_unit_label: string;
  equipment_kind: string;
  hospital_user_id: string | null;
  deployed_at: string | null;
  returned_at: string | null;
  days_deployed: number;
  utilization_pct: number;
  idle_days: number;
  status: string;
  revenue_substituted_rupees: number;
  owner_email: string;
  notes: string | null;
};

type QueueRow = {
  id: string;
  equipment_kind: string;
  hospital_user_id: string | null;
  requested_at: string;
  expected_deploy_at: string | null;
  status: string;
  priority: string;
  owner_email: string;
  notes: string | null;
};

type TopUtilizedRow = {
  loaner_unit_label: string;
  equipment_kind: string;
  utilization_pct: number;
  days_deployed: number;
  revenue_substituted_rupees: number;
};

type KindSummaryRow = {
  equipment_kind: string;
  unit_count: number;
  avg_utilization: number;
  total_idle_days: number;
  total_revenue_substituted: number;
};

type TrendRow = {
  month_start: string;
  deployments_count: number;
  avg_utilization: number;
  total_revenue_substituted: number;
};

type IdleRow = {
  id: string;
  loaner_unit_label: string;
  equipment_kind: string;
  idle_days: number;
  status: string;
  utilization_pct: number;
  notes: string | null;
};

type PriorityRow = {
  priority: string;
  queue_count: number;
  queued_count: number;
  assigned_count: number;
  fulfilled_count: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtRupees(n: number): string {
  if (!n) return "₹0";
  return "₹" + n.toLocaleString("en-IN");
}

function fmtPct(n: number): string {
  return `${Number(n ?? 0).toFixed(2)}%`;
}

function statusBadge(status: string): string {
  if (status === "deployed") return "text-emerald-700";
  if (status === "returned") return "text-blue-700";
  if (status === "in_repair") return "text-amber-700";
  if (status === "lost") return "text-red-700";
  if (status === "pending") return "text-gray-600";
  return "";
}

function priorityBadge(p: string): string {
  if (p === "critical") return "text-red-700";
  if (p === "high") return "text-amber-700";
  if (p === "medium") return "text-blue-700";
  return "text-gray-600";
}

export default async function FounderCustomerEquipmentLoanerFleetUtilizationPage() {
  const sb = await getSupabaseServerClient();
  const [
    deploymentsRes,
    queueRes,
    topUtilizedRes,
    kindSummaryRes,
    trendRes,
    idleRes,
    priorityRes,
  ] = await Promise.all([
    sb.rpc("list_deployments_r2528"),
    sb.rpc("list_wait_queue_r2528"),
    sb.rpc("top_utilized_loaners_r2528"),
    sb.rpc("equipment_kind_summary_r2528"),
    sb.rpc("monthly_utilization_trend_r2528"),
    sb.rpc("idle_loaners_focus_r2528"),
    sb.rpc("queue_priority_distribution_r2528"),
  ]);

  if (deploymentsRes.error) throw new Error(`list_deployments_r2528: ${deploymentsRes.error.message}`);
  if (queueRes.error) throw new Error(`list_wait_queue_r2528: ${queueRes.error.message}`);
  if (topUtilizedRes.error) throw new Error(`top_utilized_loaners_r2528: ${topUtilizedRes.error.message}`);
  if (kindSummaryRes.error) throw new Error(`equipment_kind_summary_r2528: ${kindSummaryRes.error.message}`);
  if (trendRes.error) throw new Error(`monthly_utilization_trend_r2528: ${trendRes.error.message}`);
  if (idleRes.error) throw new Error(`idle_loaners_focus_r2528: ${idleRes.error.message}`);
  if (priorityRes.error) throw new Error(`queue_priority_distribution_r2528: ${priorityRes.error.message}`);

  const deployments = (deploymentsRes.data ?? []) as DeploymentRow[];
  const queue = (queueRes.data ?? []) as QueueRow[];
  const topUtilized = (topUtilizedRes.data ?? []) as TopUtilizedRow[];
  const kindSummary = (kindSummaryRes.data ?? []) as KindSummaryRow[];
  const trend = (trendRes.data ?? []) as TrendRow[];
  const idle = (idleRes.data ?? []) as IdleRow[];
  const priority = (priorityRes.data ?? []) as PriorityRow[];

  const totalUnits = deployments.length;
  const deployedNow = deployments.filter((d) => d.status === "deployed").length;
  const totalRevenueSubstituted = deployments.reduce((s, d) => s + (d.revenue_substituted_rupees ?? 0), 0);
  const avgUtil =
    deployments.length === 0
      ? 0
      : deployments.reduce((s, d) => s + Number(d.utilization_pct ?? 0), 0) / deployments.length;
  const queueOpen = queue.filter((q) => q.status === "queued" || q.status === "assigned").length;

  const deploymentCols: Column<any>[] = [
    { key: "loaner_unit_label", header: "Unit", render: (r: any) => r.loaner_unit_label },
    { key: "equipment_kind", header: "Kind", render: (r: any) => r.equipment_kind },
    { key: "deployed_at", header: "Deployed", render: (r: any) => fmtDate(r.deployed_at) },
    { key: "returned_at", header: "Returned", render: (r: any) => fmtDate(r.returned_at) },
    { key: "days_deployed", header: "Days", render: (r: any) => r.days_deployed },
    { key: "utilization_pct", header: "Util%", render: (r: any) => fmtPct(r.utilization_pct) },
    { key: "idle_days", header: "Idle days", render: (r: any) => r.idle_days },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span>,
    },
    {
      key: "revenue_substituted_rupees",
      header: "Revenue sub",
      render: (r: any) => fmtRupees(r.revenue_substituted_rupees),
    },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const queueCols: Column<any>[] = [
    { key: "equipment_kind", header: "Kind", render: (r: any) => r.equipment_kind },
    { key: "requested_at", header: "Requested", render: (r: any) => fmtDate(r.requested_at) },
    { key: "expected_deploy_at", header: "Expected", render: (r: any) => fmtDate(r.expected_deploy_at) },
    {
      key: "priority",
      header: "Priority",
      render: (r: any) => <span className={priorityBadge(r.priority)}>{r.priority}</span>,
    },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span>,
    },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const topUtilizedCols: Column<any>[] = [
    { key: "loaner_unit_label", header: "Unit", render: (r: any) => r.loaner_unit_label },
    { key: "equipment_kind", header: "Kind", render: (r: any) => r.equipment_kind },
    { key: "utilization_pct", header: "Util%", render: (r: any) => fmtPct(r.utilization_pct) },
    { key: "days_deployed", header: "Days deployed", render: (r: any) => r.days_deployed },
    {
      key: "revenue_substituted_rupees",
      header: "Revenue sub",
      render: (r: any) => fmtRupees(r.revenue_substituted_rupees),
    },
  ];

  const kindSummaryCols: Column<any>[] = [
    { key: "equipment_kind", header: "Kind", render: (r: any) => r.equipment_kind },
    { key: "unit_count", header: "Units", render: (r: any) => r.unit_count },
    { key: "avg_utilization", header: "Avg util%", render: (r: any) => fmtPct(r.avg_utilization) },
    { key: "total_idle_days", header: "Idle days", render: (r: any) => r.total_idle_days },
    {
      key: "total_revenue_substituted",
      header: "Revenue sub",
      render: (r: any) => fmtRupees(r.total_revenue_substituted),
    },
  ];

  const trendCols: Column<any>[] = [
    { key: "month_start", header: "Month", render: (r: any) => fmtDate(r.month_start) },
    { key: "deployments_count", header: "Deployments", render: (r: any) => r.deployments_count },
    { key: "avg_utilization", header: "Avg util%", render: (r: any) => fmtPct(r.avg_utilization) },
    {
      key: "total_revenue_substituted",
      header: "Revenue sub",
      render: (r: any) => fmtRupees(r.total_revenue_substituted),
    },
  ];

  const idleCols: Column<any>[] = [
    { key: "loaner_unit_label", header: "Unit", render: (r: any) => r.loaner_unit_label },
    { key: "equipment_kind", header: "Kind", render: (r: any) => r.equipment_kind },
    { key: "idle_days", header: "Idle days", render: (r: any) => r.idle_days },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span>,
    },
    { key: "utilization_pct", header: "Util%", render: (r: any) => fmtPct(r.utilization_pct) },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const priorityCols: Column<any>[] = [
    {
      key: "priority",
      header: "Priority",
      render: (r: any) => <span className={priorityBadge(r.priority)}>{r.priority}</span>,
    },
    { key: "queue_count", header: "Total", render: (r: any) => r.queue_count },
    { key: "queued_count", header: "Queued", render: (r: any) => r.queued_count },
    { key: "assigned_count", header: "Assigned", render: (r: any) => r.assigned_count },
    { key: "fulfilled_count", header: "Fulfilled", render: (r: any) => r.fulfilled_count },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Customer equipment loaner fleet utilization</h1>
        <p className="text-sm text-gray-600 mt-1">
          Round r2528 — loaner unit × hospital × deployed days × utilization × wait queue
          × idle.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Loaner units</div>
          <div className="text-2xl font-semibold">{totalUnits}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Deployed now</div>
          <div className="text-2xl font-semibold">{deployedNow}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Avg utilization</div>
          <div className="text-2xl font-semibold">{fmtPct(avgUtil)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Revenue substituted</div>
          <div className="text-2xl font-semibold">{fmtRupees(totalRevenueSubstituted)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs text-gray-500">Queue open</div>
          <div className="text-2xl font-semibold">{queueOpen}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Loaner deployments</h2>
        <DataTable
          rows={deployments}
          columns={deploymentCols}
          emptyMessage="No loaner deployments."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Wait queue</h2>
        <DataTable
          rows={queue}
          columns={queueCols}
          emptyMessage="Queue empty."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top utilized loaners</h2>
        <DataTable
          rows={topUtilized}
          columns={topUtilizedCols}
          emptyMessage="No utilization data."
          rowKey={(r: any, i: number) => String(r.loaner_unit_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Equipment kind summary</h2>
        <DataTable
          rows={kindSummary}
          columns={kindSummaryCols}
          emptyMessage="No kinds."
          rowKey={(r: any, i: number) => String(r.equipment_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Monthly utilization trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Idle loaners focus</h2>
        <DataTable
          rows={idle}
          columns={idleCols}
          emptyMessage="No idle loaners > threshold."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Queue priority distribution</h2>
        <DataTable
          rows={priority}
          columns={priorityCols}
          emptyMessage="No queue priority rows."
          rowKey={(r: any, i: number) => String(r.priority ?? i)}
        />
      </section>
    </main>
  );
}
