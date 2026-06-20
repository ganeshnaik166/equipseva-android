import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRelativeTime, shortId } from "@/lib/format";

export const metadata = { title: "Hospital chains deep drilldown — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_chains: number;
  prospecting_count: number;
  signed_count: number;
  live_count: number;
  churned_count: number;
  total_hospitals_under_chains: number;
  total_engineers_serving_chains: number;
  total_amc_mrr_from_chains_rupees: number;
  top_chain_by_hospital_count: string | null;
  top_chain_name: string | null;
  top_chain_hospital_count: number;
  avg_hospitals_per_chain: number;
  top_state_for_chains: string | null;
  conversion_pct_prospecting_to_live: number;
  days_to_signed_median: number;
  chain_revenue_concentration_top3_pct: number;
  chain_revenue_concentration_top10_pct: number;
  generated_at: string;
};

type ByChainRow = {
  chain_id: string;
  chain_name: string | null;
  status: string | null;
  total_hospitals_onboarded: number;
  total_active_amcs: number;
  total_mrr_rupees: number;
  last_activity_at: string | null;
  days_since_last_activity: number | null;
  churn_risk_band: string;
  primary_state: string | null;
};

type ConcentrationRow = {
  rank_pos: number;
  chain_id: string;
  chain_name: string | null;
  mrr_rupees: number;
  pct_of_total: number;
  cumulative_pct: number;
};

type TrendRow = { month_start: string; mrr_rupees: number; paid_orders: number };
type FunnelRow = { stage: string; current_count: number; avg_days_in_stage: number };

function Card({ title, val, sub, danger, ok, warn }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean; warn?: boolean }) {
  const color = danger ? "text-[var(--color-danger)]" : warn ? "text-[var(--color-warn)]" : ok ? "text-[var(--color-ok)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${color}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function StatusBadge({ s }: { s: string | null }) {
  const v = (s ?? "").toLowerCase();
  const cls =
    v === "live" || v === "active"
      ? "bg-green-100 text-[var(--color-ok)]"
      : v === "churned" || v === "offboarded"
        ? "bg-red-100 text-[var(--color-danger)]"
        : v === "paused" || v === "prospecting"
          ? "bg-yellow-100 text-[var(--color-warn)]"
          : "bg-gray-100 text-[var(--color-muted)]";
  return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{s ?? "—"}</span>;
}

function RiskBadge({ r }: { r: string }) {
  const cls =
    r === "high" ? "bg-red-100 text-[var(--color-danger)]"
      : r === "medium" ? "bg-yellow-100 text-[var(--color-warn)]"
        : "bg-green-100 text-[var(--color-ok)]";
  return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r}</span>;
}

export default async function FounderHospitalChainsDeepDrilldownPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, chRes, conRes, trRes, fnRes] = await Promise.all([
    supabase.rpc("founder_hospital_chains_drilldown_summary"),
    supabase.rpc("founder_hospital_chains_drilldown_by_chain", { p_limit: 30 }),
    supabase.rpc("founder_hospital_chains_drilldown_concentration_risk"),
    supabase.rpc("founder_hospital_chains_drilldown_revenue_trend", { p_months: 12 }),
    supabase.rpc("founder_hospital_chains_drilldown_funnel_velocity"),
  ]);
  if (sumRes.error) throw new Error(`drilldown_summary: ${sumRes.error.message}`);
  if (chRes.error)  throw new Error(`drilldown_by_chain: ${chRes.error.message}`);
  if (conRes.error) throw new Error(`drilldown_concentration_risk: ${conRes.error.message}`);
  if (trRes.error)  throw new Error(`drilldown_revenue_trend: ${trRes.error.message}`);
  if (fnRes.error)  throw new Error(`drilldown_funnel_velocity: ${fnRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as SummaryRow | null;
  const chains  = (chRes.data ?? []) as ByChainRow[];
  const conc    = (conRes.data ?? []) as ConcentrationRow[];
  const trend   = (trRes.data ?? []) as TrendRow[];
  const funnel  = (fnRes.data ?? []) as FunnelRow[];

  const trendMax = Math.max(1, ...trend.map((t) => Number(t.mrr_rupees) || 0));

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between gap-4">
        <h1 className="text-xl font-semibold">Hospital chains deep drilldown</h1>
        <span className="text-xs text-[var(--color-muted)]">
          18 KPIs · 30-chain table · top-10 concentration · 12mo MRR trend · funnel velocity · pure read aggregator
        </span>
      </header>

      {s ? (
        <section>
          <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Portfolio summary</h2>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
            <Card title="Total chains"               val={formatNumber(s.total_chains)} />
            <Card title="Prospecting"                val={formatNumber(s.prospecting_count)} warn />
            <Card title="Signed"                     val={formatNumber(s.signed_count)} />
            <Card title="Live"                       val={formatNumber(s.live_count)} ok />
            <Card title="Churned"                    val={formatNumber(s.churned_count)} danger={s.churned_count > 0} />
            <Card title="Hospitals under chains"     val={formatNumber(s.total_hospitals_under_chains)} />
            <Card title="Engineers serving chains"   val={formatNumber(s.total_engineers_serving_chains)} sub="distinct, 90d" />
            <Card title="AMC MRR from chains (INR)"  val={formatNumber(s.total_amc_mrr_from_chains_rupees)} ok />
            <Card title="Top chain"                  val={s.top_chain_name ?? "—"} sub="by hospital count" />
            <Card title="Top chain hospital count"   val={formatNumber(s.top_chain_hospital_count)} />
            <Card title="Avg hospitals / chain"      val={Number(s.avg_hospitals_per_chain).toFixed(2)} />
            <Card title="Top state"                  val={s.top_state_for_chains ?? "—"} sub="member concentration" />
            <Card title="Conversion prospect→live"   val={`${Number(s.conversion_pct_prospecting_to_live).toFixed(1)}%`}
                  ok={s.conversion_pct_prospecting_to_live >= 50} danger={s.conversion_pct_prospecting_to_live < 20} />
            <Card title="Median days to signed"      val={Number(s.days_to_signed_median).toFixed(1)} sub="sales cycle" />
            <Card title="Top-3 MRR concentration"    val={`${Number(s.chain_revenue_concentration_top3_pct).toFixed(1)}%`}
                  danger={s.chain_revenue_concentration_top3_pct >= 60} warn={s.chain_revenue_concentration_top3_pct >= 40} />
            <Card title="Top-10 MRR concentration"   val={`${Number(s.chain_revenue_concentration_top10_pct).toFixed(1)}%`}
                  danger={s.chain_revenue_concentration_top10_pct >= 80} warn={s.chain_revenue_concentration_top10_pct >= 60} />
            <Card title="Top-chain id"               val={shortId(s.top_chain_by_hospital_count ?? "")} sub="for ops links" />
            <Card title="Generated"                  val={formatRelativeTime(s.generated_at)} sub={s.generated_at} />
          </div>
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No summary data.</p>}

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Per-chain drilldown (top 30 by MRR)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)] text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Chain</th>
                <th className="px-3 py-2 text-left">Status</th>
                <th className="px-3 py-2 text-right">Hospitals</th>
                <th className="px-3 py-2 text-right">Active AMCs</th>
                <th className="px-3 py-2 text-right">MRR (INR)</th>
                <th className="px-3 py-2 text-left">Last activity</th>
                <th className="px-3 py-2 text-right">Days idle</th>
                <th className="px-3 py-2 text-left">Churn risk</th>
                <th className="px-3 py-2 text-left">Primary state</th>
              </tr>
            </thead>
            <tbody>
              {chains.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={9}>No chains.</td></tr>
              ) : chains.map((c) => (
                <tr key={c.chain_id} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">{c.chain_name ?? "—"}</td>
                  <td className="px-3 py-2"><StatusBadge s={c.status} /></td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(c.total_hospitals_onboarded)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(c.total_active_amcs)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(c.total_mrr_rupees)}</td>
                  <td className="px-3 py-2">{c.last_activity_at ? formatRelativeTime(c.last_activity_at) : "—"}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{c.days_since_last_activity == null ? "—" : c.days_since_last_activity.toFixed(1)}</td>
                  <td className="px-3 py-2"><RiskBadge r={c.churn_risk_band} /></td>
                  <td className="px-3 py-2">{c.primary_state ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Revenue concentration risk (top 10 chains by MRR)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)] text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-right">#</th>
                <th className="px-3 py-2 text-left">Chain</th>
                <th className="px-3 py-2 text-right">MRR (INR)</th>
                <th className="px-3 py-2 text-right">% of total</th>
                <th className="px-3 py-2 text-right">Cumulative %</th>
              </tr>
            </thead>
            <tbody>
              {conc.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={5}>No data.</td></tr>
              ) : conc.map((r) => (
                <tr key={r.chain_id} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2 text-right tabular-nums">{r.rank_pos}</td>
                  <td className="px-3 py-2">{r.chain_name ?? "—"}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.mrr_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{Number(r.pct_of_total).toFixed(2)}%</td>
                  <td className="px-3 py-2 text-right tabular-nums">{Number(r.cumulative_pct).toFixed(2)}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">12-month MRR trend from chains</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
          <table className="min-w-full text-sm">
            <thead className="text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Month</th>
                <th className="px-3 py-2 text-right">Paid (INR)</th>
                <th className="px-3 py-2 text-right">Orders</th>
                <th className="px-3 py-2 text-left">Trend</th>
              </tr>
            </thead>
            <tbody>
              {trend.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={4}>No data.</td></tr>
              ) : trend.map((t) => {
                const pct = Math.max(2, Math.round((Number(t.mrr_rupees) / trendMax) * 100));
                return (
                  <tr key={t.month_start} className="border-t border-[var(--color-border)]">
                    <td className="px-3 py-2 tabular-nums">{t.month_start}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatNumber(t.mrr_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatNumber(t.paid_orders)}</td>
                    <td className="px-3 py-2">
                      <div className="h-2 w-full rounded bg-[var(--color-border)]">
                        <div className="h-2 rounded bg-[var(--color-ok)]" style={{ width: `${pct}%` }} />
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Funnel velocity (avg days currently in stage)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)] text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Stage</th>
                <th className="px-3 py-2 text-right">Chains in stage</th>
                <th className="px-3 py-2 text-right">Avg days in stage</th>
              </tr>
            </thead>
            <tbody>
              {funnel.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={3}>No data.</td></tr>
              ) : funnel.map((f) => (
                <tr key={f.stage} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2"><StatusBadge s={f.stage} /></td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(f.current_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{Number(f.avg_days_in_stage).toFixed(1)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
