import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder unit economics — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  snapshot_label: string;
  cac_rupees: number | null;
  monthly_revenue_per_account_rupees: number | null;
  monthly_gross_profit_per_account_rupees: number | null;
  monthly_contribution_per_account_rupees: number | null;
  contribution_margin_pct: number | null;
  ltv_rupees: number | null;
  ltv_to_cac_ratio: number | null;
  payback_months: number | null;
  health_band: "ok" | "warn" | "danger";
};

type HistRow = {
  snapshot_label: string;
  sales_cost_quarter_rupees: number;
  bd_headcount_cost_quarter_rupees: number;
  marketing_cost_quarter_rupees: number;
  avg_hospital_amc_monthly_rupees: number;
  avg_take_rate_pct: number;
  avg_cogs_per_amc_monthly_rupees: number;
  avg_hospital_lifetime_months: number;
  created_at: string;
};

function bandTone(band: string | null | undefined): string {
  if (band === "ok") return "text-[var(--color-ok)]";
  if (band === "warn") return "text-[var(--color-warn)]";
  if (band === "danger") return "text-[var(--color-danger)]";
  return "text-[var(--color-muted)]";
}

function bandLabel(band: string | null | undefined): string {
  if (band === "ok") return "HEALTHY · LTV:CAC ≥ 3 and payback ≤ 18 mo";
  if (band === "warn") return "WATCH · LTV:CAC between 1.5 and 3";
  if (band === "danger") return "DANGER · LTV:CAC < 1.5 — re-price or cut acquisition cost";
  return "NO DATA · record a snapshot to compute";
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!isFinite(v)) return "—";
  return "₹" + formatNumber(Math.round(v));
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(1) + "%";
}

function fmtMonths(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(1) + " mo";
}

function fmtRatio(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(2) + "×";
}

function fmtDate(d: string | null): string {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata", year: "numeric", month: "short", day: "2-digit" });
}

export default async function FounderUnitEconomicsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, histRes] = await Promise.all([
    supabase.rpc("founder_unit_economics_summary"),
    supabase.rpc("founder_unit_economics_history", { p_limit: 8 }),
  ]);
  if (sumRes.error) throw new Error(`founder_unit_economics_summary: ${sumRes.error.message}`);
  if (histRes.error) throw new Error(`founder_unit_economics_history: ${histRes.error.message}`);
  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const history = (histRes.data ?? []) as HistRow[];

  const tone = bandTone(s?.health_band);
  const ratio = s?.ltv_to_cac_ratio ?? null;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder unit economics ★★★ r1334</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          CAC + LTV + payback + contribution margin · CAC cohort = AMC contracts activated in last 90 days · LTV = monthly contribution × avg hospital lifetime months
        </p>
      </header>

      {s === null ? (
        <section className="rounded-lg border-2 border-[var(--color-warn)] bg-[var(--color-surface)] p-6">
          <div className="text-sm font-semibold text-[var(--color-warn)]">No snapshot recorded yet</div>
          <p className="mt-2 text-xs text-[var(--color-muted)]">
            Record the first quarter via <code>log_founder_unit_economics_snapshot(...)</code> RPC. Inputs: quarterly sales cost, BD headcount cost, marketing cost, avg AMC monthly fee, take rate %, COGS per AMC, avg hospital lifetime months.
          </p>
        </section>
      ) : (
        <section className="rounded-lg border-2 border-[var(--color-border)] bg-[var(--color-surface)] p-6">
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">LTV : CAC ratio</div>
              <div className={`mt-1 text-6xl font-bold tabular-nums ${tone}`}>{fmtRatio(ratio)}</div>
              <div className={`text-xs mt-2 font-medium ${tone}`}>{bandLabel(s.health_band)}</div>
              <div className="text-xs text-[var(--color-muted)] mt-1">snapshot: <span className="font-mono">{s.snapshot_label}</span></div>
            </div>
            <div>
              <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">CAC payback</div>
              <div className={`mt-1 text-5xl font-bold tabular-nums ${tone}`}>{fmtMonths(s.payback_months)}</div>
              <div className="text-xs text-[var(--color-muted)] mt-2">
                Months of monthly contribution to recover one CAC. Target {"<="} 18 mo for SaaS-style books.
              </div>
            </div>
          </div>
        </section>
      )}

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">CAC</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{fmtRupees(s.cac_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">cost ÷ new AMCs 90d</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">LTV</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{fmtRupees(s.ltv_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">contribution × lifetime</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Monthly revenue / acct</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{fmtRupees(s.monthly_revenue_per_account_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">AMC fee × take-rate</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Monthly gross profit / acct</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{fmtRupees(s.monthly_gross_profit_per_account_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">revenue − COGS</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Monthly contribution / acct</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{fmtRupees(s.monthly_contribution_per_account_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">recovers CAC</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Contribution margin %</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{fmtPct(s.contribution_margin_pct)}</div>
            <div className="text-xs text-[var(--color-muted)]">target {">="} 60%</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">LTV : CAC</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${tone}`}>{fmtRatio(s.ltv_to_cac_ratio)}</div>
            <div className="text-xs text-[var(--color-muted)]">target {">="} 3×</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">CAC payback</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${tone}`}>{fmtMonths(s.payback_months)}</div>
            <div className="text-xs text-[var(--color-muted)]">target {"<="} 18 mo</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Health band</div>
            <div className={`mt-1 text-2xl font-bold uppercase ${tone}`}>{s.health_band ?? "—"}</div>
            <div className="text-xs text-[var(--color-muted)]">ratio + payback gate</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Snapshot</div>
            <div className="mt-1 text-base font-bold font-mono break-all">{s.snapshot_label}</div>
            <div className="text-xs text-[var(--color-muted)]">latest input row</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Snapshot history (last 8)</h2>
        {history.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No history yet.</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
            <table className="min-w-full text-xs">
              <thead className="bg-[var(--color-surface-2)]">
                <tr className="text-left text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="px-3 py-2 font-medium">Label</th>
                  <th className="px-3 py-2 font-medium">Recorded</th>
                  <th className="px-3 py-2 font-medium text-right">Sales /Q</th>
                  <th className="px-3 py-2 font-medium text-right">BD /Q</th>
                  <th className="px-3 py-2 font-medium text-right">Mkt /Q</th>
                  <th className="px-3 py-2 font-medium text-right">AMC fee /mo</th>
                  <th className="px-3 py-2 font-medium text-right">Take rate</th>
                  <th className="px-3 py-2 font-medium text-right">COGS /mo</th>
                  <th className="px-3 py-2 font-medium text-right">Lifetime</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--color-border)]">
                {history.map((h) => (
                  <tr key={h.snapshot_label} className="hover:bg-[var(--color-surface-2)]">
                    <td className="px-3 py-2 font-mono font-semibold">{h.snapshot_label}</td>
                    <td className="px-3 py-2 font-mono text-[var(--color-muted)]">{fmtDate(h.created_at)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{fmtRupees(h.sales_cost_quarter_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{fmtRupees(h.bd_headcount_cost_quarter_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{fmtRupees(h.marketing_cost_quarter_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{fmtRupees(h.avg_hospital_amc_monthly_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{fmtPct(h.avg_take_rate_pct)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{fmtRupees(h.avg_cogs_per_amc_monthly_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{fmtMonths(h.avg_hospital_lifetime_months)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
        <p><strong className="text-[var(--color-text)]">Update cadence:</strong> Update the input parameters each quarter when new sales spend numbers land. CAC formula uses last-90d AMC activations as the cohort.</p>
        <p><strong className="text-[var(--color-text)]">CAC =</strong> (sales cost + BD headcount cost + marketing cost) ÷ COUNT(amc_contracts WHERE activated_at {">="} now() − 90 days).</p>
        <p><strong className="text-[var(--color-text)]">Monthly revenue / acct =</strong> avg AMC monthly fee × take-rate %. <strong className="text-[var(--color-text)]">Gross profit =</strong> revenue − COGS. <strong className="text-[var(--color-text)]">Contribution margin =</strong> gross profit ÷ revenue.</p>
        <p><strong className="text-[var(--color-text)]">LTV =</strong> monthly contribution × avg hospital lifetime months. <strong className="text-[var(--color-text)]">Payback =</strong> CAC ÷ monthly contribution.</p>
        <p><strong className="text-[var(--color-text)]">Health band:</strong> OK = ratio {">="} 3× AND payback {"<="} 18 mo · WARN = ratio {">="} 1.5× · DANGER = below 1.5× or payback unrecoverable.</p>
      </section>
    </div>
  );
}
