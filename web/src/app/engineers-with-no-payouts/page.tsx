import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Engineers with no payouts — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_engineers: number;
  verified_engineers: number;
  with_zero_payouts_ever: number;
  with_zero_payouts_pct: number;
  with_at_least_one_paid: number;
  with_only_failed_payouts: number;
};

function Card({ title, val, sub, danger }: { title: string; val: string; sub?: string; danger?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function EngineersWithNoPayoutsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineers_with_no_payouts");
  if (error) throw new Error(`founder_engineers_with_no_payouts: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineers with no payouts</h1>
        <span className="text-xs text-[var(--color-muted)]">Activation gap on the supply side · 5-card breakdown</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <Card title="Total engineers" val={formatNumber(r.total_engineers)} />
          <Card title="Verified engineers" val={formatNumber(r.verified_engineers)} />
          <Card title="With 0 payouts ever" val={formatNumber(r.with_zero_payouts_ever)} sub={formatPct(r.with_zero_payouts_pct / 100)} danger={r.with_zero_payouts_pct > 50} />
          <Card title="With ≥1 paid payout" val={formatNumber(r.with_at_least_one_paid)} />
          <Card title="Only failed payouts" val={formatNumber(r.with_only_failed_payouts)} sub="trust at risk" danger={r.with_only_failed_payouts > 0} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
