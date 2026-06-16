import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatPct, formatRelativeTime, shortId } from "@/lib/format";

export const metadata = { title: "Engineer tiers — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type DistRow = {
  tier: string;
  display_label: string;
  engineer_count: number | null;
  manual_override_count: number | null;
};

type TierDef = {
  tier: string;
  min_completed_jobs: number;
  max_dispute_rate_pct: number;
  min_verified_tier: string;
  min_supervised_completions: number;
  platform_fee_pct: number;
  code_red_priority: number;
  pi_insurance_eligible: boolean;
  featured_in_search: boolean;
  display_label: string;
  display_order: number;
};

type ProgressRow = {
  engineer_user_id: string;
  current_tier: string;
  jobs_completed: number | null;
  dispute_rate_pct: number | null;
  verified_tier_at_eval: string | null;
  supervised_completions_at_eval: number | null;
  manual_override: boolean;
  override_reason: string | null;
  last_computed_at: string;
  updated_at: string;
};

const TIER_TONE: Record<string, string> = {
  gold: "bg-yellow-100 text-[var(--color-warn)]",
  silver: "bg-gray-200",
  bronze: "bg-orange-100",
  none: "bg-gray-50 text-[var(--color-muted)]",
};

export default async function TiersPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [distRes, defsRes, progressRes] = await Promise.all([
    supabase.rpc("founder_certification_tier_distribution"),
    supabase
      .from("engineer_certification_tiers")
      .select(
        "tier, min_completed_jobs, max_dispute_rate_pct, min_verified_tier, min_supervised_completions, platform_fee_pct, code_red_priority, pi_insurance_eligible, featured_in_search, display_label, display_order",
      )
      .order("display_order", { ascending: false }),
    supabase
      .from("engineer_certification_progress")
      .select(
        "engineer_user_id, current_tier, jobs_completed, dispute_rate_pct, verified_tier_at_eval, supervised_completions_at_eval, manual_override, override_reason, last_computed_at, updated_at",
      )
      .order("updated_at", { ascending: false })
      .limit(100),
  ]);

  if (distRes.error)
    throw new Error(`founder_certification_tier_distribution: ${distRes.error.message}`);
  if (defsRes.error)
    throw new Error(`engineer_certification_tiers: ${defsRes.error.message}`);

  const dist = (distRes.data ?? []) as DistRow[];
  const defs = (defsRes.data ?? []) as TierDef[];
  const progress = (progressRes.error ? [] : (progressRes.data ?? [])) as ProgressRow[];

  const totalEngineers = dist.reduce((s, r) => s + (r.engineer_count ?? 0), 0);
  const totalOverrides = dist.reduce((s, r) => s + (r.manual_override_count ?? 0), 0);
  const totalSupervised = progress.reduce(
    (s, r) => s + (r.supervised_completions_at_eval ?? 0),
    0,
  );

  const progressCols: Column<ProgressRow>[] = [
    {
      key: "eng",
      header: "Engineer",
      render: (r) => (
        <Link
          href={`/engineers/${r.engineer_user_id}`}
          className="text-[var(--color-accent)] hover:underline"
        >
          {shortId(r.engineer_user_id)}
        </Link>
      ),
    },
    {
      key: "tier",
      header: "Tier",
      render: (r) => (
        <span className={`rounded px-1.5 py-0.5 text-xs uppercase ${TIER_TONE[r.current_tier] ?? "bg-gray-100"}`}>
          {r.current_tier}
        </span>
      ),
    },
    { key: "jobs", header: "Jobs done", render: (r) => formatNumber(r.jobs_completed) },
    {
      key: "disp",
      header: "Dispute rate",
      render: (r) => (
        <span
          className={
            (r.dispute_rate_pct ?? 0) > 10
              ? "text-[var(--color-danger)]"
              : (r.dispute_rate_pct ?? 0) > 5
                ? "text-[var(--color-warn)]"
                : "text-[var(--color-muted)]"
          }
        >
          {formatPct(r.dispute_rate_pct)}
        </span>
      ),
    },
    {
      key: "verified",
      header: "Verified ceiling",
      render: (r) => (
        <code className="text-xs">{r.verified_tier_at_eval ?? "—"}</code>
      ),
    },
    {
      key: "supervised",
      header: "Supervised",
      render: (r) =>
        (r.supervised_completions_at_eval ?? 0) > 0 ? (
          <span className="rounded bg-blue-50 px-1.5 py-0.5 text-xs tabular-nums">
            {r.supervised_completions_at_eval}
          </span>
        ) : (
          <span className="text-xs text-[var(--color-muted)]">—</span>
        ),
    },
    {
      key: "manual",
      header: "Manual",
      render: (r) =>
        r.manual_override ? (
          <span
            className="rounded bg-blue-100 px-1.5 py-0.5 text-xs"
            title={r.override_reason ?? ""}
          >
            override
          </span>
        ) : (
          <span className="text-xs text-[var(--color-muted)]">—</span>
        ),
    },
    {
      key: "when",
      header: "Last computed",
      render: (r) => formatRelativeTime(r.last_computed_at),
    },
  ];

  return (
    <div className="space-y-8">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer certification tiers</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {formatNumber(totalEngineers)} engineers · {formatNumber(totalOverrides)} manual overrides ·{" "}
          {formatNumber(totalSupervised)} supervised completions (last 100)
        </span>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Distribution
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {dist.map((d) => (
            <StatCard
              key={d.tier}
              label={d.display_label}
              value={formatNumber(d.engineer_count)}
              subtext={
                (d.manual_override_count ?? 0) > 0
                  ? `${d.manual_override_count} overrides`
                  : undefined
              }
              tone={d.tier === "gold" ? "ok" : d.tier === "none" ? "neutral" : "warn"}
            />
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Tier requirements</h2>
        <div className="overflow-x-auto rounded border border-[var(--color-border)] bg-white">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] bg-gray-50 text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="px-3 py-2 font-medium">Tier</th>
                <th className="px-3 py-2 font-medium">Min jobs</th>
                <th className="px-3 py-2 font-medium">Max dispute%</th>
                <th className="px-3 py-2 font-medium">Min verified</th>
                <th className="px-3 py-2 font-medium" title="Supervised completions required (r578)">Supervised</th>
                <th className="px-3 py-2 font-medium">Platform fee</th>
                <th className="px-3 py-2 font-medium">Code Red priority</th>
                <th className="px-3 py-2 font-medium">PI insurance</th>
                <th className="px-3 py-2 font-medium">Featured</th>
              </tr>
            </thead>
            <tbody>
              {defs.map((t) => (
                <tr key={t.tier} className="border-b border-[var(--color-border)] last:border-0">
                  <td className="px-3 py-2">
                    <span className={`rounded px-1.5 py-0.5 text-xs uppercase ${TIER_TONE[t.tier] ?? "bg-gray-100"}`}>
                      {t.display_label}
                    </span>
                  </td>
                  <td className="px-3 py-2 tabular-nums">{formatNumber(t.min_completed_jobs)}</td>
                  <td className="px-3 py-2 tabular-nums">{t.max_dispute_rate_pct}%</td>
                  <td className="px-3 py-2">
                    <code className="text-xs">{t.min_verified_tier}</code>
                  </td>
                  <td className="px-3 py-2 tabular-nums">
                    {t.min_supervised_completions > 0 ? (
                      <span className="rounded bg-blue-50 px-1.5 py-0.5 text-xs">
                        ≥{t.min_supervised_completions}
                      </span>
                    ) : (
                      <span className="text-[var(--color-muted)]">—</span>
                    )}
                  </td>
                  <td className="px-3 py-2 tabular-nums">{t.platform_fee_pct}%</td>
                  <td className="px-3 py-2 tabular-nums">{t.code_red_priority}</td>
                  <td className="px-3 py-2">{t.pi_insurance_eligible ? "✓" : "—"}</td>
                  <td className="px-3 py-2">{t.featured_in_search ? "✓" : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Recent engineer evaluations{" "}
          <span className="text-[var(--color-muted)]">({progress.length})</span>
        </h2>
        <DataTable
          columns={progressCols}
          rows={progress}
          rowKey={(r) => r.engineer_user_id}
          emptyMessage="No engineer tiers computed yet — daily cron will populate as soon as completed jobs exist."
        />
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Daily cron at 03:17 UTC recomputes all engineers via{" "}
        <code>recompute_all_engineer_certifications()</code>. Founder can force a
        promotion or demotion via <code>founder_promote_engineer_tier</code>
        (≥10-char reason required, logged forever). Manual overrides are honoured by the
        daily recompute — engineer stays pinned to the manually set tier.
      </section>
    </div>
  );
}
