import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer utilization — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_active_engineers: number;
  engineers_with_zero_jobs_30d: number;
  engineers_with_zero_jobs_90d: number;
  workhorse_count: number;
  avg_jobs_per_engineer_30d: number;
  median_jobs_per_engineer_30d: number;
  p90_jobs_per_engineer_30d: number;
  top_engineer_jobs_30d: number;
  total_jobs_30d: number;
  total_jobs_completed_lifetime: number;
  engineers_active_in_30d: number;
  active_engagement_pct: number;
  generated_at: string;
};
type Row = {
  engineer_user_id: string; cached_highest_tier: string;
  jobs_30d: number; jobs_90d: number; jobs_lifetime: number;
  last_completed_at: string | null;
  utilization_band: string;
};

function Card({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "ok" | "warn" | "danger" }) {
  const toneClass = tone === "ok" ? "text-[var(--color-ok)]" : tone === "warn" ? "text-[var(--color-warn)]" : tone === "danger" ? "text-[var(--color-danger)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${toneClass}`}>{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)] tabular-nums">{sub}</div> : null}
    </div>
  );
}

function bandTone(b: string): "ok" | "warn" | "danger" | undefined {
  if (b === "workhorse" || b === "active") return "ok";
  if (b === "low") return "warn";
  if (b === "idle") return "danger";
  return undefined;
}

export default async function FounderEngineerUtilizationPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, rRes] = await Promise.all([
    sb.rpc("founder_engineer_utilization_summary"),
    sb.rpc("founder_engineer_utilization_by_engineer", { p_limit: 100 }),
  ]);
  if (sRes.error) throw new Error(`utilization_summary: ${sRes.error.message}`);
  if (rRes.error) throw new Error(`utilization_by_engineer: ${rRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const rows = (rRes.data ?? []) as Row[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Engineer utilization ★ 12 KPIs</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Active engineer utilization signal · jobs completed 30d/90d/lifetime · band: idle (0), low (1-2), normal (3-9), active (10-19), workhorse (≥20). p90 = top decile threshold. Active engagement pct = engineers w/ ≥1 job in 30d.
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Total active" value={formatNumber(s.total_active_engineers)} sub="verified" />
          <Card label="Active in 30d" value={formatNumber(s.engineers_active_in_30d)} sub={`${s.active_engagement_pct.toFixed(1)}%`} tone="ok" />
          <Card label="Idle 30d" value={formatNumber(s.engineers_with_zero_jobs_30d)} tone="danger" />
          <Card label="Idle 90d" value={formatNumber(s.engineers_with_zero_jobs_90d)} sub="dormant supply" tone="danger" />
          <Card label="Workhorses" value={formatNumber(s.workhorse_count)} sub="top decile (p90+)" tone="ok" />
          <Card label="Avg jobs / engineer 30d" value={s.avg_jobs_per_engineer_30d.toFixed(1)} />
          <Card label="Median jobs 30d" value={s.median_jobs_per_engineer_30d.toFixed(0)} />
          <Card label="p90 jobs 30d" value={s.p90_jobs_per_engineer_30d.toFixed(0)} />
          <Card label="Top engineer 30d" value={formatNumber(s.top_engineer_jobs_30d)} />
          <Card label="Total jobs 30d" value={formatNumber(s.total_jobs_30d)} />
          <Card label="Total jobs lifetime" value={formatNumber(s.total_jobs_completed_lifetime)} />
          <Card label="Generated" value={new Date(s.generated_at).toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" })} sub="IST" />
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Top 100 engineers ({rows.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Engineer</th>
                <th className="py-2 pr-3">Tier</th>
                <th className="py-2 pr-3 text-right">Jobs 30d</th>
                <th className="py-2 pr-3 text-right">Jobs 90d</th>
                <th className="py-2 pr-3 text-right">Lifetime</th>
                <th className="py-2 pr-3">Last completed</th>
                <th className="py-2">Band</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.engineer_user_id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{r.engineer_user_id.slice(0, 8)}</td>
                  <td className="py-2 pr-3 text-xs">{r.cached_highest_tier}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums font-semibold">{formatNumber(r.jobs_30d)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{formatNumber(r.jobs_90d)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{formatNumber(r.jobs_lifetime)}</td>
                  <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{r.last_completed_at ? new Date(r.last_completed_at).toLocaleDateString("en-IN") : "—"}</td>
                  <td className={`py-2 text-xs ${bandTone(r.utilization_band) === "ok" ? "text-[var(--color-ok)]" : bandTone(r.utilization_band) === "warn" ? "text-[var(--color-warn)]" : bandTone(r.utilization_band) === "danger" ? "text-[var(--color-danger)]" : ""}`}>{r.utilization_band}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
