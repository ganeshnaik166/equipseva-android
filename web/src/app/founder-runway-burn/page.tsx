import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder runway & burn — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  latest_cash_balance_rupees: number | null;
  latest_snapshot_date: string | null;
  days_since_last_snapshot: number | null;
  monthly_burn_avg_3m_rupees: number;
  monthly_burn_last_30d_rupees: number;
  estimated_runway_months: number | null;
  estimated_zero_cash_date: string | null;
  monthly_inflow_avg_3m_rupees: number;
  monthly_payouts_avg_3m_rupees: number;
  monthly_refunds_avg_3m_rupees: number;
  monthly_net_position_rupees: number;
  cash_cumulative_change_30d_rupees: number;
};

type HistRow = {
  month_start: string;
  snapshot_date: string | null;
  cash_balance_rupees: number | null;
  month_inflow_rupees: number;
  month_burn_rupees: number;
  month_net_rupees: number;
  snapshot_note: string | null;
};

function runwayTone(months: number | null): string {
  if (months === null || months === undefined) return "text-[var(--color-ok)]";
  if (months < 6) return "text-[var(--color-danger)]";
  if (months < 12) return "text-[var(--color-warn)]";
  return "text-[var(--color-ok)]";
}

function freshnessTone(days: number | null): string {
  if (days === null) return "text-[var(--color-muted)]";
  if (days > 45) return "text-[var(--color-danger)]";
  if (days > 30) return "text-[var(--color-warn)]";
  return "text-[var(--color-ok)]";
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!isFinite(v)) return "—";
  return "₹" + formatNumber(Math.round(v));
}

function fmtMonths(n: number | null): string {
  if (n === null || n === undefined) return "∞";
  return Number(n).toFixed(1) + " mo";
}

function fmtDate(d: string | null): string {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata", year: "numeric", month: "short", day: "2-digit" });
}

export default async function FounderRunwayBurnPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, histRes] = await Promise.all([
    supabase.rpc("founder_runway_burn_summary"),
    supabase.rpc("founder_runway_history", { p_months: 12 }),
  ]);
  if (sumRes.error) throw new Error(`founder_runway_burn_summary: ${sumRes.error.message}`);
  if (histRes.error) throw new Error(`founder_runway_history: ${histRes.error.message}`);
  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const history = (histRes.data ?? []) as HistRow[];

  const noSnapshot = !s || s.latest_snapshot_date === null;
  const runwayMonths = s?.estimated_runway_months ?? null;
  const tone = runwayTone(runwayMonths);

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder runway & burn ★★★ r1328</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Cash position + monthly burn → runway months & zero-cash date · Burn = engineer payouts (processed) + spare-part orders (paid) + escrow refunds · Inflow = payments (captured) · 3-month rolling average
        </p>
      </header>

      {noSnapshot ? (
        <section className="rounded-lg border-2 border-[var(--color-warn)] bg-[var(--color-surface)] p-6">
          <div className="text-sm font-semibold text-[var(--color-warn)]">No cash-balance snapshot yet</div>
          <p className="mt-2 text-xs text-[var(--color-muted)]">
            Enter the current bank-balance manually at <code>/founder-cash-snapshot-new</code> (TODO — not built yet). Once a snapshot exists, runway projects from latest balance ÷ 3-month-avg net burn.
          </p>
        </section>
      ) : (
        <section className="rounded-lg border-2 border-[var(--color-border)] bg-[var(--color-surface)] p-6">
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Estimated runway</div>
              <div className={`mt-1 text-5xl font-bold tabular-nums ${tone}`}>{fmtMonths(runwayMonths)}</div>
              <div className="text-xs text-[var(--color-muted)] mt-1">
                {runwayMonths === null
                  ? "Net position positive — revenue covers burn"
                  : runwayMonths < 6
                  ? "DANGER · raise round now"
                  : runwayMonths < 12
                  ? "WARN · plan raise within 90 days"
                  : "Healthy · runway >12 months"}
              </div>
            </div>
            <div>
              <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Estimated zero-cash date</div>
              <div className={`mt-1 text-3xl font-bold tabular-nums ${tone}`}>{fmtDate(s?.estimated_zero_cash_date ?? null)}</div>
              <div className="text-xs text-[var(--color-muted)] mt-1">
                Projected from latest snapshot ({fmtDate(s?.latest_snapshot_date ?? null)}) + monthly net burn
              </div>
            </div>
          </div>
        </section>
      )}

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Latest cash balance</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{fmtRupees(s.latest_cash_balance_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">as of {fmtDate(s.latest_snapshot_date)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Days since last snapshot</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${freshnessTone(s.days_since_last_snapshot)}`}>
              {s.days_since_last_snapshot === null ? "—" : formatNumber(s.days_since_last_snapshot)}
            </div>
            <div className="text-xs text-[var(--color-muted)]">refresh monthly</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Monthly burn (3m avg)</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{fmtRupees(s.monthly_burn_avg_3m_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">payouts + spares + refunds</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Burn last 30d</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{fmtRupees(s.monthly_burn_last_30d_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">short-term trend</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Monthly inflow (3m avg)</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{fmtRupees(s.monthly_inflow_avg_3m_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">captured payments</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Monthly net position</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${Number(s.monthly_net_position_rupees) >= 0 ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]"}`}>
              {fmtRupees(s.monthly_net_position_rupees)}
            </div>
            <div className="text-xs text-[var(--color-muted)]">inflow − burn</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Engineer payouts (3m avg)</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{fmtRupees(s.monthly_payouts_avg_3m_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">processed only</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Escrow refunds (3m avg)</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{fmtRupees(s.monthly_refunds_avg_3m_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">refunded to hospitals</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Cash change last 30d</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${Number(s.cash_cumulative_change_30d_rupees) >= 0 ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]"}`}>
              {fmtRupees(s.cash_cumulative_change_30d_rupees)}
            </div>
            <div className="text-xs text-[var(--color-muted)]">inflow30d − burn30d</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Months covered by cash</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${tone}`}>{fmtMonths(runwayMonths)}</div>
            <div className="text-xs text-[var(--color-muted)]">at current net burn</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Burn trend</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">
              {s.monthly_burn_avg_3m_rupees > 0
                ? (((Number(s.monthly_burn_last_30d_rupees) - Number(s.monthly_burn_avg_3m_rupees)) / Number(s.monthly_burn_avg_3m_rupees)) * 100).toFixed(0) + "%"
                : "—"}
            </div>
            <div className="text-xs text-[var(--color-muted)]">30d vs 3m avg</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Default alive?</div>
            <div className={`mt-1 text-2xl font-bold ${Number(s.monthly_net_position_rupees) >= 0 ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]"}`}>
              {Number(s.monthly_net_position_rupees) >= 0 ? "YES" : "NO"}
            </div>
            <div className="text-xs text-[var(--color-muted)]">net position {">="} 0</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Monthly history (last 12 months)</h2>
        {history.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No history yet.</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
            <table className="min-w-full text-xs">
              <thead className="bg-[var(--color-surface-2)]">
                <tr className="text-left text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="px-3 py-2 font-medium">Month</th>
                  <th className="px-3 py-2 font-medium">Snapshot date</th>
                  <th className="px-3 py-2 font-medium text-right">Cash balance</th>
                  <th className="px-3 py-2 font-medium text-right">Inflow</th>
                  <th className="px-3 py-2 font-medium text-right">Burn</th>
                  <th className="px-3 py-2 font-medium text-right">Net</th>
                  <th className="px-3 py-2 font-medium">Note</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--color-border)]">
                {history.map((h) => (
                  <tr key={h.month_start} className="hover:bg-[var(--color-surface-2)]">
                    <td className="px-3 py-2 font-mono">{new Date(h.month_start).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata", year: "numeric", month: "short" })}</td>
                    <td className="px-3 py-2 font-mono text-[var(--color-muted)]">{fmtDate(h.snapshot_date)}</td>
                    <td className="px-3 py-2 text-right tabular-nums font-semibold">{fmtRupees(h.cash_balance_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums text-[var(--color-ok)]">{fmtRupees(h.month_inflow_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums text-[var(--color-danger)]">{fmtRupees(h.month_burn_rupees)}</td>
                    <td className={`px-3 py-2 text-right tabular-nums ${Number(h.month_net_rupees) >= 0 ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]"}`}>
                      {fmtRupees(h.month_net_rupees)}
                    </td>
                    <td className="px-3 py-2 text-[var(--color-muted)] italic">{h.snapshot_note ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
        <p><strong className="text-[var(--color-text)]">Snapshot workflow:</strong> Update <code>founder_cash_position_snapshots</code> manually each month at <code>/founder-cash-snapshot-new</code> (TODO — not built yet). Founder enters current bank-balance, optional note. Latest snapshot used as runway anchor.</p>
        <p><strong className="text-[var(--color-text)]">Burn formula:</strong> engineer_payouts (status='processed') + spare_part_orders.total_amount (payment_status='paid') + repair_job_escrow (status='refunded'). Rolling 90d ÷ 3 = monthly average.</p>
        <p><strong className="text-[var(--color-text)]">Inflow formula:</strong> payments.amount_rupees (status='captured'), rolling 90d ÷ 3 = monthly average.</p>
        <p><strong className="text-[var(--color-text)]">Runway formula:</strong> latest_cash_balance ÷ |monthly_net| (only when net {"<"} 0). Net {">="} 0 means default alive — runway is infinite.</p>
        <p><strong className="text-[var(--color-text)]">Color thresholds:</strong> {"<"}6 mo danger · {"<"}12 mo warn · {">="}12 mo ok.</p>
      </section>
    </div>
  );
}
