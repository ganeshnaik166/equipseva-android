import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { KpiGrid, type Kpi } from "@/components/KpiGrid";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spot audit responses summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  responses_24h: number;
  responses_7d: number;
  responses_30d: number;
  responses_90d: number;
  low_rating_30d: number;
  mid_rating_30d: number;
  high_rating_30d: number;
  avg_rating_30d: number;
  with_feedback_30d: number;
  feedback_pct_30d: number;
  distinct_hospitals_30d: number;
  distinct_engineers_30d: number;
  median_response_hours_30d: number;
  last_response_at: string | null;
};

function fmtAgo(iso: string | null): string {
  if (!iso) return "never";
  const ms = Date.now() - new Date(iso).getTime();
  if (ms < 0) return "just now";
  const m = Math.floor(ms / 60000);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 48) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

export default async function SpotAuditResponsesSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spot_audit_responses_summary");
  if (error) throw new Error(`founder_spot_audit_responses_summary: ${error.message}`);
  const row = ((data ?? [])[0] ?? null) as Row | null;

  const r24 = row?.responses_24h ?? 0;
  const r7 = row?.responses_7d ?? 0;
  const r30 = row?.responses_30d ?? 0;
  const r90 = row?.responses_90d ?? 0;
  const low = row?.low_rating_30d ?? 0;
  const mid = row?.mid_rating_30d ?? 0;
  const high = row?.high_rating_30d ?? 0;
  const avg = Number(row?.avg_rating_30d ?? 0);
  const fb = row?.with_feedback_30d ?? 0;
  const fbPct = Number(row?.feedback_pct_30d ?? 0);
  const hosps = row?.distinct_hospitals_30d ?? 0;
  const engs = row?.distinct_engineers_30d ?? 0;
  const medianH = Number(row?.median_response_hours_30d ?? 0);
  const last = row?.last_response_at ?? null;

  const avgTone = avg < 3 ? "danger" : avg < 4 ? "warn" : "ok";
  const lowTone = low > 0 ? "warn" : "muted";
  const fbTone = fbPct < 20 ? "muted" : fbPct < 50 ? "ok" : "ok";

  const kpis: Kpi[] = [
    { label: "Responses 24h", value: formatNumber(r24) },
    { label: "Responses 7d", value: formatNumber(r7) },
    { label: "Responses 30d", value: formatNumber(r30) },
    { label: "Responses 90d", value: formatNumber(r90) },
    { label: "Low (1-2) 30d", value: formatNumber(low), tone: lowTone },
    { label: "Mid (3) 30d", value: formatNumber(mid) },
    { label: "High (4-5) 30d", value: formatNumber(high), tone: "ok" },
    { label: "Avg rating 30d", value: avg.toFixed(2), tone: avgTone },
    { label: "With feedback 30d", value: formatNumber(fb) },
    { label: "Feedback % 30d", value: `${fbPct.toFixed(1)}%`, tone: fbTone },
    { label: "Hospitals 30d", value: formatNumber(hosps) },
    { label: "Engineers 30d", value: formatNumber(engs) },
    { label: "Median response 30d", value: `${medianH.toFixed(1)}h` },
    { label: "Last response", value: fmtAgo(last) },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spot audit responses summary</h1>
        <span className="text-xs text-[var(--color-muted)]">field-integrity program health · 14 KPIs · 24h/7d/30d/90d</span>
      </header>
      <KpiGrid kpis={kpis} />
      <p className="text-xs text-[var(--color-muted)]">
        spot_audit_responses (v2.1 PR-D43) is the hospital-side 1-in-20 random-sweep rating ledger.
        Distinct from the targeted cash-flag survey (per-job single-question) and from the legacy
        /spot-audits table. Pair with /spot-audit-by-engineer and /spot-audit-rating-distribution
        for row-level triage.
      </p>
    </div>
  );
}
