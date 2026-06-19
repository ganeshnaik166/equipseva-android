import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital segmentation — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_active_hospitals: number;
  high_volume_count: number; medium_volume_count: number; low_volume_count: number; dormant_count: number;
  top_hospital_jobs_90d_count: number;
  top_hospital_name: string;
  avg_jobs_per_hospital_90d: number;
  avg_spend_per_hospital_90d_rupees: number;
  enterprise_segment_count: number;
  starter_segment_count: number;
  super_user_count: number;
  segment_at_risk_count: number;
  generated_at: string;
};

type Hosp = {
  hospital_org_id: string; hospital_name: string;
  amc_tier: string; monthly_fee_rupees: number;
  jobs_90d: number; spend_90d_rupees: number; last_job_at: string | null;
  volume_segment: string; value_segment: string; composite_segment: string;
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
function rup(n: number): string { return `₹${formatNumber(Math.round(n))}`; }

function segmentTone(seg: string): "ok" | "warn" | "danger" | undefined {
  if (seg === "h_h") return "ok";
  if (seg.startsWith("d_")) return "danger";
  if (seg.startsWith("l_")) return "warn";
  return undefined;
}

export default async function FounderHospitalSegmentationPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, hRes] = await Promise.all([
    sb.rpc("founder_hospital_segmentation_summary"),
    sb.rpc("founder_hospital_segmentation_by_segment", { p_limit: 100 }),
  ]);
  if (sRes.error) throw new Error(`hospital_segmentation_summary: ${sRes.error.message}`);
  if (hRes.error) throw new Error(`hospital_segmentation_by_segment: ${hRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const rows = (hRes.data ?? []) as Hosp[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Hospital segmentation ★ 9-cell volume × value</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Volume bands: high {"≥"}10 jobs/90d, medium {"≥"}3, low {"≥"}1, dormant=0. Value bands: high {"≥"}₹10k/mo, medium {"≥"}₹3k, low {"<"}₹3k. Super-user = ≥20 jobs AND enterprise tier. Segment-at-risk = dormant AND end_date {"<"} now+60d.
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Total active" value={formatNumber(s.total_active_hospitals)} />
          <Card label="High volume" value={formatNumber(s.high_volume_count)} sub="≥10 jobs/90d" tone="ok" />
          <Card label="Medium volume" value={formatNumber(s.medium_volume_count)} sub="3-9 jobs/90d" />
          <Card label="Low volume" value={formatNumber(s.low_volume_count)} sub="1-2 jobs/90d" />
          <Card label="Dormant" value={formatNumber(s.dormant_count)} sub="0 jobs/90d" tone="danger" />
          <Card label="Super users" value={formatNumber(s.super_user_count)} sub="≥20 jobs + enterprise" tone="ok" />
          <Card label="Segment at risk" value={formatNumber(s.segment_at_risk_count)} sub="dormant + end{<}60d" tone="danger" />
          <Card label="Top hospital jobs" value={formatNumber(s.top_hospital_jobs_90d_count)} sub={s.top_hospital_name} />
          <Card label="Avg jobs / hospital 90d" value={s.avg_jobs_per_hospital_90d.toFixed(1)} />
          <Card label="Avg spend / hospital 90d" value={rup(s.avg_spend_per_hospital_90d_rupees)} />
          <Card label="Enterprise tier count" value={formatNumber(s.enterprise_segment_count)} />
          <Card label="Starter tier count" value={formatNumber(s.starter_segment_count)} />
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Top 100 hospitals (by spend 90d)</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Hospital</th>
                <th className="py-2 pr-3">Tier</th>
                <th className="py-2 pr-3 text-right">Monthly fee</th>
                <th className="py-2 pr-3 text-right">Jobs 90d</th>
                <th className="py-2 pr-3 text-right">Spend 90d</th>
                <th className="py-2 pr-3">Volume</th>
                <th className="py-2 pr-3">Value</th>
                <th className="py-2">Composite</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.hospital_org_id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs">{r.hospital_name}</td>
                  <td className="py-2 pr-3 text-xs">{r.amc_tier}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{rup(r.monthly_fee_rupees)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{formatNumber(r.jobs_90d)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{rup(r.spend_90d_rupees)}</td>
                  <td className="py-2 pr-3 text-xs">{r.volume_segment}</td>
                  <td className="py-2 pr-3 text-xs">{r.value_segment}</td>
                  <td className={`py-2 text-xs font-mono ${segmentTone(r.composite_segment) === "ok" ? "text-[var(--color-ok)]" : segmentTone(r.composite_segment) === "danger" ? "text-[var(--color-danger)]" : segmentTone(r.composite_segment) === "warn" ? "text-[var(--color-warn)]" : ""}`}>{r.composite_segment}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
