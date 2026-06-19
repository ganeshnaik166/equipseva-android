import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer tier progression — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_engineers_active: number;
  bronze_count: number; silver_count: number; gold_count: number; platinum_count: number;
  top_tier_engineer_user_id: string | null;
  top_tier_engineer_jobs_count: number | null;
  median_completed_jobs_per_engineer: number;
  total_completed_jobs_lifetime: number;
  generated_at: string;
};

type Climber = {
  engineer_user_id: string;
  current_tier: string;
  jobs_completed_total: number;
  last_completed_at: string | null;
  jobs_to_next_tier_estimate: number;
};

function Card({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function FounderEngineerTierProgressionPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, cRes] = await Promise.all([
    sb.rpc("founder_engineer_tier_progression_summary"),
    sb.rpc("founder_engineer_tier_progression_climbers", { p_limit: 30 }),
  ]);
  if (sRes.error) throw new Error(`tier_progression_summary: ${sRes.error.message}`);
  if (cRes.error) throw new Error(`tier_progression_climbers: ${cRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const climbers = (cRes.data ?? []) as Climber[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Engineer tier progression ★ tier ladder</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Active engineer distribution across bronze/silver/gold/platinum + top 30 climbers nearest to next-tier promotion. Tier thresholds: silver≥50 jobs, gold≥200, platinum≥500.
        </p>
      </header>

      {s ? (
        <>
          <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <Card label="Total active" value={formatNumber(s.total_engineers_active)} sub="verified engineers" />
            <Card label="Total jobs lifetime" value={formatNumber(s.total_completed_jobs_lifetime)} />
            <Card label="Median jobs / engineer" value={s.median_completed_jobs_per_engineer.toFixed(0)} />
            <Card label="Top engineer jobs" value={formatNumber(s.top_tier_engineer_jobs_count ?? 0)} />
          </section>

          <section>
            <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">By tier</h2>
            <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
              <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
                <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Bronze</div>
                <div className="mt-2 text-3xl font-semibold tabular-nums text-amber-700">{formatNumber(s.bronze_count)}</div>
              </div>
              <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
                <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Silver</div>
                <div className="mt-2 text-3xl font-semibold tabular-nums text-slate-500">{formatNumber(s.silver_count)}</div>
              </div>
              <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
                <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Gold</div>
                <div className="mt-2 text-3xl font-semibold tabular-nums text-yellow-600">{formatNumber(s.gold_count)}</div>
              </div>
              <div className="rounded-lg border border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
                <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Platinum</div>
                <div className="mt-2 text-3xl font-semibold tabular-nums text-[var(--color-ok)]">{formatNumber(s.platinum_count)}</div>
              </div>
            </div>
          </section>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Top 30 climbers (jobs to next tier)</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Engineer (user_id)</th>
                <th className="py-2 pr-3">Current tier</th>
                <th className="py-2 pr-3 text-right">Jobs done</th>
                <th className="py-2 pr-3 text-right">Jobs to next tier</th>
                <th className="py-2">Last completed</th>
              </tr>
            </thead>
            <tbody>
              {climbers.map((c) => (
                <tr key={c.engineer_user_id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{c.engineer_user_id.slice(0, 8)}</td>
                  <td className="py-2 pr-3 text-xs">{c.current_tier}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{formatNumber(c.jobs_completed_total)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums font-semibold">{formatNumber(c.jobs_to_next_tier_estimate)}</td>
                  <td className="py-2 text-xs text-[var(--color-muted)]">{c.last_completed_at ? new Date(c.last_completed_at).toLocaleDateString("en-IN") : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
