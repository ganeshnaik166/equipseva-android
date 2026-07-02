import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bonded parts supply chain v2 — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_bonded_suppliers: number;
  dental_supplier_count: number;
  lab_supplier_count: number;
  cross_vertical_supplier_count: number;
  signed_count: number;
  pending_count: number;
  active_count: number;
  revoked_count: number;
  total_bond_value_rupees: number;
  avg_bond_amount_rupees: number;
  top_supplier_name: string | null;
  top_supplier_orders_count: number;
  total_orders_via_bonded_30d: number;
  avg_delivery_days: number;
  on_time_pct: number;
  supplier_dependency_top3_pct: number;
  single_source_risk_count: number;
  avg_parts_per_supplier: number;
  longest_relationship_days: number;
  total_spare_part_volume_30d_rupees: number;
  expiring_bonds_60d_count: number;
  generated_at: string;
};

type ByVertical = {
  vertical: string;
  supplier_count: number;
  signed_count: number;
  total_bond_rupees: number;
  recent_order_count: number;
  avg_order_amount: number;
};

type TopSupplier = {
  supplier_org_id: string;
  supplier_name: string;
  vertical: string;
  bonded_status: string | null;
  total_bond: number;
  orders_count: number;
  total_amount: number;
  last_order_at: string | null;
};

type Concentration = {
  rank_no: number;
  supplier_org_id: string;
  supplier_name: string;
  volume_rupees: number;
  pct_of_total: number;
  cumulative_pct: number;
};

type TrendRow = { month_label: string; order_count: number; total_amount: number; distinct_suppliers: number };
type AtRisk = {
  supplier_org_id: string;
  supplier_name: string;
  vertical: string;
  bonded_status: string | null;
  bond_expires_at: string | null;
  days_to_expiry: number | null;
  pending_days: number | null;
  risk_reason: string;
};

const inr = (n: number) => `₹${Number(n ?? 0).toLocaleString("en-IN")}`;
const pct = (n: number) => `${Number(n ?? 0).toFixed(2)}%`;

function Card({ title, val, sub, danger, ok, warn }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean; warn?: boolean }) {
  const color = danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : warn ? "text-[var(--color-warn)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${color}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function FounderBondedPartsSupplyChainV2Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, vertRes, topRes, concRes, trendRes, riskRes] = await Promise.all([
    supabase.rpc("founder_bonded_parts_supply_chain_v2_summary"),
    supabase.rpc("founder_bonded_parts_v2_by_vertical"),
    supabase.rpc("founder_bonded_parts_v2_top_suppliers", { p_limit: 30 }),
    supabase.rpc("founder_bonded_parts_v2_concentration_risk"),
    supabase.rpc("founder_bonded_parts_v2_order_trend", { p_months: 12 }),
    supabase.rpc("founder_bonded_parts_v2_at_risk_suppliers"),
  ]);
  if (summaryRes.error) throw new Error(`summary: ${summaryRes.error.message}`);
  if (vertRes.error) throw new Error(`by_vertical: ${vertRes.error.message}`);
  if (topRes.error) throw new Error(`top_suppliers: ${topRes.error.message}`);
  if (concRes.error) throw new Error(`concentration: ${concRes.error.message}`);
  if (trendRes.error) throw new Error(`trend: ${trendRes.error.message}`);
  if (riskRes.error) throw new Error(`at_risk: ${riskRes.error.message}`);

  const s = ((summaryRes.data?.[0] ?? null) as Summary | null);
  const verticals = (vertRes.data ?? []) as ByVertical[];
  const tops = (topRes.data ?? []) as TopSupplier[];
  const conc = (concRes.data ?? []) as Concentration[];
  const trend = (trendRes.data ?? []) as TrendRow[];
  const risk = (riskRes.data ?? []) as AtRisk[];

  const maxTrendAmt = Math.max(1, ...trend.map((t) => Number(t.total_amount || 0)));

  return (
    <div className="space-y-8">
      <header className="flex items-baseline justify-between flex-wrap gap-2">
        <h1 className="text-xl font-semibold">Bonded parts supply chain v2</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Unified rollup across dental + lab diagnostics · 18 KPIs · vertical mix · top 30 · concentration risk · 12mo trend · at-risk pile
        </span>
      </header>

      {s ? (
        <section className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total bonded suppliers" val={formatNumber(s.total_bonded_suppliers)} sub={`dental ${s.dental_supplier_count} · lab ${s.lab_supplier_count} · cross ${s.cross_vertical_supplier_count}`} />
          <Card title="Signed" val={formatNumber(s.signed_count)} ok />
          <Card title="Pending" val={formatNumber(s.pending_count)} warn={s.pending_count > 0} />
          <Card title="Active" val={formatNumber(s.active_count)} ok />
          <Card title="Revoked" val={formatNumber(s.revoked_count)} danger={s.revoked_count > 0} />
          <Card title="Total bond value" val={inr(s.total_bond_value_rupees)} />
          <Card title="Avg bond amount" val={inr(s.avg_bond_amount_rupees)} sub="across signed suppliers" />
          <Card title="Top supplier" val={s.top_supplier_name ?? "—"} sub={`${formatNumber(s.top_supplier_orders_count)} orders 30d`} />
          <Card title="Orders via bonded 30d" val={formatNumber(s.total_orders_via_bonded_30d)} />
          <Card title="Avg delivery days" val={`${Number(s.avg_delivery_days ?? 0).toFixed(1)}`} sub="delivered orders 90d" />
          <Card title="On-time % (≤7d)" val={pct(s.on_time_pct)} ok={s.on_time_pct >= 80} danger={s.on_time_pct < 50} />
          <Card title="Top-3 dependency" val={pct(s.supplier_dependency_top3_pct)} warn={s.supplier_dependency_top3_pct >= 60} danger={s.supplier_dependency_top3_pct >= 80} sub="paid volume 30d" />
          <Card title="Single-source categories" val={formatNumber(s.single_source_risk_count)} danger={s.single_source_risk_count > 0} sub="only 1 bonded supplier" />
          <Card title="Avg parts / supplier" val={Number(s.avg_parts_per_supplier ?? 0).toFixed(2)} sub="supported_categories" />
          <Card title="Longest relationship" val={`${formatNumber(s.longest_relationship_days)}d`} />
          <Card title="Bonded GMV 30d" val={inr(s.total_spare_part_volume_30d_rupees)} ok />
          <Card title="Bonds expiring ≤60d" val={formatNumber(s.expiring_bonds_60d_count)} danger={s.expiring_bonds_60d_count > 0} />
          <Card title="Generated" val={new Date(s.generated_at).toLocaleString("en-IN")} sub="server-side · live RPC" />
        </section>
      ) : (
        <p className="text-sm text-[var(--color-muted)]">No data.</p>
      )}

      <section>
        <h2 className="text-sm font-semibold mb-2">By vertical</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)]">
              <tr>
                <th className="px-3 py-2 text-left">Vertical</th>
                <th className="px-3 py-2 text-right">Suppliers</th>
                <th className="px-3 py-2 text-right">Signed</th>
                <th className="px-3 py-2 text-right">Total bond</th>
                <th className="px-3 py-2 text-right">Orders 30d</th>
                <th className="px-3 py-2 text-right">Avg order</th>
              </tr>
            </thead>
            <tbody>
              {verticals.length === 0 ? (
                <tr><td colSpan={6} className="px-3 py-3 text-center text-[var(--color-muted)]">No verticals.</td></tr>
              ) : verticals.map((v) => (
                <tr key={v.vertical} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2 font-medium">{v.vertical}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(v.supplier_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(v.signed_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{inr(v.total_bond_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(v.recent_order_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{inr(v.avg_order_amount)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-2">Top 30 bonded suppliers (cross-vertical merged · ordered by spare-parts GMV)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)]">
              <tr>
                <th className="px-3 py-2 text-left">Supplier</th>
                <th className="px-3 py-2 text-left">Vertical</th>
                <th className="px-3 py-2 text-left">Bond status</th>
                <th className="px-3 py-2 text-right">Bond ₹</th>
                <th className="px-3 py-2 text-right">Orders</th>
                <th className="px-3 py-2 text-right">GMV</th>
                <th className="px-3 py-2 text-right">Last order</th>
              </tr>
            </thead>
            <tbody>
              {tops.length === 0 ? (
                <tr><td colSpan={7} className="px-3 py-3 text-center text-[var(--color-muted)]">No suppliers.</td></tr>
              ) : tops.map((t) => (
                <tr key={t.supplier_org_id} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">{t.supplier_name}</td>
                  <td className="px-3 py-2">{t.vertical}</td>
                  <td className="px-3 py-2">{t.bonded_status ?? "—"}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{inr(t.total_bond)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(t.orders_count)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{inr(t.total_amount)}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--color-muted)]">{t.last_order_at ? new Date(t.last_order_at).toLocaleDateString("en-IN") : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-2">Concentration risk (top-10 paid 90d)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)]">
              <tr>
                <th className="px-3 py-2 text-right">#</th>
                <th className="px-3 py-2 text-left">Supplier</th>
                <th className="px-3 py-2 text-right">Volume</th>
                <th className="px-3 py-2 text-right">% total</th>
                <th className="px-3 py-2 text-right">Cumulative %</th>
              </tr>
            </thead>
            <tbody>
              {conc.length === 0 ? (
                <tr><td colSpan={5} className="px-3 py-3 text-center text-[var(--color-muted)]">No paid orders 90d.</td></tr>
              ) : conc.map((c) => (
                <tr key={`${c.rank_no}-${c.supplier_org_id}`} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2 text-right tabular-nums">{c.rank_no}</td>
                  <td className="px-3 py-2">{c.supplier_name}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{inr(c.volume_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{pct(c.pct_of_total)}</td>
                  <td className={`px-3 py-2 text-right tabular-nums ${c.cumulative_pct >= 80 ? "text-[var(--color-danger)]" : ""}`}>{pct(c.cumulative_pct)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-2">12-month order trend (bonded suppliers only)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)]">
              <tr>
                <th className="px-3 py-2 text-left">Month</th>
                <th className="px-3 py-2 text-right">Orders</th>
                <th className="px-3 py-2 text-right">GMV</th>
                <th className="px-3 py-2 text-right">Distinct suppliers</th>
                <th className="px-3 py-2 text-left">Volume</th>
              </tr>
            </thead>
            <tbody>
              {trend.length === 0 ? (
                <tr><td colSpan={5} className="px-3 py-3 text-center text-[var(--color-muted)]">No trend.</td></tr>
              ) : trend.map((row) => {
                const w = Math.round((Number(row.total_amount || 0) / maxTrendAmt) * 100);
                return (
                  <tr key={row.month_label} className="border-t border-[var(--color-border)]">
                    <td className="px-3 py-2 tabular-nums">{row.month_label}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatNumber(row.order_count)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{inr(row.total_amount)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatNumber(row.distinct_suppliers)}</td>
                    <td className="px-3 py-2">
                      <div className="h-2 rounded bg-[var(--color-border)]">
                        <div className="h-2 rounded bg-[var(--color-ok)]" style={{ width: `${w}%` }} />
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
        <h2 className="text-sm font-semibold mb-2">At-risk suppliers (bond expiring ≤60d OR pending {">"}30d)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)]">
              <tr>
                <th className="px-3 py-2 text-left">Supplier</th>
                <th className="px-3 py-2 text-left">Vertical</th>
                <th className="px-3 py-2 text-left">Status</th>
                <th className="px-3 py-2 text-right">Days → expiry</th>
                <th className="px-3 py-2 text-right">Pending days</th>
                <th className="px-3 py-2 text-left">Risk reason</th>
              </tr>
            </thead>
            <tbody>
              {risk.length === 0 ? (
                <tr><td colSpan={6} className="px-3 py-3 text-center text-[var(--color-muted)]">No at-risk suppliers — supply chain healthy.</td></tr>
              ) : risk.map((r) => (
                <tr key={`${r.supplier_org_id}-${r.risk_reason}`} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">{r.supplier_name}</td>
                  <td className="px-3 py-2">{r.vertical}</td>
                  <td className="px-3 py-2">{r.bonded_status ?? "—"}</td>
                  <td className={`px-3 py-2 text-right tabular-nums ${r.days_to_expiry !== null && r.days_to_expiry <= 30 ? "text-[var(--color-danger)]" : ""}`}>{r.days_to_expiry ?? "—"}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{r.pending_days ?? "—"}</td>
                  <td className="px-3 py-2 text-[var(--color-warn)]">{r.risk_reason}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
