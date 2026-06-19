import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Runway forecast v2 — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  current_cash_balance_rupees: number;
  days_since_snapshot: number | null;
  base_runway_months: number | null;
  base_zero_cash_date: string | null;
  upside_runway_months: number | null;
  downside_runway_months: number | null;
  stress_runway_months: number | null;
  actual_burn_last_30d_rupees: number;
  actual_inflow_last_30d_rupees: number;
  actual_net_last_30d_rupees: number;
  burn_vs_base_variance_pct: number;
  scenarios_active_count: number;
  longest_runway_scenario_label: string;
  shortest_runway_scenario_label: string;
  newest_scenario_at: string | null;
  generated_at: string;
};

type Scenario = {
  id: string;
  scenario_label: string;
  scenario_kind: string;
  assumed_monthly_burn_rupees: number;
  assumed_monthly_inflow_rupees: number;
  assumed_starting_cash_rupees: number | null;
  is_active: boolean;
  created_at: string;
};

function Card({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "ok" | "warn" | "danger" | "info" }) {
  const toneClass = tone === "ok" ? "text-[var(--color-ok)]" : tone === "warn" ? "text-[var(--color-warn)]" : tone === "danger" ? "text-[var(--color-danger)]" : tone === "info" ? "text-[var(--color-info)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${toneClass}`}>{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)] tabular-nums">{sub}</div> : null}
    </div>
  );
}

function runwayTone(months: number | null): "ok" | "warn" | "danger" | undefined {
  if (months === null) return undefined;
  if (months < 6) return "danger";
  if (months < 12) return "warn";
  return "ok";
}

function rup(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return `₹${formatNumber(Math.round(n))}`;
}

function months(n: number | null): string {
  if (n === null) return "∞";
  return `${n.toFixed(1)} mo`;
}

export default async function FounderRunwayForecastV2Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, scRes] = await Promise.all([
    sb.rpc("founder_runway_forecast_v2_summary"),
    sb.rpc("founder_runway_forecast_v2_scenarios_recent", { p_limit: 50 }),
  ]);
  if (sRes.error) throw new Error(`runway_forecast_v2_summary: ${sRes.error.message}`);
  if (scRes.error) throw new Error(`runway_forecast_v2_scenarios_recent: ${scRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const scenarios = (scRes.data ?? []) as Scenario[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Runway forecast v2 ★ scenario planning</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          4 scenario kinds (base / upside / downside / stress) — register monthly burn + inflow assumptions, see runway months projected against current cash. Actuals last-30d vs base variance.
        </p>
      </header>

      {s ? (
        <>
          <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <Card label="Current cash" value={rup(s.current_cash_balance_rupees)} sub={s.days_since_snapshot !== null ? `${s.days_since_snapshot}d since snapshot` : "no snapshot"} />
            <Card label="Base runway" value={months(s.base_runway_months)} sub={s.base_zero_cash_date ?? "—"} tone={runwayTone(s.base_runway_months)} />
            <Card label="Actual burn 30d" value={rup(s.actual_burn_last_30d_rupees)} />
            <Card label="Actual net 30d" value={rup(s.actual_net_last_30d_rupees)} tone={s.actual_net_last_30d_rupees >= 0 ? "ok" : "danger"} />
          </section>

          <section>
            <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Scenario comparison</h2>
            <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
              <Card label="Base" value={months(s.base_runway_months)} tone={runwayTone(s.base_runway_months)} />
              <Card label="Upside" value={months(s.upside_runway_months)} tone={runwayTone(s.upside_runway_months)} />
              <Card label="Downside" value={months(s.downside_runway_months)} tone={runwayTone(s.downside_runway_months)} />
              <Card label="Stress" value={months(s.stress_runway_months)} tone={runwayTone(s.stress_runway_months)} />
            </div>
          </section>

          <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <Card label="Actual inflow 30d" value={rup(s.actual_inflow_last_30d_rupees)} />
            <Card label="Burn vs base variance" value={`${s.burn_vs_base_variance_pct.toFixed(1)}%`} tone={s.burn_vs_base_variance_pct > 10 ? "danger" : s.burn_vs_base_variance_pct > 0 ? "warn" : "ok"} />
            <Card label="Active scenarios" value={formatNumber(s.scenarios_active_count)} />
            <Card label="Longest runway scenario" value={s.longest_runway_scenario_label || "—"} />
          </section>
        </>
      ) : (
        <p className="text-sm text-[var(--color-muted)]">No data — register a base scenario via log_founder_runway_forecast_v2_register_scenario RPC.</p>
      )}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Registered scenarios ({scenarios.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Label</th>
                <th className="py-2 pr-3">Kind</th>
                <th className="py-2 pr-3 text-right">Monthly burn</th>
                <th className="py-2 pr-3 text-right">Monthly inflow</th>
                <th className="py-2 pr-3 text-right">Starting cash</th>
                <th className="py-2 pr-3">Active</th>
                <th className="py-2 pr-3">Registered</th>
              </tr>
            </thead>
            <tbody>
              {scenarios.map((sc) => (
                <tr key={sc.id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-mono">{sc.scenario_label}</td>
                  <td className="py-2 pr-3 text-xs">{sc.scenario_kind}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{rup(sc.assumed_monthly_burn_rupees)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{rup(sc.assumed_monthly_inflow_rupees)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{rup(sc.assumed_starting_cash_rupees)}</td>
                  <td className="py-2 pr-3 text-xs">{sc.is_active ? <span className="text-[var(--color-ok)]">✓</span> : "—"}</td>
                  <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{new Date(sc.created_at).toLocaleDateString("en-IN")}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
