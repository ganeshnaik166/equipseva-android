import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";
import Link from "next/link";

export const metadata = {
  title: "Monthly Cash Ledger — Founder Console",
  description: "Monthly cash transaction log + reconciliation diff against snapshots.",
};

export const dynamic = "force-dynamic";

type SummaryRow = {
  total_snapshots_recorded: number;
  snapshots_last_12m: number;
  last_snapshot_at: string | null;
  last_snapshot_balance_rupees: number | null;
  first_snapshot_at: string | null;
  first_snapshot_balance_rupees: number | null;
  net_cash_change_lifetime_rupees: number | null;
  avg_monthly_change_rupees: number | null;
  biggest_inflow_month: string | null;
  biggest_inflow_amount_rupees: number | null;
  biggest_outflow_month: string | null;
  biggest_outflow_amount_rupees: number | null;
  months_with_negative_cash_change: number;
  generated_at: string;
};

type HistoryRow = {
  month_start: string;
  snapshot_balance_rupees: number | null;
  inflow_captured_rupees: number | null;
  outflow_payouts_rupees: number | null;
  outflow_spares_rupees: number | null;
  net_change_rupees: number | null;
  reconciliation_diff_rupees: number | null;
};

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "₹" + formatNumber(Math.round(Number(n)));
}

function diffClass(diff: number | null): string {
  if (diff === null || diff === undefined) return "text-gray-400";
  const abs = Math.abs(Number(diff));
  if (abs > 100000) return "text-red-700 font-semibold";
  if (abs > 25000) return "text-amber-600 font-medium";
  return "text-emerald-700";
}

function diffBadge(diff: number | null): string {
  if (diff === null || diff === undefined) return "n/a";
  const abs = Math.abs(Number(diff));
  if (abs > 100000) return "DANGER";
  if (abs > 25000) return "WARN";
  return "OK";
}

export default async function FounderMonthlyCashLedgerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: summaryData }, { data: historyData }] = await Promise.all([
    supabase.rpc("founder_monthly_cash_ledger_summary"),
    supabase.rpc("founder_monthly_cash_ledger_history", { p_months: 12 }),
  ]);

  const s: SummaryRow | null = Array.isArray(summaryData) ? summaryData[0] : null;
  const history: HistoryRow[] = Array.isArray(historyData) ? historyData : [];

  const cards = [
    { label: "Total snapshots recorded", value: s ? formatNumber(s.total_snapshots_recorded) : "—" },
    { label: "Snapshots last 12m", value: s ? formatNumber(s.snapshots_last_12m) : "—" },
    { label: "Last snapshot at", value: s?.last_snapshot_at ?? "—" },
    { label: "Last snapshot balance", value: rupees(s?.last_snapshot_balance_rupees) },
    { label: "First snapshot at", value: s?.first_snapshot_at ?? "—" },
    { label: "First snapshot balance", value: rupees(s?.first_snapshot_balance_rupees) },
    { label: "Net cash change (lifetime)", value: rupees(s?.net_cash_change_lifetime_rupees) },
    { label: "Avg monthly change", value: rupees(s?.avg_monthly_change_rupees) },
    { label: "Biggest inflow month", value: s?.biggest_inflow_month ?? "—" },
    { label: "Biggest inflow amount", value: rupees(s?.biggest_inflow_amount_rupees) },
    { label: "Biggest outflow month", value: s?.biggest_outflow_month ?? "—" },
    { label: "Biggest outflow amount", value: rupees(s?.biggest_outflow_amount_rupees) },
    { label: "Months with negative net", value: s ? formatNumber(s.months_with_negative_cash_change) : "—" },
    { label: "Generated at", value: s ? new Date(s.generated_at).toLocaleString("en-IN") : "—" },
  ];

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="mx-auto max-w-7xl">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <Link href="/ops-index" className="text-sm text-blue-600 hover:underline">
              {"←"} Ops Index
            </Link>
            <h1 className="mt-2 text-3xl font-bold text-gray-900">Monthly Cash Ledger</h1>
            <p className="mt-1 text-sm text-gray-600">
              Reconciliation of recorded cash snapshots vs computed net change from payments · payouts · spares.
            </p>
          </div>
          <span className="rounded bg-indigo-100 px-3 py-1 text-xs font-semibold text-indigo-800">r1379</span>
        </div>

        <div className="mb-8 grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7">
          {cards.map((c) => (
            <div key={c.label} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
              <div className="text-xs font-medium uppercase tracking-wide text-gray-500">{c.label}</div>
              <div className="mt-2 text-lg font-semibold text-gray-900">{c.value}</div>
            </div>
          ))}
        </div>

        <div className="rounded-lg border border-gray-200 bg-white shadow-sm">
          <div className="border-b border-gray-200 px-6 py-4">
            <h2 className="text-lg font-semibold text-gray-900">12-month history · reconciliation diff</h2>
            <p className="mt-1 text-xs text-gray-500">
              Reconciliation diff = (snapshot balance change) {"−"} (captured inflow {"−"} payouts {"−"} spares).
              Threshold: {">"} ₹1,00,000 marks danger · {">"} ₹25,000 marks warn.
            </p>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-left text-xs uppercase text-gray-600">
                <tr>
                  <th className="px-4 py-3">Month</th>
                  <th className="px-4 py-3 text-right">Snapshot balance</th>
                  <th className="px-4 py-3 text-right">Inflow (captured)</th>
                  <th className="px-4 py-3 text-right">Outflow · payouts</th>
                  <th className="px-4 py-3 text-right">Outflow · spares</th>
                  <th className="px-4 py-3 text-right">Net change</th>
                  <th className="px-4 py-3 text-right">Recon diff</th>
                  <th className="px-4 py-3 text-center">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {history.length === 0 && (
                  <tr>
                    <td colSpan={8} className="px-4 py-12 text-center text-sm text-gray-500">
                      No data yet. Cash snapshots will surface here once founder_cash_position_snapshots accumulates rows.
                    </td>
                  </tr>
                )}
                {history.map((row) => (
                  <tr key={row.month_start} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium text-gray-900">{row.month_start}</td>
                    <td className="px-4 py-3 text-right text-gray-700">{rupees(row.snapshot_balance_rupees)}</td>
                    <td className="px-4 py-3 text-right text-emerald-700">{rupees(row.inflow_captured_rupees)}</td>
                    <td className="px-4 py-3 text-right text-red-700">{rupees(row.outflow_payouts_rupees)}</td>
                    <td className="px-4 py-3 text-right text-red-700">{rupees(row.outflow_spares_rupees)}</td>
                    <td className="px-4 py-3 text-right font-medium text-gray-900">{rupees(row.net_change_rupees)}</td>
                    <td className={"px-4 py-3 text-right " + diffClass(row.reconciliation_diff_rupees)}>
                      {row.reconciliation_diff_rupees === null ? "—" : rupees(row.reconciliation_diff_rupees)}
                    </td>
                    <td className="px-4 py-3 text-center">
                      <span className={"rounded px-2 py-0.5 text-xs font-semibold " +
                        (diffBadge(row.reconciliation_diff_rupees) === "DANGER"
                          ? "bg-red-100 text-red-800"
                          : diffBadge(row.reconciliation_diff_rupees) === "WARN"
                          ? "bg-amber-100 text-amber-800"
                          : diffBadge(row.reconciliation_diff_rupees) === "OK"
                          ? "bg-emerald-100 text-emerald-800"
                          : "bg-gray-100 text-gray-600")}>
                        {diffBadge(row.reconciliation_diff_rupees)}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="mt-6 rounded-lg border border-blue-100 bg-blue-50 p-4 text-xs text-blue-900">
          <strong>How to read:</strong> if recon diff stays near zero, recorded snapshots match the ops cash flow model.
          A large positive diff = snapshot grew faster than payments captured (untracked inflow · refunds reversed · manual deposit).
          A large negative diff = snapshot dropped faster than payouts {"+"} spares (untracked outflow · tax · founder draw · refund).
        </div>
      </div>
    </div>
  );
}
