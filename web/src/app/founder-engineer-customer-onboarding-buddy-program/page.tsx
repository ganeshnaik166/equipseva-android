import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Engineer customer onboarding buddy program — r2662" };
export const dynamic = "force-dynamic";

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return "₹0";
  return "₹" + Number(n).toLocaleString("en-IN");
}

function statusBadge(status: string): string {
  if (status === "active" || status === "open") return "text-amber-700";
  if (status === "completed" || status === "done") return "text-emerald-700";
  if (status === "cancelled" || status === "dropped") return "text-gray-500";
  return "";
}

function signalBadge(sig: string): string {
  if (sig === "positive") return "text-emerald-700";
  if (sig === "negative") return "text-rose-700";
  return "text-gray-600";
}

export default async function FounderEngineerCustomerOnboardingBuddyProgramPage() {
  const sb = await getSupabaseServerClient();
  const [buddiesRes, outcomesRes, topPairingsRes, knowledgeRes, funnelRes, trendRes, ownerLoadRes] = await Promise.all([
    sb.rpc("list_buddies_r2662"),
    sb.rpc("list_outcomes_r2662"),
    sb.rpc("top_pairing_focus_r2662"),
    sb.rpc("knowledge_kind_distribution_r2662"),
    sb.rpc("status_funnel_r2662"),
    sb.rpc("monthly_buddy_trend_r2662"),
    sb.rpc("owner_load_r2662"),
  ]);

  if (buddiesRes.error) throw new Error(`list_buddies_r2662: ${buddiesRes.error.message}`);
  if (outcomesRes.error) throw new Error(`list_outcomes_r2662: ${outcomesRes.error.message}`);
  if (topPairingsRes.error) throw new Error(`top_pairing_focus_r2662: ${topPairingsRes.error.message}`);
  if (knowledgeRes.error) throw new Error(`knowledge_kind_distribution_r2662: ${knowledgeRes.error.message}`);
  if (funnelRes.error) throw new Error(`status_funnel_r2662: ${funnelRes.error.message}`);
  if (trendRes.error) throw new Error(`monthly_buddy_trend_r2662: ${trendRes.error.message}`);
  if (ownerLoadRes.error) throw new Error(`owner_load_r2662: ${ownerLoadRes.error.message}`);

  const buddies = (buddiesRes.data ?? []) as any[];
  const outcomes = (outcomesRes.data ?? []) as any[];
  const topPairings = (topPairingsRes.data ?? []) as any[];
  const knowledge = (knowledgeRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];

  const totalPairings = buddies.length;
  const activeCount = buddies.filter((b: any) => b.status === "active").length;
  const completedCount = buddies.filter((b: any) => b.status === "completed").length;
  const cancelledCount = buddies.filter((b: any) => b.status === "cancelled").length;
  const positiveSignals = buddies.filter((b: any) => b.retention_signal === "positive").length;
  const totalRevenueImpact = outcomes.reduce((s: number, o: any) => s + Number(o.revenue_impact_rupees ?? 0), 0);

  const buddyColumns: Column<any>[] = [
    { key: "paired_at", header: "Paired", render: (r: any) => fmtDate(r.paired_at) },
    { key: "knowledge_transfer_kind", header: "Knowledge", render: (r: any) => r.knowledge_transfer_kind },
    { key: "days_paired", header: "Days", render: (r: any) => String(r.days_paired) },
    { key: "retention_signal", header: "Signal", render: (r: any) => <span className={signalBadge(r.retention_signal)}>{r.retention_signal}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const outcomeColumns: Column<any>[] = [
    { key: "observed_at", header: "Observed", render: (r: any) => fmtDate(r.observed_at) },
    { key: "outcome_kind", header: "Outcome", render: (r: any) => r.outcome_kind },
    { key: "revenue_impact_rupees", header: "Revenue impact", render: (r: any) => fmtRupees(r.revenue_impact_rupees) },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const topPairingColumns: Column<any>[] = [
    { key: "knowledge_transfer_kind", header: "Knowledge", render: (r: any) => r.knowledge_transfer_kind },
    { key: "retention_signal", header: "Signal", render: (r: any) => <span className={signalBadge(r.retention_signal)}>{r.retention_signal}</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "days_paired", header: "Days paired", render: (r: any) => String(r.days_paired) },
    { key: "outcome_count", header: "Outcomes", render: (r: any) => String(r.outcome_count) },
    { key: "total_revenue_impact", header: "Revenue impact", render: (r: any) => fmtRupees(r.total_revenue_impact) },
  ];

  const knowledgeColumns: Column<any>[] = [
    { key: "knowledge_transfer_kind", header: "Knowledge kind", render: (r: any) => r.knowledge_transfer_kind },
    { key: "pairing_count", header: "Pairings", render: (r: any) => String(r.pairing_count) },
    { key: "positive_signal_count", header: "Positive", render: (r: any) => <span className="text-emerald-700">{String(r.positive_signal_count)}</span> },
    { key: "negative_signal_count", header: "Negative", render: (r: any) => <span className="text-rose-700">{String(r.negative_signal_count)}</span> },
  ];

  const funnelColumns: Column<any>[] = [
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "pairing_count", header: "Pairings", render: (r: any) => String(r.pairing_count) },
    { key: "avg_days_paired", header: "Avg days", render: (r: any) => String(r.avg_days_paired ?? 0) },
  ];

  const trendColumns: Column<any>[] = [
    { key: "month_start", header: "Month", render: (r: any) => fmtDate(r.month_start) },
    { key: "pairing_count", header: "Pairings", render: (r: any) => String(r.pairing_count) },
    { key: "completed_count", header: "Completed", render: (r: any) => <span className="text-emerald-700">{String(r.completed_count)}</span> },
    { key: "cancelled_count", header: "Cancelled", render: (r: any) => <span className="text-gray-500">{String(r.cancelled_count)}</span> },
  ];

  const ownerLoadColumns: Column<any>[] = [
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email },
    { key: "open_pairings", header: "Active pairings", render: (r: any) => String(r.open_pairings) },
    { key: "open_outcomes", header: "Open outcomes", render: (r: any) => String(r.open_outcomes) },
    { key: "total_revenue_impact", header: "Revenue impact", render: (r: any) => fmtRupees(r.total_revenue_impact) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Engineer customer onboarding buddy program — r2662</h1>
        <p className="mt-1 text-xs text-gray-500">
          Pair new engineers with veteran buddies. Track ramp speed, retention signal & revenue impact so the
          buddy program earns its keep.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total pairings</div>
          <div className="mt-1 text-lg font-semibold">{totalPairings}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Active</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{activeCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Completed</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{completedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Cancelled</div>
          <div className="mt-1 text-lg font-semibold text-gray-500">{cancelledCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Positive signal</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{positiveSignals}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Revenue impact</div>
          <div className="mt-1 text-lg font-semibold">{fmtRupees(totalRevenueImpact)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All pairings</h2>
        <p className="text-xs text-gray-500">
          New engineer paired with a buddy. Days paired >= 14 with positive signal => ramp on track.
        </p>
        <DataTable
          rows={buddies}
          columns={buddyColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No pairings yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Outcomes log</h2>
        <p className="text-xs text-gray-500">
          Outcome observed per pairing. Revenue impact > 0 => buddy program paying back.
        </p>
        <DataTable
          rows={outcomes}
          columns={outcomeColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No outcomes logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top pairings by revenue impact</h2>
        <p className="text-xs text-gray-500">Ranked by total revenue impact & outcome count.</p>
        <DataTable
          rows={topPairings}
          columns={topPairingColumns}
          rowKey={(r: any, i: number) => String(r.pairing_id ?? i)}
          emptyMessage="No ranked pairings yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Knowledge transfer mix</h2>
        <p className="text-xs text-gray-500">Distribution by knowledge kind & retention signal.</p>
        <DataTable
          rows={knowledge}
          columns={knowledgeColumns}
          rowKey={(r: any, i: number) => String(r.knowledge_transfer_kind ?? i)}
          emptyMessage="No knowledge mix data."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Status funnel</h2>
        <p className="text-xs text-gray-500">Pairings by status with average days paired.</p>
        <DataTable
          rows={funnel}
          columns={funnelColumns}
          rowKey={(r: any, i: number) => String(r.status ?? i)}
          emptyMessage="No funnel data."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Monthly trend</h2>
        <p className="text-xs text-gray-500">Pairings created per month & completion/cancellation counts.</p>
        <DataTable
          rows={trend}
          columns={trendColumns}
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
          emptyMessage="No monthly trend yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Owner workload</h2>
        <p className="text-xs text-gray-500">Open work per owner email. Balance load & chase high-impact pairings.</p>
        <DataTable
          rows={ownerLoad}
          columns={ownerLoadColumns}
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
          emptyMessage="No owner load yet."
        />
      </section>
    </div>
  );
}
