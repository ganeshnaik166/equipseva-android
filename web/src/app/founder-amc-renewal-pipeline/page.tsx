import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder AMC renewal pipeline — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_active_amcs: number;
  renewals_due_t90: number;
  renewals_due_t60: number;
  renewals_due_t30: number;
  renewals_overdue: number;
  expected_renewal_arr_rupees: number;
  avg_renewal_lead_time_days: number;
  highest_value_renewal_due_rupees: number;
  highest_value_renewal_hospital_name: string;
  contracts_at_risk_due_t90: number;
  contracts_renewed_30d: number;
  contracts_churned_30d: number;
  net_renewal_pct: number;
  enterprise_tier_due_t90: number;
  growth_tier_due_t90: number;
  starter_tier_due_t90: number;
};

type DueRow = {
  contract_id: string;
  hospital_org_id: string | null;
  hospital_name: string;
  amc_tier: string | null;
  monthly_fee_rupees: number;
  end_date: string;
  days_until_renewal: number;
  last_visit_at: string | null;
  has_open_codered: boolean;
  has_open_dispute: boolean;
  expected_renewal_value_rupees: number;
  risk_band: string;
};

function Card({ title, val, sub, danger, ok, warn, info }: {
  title: string; val: string; sub?: string;
  danger?: boolean; ok?: boolean; warn?: boolean; info?: boolean;
}) {
  const tone = danger
    ? "text-[var(--color-danger)]"
    : ok ? "text-[var(--color-ok)]"
    : warn ? "text-[var(--color-warn)]"
    : info ? "text-[var(--color-info)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${tone}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function riskTone(band: string): string {
  switch (band) {
    case "critical": return "text-[var(--color-danger)] font-semibold";
    case "high":     return "text-[var(--color-danger)]";
    case "medium":   return "text-[var(--color-warn)]";
    case "low":      return "text-[var(--color-info)]";
    case "ok":       return "text-[var(--color-ok)]";
    default:         return "text-[var(--color-muted)]";
  }
}

function tierLabel(t: string | null): string {
  if (!t) return "·";
  return t.charAt(0).toUpperCase() + t.slice(1);
}

function daysCellTone(d: number): string {
  if (d < 0)  return "text-[var(--color-danger)] font-semibold";
  if (d <= 30) return "text-[var(--color-danger)]";
  if (d <= 60) return "text-[var(--color-warn)]";
  return "text-[var(--color-muted)]";
}

export default async function FounderAmcRenewalPipelinePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: sumData, error: sumErr }, { data: dueData, error: dueErr }] = await Promise.all([
    supabase.rpc("founder_amc_renewal_pipeline_summary"),
    supabase.rpc("founder_amc_renewal_pipeline_due", { p_window_days: 90, p_limit: 100 }),
  ]);
  if (sumErr) throw new Error(`founder_amc_renewal_pipeline_summary: ${sumErr.message}`);
  if (dueErr) throw new Error(`founder_amc_renewal_pipeline_due: ${dueErr.message}`);

  const s = (sumData?.[0] ?? null) as Summary | null;
  const rows = (dueData ?? []) as DueRow[];

  const critCount = rows.filter((r) => r.risk_band === "critical").length;
  const highCount = rows.filter((r) => r.risk_band === "high").length;

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between flex-wrap gap-2">
        <h1 className="text-xl font-semibold">Founder AMC renewal pipeline</h1>
        <span className="text-xs text-[var(--color-muted)]">
          T-90/60/30 windows · risk-banded · pure read aggregator
        </span>
      </header>

      {s ? (
        <>
          <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-info)]/10 p-5">
            <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">
              Expected renewal ARR · T-90 window
            </div>
            <div className="mt-1 text-4xl font-bold tabular-nums text-[var(--color-info)]">
              Rs {formatNumber(Math.round(s.expected_renewal_arr_rupees))}
            </div>
            <div className="mt-1 text-sm text-[var(--color-muted)]">
              {formatNumber(s.renewals_due_t90)} contracts due in next 90 days ·
              {" "}highest single: <span className="font-medium">Rs {formatNumber(Math.round(s.highest_value_renewal_due_rupees))}</span>
              {" "}({s.highest_value_renewal_hospital_name})
            </div>
          </section>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Card title="Total active AMCs"        val={formatNumber(s.total_active_amcs)} ok />
            <Card title="Due T-90"                 val={formatNumber(s.renewals_due_t90)} info sub="next 90d" />
            <Card title="Due T-60"                 val={formatNumber(s.renewals_due_t60)} warn sub="next 60d" />
            <Card title="Due T-30"                 val={formatNumber(s.renewals_due_t30)} danger={s.renewals_due_t30 > 0} sub="next 30d" />
            <Card title="Overdue"                  val={formatNumber(s.renewals_overdue)} danger={s.renewals_overdue > 0} sub="past end_date" />
            <Card title="Expected ARR T-90"        val={`Rs ${formatNumber(Math.round(s.expected_renewal_arr_rupees))}`} info sub="monthly · 12" />
            <Card title="Avg lead time (d)"        val={Number(s.avg_renewal_lead_time_days).toFixed(0)} sub="placeholder" />
            <Card title="Highest single renewal"   val={`Rs ${formatNumber(Math.round(s.highest_value_renewal_due_rupees))}`} info sub={s.highest_value_renewal_hospital_name} />
            <Card title="At-risk T-90"             val={formatNumber(s.contracts_at_risk_due_t90)} danger={s.contracts_at_risk_due_t90 > 0} sub="codered 30d or dispute" />
            <Card title="Renewed 30d"              val={formatNumber(s.contracts_renewed_30d)} ok sub="approx · created+12mo<end" />
            <Card title="Churned 30d"              val={formatNumber(s.contracts_churned_30d)} danger={s.contracts_churned_30d > 0} sub="status churned" />
            <Card title="Net renewal %"            val={`${Number(s.net_renewal_pct).toFixed(1)}%`} ok={s.net_renewal_pct >= 80} warn={s.net_renewal_pct < 80 && s.net_renewal_pct >= 60} danger={s.net_renewal_pct < 60} sub="renewed / (renewed+churned)" />
            <Card title="Enterprise T-90"          val={formatNumber(s.enterprise_tier_due_t90)} info />
            <Card title="Growth T-90"              val={formatNumber(s.growth_tier_due_t90)} info />
            <Card title="Starter T-90"             val={formatNumber(s.starter_tier_due_t90)} info />
            <Card title="Critical + high in list"  val={formatNumber(critCount + highCount)} danger={critCount + highCount > 0} sub={`${critCount} crit · ${highCount} high`} />
          </div>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No summary data.</p>}

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
        <div className="border-b border-[var(--color-border)] p-3">
          <h2 className="text-sm font-semibold">Renewal queue · top {rows.length}</h2>
          <p className="text-xs text-[var(--color-muted)]">
            Sorted by risk band severity (critical → high → medium → low → ok),
            then by days-until-renewal ascending. Codered = open in last 30d. Dispute = repair_job_escrow in_dispute.
          </p>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-[var(--color-border)]/30 text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Hospital</th>
                <th className="px-3 py-2 text-left">Tier</th>
                <th className="px-3 py-2 text-right">Monthly fee</th>
                <th className="px-3 py-2 text-right">End date</th>
                <th className="px-3 py-2 text-right">Days until</th>
                <th className="px-3 py-2 text-right">Last visit</th>
                <th className="px-3 py-2 text-center">Codered</th>
                <th className="px-3 py-2 text-center">Dispute</th>
                <th className="px-3 py-2 text-right">Expected ARR</th>
                <th className="px-3 py-2 text-left">Risk</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 ? (
                <tr>
                  <td colSpan={10} className="px-3 py-6 text-center text-[var(--color-muted)]">
                    No contracts due in the next 90 days.
                  </td>
                </tr>
              ) : rows.map((r) => (
                <tr key={r.contract_id} className="border-t border-[var(--color-border)]/40">
                  <td className="px-3 py-2 text-left font-medium">{r.hospital_name}</td>
                  <td className="px-3 py-2 text-left">{tierLabel(r.amc_tier)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">Rs {formatNumber(Math.round(r.monthly_fee_rupees))}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{r.end_date}</td>
                  <td className={`px-3 py-2 text-right tabular-nums ${daysCellTone(r.days_until_renewal)}`}>
                    {r.days_until_renewal}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--color-muted)]">
                    {r.last_visit_at ? new Date(r.last_visit_at).toISOString().slice(0, 10) : "·"}
                  </td>
                  <td className="px-3 py-2 text-center">
                    {r.has_open_codered ? <span className="text-[var(--color-danger)]">yes</span> : <span className="text-[var(--color-muted)]">·</span>}
                  </td>
                  <td className="px-3 py-2 text-center">
                    {r.has_open_dispute ? <span className="text-[var(--color-danger)]">yes</span> : <span className="text-[var(--color-muted)]">·</span>}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    Rs {formatNumber(Math.round(r.expected_renewal_value_rupees))}
                  </td>
                  <td className={`px-3 py-2 text-left ${riskTone(r.risk_band)}`}>{r.risk_band}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Risk band logic: critical = overdue OR (open codered AND ≤ 30d) · high = ≤ 30d AND open dispute ·
        medium = ≤ 30d · low = 31-90d · ok = otherwise.
        Renewed-30d uses an approximation since amc_contracts has no explicit renewed_at field:
        contracts whose end_date is in the future AND whose created_at + 12 months falls before end_date,
        and whose created_at lies within the last 30 days.
      </p>
    </div>
  );
}
