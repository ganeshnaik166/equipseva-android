import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";
import Link from "next/link";

export const metadata = {
  title: "Revenue Leakage Tracker — Founder Console",
  description: "Refunds + SLA credits + escrow refunds aggregated · leakage % of GMV.",
};

export const dynamic = "force-dynamic";

type SummaryRow = {
  total_refunds_lifetime_rupees: number | null;
  refunds_30d_rupees: number | null;
  refunds_90d_rupees: number | null;
  total_sla_credits_lifetime_rupees: number | null;
  sla_credits_30d_rupees: number | null;
  escrow_refunds_lifetime_rupees: number | null;
  escrow_refunds_30d_rupees: number | null;
  total_leakage_lifetime_rupees: number | null;
  total_leakage_30d_rupees: number | null;
  leakage_pct_of_gmv_30d: number | null;
  biggest_single_refund_rupees: number | null;
  biggest_sla_credit_rupees: number | null;
  count_of_credit_events_30d: number;
  generated_at: string;
};

type HistoryRow = {
  month_start: string;
  refunds_rupees: number | null;
  sla_credits_rupees: number | null;
  escrow_refunds_rupees: number | null;
  total_leakage_rupees: number | null;
  gmv_captured_rupees: number | null;
  leakage_pct_of_gmv: number | null;
};

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "₹" + formatNumber(Math.round(Number(n)));
}

function pct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(2) + "%";
}

function pctClass(p: number | null | undefined): string {
  if (p === null || p === undefined) return "text-gray-400";
  const v = Number(p);
  if (v >= 5) return "text-red-700 font-semibold";
  if (v >= 2) return "text-amber-600 font-medium";
  return "text-emerald-700";
}

function pctBadge(p: number | null | undefined): string {
  if (p === null || p === undefined) return "n/a";
  const v = Number(p);
  if (v >= 5) return "DANGER";
  if (v >= 2) return "WARN";
  return "OK";
}

export default async function FounderRevenueLeakageTrackerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: summaryData }, { data: historyData }] = await Promise.all([
    supabase.rpc("founder_revenue_leakage_summary"),
    supabase.rpc("founder_revenue_leakage_history", { p_months: 12 }),
  ]);

  const s: SummaryRow | null = Array.isArray(summaryData) ? summaryData[0] : null;
  const history: HistoryRow[] = Array.isArray(historyData) ? historyData : [];

  const cards = [
    { label: "Refunds · lifetime", value: rupees(s?.total_refunds_lifetime_rupees), tone: "red" },
    { label: "Refunds · 30d", value: rupees(s?.refunds_30d_rupees), tone: "red" },
    { label: "Refunds · 90d", value: rupees(s?.refunds_90d_rupees), tone: "red" },
    { label: "SLA credits · lifetime", value: rupees(s?.total_sla_credits_lifetime_rupees), tone: "amber" },
    { label: "SLA credits · 30d", value: rupees(s?.sla_credits_30d_rupees), tone: "amber" },
    { label: "Escrow refunds · lifetime", value: rupees(s?.escrow_refunds_lifetime_rupees), tone: "red" },
    { label: "Escrow refunds · 30d", value: rupees(s?.escrow_refunds_30d_rupees), tone: "red" },
    { label: "Total leakage · lifetime", value: rupees(s?.total_leakage_lifetime_rupees), tone: "indigo" },
    { label: "Total leakage · 30d", value: rupees(s?.total_leakage_30d_rupees), tone: "indigo" },
    { label: "Leakage · % of GMV 30d", value: pct(s?.leakage_pct_of_gmv_30d), tone: "indigo" },
    { label: "Biggest single refund", value: rupees(s?.biggest_single_refund_rupees), tone: "gray" },
    { label: "Biggest SLA credit", value: rupees(s?.biggest_sla_credit_rupees), tone: "gray" },
    { label: "Credit events · 30d (count)", value: s ? formatNumber(s.count_of_credit_events_30d) : "—", tone: "gray" },
    { label: "Generated at", value: s ? new Date(s.generated_at).toLocaleString("en-IN") : "—", tone: "gray" },
  ];

  const toneClass = (tone: string): string => {
    if (tone === "red") return "border-red-200 bg-red-50";
    if (tone === "amber") return "border-amber-200 bg-amber-50";
    if (tone === "indigo") return "border-indigo-200 bg-indigo-50";
    return "border-gray-200 bg-white";
  };

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="mx-auto max-w-7xl">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <Link href="/ops-index" className="text-sm text-blue-600 hover:underline">
              {"←"} Ops Index
            </Link>
            <h1 className="mt-2 text-3xl font-bold text-gray-900">Revenue Leakage Tracker</h1>
            <p className="mt-1 text-sm text-gray-600">
              Refunds {"+"} SLA credits {"+"} escrow refunds aggregated · leakage as a share of GMV.
              Healthy target: leakage {"<"} 2% of GMV.
            </p>
          </div>
          <span className="rounded bg-indigo-100 px-3 py-1 text-xs font-semibold text-indigo-800">r1383</span>
        </div>

        <div className="mb-8 grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7">
          {cards.map((c) => (
            <div key={c.label} className={"rounded-lg border p-4 shadow-sm " + toneClass(c.tone)}>
              <div className="text-xs font-medium uppercase tracking-wide text-gray-500">{c.label}</div>
              <div className="mt-2 text-lg font-semibold text-gray-900">{c.value}</div>
            </div>
          ))}
        </div>

        <div className="mb-6 grid grid-cols-1 gap-4 md:grid-cols-3">
          <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-4">
            <div className="text-xs font-semibold uppercase tracking-wide text-emerald-700">OK</div>
            <div className="mt-1 text-sm text-emerald-900">Leakage {"<"} 2% of GMV · within target.</div>
          </div>
          <div className="rounded-lg border border-amber-200 bg-amber-50 p-4">
            <div className="text-xs font-semibold uppercase tracking-wide text-amber-700">WARN</div>
            <div className="mt-1 text-sm text-amber-900">Leakage 2–5% of GMV · investigate root cause.</div>
          </div>
          <div className="rounded-lg border border-red-200 bg-red-50 p-4">
            <div className="text-xs font-semibold uppercase tracking-wide text-red-700">DANGER</div>
            <div className="mt-1 text-sm text-red-900">Leakage {"≥"} 5% of GMV · burning unit economics.</div>
          </div>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white shadow-sm">
          <div className="border-b border-gray-200 px-6 py-4">
            <h2 className="text-lg font-semibold text-gray-900">12-month history · per-month leakage</h2>
            <p className="mt-1 text-xs text-gray-500">
              Per-month sum of refunds (payments status=refunded) {"+"} SLA credits (amc_sla_breaches.credit_issued_rupees)
              {" + "} escrow refunds (repair_job_escrow status=refunded). Ratio vs captured GMV that month.
            </p>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-left text-xs uppercase text-gray-600">
                <tr>
                  <th className="px-4 py-3">Month</th>
                  <th className="px-4 py-3 text-right">Refunds</th>
                  <th className="px-4 py-3 text-right">SLA credits</th>
                  <th className="px-4 py-3 text-right">Escrow refunds</th>
                  <th className="px-4 py-3 text-right">Total leakage</th>
                  <th className="px-4 py-3 text-right">GMV captured</th>
                  <th className="px-4 py-3 text-right">Leakage % GMV</th>
                  <th className="px-4 py-3 text-center">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {history.length === 0 && (
                  <tr>
                    <td colSpan={8} className="px-4 py-12 text-center text-sm text-gray-500">
                      No data yet. Leakage events surface once refunds, SLA breaches, or escrow refunds accumulate.
                    </td>
                  </tr>
                )}
                {history.map((row) => (
                  <tr key={row.month_start} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium text-gray-900">{row.month_start}</td>
                    <td className="px-4 py-3 text-right text-red-700">{rupees(row.refunds_rupees)}</td>
                    <td className="px-4 py-3 text-right text-amber-700">{rupees(row.sla_credits_rupees)}</td>
                    <td className="px-4 py-3 text-right text-red-700">{rupees(row.escrow_refunds_rupees)}</td>
                    <td className="px-4 py-3 text-right font-semibold text-gray-900">{rupees(row.total_leakage_rupees)}</td>
                    <td className="px-4 py-3 text-right text-emerald-700">{rupees(row.gmv_captured_rupees)}</td>
                    <td className={"px-4 py-3 text-right " + pctClass(row.leakage_pct_of_gmv)}>{pct(row.leakage_pct_of_gmv)}</td>
                    <td className="px-4 py-3 text-center">
                      <span className={"rounded px-2 py-0.5 text-xs font-semibold " +
                        (pctBadge(row.leakage_pct_of_gmv) === "DANGER"
                          ? "bg-red-100 text-red-800"
                          : pctBadge(row.leakage_pct_of_gmv) === "WARN"
                          ? "bg-amber-100 text-amber-800"
                          : pctBadge(row.leakage_pct_of_gmv) === "OK"
                          ? "bg-emerald-100 text-emerald-800"
                          : "bg-gray-100 text-gray-600")}>
                        {pctBadge(row.leakage_pct_of_gmv)}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="mt-6 rounded-lg border border-blue-100 bg-blue-50 p-4 text-xs text-blue-900">
          <strong>How to read:</strong> Revenue leakage = money that came in then went back out the door
          before it could compound. Three buckets are tracked here · (1) payment refunds (cashfree/razorpay
          status=refunded) · (2) AMC SLA breach credits issued (amc_sla_breaches.credit_issued_rupees) ·
          (3) escrow refunds (repair_job_escrow status=refunded — hospital paid, engineer never delivered).
          <br /><br />
          <strong>Targets:</strong> Sustained {"<"} 2% of GMV is healthy SaaS+marketplace territory.
          2–5% means a leak somewhere — usually a single category dominates (e.g., one supplier shipping
          counterfeit parts or one engineer cluster missing SLAs). Above 5% means the unit economics
          are net-negative and the cause must be found this week.
          <br /><br />
          <strong>Drill-down:</strong> When a month spikes, cross-reference /refunds (raw refund authorizations),
          /amc-sla-breaches-recent (per-contract SLA hits), and /escrow-snapshot-summary (escrow refund pipeline).
        </div>
      </div>
    </div>
  );
}
