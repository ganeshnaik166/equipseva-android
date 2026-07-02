import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Hospital chain billing dispute resolution — r2439" };
export const dynamic = "force-dynamic";

type DisputeRow = {
  id: string;
  chain_name: string;
  hospital_user_id: string | null;
  dispute_external_ref: string | null;
  raised_at: string;
  dispute_kind: string;
  disputed_amount_rupees: number;
  refund_amount_rupees: number;
  root_cause_kind: string | null;
  resolution_status: string;
  resolved_at: string | null;
  days_to_resolve: number | null;
  owner_email: string | null;
  notes: string | null;
  created_at: string;
};

type KillRow = {
  id: string;
  period_start: string;
  period_end: string;
  root_cause_kind: string;
  dispute_count: number;
  total_refund_rupees: number;
  kill_status: string;
  kill_action_md: string | null;
  kill_owner_email: string | null;
  kill_due_at: string | null;
  kill_closed_at: string | null;
  notes: string | null;
};

type TopChainRow = {
  chain_name: string;
  dispute_count: number;
  total_disputed_rupees: number;
  total_refunded_rupees: number;
  open_count: number;
  escalated_count: number;
  avg_days_to_resolve: number | null;
};

type RootCauseRow = {
  root_cause_kind: string;
  dispute_count: number;
  total_disputed_rupees: number;
  total_refunded_rupees: number;
  kill_planned: number;
  kill_in_progress: number;
  kill_done: number;
};

type MonthlyRow = {
  month_start: string;
  dispute_count: number;
  total_disputed_rupees: number;
  total_refunded_rupees: number;
  refund_ratio: number;
};

type VelocityRow = {
  resolution_status: string;
  dispute_count: number;
  avg_days_to_resolve: number | null;
  median_days_to_resolve: number | null;
  max_days_to_resolve: number | null;
};

type FocusRow = {
  id: string;
  chain_name: string;
  dispute_kind: string;
  disputed_amount_rupees: number;
  raised_at: string;
  days_open: number;
  resolution_status: string;
  owner_email: string | null;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return "—";
  return "₹" + Number(n).toLocaleString("en-IN");
}

function statusTone(s: string): string {
  if (s === "refunded" || s === "agreed") return "text-emerald-700";
  if (s === "escalated") return "text-rose-700";
  if (s === "investigating") return "text-amber-700";
  if (s === "dropped") return "text-gray-500";
  return "text-sky-700";
}

function killTone(s: string): string {
  if (s === "done") return "text-emerald-700";
  if (s === "in_progress") return "text-amber-700";
  if (s === "dropped") return "text-gray-500";
  return "text-sky-700";
}

export default async function FounderHospitalChainBillingDisputeResolutionPage() {
  const sb = await getSupabaseServerClient();
  const [disputesRes, killsRes, topChainsRes, rootCauseRes, monthlyRes, velocityRes, focusRes] = await Promise.all([
    sb.rpc("list_disputes_r2439"),
    sb.rpc("list_root_cause_kills_r2439"),
    sb.rpc("top_dispute_chains_r2439"),
    sb.rpc("root_cause_breakdown_r2439"),
    sb.rpc("monthly_refund_trend_r2439"),
    sb.rpc("resolution_velocity_r2439"),
    sb.rpc("open_critical_focus_r2439"),
  ]);

  if (disputesRes.error) throw new Error(`list_disputes_r2439: ${disputesRes.error.message}`);
  if (killsRes.error) throw new Error(`list_root_cause_kills_r2439: ${killsRes.error.message}`);
  if (topChainsRes.error) throw new Error(`top_dispute_chains_r2439: ${topChainsRes.error.message}`);
  if (rootCauseRes.error) throw new Error(`root_cause_breakdown_r2439: ${rootCauseRes.error.message}`);
  if (monthlyRes.error) throw new Error(`monthly_refund_trend_r2439: ${monthlyRes.error.message}`);
  if (velocityRes.error) throw new Error(`resolution_velocity_r2439: ${velocityRes.error.message}`);
  if (focusRes.error) throw new Error(`open_critical_focus_r2439: ${focusRes.error.message}`);

  const disputes = (disputesRes.data ?? []) as DisputeRow[];
  const kills = (killsRes.data ?? []) as KillRow[];
  const topChains = (topChainsRes.data ?? []) as TopChainRow[];
  const rootCauses = (rootCauseRes.data ?? []) as RootCauseRow[];
  const monthly = (monthlyRes.data ?? []) as MonthlyRow[];
  const velocity = (velocityRes.data ?? []) as VelocityRow[];
  const focus = (focusRes.data ?? []) as FocusRow[];

  const totalDisputed = disputes.reduce((s, d) => s + (d.disputed_amount_rupees ?? 0), 0);
  const totalRefunded = disputes.reduce((s, d) => s + (d.refund_amount_rupees ?? 0), 0);
  const openCount = disputes.filter((d) => d.resolution_status === "open" || d.resolution_status === "investigating").length;
  const escalatedCount = disputes.filter((d) => d.resolution_status === "escalated").length;
  const refundedCount = disputes.filter((d) => d.resolution_status === "refunded").length;
  const killsOpen = kills.filter((k) => k.kill_status === "planned" || k.kill_status === "in_progress").length;

  const disputeCols: Column<DisputeRow>[] = [
    { key: "chain_name", header: "Chain", render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: "dispute_kind", header: "Kind", render: (r: any) => r.dispute_kind },
    { key: "disputed_amount_rupees", header: "Disputed", render: (r: any) => fmtRupees(r.disputed_amount_rupees) },
    { key: "refund_amount_rupees", header: "Refunded", render: (r: any) => fmtRupees(r.refund_amount_rupees) },
    { key: "root_cause_kind", header: "Root cause", render: (r: any) => r.root_cause_kind ?? "—" },
    { key: "resolution_status", header: "Status", render: (r: any) => <span className={statusTone(r.resolution_status)}>{r.resolution_status}</span> },
    { key: "days_to_resolve", header: "Days", render: (r: any) => (r.days_to_resolve != null ? String(r.days_to_resolve) : "—") },
    { key: "raised_at", header: "Raised", render: (r: any) => fmtDate(r.raised_at) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "dispute_external_ref", header: "Ref", render: (r: any) => r.dispute_external_ref ?? "—" },
  ];

  const killCols: Column<KillRow>[] = [
    { key: "root_cause_kind", header: "Root cause", render: (r: any) => <span className="font-medium">{r.root_cause_kind}</span> },
    { key: "kill_status", header: "Kill status", render: (r: any) => <span className={killTone(r.kill_status)}>{r.kill_status}</span> },
    { key: "dispute_count", header: "Disputes", render: (r: any) => String(r.dispute_count) },
    { key: "total_refund_rupees", header: "Refunds", render: (r: any) => fmtRupees(r.total_refund_rupees) },
    { key: "period_start", header: "From", render: (r: any) => fmtDate(r.period_start) },
    { key: "period_end", header: "To", render: (r: any) => fmtDate(r.period_end) },
    { key: "kill_owner_email", header: "Owner", render: (r: any) => r.kill_owner_email ?? "—" },
    { key: "kill_due_at", header: "Due", render: (r: any) => fmtDate(r.kill_due_at) },
    { key: "kill_closed_at", header: "Closed", render: (r: any) => fmtDate(r.kill_closed_at) },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const topChainCols: Column<TopChainRow>[] = [
    { key: "chain_name", header: "Chain", render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: "dispute_count", header: "Disputes", render: (r: any) => String(r.dispute_count) },
    { key: "total_disputed_rupees", header: "Disputed", render: (r: any) => fmtRupees(r.total_disputed_rupees) },
    { key: "total_refunded_rupees", header: "Refunded", render: (r: any) => fmtRupees(r.total_refunded_rupees) },
    { key: "open_count", header: "Open", render: (r: any) => String(r.open_count) },
    { key: "escalated_count", header: "Escalated", render: (r: any) => String(r.escalated_count) },
    { key: "avg_days_to_resolve", header: "Avg days", render: (r: any) => (r.avg_days_to_resolve != null ? String(r.avg_days_to_resolve) : "—") },
  ];

  const rootCauseCols: Column<RootCauseRow>[] = [
    { key: "root_cause_kind", header: "Root cause", render: (r: any) => <span className="font-medium">{r.root_cause_kind}</span> },
    { key: "dispute_count", header: "Disputes", render: (r: any) => String(r.dispute_count) },
    { key: "total_disputed_rupees", header: "Disputed", render: (r: any) => fmtRupees(r.total_disputed_rupees) },
    { key: "total_refunded_rupees", header: "Refunded", render: (r: any) => fmtRupees(r.total_refunded_rupees) },
    { key: "kill_planned", header: "Kill planned", render: (r: any) => String(r.kill_planned) },
    { key: "kill_in_progress", header: "Kill in-progress", render: (r: any) => String(r.kill_in_progress) },
    { key: "kill_done", header: "Kill done", render: (r: any) => String(r.kill_done) },
  ];

  const monthlyCols: Column<MonthlyRow>[] = [
    { key: "month_start", header: "Month", render: (r: any) => fmtDate(r.month_start) },
    { key: "dispute_count", header: "Disputes", render: (r: any) => String(r.dispute_count) },
    { key: "total_disputed_rupees", header: "Disputed", render: (r: any) => fmtRupees(r.total_disputed_rupees) },
    { key: "total_refunded_rupees", header: "Refunded", render: (r: any) => fmtRupees(r.total_refunded_rupees) },
    { key: "refund_ratio", header: "Refund %", render: (r: any) => (r.refund_ratio != null ? String(r.refund_ratio) + "%" : "—") },
  ];

  const velocityCols: Column<VelocityRow>[] = [
    { key: "resolution_status", header: "Status", render: (r: any) => <span className={statusTone(r.resolution_status)}>{r.resolution_status}</span> },
    { key: "dispute_count", header: "Disputes", render: (r: any) => String(r.dispute_count) },
    { key: "avg_days_to_resolve", header: "Avg days", render: (r: any) => (r.avg_days_to_resolve != null ? String(r.avg_days_to_resolve) : "—") },
    { key: "median_days_to_resolve", header: "Median days", render: (r: any) => (r.median_days_to_resolve != null ? String(r.median_days_to_resolve) : "—") },
    { key: "max_days_to_resolve", header: "Max days", render: (r: any) => (r.max_days_to_resolve != null ? String(r.max_days_to_resolve) : "—") },
  ];

  const focusCols: Column<FocusRow>[] = [
    { key: "chain_name", header: "Chain", render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: "dispute_kind", header: "Kind", render: (r: any) => r.dispute_kind },
    { key: "disputed_amount_rupees", header: "At stake", render: (r: any) => fmtRupees(r.disputed_amount_rupees) },
    { key: "days_open", header: "Days open", render: (r: any) => String(r.days_open) },
    { key: "resolution_status", header: "Status", render: (r: any) => <span className={statusTone(r.resolution_status)}>{r.resolution_status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "raised_at", header: "Raised", render: (r: any) => fmtDate(r.raised_at) },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">Hospital chain billing dispute resolution</h1>
        <p className="mt-1 text-sm text-gray-600">
          Round r2439 — dispute × kind × amount × root cause × resolution × refund × root-cause kill.
        </p>
      </header>

      <section className="mb-8 grid grid-cols-2 gap-4 md:grid-cols-6">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Disputes</div>
          <div className="mt-1 text-2xl font-semibold">{disputes.length}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Disputed</div>
          <div className="mt-1 text-2xl font-semibold">{fmtRupees(totalDisputed)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Refunded</div>
          <div className="mt-1 text-2xl font-semibold">{fmtRupees(totalRefunded)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Open / investigating</div>
          <div className="mt-1 text-2xl font-semibold">{openCount}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Escalated</div>
          <div className="mt-1 text-2xl font-semibold text-rose-700">{escalatedCount}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Kills active</div>
          <div className="mt-1 text-2xl font-semibold">{killsOpen}</div>
        </div>
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Open critical focus</h2>
        <p className="mb-2 text-sm text-gray-600">
          Disputes that are open, investigating, or escalated — sorted by amount at stake.
        </p>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No open disputes."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Top dispute chains</h2>
        <DataTable
          rows={topChains}
          columns={topChainCols}
          emptyMessage="No chain disputes yet."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Root cause breakdown</h2>
        <p className="mb-2 text-sm text-gray-600">
          Refunded counts paired with how many kills are planned / in-progress / done for each root cause.
        </p>
        <DataTable
          rows={rootCauses}
          columns={rootCauseCols}
          emptyMessage="No root-cause data."
          rowKey={(r: any, i: number) => String(r.root_cause_kind ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Monthly refund trend</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No monthly trend."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Resolution velocity</h2>
        <DataTable
          rows={velocity}
          columns={velocityCols}
          emptyMessage="No resolution data."
          rowKey={(r: any, i: number) => String(r.resolution_status ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">Root-cause kill program</h2>
        <p className="mb-2 text-sm text-gray-600">
          Each kill targets a root cause to prevent the same dispute class from repeating.
        </p>
        <DataTable
          rows={kills}
          columns={killCols}
          emptyMessage="No kill items."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-lg font-semibold">All disputes</h2>
        <DataTable
          rows={disputes}
          columns={disputeCols}
          emptyMessage="No disputes recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer className="mt-12 text-xs text-gray-500">
        <p>
          Refunded {refundedCount} of {disputes.length} disputes total. Source: chain_billing_disputes_r2439 & billing_dispute_root_cause_kills_r2439.
        </p>
      </footer>
    </main>
  );
}
