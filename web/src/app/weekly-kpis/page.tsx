import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Weekly KPIs — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  metric: string;
  this_week: number;
  last_week: number;
  delta_pct: number | null;
};

const LABELS: Record<string, string> = {
  signups: "Signups",
  repair_jobs_posted: "Jobs posted",
  completed_jobs: "Jobs completed",
  new_amc: "New AMCs",
  disputes_opened: "Disputes opened",
  demand_signals: "Demand signals",
  tier_promotions: "Tier promotions",
};

export default async function WeeklyKpisPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_weekly_kpis");
  if (error) throw new Error(`founder_weekly_kpis: ${error.message}`);
  const rows = (data ?? []) as Row[];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Weekly KPIs</h1>
        <span className="text-xs text-[var(--color-muted)]">this week vs last week</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {rows.map((r) => {
            const delta = r.delta_pct;
            const tone = delta == null
              ? "neutral"
              : delta > 0
                ? (r.metric === "disputes_opened" ? "warn" : "ok")
                : delta < 0
                  ? (r.metric === "disputes_opened" ? "ok" : "warn")
                  : "neutral";
            const sign = delta != null && delta > 0 ? "+" : "";
            return (
              <StatCard
                key={r.metric}
                label={LABELS[r.metric] ?? r.metric}
                value={formatNumber(r.this_week)}
                subtext={delta == null ? `vs ${formatNumber(r.last_week)} last week` : `${sign}${delta}% · ${formatNumber(r.last_week)} last`}
                tone={tone}
              />
            );
          })}
        </div>
      </section>
    </div>
  );
}
