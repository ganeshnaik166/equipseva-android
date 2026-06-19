import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";
import Link from "next/link";

export const metadata = { title: "AMC churn early warning — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  contract_id: string;
  hospital_org_id: string | null;
  hospital_name: string;
  amc_tier: string;
  monthly_fee_rupees: number;
  activated_at: string;
  days_active: number;
  last_repair_completed_at: string | null;
  days_since_last_visit: number;
  overdue_visits_count: number;
  payment_overdue_days: number;
  sla_breaches_count: number;
  open_disputes_count: number;
  code_red_count_180d: number;
  churn_score: number;
  churn_band: "low" | "medium" | "high" | "critical";
  primary_signal: string;
};

type Summary = {
  total_active_contracts: number;
  critical_band: number;
  high_band: number;
  medium_band: number;
  low_band: number;
  total_arr_at_risk_critical_rupees: number;
  total_arr_at_risk_high_rupees: number;
  median_churn_score: number;
  contracts_with_overdue_visit: number;
  contracts_with_payment_overdue: number;
};

function bandTone(band: Row["churn_band"]): string {
  if (band === "critical") return "text-[var(--color-danger)]";
  if (band === "high") return "text-[var(--color-warn)]";
  if (band === "medium") return "text-[var(--color-info)]";
  return "text-[var(--color-ok)]";
}

function bandLabel(band: Row["churn_band"]): string {
  return band.charAt(0).toUpperCase() + band.slice(1);
}

export default async function AmcChurnEarlyWarningPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [scoresRes, summaryRes] = await Promise.all([
    supabase.rpc("founder_amc_churn_scores", { p_limit: 100 }),
    supabase.rpc("founder_amc_churn_summary"),
  ]);

  if (scoresRes.error) throw new Error(`founder_amc_churn_scores: ${scoresRes.error.message}`);
  if (summaryRes.error) throw new Error(`founder_amc_churn_summary: ${summaryRes.error.message}`);

  const rows = (scoresRes.data ?? []) as Row[];
  const summary = ((summaryRes.data ?? [])[0] ?? {
    total_active_contracts: 0,
    critical_band: 0,
    high_band: 0,
    medium_band: 0,
    low_band: 0,
    total_arr_at_risk_critical_rupees: 0,
    total_arr_at_risk_high_rupees: 0,
    median_churn_score: 0,
    contracts_with_overdue_visit: 0,
    contracts_with_payment_overdue: 0,
  }) as Summary;

  const cards: { label: string; value: string; tone?: string; sub?: string }[] = [
    { label: "Active contracts", value: formatNumber(summary.total_active_contracts) },
    { label: "Critical band", value: formatNumber(summary.critical_band), tone: "text-[var(--color-danger)]", sub: "score >= 0.75" },
    { label: "High band", value: formatNumber(summary.high_band), tone: "text-[var(--color-warn)]", sub: "score >= 0.50" },
    { label: "Medium band", value: formatNumber(summary.medium_band), tone: "text-[var(--color-info)]", sub: "score >= 0.25" },
    { label: "Low band", value: formatNumber(summary.low_band), tone: "text-[var(--color-ok)]", sub: "score < 0.25" },
    { label: "ARR at risk (critical)", value: `Rs ${formatNumber(summary.total_arr_at_risk_critical_rupees)}`, tone: "text-[var(--color-danger)]", sub: "annualized" },
    { label: "ARR at risk (high)", value: `Rs ${formatNumber(summary.total_arr_at_risk_high_rupees)}`, tone: "text-[var(--color-warn)]", sub: "annualized" },
    { label: "Median churn score", value: summary.median_churn_score.toFixed(3), sub: "0.0 = safe, 1.0 = gone" },
    { label: "Overdue visit", value: formatNumber(summary.contracts_with_overdue_visit), sub: "contracts" },
    { label: "Payment overdue", value: formatNumber(summary.contracts_with_payment_overdue), sub: "contracts" },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC churn early warning</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 100 active contracts ranked by composite churn score (visit recency 25%, overdue visits 20%, payment lateness 20%, SLA 15%, disputes 10%, code-red 10%)
        </span>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-5">
        {cards.map((c) => (
          <div
            key={c.label}
            className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4"
          >
            <div className="text-xs text-[var(--color-muted)]">{c.label}</div>
            <div className={`mt-1 text-lg font-semibold tabular-nums ${c.tone ?? ""}`}>{c.value}</div>
            {c.sub ? <div className="mt-0.5 text-[10px] text-[var(--color-muted)]">{c.sub}</div> : null}
          </div>
        ))}
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <div className="mb-3 flex items-baseline justify-between">
          <h2 className="text-sm font-semibold">Watchlist — top {rows.length} highest churn risk</h2>
          <span className="text-[10px] text-[var(--color-muted)]">sorted by score desc</span>
        </div>
        {rows.length === 0 ? (
          <div className="py-6 text-center text-xs text-[var(--color-muted)]">No active contracts to score.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="border-b border-[var(--color-border)] text-left text-[var(--color-muted)]">
                <tr>
                  <th className="px-2 py-2 font-medium">#</th>
                  <th className="px-2 py-2 font-medium">Contract</th>
                  <th className="px-2 py-2 font-medium">Hospital</th>
                  <th className="px-2 py-2 font-medium">Tier</th>
                  <th className="px-2 py-2 text-right font-medium">Monthly fee</th>
                  <th className="px-2 py-2 text-right font-medium">Days active</th>
                  <th className="px-2 py-2 text-right font-medium">Last visit (d ago)</th>
                  <th className="px-2 py-2 text-right font-medium">Overdue visits</th>
                  <th className="px-2 py-2 text-right font-medium">Payment late (d)</th>
                  <th className="px-2 py-2 text-right font-medium">SLA br.</th>
                  <th className="px-2 py-2 text-right font-medium">Disputes</th>
                  <th className="px-2 py-2 text-right font-medium">Code-red 180d</th>
                  <th className="px-2 py-2 text-right font-medium">Score</th>
                  <th className="px-2 py-2 font-medium">Band</th>
                  <th className="px-2 py-2 font-medium">Primary signal</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r, i) => (
                  <tr key={r.contract_id} className="border-b border-[var(--color-border)]/50">
                    <td className="px-2 py-2 text-[var(--color-muted)] tabular-nums">{i + 1}</td>
                    <td className="px-2 py-2">
                      <Link
                        href={`/amc-contracts/${r.contract_id}`}
                        className="font-mono text-[var(--color-accent)] hover:underline"
                      >
                        {r.contract_id.slice(0, 8)}
                      </Link>
                    </td>
                    <td className="px-2 py-2 max-w-[220px] truncate" title={r.hospital_name}>{r.hospital_name}</td>
                    <td className="px-2 py-2">{r.amc_tier}</td>
                    <td className="px-2 py-2 text-right tabular-nums">{formatNumber(r.monthly_fee_rupees)}</td>
                    <td className="px-2 py-2 text-right tabular-nums">{formatNumber(r.days_active)}</td>
                    <td className={`px-2 py-2 text-right tabular-nums ${r.days_since_last_visit >= 60 ? "text-[var(--color-danger)]" : r.days_since_last_visit >= 30 ? "text-[var(--color-warn)]" : ""}`}>
                      {formatNumber(r.days_since_last_visit)}
                    </td>
                    <td className={`px-2 py-2 text-right tabular-nums ${r.overdue_visits_count > 0 ? "text-[var(--color-warn)]" : ""}`}>
                      {formatNumber(r.overdue_visits_count)}
                    </td>
                    <td className={`px-2 py-2 text-right tabular-nums ${r.payment_overdue_days >= 30 ? "text-[var(--color-danger)]" : r.payment_overdue_days > 0 ? "text-[var(--color-warn)]" : ""}`}>
                      {formatNumber(r.payment_overdue_days)}
                    </td>
                    <td className={`px-2 py-2 text-right tabular-nums ${r.sla_breaches_count > 0 ? "text-[var(--color-warn)]" : ""}`}>
                      {formatNumber(r.sla_breaches_count)}
                    </td>
                    <td className={`px-2 py-2 text-right tabular-nums ${r.open_disputes_count > 0 ? "text-[var(--color-danger)]" : ""}`}>
                      {formatNumber(r.open_disputes_count)}
                    </td>
                    <td className={`px-2 py-2 text-right tabular-nums ${r.code_red_count_180d > 0 ? "text-[var(--color-danger)]" : ""}`}>
                      {formatNumber(r.code_red_count_180d)}
                    </td>
                    <td className={`px-2 py-2 text-right font-semibold tabular-nums ${bandTone(r.churn_band)}`}>
                      {r.churn_score.toFixed(3)}
                    </td>
                    <td className={`px-2 py-2 font-medium ${bandTone(r.churn_band)}`}>{bandLabel(r.churn_band)}</td>
                    <td className="px-2 py-2 text-[var(--color-muted)]">{r.primary_signal}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <footer className="text-[10px] text-[var(--color-muted)]">
        Score formula: clamp((days_since_visit/90)*0.25 + (overdue_visits/3)*0.20 + (pay_overdue_days/30)*0.20 + (sla/5)*0.15 + (disputes/2)*0.10 + (code_red_180d/3)*0.10, 0, 1). Bands: critical {">="} 0.75, high {">="} 0.50, medium {">="} 0.25.
      </footer>
    </div>
  );
}
