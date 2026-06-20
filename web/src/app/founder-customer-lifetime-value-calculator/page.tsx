import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type SummaryRow = {
  total_snapshots: number | null;
  unique_hospitals: number | null;
  snapshots_last_7d: number | null;
  snapshots_last_30d: number | null;
  avg_clv_rupees: number | null;
  top_clv_rupees: number | null;
  bottom_clv_rupees: number | null;
  median_clv_rupees: number | null;
  p90_clv_threshold_rupees: number | null;
  total_clv_book_rupees: number | null;
  platinum_count: number | null;
  gold_count: number | null;
  silver_count: number | null;
  bronze_count: number | null;
  critical_band_count: number | null;
  gold_to_bronze_ratio: number | null;
};

type TopRow = {
  hospital_user_id: string;
  hospital_name: string | null;
  city: string | null;
  snapshot_at: string | null;
  total_lifetime_revenue_rupees: number | null;
  total_lifetime_gross_profit_rupees: number | null;
  total_projected_clv_rupees: number | null;
  days_active: number | null;
  value_segment: string | null;
  churn_risk_band: string | null;
};

type SegmentRow = {
  value_segment: string;
  hospital_count: number | null;
  avg_clv_rupees: number | null;
  total_clv_rupees: number | null;
  avg_days_active: number | null;
  critical_risk_count: number | null;
};

type RecentRow = {
  id: string;
  hospital_user_id: string;
  hospital_name: string | null;
  snapshot_at: string | null;
  total_lifetime_revenue_rupees: number | null;
  total_lifetime_gross_profit_rupees: number | null;
  total_projected_clv_rupees: number | null;
  days_active: number | null;
  churn_risk_band: string | null;
  value_segment: string | null;
};

function fmtRupees(v: number | null | undefined) {
  if (v == null) return "—";
  return `₹${formatNumber(Number(v))}`;
}

function fmtDate(v: string | null | undefined) {
  if (!v) return "—";
  return new Date(v).toLocaleString();
}

function segmentTone(seg: string | null | undefined) {
  switch (seg) {
    case "platinum": return "border-violet-200 bg-violet-50 text-violet-700";
    case "gold": return "border-amber-200 bg-amber-50 text-amber-700";
    case "silver": return "border-zinc-200 bg-zinc-50 text-zinc-700";
    default: return "border-orange-200 bg-orange-50 text-orange-700";
  }
}

function bandTone(band: string | null | undefined) {
  switch (band) {
    case "critical": return "text-rose-700";
    case "high": return "text-amber-700";
    case "medium": return "text-yellow-700";
    default: return "text-emerald-700";
  }
}

export default async function FounderCustomerLifetimeValueCalculatorPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, topRes, segmentRes, recentRes] = await Promise.all([
    supabase.rpc("founder_clv_calculator_summary"),
    supabase.rpc("founder_clv_top_customers", { p_limit: 50 }),
    supabase.rpc("founder_clv_by_segment"),
    supabase.rpc("founder_clv_recent_snapshots", { p_limit: 30 }),
  ]);

  const summary: SummaryRow = (summaryRes.data?.[0] ?? {}) as SummaryRow;
  const top: TopRow[] = (topRes.data ?? []) as TopRow[];
  const segments: SegmentRow[] = (segmentRes.data ?? []) as SegmentRow[];
  const recent: RecentRow[] = (recentRes.data ?? []) as RecentRow[];

  const cards: { label: string; value: string; tone?: "good" | "warn" | "bad" }[] = [
    { label: "Total snapshots", value: formatNumber(summary.total_snapshots ?? 0) },
    { label: "Unique hospitals", value: formatNumber(summary.unique_hospitals ?? 0) },
    { label: "Snapshots 7d", value: formatNumber(summary.snapshots_last_7d ?? 0) },
    { label: "Snapshots 30d", value: formatNumber(summary.snapshots_last_30d ?? 0) },
    { label: "Avg CLV", value: fmtRupees(summary.avg_clv_rupees), tone: "good" },
    { label: "Top CLV", value: fmtRupees(summary.top_clv_rupees), tone: "good" },
    { label: "Bottom CLV", value: fmtRupees(summary.bottom_clv_rupees) },
    { label: "Median CLV", value: fmtRupees(summary.median_clv_rupees) },
    { label: "P90 threshold", value: fmtRupees(summary.p90_clv_threshold_rupees) },
    { label: "Total book", value: fmtRupees(summary.total_clv_book_rupees), tone: "good" },
    { label: "Platinum", value: formatNumber(summary.platinum_count ?? 0), tone: "good" },
    { label: "Gold", value: formatNumber(summary.gold_count ?? 0) },
    { label: "Silver", value: formatNumber(summary.silver_count ?? 0) },
    { label: "Bronze", value: formatNumber(summary.bronze_count ?? 0) },
    { label: "Critical risk", value: formatNumber(summary.critical_band_count ?? 0), tone: "bad" },
    { label: "Gold:Bronze", value: summary.gold_to_bronze_ratio != null ? Number(summary.gold_to_bronze_ratio).toFixed(2) : "—" },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-8 space-y-8">
      <header className="space-y-1">
        <p className="text-xs uppercase tracking-wider text-zinc-500">r1427 Founder ops</p>
        <h1 className="text-2xl font-semibold">Customer lifetime value calculator</h1>
        <p className="text-sm text-zinc-600">
          Per-hospital CLV computation — pulls AMC revenue, engineer payouts, days active, and churn signal into a snapshot ledger with segment + risk-band classification.
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-sm font-medium text-zinc-700">CLV book KPIs</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {cards.map((c) => (
            <div
              key={c.label}
              className={
                "rounded-lg border p-4 " +
                (c.tone === "good"
                  ? "border-emerald-200 bg-emerald-50"
                  : c.tone === "warn"
                  ? "border-amber-200 bg-amber-50"
                  : c.tone === "bad"
                  ? "border-rose-200 bg-rose-50"
                  : "border-zinc-200 bg-white")
              }
            >
              <div className="text-xs uppercase tracking-wider text-zinc-500">{c.label}</div>
              <div className="mt-1 text-xl font-semibold text-zinc-900">{c.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-medium text-zinc-700">Segment breakdown</h2>
        <div className="overflow-x-auto rounded-lg border border-zinc-200">
          <table className="min-w-full text-sm">
            <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
              <tr>
                <th className="px-3 py-2 text-left">Segment</th>
                <th className="px-3 py-2 text-right">Hospitals</th>
                <th className="px-3 py-2 text-right">Avg CLV</th>
                <th className="px-3 py-2 text-right">Total CLV</th>
                <th className="px-3 py-2 text-right">Avg days active</th>
                <th className="px-3 py-2 text-right">Critical risk</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {segments.length === 0 ? (
                <tr><td colSpan={6} className="px-3 py-6 text-center text-zinc-500">No segment data yet — run founder_clv_snapshot_all_hospitals().</td></tr>
              ) : (
                segments.map((s) => (
                  <tr key={s.value_segment} className="hover:bg-zinc-50">
                    <td className="px-3 py-2">
                      <span className={"inline-block rounded-full border px-2 py-0.5 text-xs font-medium capitalize " + segmentTone(s.value_segment)}>
                        {s.value_segment}
                      </span>
                    </td>
                    <td className="px-3 py-2 text-right">{formatNumber(s.hospital_count ?? 0)}</td>
                    <td className="px-3 py-2 text-right">{fmtRupees(s.avg_clv_rupees)}</td>
                    <td className="px-3 py-2 text-right font-medium">{fmtRupees(s.total_clv_rupees)}</td>
                    <td className="px-3 py-2 text-right">{s.avg_days_active != null ? Number(s.avg_days_active).toFixed(0) : "—"}</td>
                    <td className={"px-3 py-2 text-right " + ((s.critical_risk_count ?? 0) > 0 ? "text-rose-600 font-medium" : "")}>{formatNumber(s.critical_risk_count ?? 0)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-medium text-zinc-700">Top 50 hospital CLV ladder</h2>
        <div className="overflow-x-auto rounded-lg border border-zinc-200">
          <table className="min-w-full text-sm">
            <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
              <tr>
                <th className="px-3 py-2 text-left">#</th>
                <th className="px-3 py-2 text-left">Hospital</th>
                <th className="px-3 py-2 text-left">City</th>
                <th className="px-3 py-2 text-right">Lifetime revenue</th>
                <th className="px-3 py-2 text-right">Gross profit</th>
                <th className="px-3 py-2 text-right">Projected CLV</th>
                <th className="px-3 py-2 text-right">Days active</th>
                <th className="px-3 py-2 text-left">Segment</th>
                <th className="px-3 py-2 text-left">Risk band</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {top.length === 0 ? (
                <tr><td colSpan={9} className="px-3 py-6 text-center text-zinc-500">No CLV snapshots yet.</td></tr>
              ) : (
                top.map((r, idx) => (
                  <tr key={r.hospital_user_id} className="hover:bg-zinc-50">
                    <td className="px-3 py-2 text-zinc-500">{idx + 1}</td>
                    <td className="px-3 py-2">{r.hospital_name ?? r.hospital_user_id}</td>
                    <td className="px-3 py-2 text-zinc-600">{r.city ?? "—"}</td>
                    <td className="px-3 py-2 text-right">{fmtRupees(r.total_lifetime_revenue_rupees)}</td>
                    <td className="px-3 py-2 text-right">{fmtRupees(r.total_lifetime_gross_profit_rupees)}</td>
                    <td className="px-3 py-2 text-right font-medium">{fmtRupees(r.total_projected_clv_rupees)}</td>
                    <td className="px-3 py-2 text-right">{r.days_active ?? "—"}</td>
                    <td className="px-3 py-2">
                      <span className={"inline-block rounded-full border px-2 py-0.5 text-xs font-medium capitalize " + segmentTone(r.value_segment)}>
                        {r.value_segment ?? "—"}
                      </span>
                    </td>
                    <td className={"px-3 py-2 capitalize font-medium " + bandTone(r.churn_risk_band)}>{r.churn_risk_band ?? "—"}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-medium text-zinc-700">Recent snapshots</h2>
        <div className="overflow-x-auto rounded-lg border border-zinc-200">
          <table className="min-w-full text-sm">
            <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
              <tr>
                <th className="px-3 py-2 text-left">When</th>
                <th className="px-3 py-2 text-left">Hospital</th>
                <th className="px-3 py-2 text-right">Revenue</th>
                <th className="px-3 py-2 text-right">Gross profit</th>
                <th className="px-3 py-2 text-right">Projected CLV</th>
                <th className="px-3 py-2 text-right">Days active</th>
                <th className="px-3 py-2 text-left">Segment</th>
                <th className="px-3 py-2 text-left">Band</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {recent.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-6 text-center text-zinc-500">No recent snapshots.</td></tr>
              ) : (
                recent.map((r) => (
                  <tr key={r.id} className="hover:bg-zinc-50">
                    <td className="px-3 py-2 text-zinc-500">{fmtDate(r.snapshot_at)}</td>
                    <td className="px-3 py-2">{r.hospital_name ?? "—"}</td>
                    <td className="px-3 py-2 text-right">{fmtRupees(r.total_lifetime_revenue_rupees)}</td>
                    <td className="px-3 py-2 text-right">{fmtRupees(r.total_lifetime_gross_profit_rupees)}</td>
                    <td className="px-3 py-2 text-right font-medium">{fmtRupees(r.total_projected_clv_rupees)}</td>
                    <td className="px-3 py-2 text-right">{r.days_active ?? "—"}</td>
                    <td className="px-3 py-2">
                      <span className={"inline-block rounded-full border px-2 py-0.5 text-xs font-medium capitalize " + segmentTone(r.value_segment)}>
                        {r.value_segment ?? "—"}
                      </span>
                    </td>
                    <td className={"px-3 py-2 capitalize font-medium " + bandTone(r.churn_risk_band)}>{r.churn_risk_band ?? "—"}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="text-xs text-zinc-500">
        Backed by 1 table + 7 RPCs. CLV = lifetime revenue + (avg monthly revenue × 60 projected months). Segment by total CLV thresholds; band by last-activity recency. Cron-friendly snapshot_all_hospitals + per-hospital calculator.
      </footer>
    </main>
  );
}
