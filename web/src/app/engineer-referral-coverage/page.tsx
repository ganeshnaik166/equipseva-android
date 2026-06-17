import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer referral coverage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { total_engineers: number; with_referrals: number; paid_referrals: number; coverage_pct: number; paid_pct: number };

export default async function EngineerReferralCoveragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_referral_coverage");
  if (error) throw new Error(`founder_engineer_referral_coverage: ${error.message}`);
  const r = ((data ?? [{}])[0] ?? {}) as Row;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer referral coverage</h1>
        <span className="text-xs text-[var(--color-muted)]">% of engineers who have referred ≥1 other</span>
      </header>
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-5">
        <StatCard label="Total engineers" value={formatNumber(r.total_engineers)} />
        <StatCard label="With ≥1 referral" value={formatNumber(r.with_referrals)} />
        <StatCard label="With ≥1 paid" value={formatNumber(r.paid_referrals)} />
        <StatCard label="Coverage %" value={`${r.coverage_pct}%`} />
        <StatCard label="Paid coverage %" value={`${r.paid_pct}%`} />
      </div>
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Network-effect gauge. Higher coverage = stronger word-of-mouth growth loop.
      </section>
    </div>
  );
}
