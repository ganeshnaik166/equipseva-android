import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type SummaryRow = {
  snapshots_total: number;
  engineers_covered: number;
  snapshots_30d: number;
  snapshots_90d: number;
  top_engineer_net_profit_rupees: number;
  avg_net_profit_rupees: number;
  avg_net_margin_pct: number;
  total_lifetime_revenue_rupees: number;
  total_lifetime_payouts_rupees: number;
  total_lifetime_parts_rupees: number;
  total_lifetime_travel_rupees: number;
  total_lifetime_kit_amort_rupees: number;
  total_lifetime_training_rupees: number;
  total_lifetime_net_profit_rupees: number;
};

type SnapshotRow = {
  snapshot_id: string;
  engineer_user_id: string;
  period_label: string;
  period_start: string | null;
  period_end: string | null;
  gross_revenue_attributed_rupees: number;
  payouts_received_rupees: number;
  parts_consumed_rupees: number;
  travel_expense_rupees: number;
  equipment_kit_amortization_rupees: number;
  training_cost_rupees: number;
  net_engineer_profit_rupees: number;
  gross_margin_pct: number | null;
  generated_at: string;
  created_at: string;
};

type TopPerformerRow = {
  engineer_user_id: string;
  snapshots_count: number;
  total_revenue_rupees: number;
  total_payouts_rupees: number;
  total_net_profit_rupees: number;
  avg_margin_pct: number;
  last_snapshot_at: string;
};

function shortId(id: string): string {
  return id ? id.slice(0, 8) : "—";
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, recentRes, topRes] = await Promise.all([
    supabase.rpc("founder_engineer_personal_pnl_summary"),
    supabase.rpc("founder_engineer_personal_pnl_recent", { p_limit: 50 }),
    supabase.rpc("founder_engineer_personal_pnl_top_performers", { p_limit: 20 }),
  ]);

  const s: SummaryRow = (summaryRes.data?.[0] as SummaryRow) ?? {
    snapshots_total: 0, engineers_covered: 0, snapshots_30d: 0, snapshots_90d: 0,
    top_engineer_net_profit_rupees: 0, avg_net_profit_rupees: 0, avg_net_margin_pct: 0,
    total_lifetime_revenue_rupees: 0, total_lifetime_payouts_rupees: 0,
    total_lifetime_parts_rupees: 0, total_lifetime_travel_rupees: 0,
    total_lifetime_kit_amort_rupees: 0, total_lifetime_training_rupees: 0,
    total_lifetime_net_profit_rupees: 0,
  };
  const snapshots: SnapshotRow[] = (recentRes.data as SnapshotRow[]) ?? [];
  const top: TopPerformerRow[] = (topRes.data as TopPerformerRow[]) ?? [];

  const cards = [
    { label: "Snapshots total", value: formatNumber(s.snapshots_total) },
    { label: "Engineers covered", value: formatNumber(s.engineers_covered) },
    { label: "Snapshots (30d)", value: formatNumber(s.snapshots_30d) },
    { label: "Snapshots (90d)", value: formatNumber(s.snapshots_90d) },
    { label: "Top engineer net profit", value: `₹${formatNumber(s.top_engineer_net_profit_rupees)}` },
    { label: "Avg net profit", value: `₹${formatNumber(s.avg_net_profit_rupees)}` },
    { label: "Avg net margin %", value: `${s.avg_net_margin_pct}%` },
    { label: "Lifetime revenue", value: `₹${formatNumber(s.total_lifetime_revenue_rupees)}` },
    { label: "Lifetime payouts", value: `₹${formatNumber(s.total_lifetime_payouts_rupees)}` },
    { label: "Lifetime parts cost", value: `₹${formatNumber(s.total_lifetime_parts_rupees)}` },
    { label: "Lifetime travel", value: `₹${formatNumber(s.total_lifetime_travel_rupees)}` },
    { label: "Lifetime kit amort.", value: `₹${formatNumber(s.total_lifetime_kit_amort_rupees)}` },
    { label: "Lifetime training", value: `₹${formatNumber(s.total_lifetime_training_rupees)}` },
    { label: "Lifetime net profit", value: `₹${formatNumber(s.total_lifetime_net_profit_rupees)}` },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Personal P&L</h1>
        <p className="text-sm text-gray-600 mt-1">
          Per-engineer profit-and-loss snapshots — revenue attributed {"<"} payouts {"<"} cost stack {"<"} net profit per period.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">KPI summary (14)</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {cards.map((c) => (
            <div key={c.label} className="rounded-lg border border-gray-200 bg-white p-4">
              <div className="text-xs uppercase tracking-wide text-gray-500">{c.label}</div>
              <div className="mt-1 text-xl font-semibold tabular-nums">{c.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top performers (by lifetime net profit)</h2>
        <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-gray-600">
              <tr>
                <th className="px-3 py-2 text-left">Engineer</th>
                <th className="px-3 py-2 text-right">Snapshots</th>
                <th className="px-3 py-2 text-right">Revenue ₹</th>
                <th className="px-3 py-2 text-right">Payouts ₹</th>
                <th className="px-3 py-2 text-right">Net profit ₹</th>
                <th className="px-3 py-2 text-right">Avg margin %</th>
                <th className="px-3 py-2 text-left">Last snapshot</th>
              </tr>
            </thead>
            <tbody>
              {top.length === 0 ? (
                <tr><td colSpan={7} className="px-3 py-4 text-gray-500 text-center">No top performers yet.</td></tr>
              ) : top.map((t) => (
                <tr key={t.engineer_user_id} className="border-t border-gray-100">
                  <td className="px-3 py-2 font-mono text-xs">{shortId(t.engineer_user_id)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(t.snapshots_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(t.total_revenue_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(t.total_payouts_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums font-semibold">{formatNumber(t.total_net_profit_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{t.avg_margin_pct}%</td>
                  <td className="px-3 py-2 text-gray-500">{new Date(t.last_snapshot_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent snapshots — per-engineer ledger</h2>
        <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-gray-600">
              <tr>
                <th className="px-3 py-2 text-left">Engineer</th>
                <th className="px-3 py-2 text-left">Period</th>
                <th className="px-3 py-2 text-left">Window</th>
                <th className="px-3 py-2 text-right">Rev ₹</th>
                <th className="px-3 py-2 text-right">Payouts ₹</th>
                <th className="px-3 py-2 text-right">Parts ₹</th>
                <th className="px-3 py-2 text-right">Travel ₹</th>
                <th className="px-3 py-2 text-right">Kit ₹</th>
                <th className="px-3 py-2 text-right">Training ₹</th>
                <th className="px-3 py-2 text-right">Net ₹</th>
                <th className="px-3 py-2 text-right">Margin %</th>
                <th className="px-3 py-2 text-left">Generated</th>
              </tr>
            </thead>
            <tbody>
              {snapshots.length === 0 ? (
                <tr><td colSpan={12} className="px-3 py-4 text-gray-500 text-center">No snapshots yet. Use log_founder_engineer_pnl_record_snapshot or bulk_compute_period to seed.</td></tr>
              ) : snapshots.map((r) => (
                <tr key={r.snapshot_id} className="border-t border-gray-100">
                  <td className="px-3 py-2 font-mono text-xs">{shortId(r.engineer_user_id)}</td>
                  <td className="px-3 py-2 font-medium">{r.period_label}</td>
                  <td className="px-3 py-2 text-gray-500 text-xs">
                    {r.period_start ?? "—"} {"→"} {r.period_end ?? "—"}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.gross_revenue_attributed_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.payouts_received_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.parts_consumed_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.travel_expense_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.equipment_kit_amortization_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.training_cost_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums font-semibold">{formatNumber(r.net_engineer_profit_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{r.gross_margin_pct ?? "—"}</td>
                  <td className="px-3 py-2 text-gray-500 text-xs">{new Date(r.generated_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
