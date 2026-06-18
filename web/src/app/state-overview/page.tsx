import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "State overview — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type JobsRow = { state: string; hospital_cnt: number; jobs_90d: number; gross_rupees: number; active_amc_cnt: number };
type SignupsRow = { state: string; total_90d: number; engineers_90d: number; hospitals_90d: number };
type AmcRow = { state: string; hospital_cnt: number; paid_orders: number; paid_rupees: number };
type PoolRow = { state: string; contracts: number; total_balance: number; mrr: number };

async function tryRpc<T>(supabase: Awaited<ReturnType<typeof getSupabaseServerClient>>, fn: string): Promise<T[]> {
  const { data, error } = await supabase.rpc(fn);
  if (error) return [];
  return (data ?? []) as T[];
}

export default async function StateOverviewPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [jobs, signups, amc, pool] = await Promise.all([
    tryRpc<JobsRow>(supabase, "founder_jobs_by_state"),
    tryRpc<SignupsRow>(supabase, "founder_signups_by_state"),
    tryRpc<AmcRow>(supabase, "founder_amc_revenue_by_state"),
    tryRpc<PoolRow>(supabase, "founder_amc_pool_balance_by_state"),
  ]);

  // Build unified map: state → {jobs90, signups90, amcPaid90, poolBalance}
  type Combined = { state: string; jobs90: number; signups90: number; amcPaid90: number; poolBalance: number; amcCount: number };
  const m = new Map<string, Combined>();
  const ensure = (s: string): Combined => {
    if (!m.has(s)) m.set(s, { state: s, jobs90: 0, signups90: 0, amcPaid90: 0, poolBalance: 0, amcCount: 0 });
    return m.get(s)!;
  };
  for (const r of jobs) { const x = ensure(r.state); x.jobs90 = r.jobs_90d; x.amcCount = r.active_amc_cnt; }
  for (const r of signups) { ensure(r.state).signups90 = r.total_90d; }
  for (const r of amc) { ensure(r.state).amcPaid90 = r.paid_rupees; }
  for (const r of pool) { ensure(r.state).poolBalance = r.total_balance; }

  const allStates = Array.from(m.values()).sort((a, b) => b.amcPaid90 - a.amcPaid90).slice(0, 20);

  return (
    <div className="space-y-8">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">State overview ★</h1>
        <span className="text-xs text-[var(--color-muted)]">r925 / PR #1550 milestone · all-state founder dashboard</span>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">Top 20 states (90d AMC paid)</h2>
        <table className="w-full text-xs">
          <thead>
            <tr className="border-b border-[var(--color-border)]">
              <th className="px-2 py-2 text-left">State</th>
              <th className="px-2 py-2 text-right">Signups 90d</th>
              <th className="px-2 py-2 text-right">Jobs 90d</th>
              <th className="px-2 py-2 text-right">Active AMCs</th>
              <th className="px-2 py-2 text-right">AMC paid 90d (₹)</th>
              <th className="px-2 py-2 text-right">Pool balance (₹)</th>
            </tr>
          </thead>
          <tbody>
            {allStates.map((s) => (
              <tr key={s.state} className="border-b border-[var(--color-border)] hover:bg-[var(--color-bg)]">
                <td className="px-2 py-2 font-semibold">{s.state}</td>
                <td className="px-2 py-2 text-right tabular-nums">{formatNumber(s.signups90)}</td>
                <td className="px-2 py-2 text-right tabular-nums">{formatNumber(s.jobs90)}</td>
                <td className="px-2 py-2 text-right tabular-nums text-[var(--color-ok)]">{formatNumber(s.amcCount)}</td>
                <td className="px-2 py-2 text-right tabular-nums font-semibold">{formatNumber(s.amcPaid90)}</td>
                <td className="px-2 py-2 text-right tabular-nums">{formatNumber(s.poolBalance)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="grid grid-cols-1 gap-3 md:grid-cols-2">
        <Link href="/jobs-by-state" className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
          <div className="text-sm font-semibold">Jobs by state →</div>
          <div className="text-xs text-[var(--color-muted)]">r920 · Top 40 states + AMC count</div>
        </Link>
        <Link href="/signups-by-state" className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
          <div className="text-sm font-semibold">Signups by state →</div>
          <div className="text-xs text-[var(--color-muted)]">r922 · 90d engineer + hospital split</div>
        </Link>
        <Link href="/amc-revenue-by-state" className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
          <div className="text-sm font-semibold">AMC revenue by state →</div>
          <div className="text-xs text-[var(--color-muted)]">r923 · 90d paid revenue</div>
        </Link>
        <Link href="/amc-pool-balance-by-state" className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
          <div className="text-sm font-semibold">AMC pool balance by state →</div>
          <div className="text-xs text-[var(--color-muted)]">r924 · Active pool balance + MRR</div>
        </Link>
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Why this page.</strong> 4 state-level RPCs from r920/r922/r923/r924 joined into one table. Sort signal = 90d AMC paid revenue (the recurring-revenue North Star). Use to decide which states deserve sales / KYC / supply concentration next quarter.
      </section>
    </div>
  );
}
