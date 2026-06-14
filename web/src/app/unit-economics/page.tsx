import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct, formatRupees } from "@/lib/format";

export const metadata = { title: "Unit economics — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type HeroKpis = {
  gmv_7d_rupees: number | null;
  gmv_prior_7d_rupees: number | null;
  gmv_wow_pct: number | null;
  completed_jobs_7d: number | null;
  active_engineers_30d: number | null;
  open_disputes: number | null;
  total_escrow_held_rupees: number | null;
  amc_contracts_active: number | null;
};

type LtvRow = {
  engineer_user_id: string;
  total_jobs_completed: number | null;
  total_gross_rupees: number | null;
  total_net_paid_rupees: number | null;
  total_tds_rupees: number | null;
};

type VerticalRow = {
  equipment_type: string;
  job_count: number | null;
  gmv_rupees: number | null;
  avg_ticket_rupees: number | null;
  dispute_count: number | null;
  dispute_rate_pct: number | null;
};

type CohortRow = {
  cohort_month: string;
  cohort_size: number | null;
  retained_30d: number | null;
  retained_90d: number | null;
  retained_180d: number | null;
};

export default async function UnitEconomicsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [heroRes, ltvRes, vertRes, cohortRes] = await Promise.all([
    supabase.rpc("founder_hero_kpis"),
    supabase.rpc("founder_engineer_ltv_ranked", { p_limit: 200 }),
    supabase.rpc("founder_gmv_by_equipment_type", { p_days: 90 }),
    supabase.rpc("founder_hospital_cohort_retention", { p_months: 12 }),
  ]);

  if (heroRes.error) throw new Error(`founder_hero_kpis: ${heroRes.error.message}`);
  if (ltvRes.error) throw new Error(`founder_engineer_ltv_ranked: ${ltvRes.error.message}`);
  if (vertRes.error)
    throw new Error(`founder_gmv_by_equipment_type: ${vertRes.error.message}`);

  const k: HeroKpis =
    (Array.isArray(heroRes.data) ? heroRes.data[0] : heroRes.data) ?? ({} as HeroKpis);
  const engineers = (ltvRes.data ?? []) as LtvRow[];
  const verticals = (vertRes.data ?? []) as VerticalRow[];
  const cohorts = (cohortRes.error ? [] : (cohortRes.data ?? [])) as CohortRow[];

  // Derived KPIs (computed client-side from existing RPCs).
  const totalEngineerGross = engineers.reduce(
    (s, r) => s + (r.total_gross_rupees ?? 0),
    0,
  );
  const totalEngineerNet = engineers.reduce(
    (s, r) => s + (r.total_net_paid_rupees ?? 0),
    0,
  );
  const totalEngineerTds = engineers.reduce(
    (s, r) => s + (r.total_tds_rupees ?? 0),
    0,
  );
  const totalJobsLifetime = engineers.reduce(
    (s, r) => s + (r.total_jobs_completed ?? 0),
    0,
  );
  const activeEngineers = engineers.filter(
    (r) => (r.total_jobs_completed ?? 0) > 0,
  ).length;

  const platformFee = totalEngineerGross - totalEngineerNet - totalEngineerTds;
  const platformFeePct =
    totalEngineerGross > 0 ? (platformFee / totalEngineerGross) * 100 : 0;
  const avgJobValue =
    totalJobsLifetime > 0 ? totalEngineerGross / totalJobsLifetime : 0;
  const arpe = activeEngineers > 0 ? totalEngineerGross / activeEngineers : 0; // gross per engineer lifetime
  const jobsPerEngineer =
    activeEngineers > 0 ? totalJobsLifetime / activeEngineers : 0;

  // 90-day vertical economics
  const verticalsGmv = verticals.reduce((s, r) => s + (r.gmv_rupees ?? 0), 0);
  const verticalsJobs = verticals.reduce((s, r) => s + (r.job_count ?? 0), 0);
  const verticalsDisputes = verticals.reduce(
    (s, r) => s + (r.dispute_count ?? 0),
    0,
  );
  const overallDisputeRate =
    verticalsJobs > 0 ? (verticalsDisputes / verticalsJobs) * 100 : 0;

  // Retention sketch: average 90-day retention pct across cohorts with at
  // least 5 hospitals.
  const meaningfulCohorts = cohorts.filter((c) => (c.cohort_size ?? 0) >= 5);
  const avgRet90 =
    meaningfulCohorts.length > 0
      ? meaningfulCohorts.reduce(
          (s, c) =>
            s +
            (c.cohort_size && c.cohort_size > 0
              ? ((c.retained_90d ?? 0) / c.cohort_size) * 100
              : 0),
          0,
        ) / meaningfulCohorts.length
      : null;

  // Vertical mix table
  const verticalCols: Column<VerticalRow>[] = [
    { key: "type", header: "Equipment", render: (r) => r.equipment_type },
    { key: "jobs", header: "Jobs (90d)", render: (r) => formatNumber(r.job_count) },
    {
      key: "gmv",
      header: "GMV",
      render: (r) => formatRupees(r.gmv_rupees),
    },
    {
      key: "share",
      header: "% GMV",
      render: (r) =>
        formatPct(
          verticalsGmv > 0 ? ((r.gmv_rupees ?? 0) / verticalsGmv) * 100 : 0,
        ),
    },
    {
      key: "aov",
      header: "Avg ticket",
      render: (r) => formatRupees(r.avg_ticket_rupees),
    },
    {
      key: "fee",
      header: "Platform fee est.",
      render: (r) => formatRupees((r.gmv_rupees ?? 0) * (platformFeePct / 100)),
    },
    {
      key: "disp",
      header: "Dispute rate",
      render: (r) => (
        <span
          className={
            (r.dispute_rate_pct ?? 0) > overallDisputeRate * 1.5
              ? "text-[var(--color-warn)]"
              : ""
          }
        >
          {formatPct(r.dispute_rate_pct)}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-8">
      <header>
        <h1 className="text-xl font-semibold">Unit economics</h1>
        <p className="mt-1 max-w-3xl text-sm text-[var(--color-muted)]">
          Derived metrics computed live from existing cockpit RPCs. Numbers are gross over
          the engineer LTV ledger (lifetime), with vertical mix on the trailing 90-day window
          and retention on monthly cohorts. No CAC stat — we don&rsquo;t have ad spend wired yet.
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Headline economics
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Total GMV (lifetime)" value={formatRupees(totalEngineerGross)} />
          <StatCard
            label="Platform take"
            value={formatRupees(platformFee)}
            subtext={`${platformFeePct.toFixed(1)}% effective`}
            tone={platformFeePct >= 5 ? "ok" : "warn"}
          />
          <StatCard
            label="Engineer net paid"
            value={formatRupees(totalEngineerNet)}
          />
          <StatCard
            label="TDS withheld (lifetime)"
            value={formatRupees(totalEngineerTds)}
          />
          <StatCard
            label="Avg job value (AOV)"
            value={formatRupees(avgJobValue)}
          />
          <StatCard
            label="Avg gross per active engineer"
            value={formatRupees(arpe)}
            subtext={`across ${formatNumber(activeEngineers)} engineers`}
          />
          <StatCard
            label="Jobs per engineer"
            value={jobsPerEngineer.toFixed(1)}
          />
          <StatCard
            label="Overall dispute rate"
            value={formatPct(overallDisputeRate)}
            tone={
              overallDisputeRate < 3 ? "ok" : overallDisputeRate < 8 ? "warn" : "danger"
            }
            subtext="across all verticals (90d)"
          />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Current quarter pulse
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="GMV last 7 days"
            value={formatRupees(k.gmv_7d_rupees)}
            subtext={k.gmv_wow_pct != null ? `${formatPct(k.gmv_wow_pct)} WoW` : undefined}
            tone={(k.gmv_wow_pct ?? 0) >= 0 ? "ok" : "warn"}
          />
          <StatCard label="Completed jobs (7d)" value={formatNumber(k.completed_jobs_7d)} />
          <StatCard
            label="Active engineers (30d)"
            value={formatNumber(k.active_engineers_30d)}
          />
          <StatCard
            label="AMC contracts active"
            value={formatNumber(k.amc_contracts_active)}
          />
          <StatCard
            label="Escrow float held"
            value={formatRupees(k.total_escrow_held_rupees)}
            subtext="trust capital"
          />
          <StatCard
            label="Open disputes"
            value={formatNumber(k.open_disputes)}
            tone={(k.open_disputes ?? 0) > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Avg 90d retention"
            value={avgRet90 != null ? `${avgRet90.toFixed(1)}%` : "—"}
            subtext={`across ${formatNumber(meaningfulCohorts.length)} cohorts ≥5`}
            tone={
              avgRet90 == null
                ? "neutral"
                : avgRet90 >= 40
                  ? "ok"
                  : avgRet90 >= 20
                    ? "warn"
                    : "danger"
            }
          />
          <StatCard
            label="AMC penetration"
            value={
              k.active_engineers_30d && k.active_engineers_30d > 0
                ? formatPct(
                    ((k.amc_contracts_active ?? 0) / k.active_engineers_30d) * 100,
                  )
                : "—"
            }
            subtext="AMC / active engineers"
          />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Vertical economics — last 90 days
        </h2>
        <DataTable
          columns={verticalCols}
          rows={verticals}
          rowKey={(r) => r.equipment_type}
          emptyMessage="No completed jobs in the last 90 days."
        />
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-4 text-sm">
        <h2 className="mb-1 text-sm font-semibold">Assumptions + caveats</h2>
        <ul className="list-disc space-y-1 pl-5 text-xs text-[var(--color-muted)]">
          <li>
            Platform take = engineer_gross − engineer_net − TDS. Mirrors the contracted
            split; doesn&rsquo;t back out gateway fees (~2% Razorpay + Cashfree combined),
            so reported take is slightly inflated.
          </li>
          <li>
            Avg job value uses lifetime gross / lifetime completed jobs across all
            engineers in the top-200 LTV window. Long-tail engineers (rank &gt;200) are
            excluded by the LTV RPC&rsquo;s default cap.
          </li>
          <li>
            Dispute rate is jobs disputed / jobs completed (90d). Verticals shown as
            warn-tone when their rate is &gt;1.5× the overall blended rate.
          </li>
          <li>
            CAC and CAC/LTV are NOT shown — we don&rsquo;t track ad spend or sales effort
            yet. v0.5 Phase 5 will wire that.
          </li>
        </ul>
      </section>
    </div>
  );
}
