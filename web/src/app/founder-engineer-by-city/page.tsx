import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer by city — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_active_engineers: number;
  total_cities_with_engineers: number;
  top_city_name: string | null;
  top_city_engineer_count: number;
  second_city_name: string | null;
  jobs_completed_30d_total: number;
  avg_jobs_per_engineer_30d: number;
  metro_engineer_count: number;
  non_metro_engineer_count: number;
  generated_at: string;
};

type Row = {
  city: string;
  state: string | null;
  engineer_count: number;
  jobs_completed_30d: number;
  jobs_completed_90d: number;
  avg_jobs_per_engineer_30d: number;
};

export default async function FounderEngineerByCityPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, breakdownRes] = await Promise.all([
    supabase.rpc("founder_engineer_by_city_summary"),
    supabase.rpc("founder_engineer_by_city_breakdown", { p_limit: 50 }),
  ]);

  if (summaryRes.error) throw new Error(`founder_engineer_by_city_summary: ${summaryRes.error.message}`);
  if (breakdownRes.error) throw new Error(`founder_engineer_by_city_breakdown: ${breakdownRes.error.message}`);

  const summary = ((summaryRes.data ?? [])[0] ?? {}) as Summary;
  const rows = (breakdownRes.data ?? []) as Row[];

  const totalEng = Number(summary.total_active_engineers ?? 0);
  const metroCount = Number(summary.metro_engineer_count ?? 0);
  const nonMetroCount = Number(summary.non_metro_engineer_count ?? 0);
  const metroPct = totalEng > 0 ? Math.round((metroCount / totalEng) * 1000) / 10 : 0;
  const nonMetroPct = totalEng > 0 ? Math.round((nonMetroCount / totalEng) * 1000) / 10 : 0;
  const topCityShare =
    totalEng > 0
      ? Math.round((Number(summary.top_city_engineer_count ?? 0) / totalEng) * 1000) / 10
      : 0;

  const cols: Column<Row>[] = [
    {
      key: "rk",
      header: "#",
      render: (_r, idx) => (
        <span className="text-xs tabular-nums text-[var(--color-muted)]">{idx + 1}</span>
      ),
    },
    {
      key: "city",
      header: "City",
      render: (r) => <span className="text-xs font-semibold">{r.city || "—"}</span>,
    },
    {
      key: "state",
      header: "State",
      render: (r) => (
        <span className="text-xs text-[var(--color-muted)]">{r.state || "—"}</span>
      ),
    },
    {
      key: "eng",
      header: "Engineers",
      render: (r) => (
        <span className="text-xs font-semibold tabular-nums">
          {formatNumber(r.engineer_count)}
        </span>
      ),
    },
    {
      key: "j30",
      header: "Jobs 30d",
      render: (r) => (
        <span className="text-xs tabular-nums">{formatNumber(r.jobs_completed_30d)}</span>
      ),
    },
    {
      key: "j90",
      header: "Jobs 90d",
      render: (r) => (
        <span className="text-xs tabular-nums text-[var(--color-muted)]">
          {formatNumber(r.jobs_completed_90d)}
        </span>
      ),
    },
    {
      key: "avg",
      header: "Avg jobs/eng 30d",
      render: (r) => {
        const v = Number(r.avg_jobs_per_engineer_30d ?? 0);
        const tone =
          v >= 10
            ? "text-[var(--color-ok)]"
            : v >= 3
              ? "text-[var(--color-fg)]"
              : "text-[var(--color-warn)]";
        return (
          <span className={`text-xs font-semibold tabular-nums ${tone}`}>{v.toFixed(2)}</span>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer by city</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Verified engineers grouped by COALESCE(profile.org.city, last job hospital.city)
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
          <StatCard
            label="Active engineers"
            value={formatNumber(totalEng)}
            subtext="verified"
          />
          <StatCard
            label="Cities covered"
            value={formatNumber(Number(summary.total_cities_with_engineers ?? 0))}
            subtext="distinct cities"
          />
          <StatCard
            label="Top city"
            value={summary.top_city_name ?? "—"}
            subtext={`${formatNumber(Number(summary.top_city_engineer_count ?? 0))} eng · ${topCityShare}%`}
            tone="ok"
          />
          <StatCard
            label="Second city"
            value={summary.second_city_name ?? "—"}
            subtext="runner-up"
          />
          <StatCard
            label="Jobs 30d (all eng)"
            value={formatNumber(Number(summary.jobs_completed_30d_total ?? 0))}
            subtext={`avg ${Number(summary.avg_jobs_per_engineer_30d ?? 0).toFixed(2)}/eng`}
          />
          <StatCard
            label="Avg jobs/eng 30d"
            value={Number(summary.avg_jobs_per_engineer_30d ?? 0).toFixed(2)}
            subtext="all verified"
          />
          <StatCard
            label="Metro engineers"
            value={formatNumber(metroCount)}
            subtext={`${metroPct}% of base`}
            tone="ok"
          />
          <StatCard
            label="Non-metro engineers"
            value={formatNumber(nonMetroCount)}
            subtext={`${nonMetroPct}% of base`}
            tone="warn"
          />
          <StatCard
            label="Metro: non-metro"
            value={`${metroPct}% : ${nonMetroPct}%`}
            subtext="distribution split"
          />
          <StatCard
            label="Top-city concentration"
            value={`${topCityShare}%`}
            subtext="engineers in #1 city"
            tone={topCityShare >= 50 ? "warn" : "neutral"}
          />
        </div>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] p-4">
        <div className="flex items-baseline justify-between">
          <h2 className="text-sm font-semibold">Metro vs non-metro split</h2>
          <span className="text-xs text-[var(--color-muted)]">
            Metros: Hyderabad · Bangalore · Chennai · Mumbai · Delhi · Pune · Kolkata · Ahmedabad
          </span>
        </div>
        <div className="mt-3 h-3 w-full overflow-hidden rounded-full bg-[var(--color-bg-muted)]">
          <div
            className="h-full bg-[var(--color-ok)]"
            style={{ width: `${metroPct}%` }}
            aria-label={`Metro ${metroPct}%`}
          />
        </div>
        <div className="mt-2 flex justify-between text-xs tabular-nums text-[var(--color-muted)]">
          <span>
            Metro {formatNumber(metroCount)} ({metroPct}%)
          </span>
          <span>
            Non-metro {formatNumber(nonMetroCount)} ({nonMetroPct}%)
          </span>
        </div>
      </section>

      <section>
        <div className="mb-2 flex items-baseline justify-between">
          <h2 className="text-sm font-semibold">Top-50 city breakdown</h2>
          <span className="text-xs text-[var(--color-muted)]">
            Ordered by engineer count · 30d + 90d completed jobs
          </span>
        </div>
        <DataTable
          columns={cols}
          rows={rows}
          rowKey={(r) => `${r.city}|${r.state ?? ""}`}
          emptyMessage="No engineers with a derivable city yet."
        />
      </section>
    </div>
  );
}
