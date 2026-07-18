import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Engineer customer relationship investment ledger — r2654" };
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
  if (n === null || n === undefined) return "₹0";
  return "₹" + Number(n).toLocaleString("en-IN");
}

function statusColor(status: string): string {
  if (status === "done") return "text-emerald-700";
  if (status === "planned" || status === "open") return "text-amber-700";
  if (status === "cancelled" || status === "dropped") return "text-gray-500";
  return "";
}

export default async function FounderEngineerCustomerRelationshipInvestmentLedgerPage() {
  const sb = await getSupabaseServerClient();

  const [investmentsRes, outcomesRes, topFocusRes, kindRes, funnelRes, trendRes, summaryRes] = await Promise.all([
    sb.rpc("list_investments_r2654"),
    sb.rpc("list_outcomes_r2654"),
    sb.rpc("top_value_focus_r2654"),
    sb.rpc("kind_distribution_r2654"),
    sb.rpc("status_funnel_r2654"),
    sb.rpc("monthly_investment_trend_r2654"),
    sb.rpc("total_realized_summary_r2654"),
  ]);

  const investments: any[] = investmentsRes.data ?? [];
  const outcomes: any[] = outcomesRes.data ?? [];
  const topFocus: any[] = topFocusRes.data ?? [];
  const kinds: any[] = kindRes.data ?? [];
  const funnel: any[] = funnelRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const summary: any = (summaryRes.data ?? [])[0] ?? null;

  const investmentCols: Column<any>[] = [
    { key: "invested_at", header: "Invested", render: (r: any) => fmtDate(r.invested_at) },
    { key: "investment_kind", header: "Kind", render: (r: any) => <span className="font-mono text-xs">{r.investment_kind}</span> },
    { key: "value_rupees", header: "Value", render: (r: any) => fmtRupees(r.value_rupees) },
    { key: "hours_invested", header: "Hours", render: (r: any) => String(r.hours_invested ?? 0) },
    { key: "expected_return_kind", header: "Expected return", render: (r: any) => r.expected_return_kind },
    { key: "status", header: "Status", render: (r: any) => <span className={statusColor(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const outcomeCols: Column<any>[] = [
    { key: "observed_at", header: "Observed", render: (r: any) => fmtDate(r.observed_at) },
    { key: "outcome_kind", header: "Outcome", render: (r: any) => <span className="font-mono text-xs">{r.outcome_kind}</span> },
    { key: "revenue_realized_rupees", header: "Revenue", render: (r: any) => fmtRupees(r.revenue_realized_rupees) },
    { key: "status", header: "Status", render: (r: any) => <span className={statusColor(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const focusCols: Column<any>[] = [
    { key: "hospital_user_id", header: "Hospital", render: (r: any) => <span className="font-mono text-xs">{String(r.hospital_user_id).slice(0, 8)}</span> },
    { key: "investment_count", header: "# Invest", render: (r: any) => String(r.investment_count) },
    { key: "total_value_rupees", header: "Total ₹", render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: "total_hours", header: "Hours", render: (r: any) => String(r.total_hours ?? 0) },
    { key: "total_realized_rupees", header: "Realized", render: (r: any) => fmtRupees(r.total_realized_rupees) },
  ];

  const kindCols: Column<any>[] = [
    { key: "investment_kind", header: "Kind", render: (r: any) => <span className="font-mono text-xs">{r.investment_kind}</span> },
    { key: "investment_count", header: "Count", render: (r: any) => String(r.investment_count) },
    { key: "total_value_rupees", header: "Value", render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: "total_hours", header: "Hours", render: (r: any) => String(r.total_hours ?? 0) },
  ];

  const funnelCols: Column<any>[] = [
    { key: "status", header: "Status", render: (r: any) => <span className={statusColor(r.status)}>{r.status}</span> },
    { key: "investment_count", header: "Count", render: (r: any) => String(r.investment_count) },
    { key: "total_value_rupees", header: "Value", render: (r: any) => fmtRupees(r.total_value_rupees) },
  ];

  const trendCols: Column<any>[] = [
    { key: "month_start", header: "Month", render: (r: any) => fmtDate(r.month_start) },
    { key: "investment_count", header: "Count", render: (r: any) => String(r.investment_count) },
    { key: "total_value_rupees", header: "Value", render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: "total_hours", header: "Hours", render: (r: any) => String(r.total_hours ?? 0) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Engineer customer relationship investment ledger</h1>
        <p className="text-sm text-gray-600">r2654 — Track time, money & favors invested in hospital relationships and the realized ARR uplift &gt; outcomes flow.</p>
      </header>

      {summary && (
        <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Investments</div>
            <div className="text-lg font-bold">{String(summary.total_investments ?? 0)}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Total ₹ invested</div>
            <div className="text-lg font-bold">{fmtRupees(summary.total_value_rupees)}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Total hours</div>
            <div className="text-lg font-bold">{String(summary.total_hours ?? 0)}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Outcomes</div>
            <div className="text-lg font-bold">{String(summary.total_outcomes ?? 0)}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">Realized ₹</div>
            <div className="text-lg font-bold text-emerald-700">{fmtRupees(summary.total_realized_rupees)}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-gray-500">ROI multiple</div>
            <div className="text-lg font-bold">{String(summary.roi_multiple ?? 0)}x</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Investment ledger</h2>
        <DataTable
          rows={investments}
          columns={investmentCols}
          emptyMessage="No investments logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Observed outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No outcomes observed yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top value focus (per hospital)</h2>
        <DataTable
          rows={topFocus}
          columns={focusCols}
          emptyMessage="No hospital focus data."
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Kind distribution</h2>
        <DataTable
          rows={kinds}
          columns={kindCols}
          emptyMessage="No kind data."
          rowKey={(r: any, i: number) => String(r.investment_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly investment trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>
    </main>
  );
}
