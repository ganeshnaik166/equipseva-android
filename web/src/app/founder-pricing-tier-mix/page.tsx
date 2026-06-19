import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Pricing tier mix — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_active_contracts: number;
  starter_count: number; growth_count: number; enterprise_count: number;
  starter_pct: number; growth_pct: number; enterprise_pct: number;
  starter_mrr_rupees: number; growth_mrr_rupees: number; enterprise_mrr_rupees: number;
  total_mrr_rupees: number;
  enterprise_mrr_pct: number;
  avg_revenue_per_contract_rupees: number;
  generated_at: string;
};

type Hist = {
  month_start: string;
  starter_count: number; growth_count: number; enterprise_count: number;
  total_mrr_rupees: number;
  enterprise_mrr_pct: number;
};

function Card({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)] tabular-nums">{sub}</div> : null}
    </div>
  );
}

function rup(n: number): string { return `₹${formatNumber(Math.round(n))}`; }

export default async function FounderPricingTierMixPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, hRes] = await Promise.all([
    sb.rpc("founder_pricing_tier_mix_summary"),
    sb.rpc("founder_pricing_tier_mix_history", { p_months: 12 }),
  ]);
  if (sRes.error) throw new Error(`tier_mix_summary: ${sRes.error.message}`);
  if (hRes.error) throw new Error(`tier_mix_history: ${hRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const history = (hRes.data ?? []) as Hist[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Pricing tier mix ★ 14 KPIs</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Active AMC contracts by tier · MRR contribution per tier · 12-month evolution of tier distribution. Enterprise-MRR pct is the headline number to watch for upmarket motion.
        </p>
      </header>

      {s ? (
        <>
          <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <Card label="Total active" value={formatNumber(s.total_active_contracts)} />
            <Card label="Total MRR" value={rup(s.total_mrr_rupees)} sub="across all tiers" />
            <Card label="Enterprise MRR pct" value={`${s.enterprise_mrr_pct.toFixed(1)}%`} sub="upmarket signal" />
            <Card label="Avg revenue / contract" value={rup(s.avg_revenue_per_contract_rupees)} />
          </section>

          <section>
            <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">By tier</h2>
            <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
              <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
                <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Starter</div>
                <div className="mt-2 text-3xl font-semibold tabular-nums">{formatNumber(s.starter_count)}</div>
                <div className="mt-1 text-xs text-[var(--color-muted)] tabular-nums">{s.starter_pct.toFixed(1)}% of contracts · {rup(s.starter_mrr_rupees)} MRR</div>
              </div>
              <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
                <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Growth</div>
                <div className="mt-2 text-3xl font-semibold tabular-nums">{formatNumber(s.growth_count)}</div>
                <div className="mt-1 text-xs text-[var(--color-muted)] tabular-nums">{s.growth_pct.toFixed(1)}% of contracts · {rup(s.growth_mrr_rupees)} MRR</div>
              </div>
              <div className="rounded-lg border border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
                <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Enterprise</div>
                <div className="mt-2 text-3xl font-semibold tabular-nums text-[var(--color-ok)]">{formatNumber(s.enterprise_count)}</div>
                <div className="mt-1 text-xs text-[var(--color-muted)] tabular-nums">{s.enterprise_pct.toFixed(1)}% of contracts · {rup(s.enterprise_mrr_rupees)} MRR</div>
              </div>
            </div>
          </section>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">12-month history ({history.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Month</th>
                <th className="py-2 pr-3 text-right">Starter</th>
                <th className="py-2 pr-3 text-right">Growth</th>
                <th className="py-2 pr-3 text-right">Enterprise</th>
                <th className="py-2 pr-3 text-right">Total MRR</th>
                <th className="py-2 text-right">Enterprise MRR%</th>
              </tr>
            </thead>
            <tbody>
              {history.map((h) => (
                <tr key={h.month_start} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-mono">{h.month_start}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{formatNumber(h.starter_count)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{formatNumber(h.growth_count)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums font-semibold">{formatNumber(h.enterprise_count)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{rup(h.total_mrr_rupees)}</td>
                  <td className="py-2 text-xs text-right tabular-nums">{h.enterprise_mrr_pct.toFixed(1)}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
