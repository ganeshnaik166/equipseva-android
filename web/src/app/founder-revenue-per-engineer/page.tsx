import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Revenue per engineer — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_active_engineers: number;
  total_amc_mrr_rupees: number;
  total_jobs_completed_30d: number;
  revenue_per_completed_job_avg_rupees: number;
  avg_rpe_30d_rupees: number;
  top_rpe_engineer_user_id: string | null;
  top_rpe_engineer_revenue_30d_rupees: number;
  engineers_above_avg_rpe_count: number;
  engineers_below_avg_rpe_count: number;
  engineers_with_zero_revenue_30d: number;
  top_decile_rpe_threshold_rupees: number;
  bottom_decile_rpe_threshold_rupees: number;
  median_rpe_rupees: number;
  generated_at: string;
};

type Row = {
  engineer_user_id: string;
  jobs_30d: number;
  attributed_revenue_30d_rupees: number;
  rpe_band: string;
};

function Card({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "ok" | "warn" | "danger" }) {
  const t = tone === "ok" ? "text-[var(--color-ok)]" : tone === "warn" ? "text-[var(--color-warn)]" : tone === "danger" ? "text-[var(--color-danger)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${t}`}>{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}
function rup(n: number): string { return `₹${formatNumber(Math.round(n))}`; }

function bandTone(b: string): "ok" | "warn" | "danger" | undefined {
  if (b === "top_decile") return "ok";
  if (b === "bottom_decile") return "danger";
  if (b === "lower_half") return "warn";
  return undefined;
}

export default async function FounderRevenuePerEngineerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, bRes] = await Promise.all([
    sb.rpc("founder_revenue_per_engineer_summary"),
    sb.rpc("founder_revenue_per_engineer_breakdown", { p_limit: 50 }),
  ]);
  if (sRes.error) throw new Error(`rpe_summary: ${sRes.error.message}`);
  if (bRes.error) throw new Error(`rpe_breakdown: ${bRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const rows = (bRes.data ?? []) as Row[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Revenue per engineer ★ 13 KPIs</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          RPE proxy = jobs_30d × (total_AMC_MRR / total_jobs_30d). Approximates per-engineer revenue contribution. Top 50 engineers banded top_decile / upper_half / lower_half / bottom_decile.
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Total active engineers" value={formatNumber(s.total_active_engineers)} sub="verified" />
          <Card label="Total AMC MRR" value={rup(s.total_amc_mrr_rupees)} sub="active contracts" />
          <Card label="Jobs done 30d" value={formatNumber(s.total_jobs_completed_30d)} />
          <Card label="Revenue / job avg" value={rup(s.revenue_per_completed_job_avg_rupees)} sub="proxy" />
          <Card label="Avg RPE 30d" value={rup(s.avg_rpe_30d_rupees)} />
          <Card label="Median RPE" value={rup(s.median_rpe_rupees)} />
          <Card label="Top RPE 30d" value={rup(s.top_rpe_engineer_revenue_30d_rupees)} tone="ok" />
          <Card label="Top-decile threshold (p90)" value={rup(s.top_decile_rpe_threshold_rupees)} />
          <Card label="Bottom-decile threshold (p10)" value={rup(s.bottom_decile_rpe_threshold_rupees)} />
          <Card label="Above avg" value={formatNumber(s.engineers_above_avg_rpe_count)} tone="ok" />
          <Card label="Below avg" value={formatNumber(s.engineers_below_avg_rpe_count)} tone="warn" />
          <Card label="Zero revenue 30d" value={formatNumber(s.engineers_with_zero_revenue_30d)} tone={s.engineers_with_zero_revenue_30d > 0 ? "danger" : "ok"} />
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Top 50 engineers ({rows.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Engineer</th>
                <th className="py-2 pr-3 text-right">Jobs 30d</th>
                <th className="py-2 pr-3 text-right">Attributed revenue 30d</th>
                <th className="py-2">Band</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.engineer_user_id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{r.engineer_user_id.slice(0, 8)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{formatNumber(r.jobs_30d)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{rup(r.attributed_revenue_30d_rupees)}</td>
                  <td className={`py-2 text-xs ${bandTone(r.rpe_band) === "ok" ? "text-[var(--color-ok)]" : bandTone(r.rpe_band) === "warn" ? "text-[var(--color-warn)]" : bandTone(r.rpe_band) === "danger" ? "text-[var(--color-danger)]" : ""}`}>{r.rpe_band}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
