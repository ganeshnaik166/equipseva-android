import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Founder critical cockpit ★ r1000 — EquipSeva" };
export const dynamic = "force-dynamic";

type Row = {
  payouts_stuck_over_7d: number;
  payouts_stuck_inr: number;
  code_red_stuck_over_4h: number;
  spare_parts_stuck_over_7d: number;
  spare_parts_stuck_inr: number;
  jobs_unassigned_over_1d: number;
  bids_stuck_over_1d: number;
  escrow_held_over_14d: number;
  escrow_held_inr: number;
  engineers_no_jobs_90d: number;
  hospitals_no_jobs_90d: number;
  amc_renewing_30d: number;
  amc_renewing_mrr_inr: number;
};

function Tile({ href, label, count, sub, danger }: { href: string; label: string; count: number; sub?: string; danger?: boolean }) {
  return (
    <Link
      href={href}
      className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]"
    >
      <div className="text-xs text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-3xl font-semibold tabular-nums ${danger && count > 0 ? "text-[var(--color-danger)]" : count > 0 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]"}`}>
        {formatNumber(count)}
      </div>
      {sub ? <div className="mt-1 text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </Link>
  );
}

export default async function CriticalCockpitPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_critical_cockpit");
  if (error) throw new Error(`founder_critical_cockpit: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Founder critical cockpit ★ r1000 milestone</h1>
        <span className="text-xs text-[var(--color-muted)]">12 cross-system aging/leak signals · click any tile for drill-down</span>
      </header>
      {r ? (
        <>
          <section className="space-y-2">
            <h2 className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Trust at risk</h2>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <Tile href="/payouts-stuck-aging" label="Payouts stuck >7d" count={r.payouts_stuck_over_7d} sub={formatRupees(Number(r.payouts_stuck_inr))} danger />
              <Tile href="/code-red-aging" label="Code Red stuck >4h" count={r.code_red_stuck_over_4h} sub="life-safety SLA breach" danger />
              <Tile href="/spare-parts-stuck-aging" label="Spare parts unshipped >7d" count={r.spare_parts_stuck_over_7d} sub={formatRupees(Number(r.spare_parts_stuck_inr))} danger />
              <Tile href="/escrow-held-aging" label="Escrow held >14d" count={r.escrow_held_over_14d} sub={formatRupees(Number(r.escrow_held_inr))} danger />
            </div>
          </section>
          <section className="space-y-2">
            <h2 className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Marketplace liquidity</h2>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <Tile href="/jobs-unassigned-aging" label="Jobs unassigned >1d" count={r.jobs_unassigned_over_1d} sub="demand outpacing supply" />
              <Tile href="/bids-stuck-aging" label="Bids no decision >1d" count={r.bids_stuck_over_1d} sub="engineer trust signal" />
              <Tile href="/engineers-no-jobs-30d" label="Engineers no jobs 90d" count={r.engineers_no_jobs_90d} sub="dormant supply" />
              <Tile href="/hospitals-no-jobs-30d" label="Hospitals no jobs 90d" count={r.hospitals_no_jobs_90d} sub="dormant demand" />
            </div>
          </section>
          <section className="space-y-2">
            <h2 className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Revenue protection</h2>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <Tile href="/amc-renewal-window-30d" label="AMCs renewing 30d" count={r.amc_renewing_30d} sub={`MRR at risk ${formatRupees(Number(r.amc_renewing_mrr_inr))}`} />
            </div>
          </section>
        </>
      ) : (
        <p className="text-sm text-[var(--color-muted)]">No cockpit data.</p>
      )}
    </div>
  );
}
