import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer payment-mode profitability — r2376" };
export const dynamic = "force-dynamic";

type CollectionRow = {
  id: string;
  collected_at: string;
  customer_name: string;
  invoice_ref: string | null;
  payment_mode: string;
  gross_amount_rupees: number;
  total_collection_cost_rupees: number;
  net_received_rupees: number;
  net_margin_pct: number;
  settlement_lag_hours: number;
  status: string;
  recorded_by_email: string;
};

type SummaryRow = {
  total_txn_count: number;
  total_gross_rupees: number;
  total_collection_cost_rupees: number;
  total_net_received_rupees: number;
  overall_net_margin_pct: number;
  settled_count: number;
  disputed_count: number;
  refunded_count: number;
  chargeback_count: number;
};

type ByModeRow = {
  payment_mode: string;
  txn_count: number;
  total_gross_rupees: number;
  total_collection_cost_rupees: number;
  total_net_received_rupees: number;
  avg_net_margin_pct: number;
  avg_settlement_lag_hours: number;
  failure_rate_pct: number;
};

type TopCustomerRow = {
  customer_name: string;
  txn_count: number;
  total_gross_rupees: number;
  total_collection_cost_rupees: number;
  effective_margin_pct: number;
  dominant_mode: string | null;
};

type MonthlyRow = {
  month_start: string;
  payment_mode: string;
  txn_count: number;
  total_gross_rupees: number;
  total_collection_cost_rupees: number;
  net_margin_pct: number;
};

type OverrideRow = {
  id: string;
  payment_mode: string;
  effective_from: string;
  effective_to: string | null;
  baseline_mdr_pct: number;
  baseline_flat_fee_rupees: number;
  baseline_reconciliation_cost_rupees: number;
  baseline_chargeback_reserve_pct: number;
  set_by_email: string;
  notes: string | null;
};

type RecommendationRow = {
  payment_mode: string;
  total_gross_rupees: number;
  effective_margin_pct: number;
  avg_settlement_lag_hours: number;
  failure_rate_pct: number;
  recommendation: string;
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
  return "₹" + Number(n).toLocaleString("en-IN", { maximumFractionDigits: 2 });
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return "—";
  return Number(n).toFixed(2) + "%";
}

function recommendationBadge(r: string): string {
  if (r === "promote") return "text-emerald-700 font-medium";
  if (r === "discourage") return "text-rose-700 font-medium";
  if (r === "investigate") return "text-amber-700 font-medium";
  if (r === "review_settlement") return "text-orange-700 font-medium";
  return "text-gray-600";
}

function statusBadge(s: string): string {
  if (s === "settled") return "text-emerald-700";
  if (s === "pending") return "text-amber-700";
  if (s === "disputed") return "text-orange-700";
  if (s === "refunded") return "text-gray-500";
  if (s === "chargeback") return "text-rose-700";
  if (s === "failed") return "text-rose-700";
  return "";
}

export default async function FounderCustomerPaymentModeProfitabilityPage() {
  const sb = await getSupabaseServerClient();
  const [collectionsRes, summaryRes, byModeRes, topCustRes, monthlyRes, overridesRes, recoRes] = await Promise.all([
    sb.rpc("r2376_list_collections"),
    sb.rpc("r2376_summary"),
    sb.rpc("r2376_by_mode"),
    sb.rpc("r2376_top_customers_by_mode_cost"),
    sb.rpc("r2376_monthly_trend"),
    sb.rpc("r2376_cost_overrides_active"),
    sb.rpc("r2376_mode_recommendations"),
  ]);

  if (collectionsRes.error) throw new Error(`r2376_list_collections: ${collectionsRes.error.message}`);
  if (summaryRes.error) throw new Error(`r2376_summary: ${summaryRes.error.message}`);
  if (byModeRes.error) throw new Error(`r2376_by_mode: ${byModeRes.error.message}`);
  if (topCustRes.error) throw new Error(`r2376_top_customers_by_mode_cost: ${topCustRes.error.message}`);
  if (monthlyRes.error) throw new Error(`r2376_monthly_trend: ${monthlyRes.error.message}`);
  if (overridesRes.error) throw new Error(`r2376_cost_overrides_active: ${overridesRes.error.message}`);
  if (recoRes.error) throw new Error(`r2376_mode_recommendations: ${recoRes.error.message}`);

  const collections = (collectionsRes.data ?? []) as CollectionRow[];
  const summary = ((summaryRes.data ?? [])[0] ?? null) as SummaryRow | null;
  const byMode = (byModeRes.data ?? []) as ByModeRow[];
  const topCustomers = (topCustRes.data ?? []) as TopCustomerRow[];
  const monthly = (monthlyRes.data ?? []) as MonthlyRow[];
  const overrides = (overridesRes.data ?? []) as OverrideRow[];
  const recommendations = (recoRes.data ?? []) as RecommendationRow[];

  const collectionColumns: Column<CollectionRow>[] = [
    { key: "collected_at", header: "Collected", render: (r: any) => fmtDate(r.collected_at) },
    { key: "customer_name", header: "Customer", render: (r: any) => <span className="font-medium">{r.customer_name}</span> },
    { key: "invoice_ref", header: "Invoice", render: (r: any) => r.invoice_ref ?? "—" },
    { key: "payment_mode", header: "Mode", render: (r: any) => <span className="uppercase">{r.payment_mode}</span> },
    { key: "gross_amount_rupees", header: "Gross", render: (r: any) => fmtRupees(r.gross_amount_rupees) },
    { key: "total_collection_cost_rupees", header: "Cost", render: (r: any) => fmtRupees(r.total_collection_cost_rupees) },
    { key: "net_received_rupees", header: "Net", render: (r: any) => fmtRupees(r.net_received_rupees) },
    { key: "net_margin_pct", header: "Margin", render: (r: any) => fmtPct(r.net_margin_pct) },
    { key: "settlement_lag_hours", header: "Settle lag (h)", render: (r: any) => String(r.settlement_lag_hours ?? 0) },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
  ];

  const byModeColumns: Column<ByModeRow>[] = [
    { key: "payment_mode", header: "Mode", render: (r: any) => <span className="font-medium uppercase">{r.payment_mode}</span> },
    { key: "txn_count", header: "Txns", render: (r: any) => String(r.txn_count) },
    { key: "total_gross_rupees", header: "Gross", render: (r: any) => fmtRupees(r.total_gross_rupees) },
    { key: "total_collection_cost_rupees", header: "Collection cost", render: (r: any) => fmtRupees(r.total_collection_cost_rupees) },
    { key: "total_net_received_rupees", header: "Net received", render: (r: any) => fmtRupees(r.total_net_received_rupees) },
    { key: "avg_net_margin_pct", header: "Margin %", render: (r: any) => fmtPct(r.avg_net_margin_pct) },
    { key: "avg_settlement_lag_hours", header: "Avg lag (h)", render: (r: any) => Number(r.avg_settlement_lag_hours ?? 0).toFixed(1) },
    { key: "failure_rate_pct", header: "Fail %", render: (r: any) => fmtPct(r.failure_rate_pct) },
  ];

  const topCustColumns: Column<TopCustomerRow>[] = [
    { key: "customer_name", header: "Customer", render: (r: any) => <span className="font-medium">{r.customer_name}</span> },
    { key: "txn_count", header: "Txns", render: (r: any) => String(r.txn_count) },
    { key: "total_gross_rupees", header: "Gross", render: (r: any) => fmtRupees(r.total_gross_rupees) },
    { key: "total_collection_cost_rupees", header: "Collection cost", render: (r: any) => fmtRupees(r.total_collection_cost_rupees) },
    { key: "effective_margin_pct", header: "Margin %", render: (r: any) => fmtPct(r.effective_margin_pct) },
    { key: "dominant_mode", header: "Dominant mode", render: (r: any) => <span className="uppercase">{r.dominant_mode ?? "—"}</span> },
  ];

  const monthlyColumns: Column<MonthlyRow>[] = [
    { key: "month_start", header: "Month", render: (r: any) => fmtDate(r.month_start) },
    { key: "payment_mode", header: "Mode", render: (r: any) => <span className="uppercase">{r.payment_mode}</span> },
    { key: "txn_count", header: "Txns", render: (r: any) => String(r.txn_count) },
    { key: "total_gross_rupees", header: "Gross", render: (r: any) => fmtRupees(r.total_gross_rupees) },
    { key: "total_collection_cost_rupees", header: "Cost", render: (r: any) => fmtRupees(r.total_collection_cost_rupees) },
    { key: "net_margin_pct", header: "Margin %", render: (r: any) => fmtPct(r.net_margin_pct) },
  ];

  const overrideColumns: Column<OverrideRow>[] = [
    { key: "payment_mode", header: "Mode", render: (r: any) => <span className="font-medium uppercase">{r.payment_mode}</span> },
    { key: "effective_from", header: "From", render: (r: any) => fmtDate(r.effective_from) },
    { key: "effective_to", header: "To", render: (r: any) => fmtDate(r.effective_to) },
    { key: "baseline_mdr_pct", header: "MDR %", render: (r: any) => fmtPct(r.baseline_mdr_pct) },
    { key: "baseline_flat_fee_rupees", header: "Flat fee", render: (r: any) => fmtRupees(r.baseline_flat_fee_rupees) },
    { key: "baseline_reconciliation_cost_rupees", header: "Recon cost", render: (r: any) => fmtRupees(r.baseline_reconciliation_cost_rupees) },
    { key: "baseline_chargeback_reserve_pct", header: "CB reserve %", render: (r: any) => fmtPct(r.baseline_chargeback_reserve_pct) },
    { key: "set_by_email", header: "Set by", render: (r: any) => r.set_by_email },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const recoColumns: Column<RecommendationRow>[] = [
    { key: "payment_mode", header: "Mode", render: (r: any) => <span className="font-medium uppercase">{r.payment_mode}</span> },
    { key: "total_gross_rupees", header: "Gross", render: (r: any) => fmtRupees(r.total_gross_rupees) },
    { key: "effective_margin_pct", header: "Margin %", render: (r: any) => fmtPct(r.effective_margin_pct) },
    { key: "avg_settlement_lag_hours", header: "Avg lag (h)", render: (r: any) => Number(r.avg_settlement_lag_hours ?? 0).toFixed(1) },
    { key: "failure_rate_pct", header: "Fail %", render: (r: any) => fmtPct(r.failure_rate_pct) },
    { key: "recommendation", header: "Action", render: (r: any) => <span className={recommendationBadge(r.recommendation)}>{r.recommendation}</span> },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder customer payment-mode profitability — r2376</h1>
        <p className="mt-1 text-xs text-gray-500">
          Net margin per collection channel. UPI vs NEFT vs card vs cash — true cost-to-collect after MDR, flat fees,
          GST on fees, reconciliation overhead & chargeback reserve. Promote high-margin modes, discourage leaky ones.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-5">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total txns</div>
          <div className="mt-1 text-lg font-semibold">{summary?.total_txn_count ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Gross collected</div>
          <div className="mt-1 text-lg font-semibold">{fmtRupees(summary?.total_gross_rupees ?? 0)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Collection cost</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{fmtRupees(summary?.total_collection_cost_rupees ?? 0)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Net received</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{fmtRupees(summary?.total_net_received_rupees ?? 0)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Net margin</div>
          <div className="mt-1 text-lg font-semibold">{fmtPct(summary?.overall_net_margin_pct ?? 0)}</div>
        </div>
      </section>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Settled</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{summary?.settled_count ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Disputed</div>
          <div className="mt-1 text-lg font-semibold text-orange-700">{summary?.disputed_count ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Refunded</div>
          <div className="mt-1 text-lg font-semibold text-gray-600">{summary?.refunded_count ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Chargebacks</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{summary?.chargeback_count ?? 0}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">By payment mode</h2>
        <p className="text-xs text-gray-500">
          Channel-level cost-to-collect &amp; effective margin. Lower fail rate + faster settlement =&gt; healthier channel.
        </p>
        <DataTable
          rows={byMode}
          columns={byModeColumns}
          rowKey={(r: any, i: number) => String(r.payment_mode ?? i)}
          emptyMessage="No payment data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Mode recommendations</h2>
        <p className="text-xs text-gray-500">
          Auto-action per channel: promote (margin &gt;= 98.5% &amp; lag &lt;= 24h), discourage (margin &lt;= 95%),
          investigate (fail &gt;= 5%), review settlement (lag &gt; 72h).
        </p>
        <DataTable
          rows={recommendations}
          columns={recoColumns}
          rowKey={(r: any, i: number) => String(r.payment_mode ?? i)}
          emptyMessage="No mode data to recommend on."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top customers by collection cost</h2>
        <p className="text-xs text-gray-500">
          Customers whose mode mix drags margin down. Pitch them on UPI/NEFT instead of card/cheque to claw back margin.
        </p>
        <DataTable
          rows={topCustomers}
          columns={topCustColumns}
          rowKey={(r: any, i: number) => String(r.customer_name ?? i)}
          emptyMessage="No customer payments yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Monthly trend by mode</h2>
        <p className="text-xs text-gray-500">
          12-month rolling. Watch margin drift per channel — MDR hikes & chargeback waves show up here first.
        </p>
        <DataTable
          rows={monthly}
          columns={monthlyColumns}
          rowKey={(r: any, i: number) => `${r.month_start}-${r.payment_mode}-${i}`}
          emptyMessage="No monthly data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Active cost overrides</h2>
        <p className="text-xs text-gray-500">
          Baseline MDR & fee assumptions per channel. Adjust when payment gateway renegotiates rates.
        </p>
        <DataTable
          rows={overrides}
          columns={overrideColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No active cost overrides."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Recent collections</h2>
        <p className="text-xs text-gray-500">
          Last 200 collection events with mode-level cost & net margin. Drill in to spot anomalies.
        </p>
        <DataTable
          rows={collections}
          columns={collectionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No collections recorded yet."
        />
      </section>
    </div>
  );
}
