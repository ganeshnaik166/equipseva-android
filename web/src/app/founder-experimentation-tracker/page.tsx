import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder experimentation tracker — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_experiments: number;
  designed_count: number;
  running_count: number;
  paused_count: number;
  shipped_count: number;
  killed_count: number;
  ship_rate_pct: number | null;
  avg_actual_lift_pct: number | null;
  avg_expected_lift_pct: number | null;
  lift_realization_pct: number | null;
  running_avg_age_days: number | null;
  oldest_running_age_days: number | null;
  last_decision_at: string | null;
  top_surface_by_volume: string | null;
};

type ExpRow = {
  id: string;
  exp_label: string;
  hypothesis: string;
  primary_kpi: string;
  surface: string | null;
  variant_kind: string;
  status: string;
  expected_lift_pct: number | null;
  actual_lift_pct: number | null;
  lift_realization_pct: number | null;
  sample_size_target: number | null;
  sample_size_actual: number | null;
  sample_size_pct: number | null;
  started_at: string | null;
  ended_at: string | null;
  decision_at: string | null;
  age_days: number;
  created_at: string;
};

function Card({ label, value, tone, sub }: { label: string; value: string | number; tone?: string; sub?: string }) {
  return (
    <div className={`rounded-lg border ${tone ?? "border-[var(--color-border)]"} bg-[var(--color-surface)] p-4`}>
      <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-2xl font-bold tabular-nums">{value}</div>
      {sub ? <div className="mt-1 text-[10px] text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

const STATUS_TONE: Record<string, string> = {
  designed:  "text-[var(--color-muted)]",
  running:   "text-[var(--color-info)]",
  paused:    "text-[var(--color-warn)]",
  analyzing: "text-[var(--color-warn)]",
  shipped:   "text-[var(--color-ok)]",
  killed:    "text-[var(--color-danger)]",
};

const STATUS_FILTERS = ["designed", "running", "paused", "analyzing", "shipped", "killed"] as const;

function liftRealizationTone(pct: number | null): string {
  if (pct == null) return "text-[var(--color-muted)]";
  if (pct >= 80) return "text-[var(--color-ok)]";
  if (pct >= 50) return "text-[var(--color-warn)]";
  return "text-[var(--color-danger)]";
}

function liftValueTone(actual: number | null): string {
  if (actual == null) return "text-[var(--color-muted)]";
  if (actual > 0) return "text-[var(--color-ok)]";
  if (actual < 0) return "text-[var(--color-danger)]";
  return "text-[var(--color-muted)]";
}

export default async function FounderExperimentationTrackerPage({
  searchParams,
}: {
  searchParams?: Promise<{ status?: string }>;
}) {
  await requireFounder();
  const sp = (await searchParams) ?? {};
  const statusParam =
    sp.status && (STATUS_FILTERS as readonly string[]).includes(sp.status) ? sp.status : null;

  const supabase = await getSupabaseServerClient();
  const [summaryRes, recentRes] = await Promise.all([
    supabase.rpc("founder_experimentation_summary"),
    supabase.rpc("founder_experiments_recent", { p_status: statusParam, p_limit: 50 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_experimentation_summary: ${summaryRes.error.message}`);
  if (recentRes.error)  throw new Error(`founder_experiments_recent: ${recentRes.error.message}`);

  const s = ((summaryRes.data ?? [])[0] ?? {}) as SummaryRow;
  const rows = (recentRes.data ?? []) as ExpRow[];

  const oldestRunningStale = (s.oldest_running_age_days ?? 0) >= 45;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder experimentation tracker · r1353</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          A/B tests, holdouts, staged rollouts. Every shipped change should pass through here: hypothesis {"->"} expected
          lift {"->"} sample-size target {"->"} actual lift {"->"} ship/kill decision with notes.
        </p>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Pair with{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-decision-log">/founder-decision-log</a>{" "}
          (record the ship decision) ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-quarterly-okrs">/founder-quarterly-okrs</a>{" "}
          (which KR did the lift move) ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-action-items-cockpit">/founder-action-items-cockpit</a>{" "}
          (followups when killed).
        </p>
      </header>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)] mb-2">Status filter</div>
        <div className="flex flex-wrap items-center gap-2 text-xs">
          <a
            href="/founder-experimentation-tracker"
            className={`rounded border px-3 py-1 ${
              statusParam == null
                ? "border-[var(--color-accent)] text-[var(--color-accent)]"
                : "border-[var(--color-border)] text-[var(--color-muted)] hover:text-[var(--color-accent)]"
            }`}
          >
            all
          </a>
          {STATUS_FILTERS.map((st) => (
            <a
              key={st}
              href={`/founder-experimentation-tracker?status=${st}`}
              className={`rounded border px-3 py-1 ${
                statusParam === st
                  ? "border-[var(--color-accent)] text-[var(--color-accent)]"
                  : "border-[var(--color-border)] text-[var(--color-muted)] hover:text-[var(--color-accent)]"
              }`}
            >
              {st}
            </a>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Portfolio totals</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-7">
          <Card label="Total experiments" value={formatNumber(s.total_experiments ?? 0)} tone="border-[var(--color-accent)]" />
          <Card label="Designed"  value={formatNumber(s.designed_count ?? 0)} />
          <Card label="Running"   value={formatNumber(s.running_count ?? 0)}  tone="border-[var(--color-info)]" />
          <Card label="Paused"    value={formatNumber(s.paused_count ?? 0)}   tone="border-[var(--color-warn)]" />
          <Card label="Shipped"   value={formatNumber(s.shipped_count ?? 0)}  tone="border-[var(--color-ok)]" />
          <Card label="Killed"    value={formatNumber(s.killed_count ?? 0)}   tone="border-[var(--color-danger)]" />
          <Card
            label="Ship rate"
            value={s.ship_rate_pct != null ? `${s.ship_rate_pct}%` : "—"}
            sub="shipped / decided"
            tone="border-[var(--color-info)]"
          />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Lift discipline + cadence</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-7">
          <Card label="Avg expected lift" value={s.avg_expected_lift_pct != null ? `${s.avg_expected_lift_pct}%` : "—"} sub="hypothesis ambition" />
          <Card label="Avg actual lift"   value={s.avg_actual_lift_pct   != null ? `${s.avg_actual_lift_pct}%`   : "—"} sub="post-decision" />
          <Card
            label="Lift realization"
            value={s.lift_realization_pct != null ? `${s.lift_realization_pct}%` : "—"}
            sub={">= 80 ok · 50-79 warn · < 50 danger"}
            tone={
              s.lift_realization_pct == null
                ? "border-[var(--color-border)]"
                : s.lift_realization_pct >= 80
                ? "border-[var(--color-ok)]"
                : s.lift_realization_pct >= 50
                ? "border-[var(--color-warn)]"
                : "border-[var(--color-danger)]"
            }
          />
          <Card label="Running avg age"   value={s.running_avg_age_days  != null ? `${s.running_avg_age_days}d`  : "—"} sub="time-in-flight" />
          <Card
            label="Oldest running"
            value={s.oldest_running_age_days != null ? `${s.oldest_running_age_days}d` : "—"}
            sub={oldestRunningStale ? "STALE >= 45d" : "fresh"}
            tone={oldestRunningStale ? "border-[var(--color-danger)]" : "border-[var(--color-ok)]"}
          />
          <Card
            label="Last decision"
            value={s.last_decision_at ? new Date(s.last_decision_at).toLocaleDateString() : "—"}
            sub="most recent ship/kill"
          />
          <Card label="Top surface" value={s.top_surface_by_volume ?? "—"} sub="by experiment volume" />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">
          Experiments {statusParam ? `· status=${statusParam}` : "· all"} (top 50, newest first)
        </h2>
        {rows.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-center text-sm">
            <span className="text-[var(--color-muted)]">No experiments match this filter.</span>
            <div className="mt-2 text-xs text-[var(--color-muted)]">
              Register with{" "}
              <code className="font-mono">
                log_founder_experiment_register(p_exp_label, p_hypothesis, p_primary_kpi, ...)
              </code>
              .
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="py-2 pr-3">Label</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3">Surface</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Primary KPI</th>
                  <th className="py-2 pr-3 tabular-nums">Expected</th>
                  <th className="py-2 pr-3 tabular-nums">Actual</th>
                  <th className="py-2 pr-3 tabular-nums">Realization</th>
                  <th className="py-2 pr-3 tabular-nums">Sample</th>
                  <th className="py-2 pr-3 tabular-nums">Age</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 font-mono text-xs">{r.exp_label}</td>
                    <td className={`py-2 pr-3 text-xs uppercase tracking-wider font-semibold ${STATUS_TONE[r.status] ?? "text-[var(--color-muted)]"}`}>
                      {r.status}
                    </td>
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{r.surface ?? "—"}</td>
                    <td className="py-2 pr-3 text-xs">{r.variant_kind}</td>
                    <td className="py-2 pr-3 text-xs max-w-xs truncate" title={r.primary_kpi}>{r.primary_kpi}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">
                      {r.expected_lift_pct != null ? `${r.expected_lift_pct}%` : "—"}
                    </td>
                    <td className={`py-2 pr-3 tabular-nums text-xs font-semibold ${liftValueTone(r.actual_lift_pct)}`}>
                      {r.actual_lift_pct != null ? `${r.actual_lift_pct}%` : "—"}
                    </td>
                    <td className={`py-2 pr-3 tabular-nums text-xs font-semibold ${liftRealizationTone(r.lift_realization_pct)}`}>
                      {r.lift_realization_pct != null ? `${r.lift_realization_pct}%` : "—"}
                    </td>
                    <td className="py-2 pr-3 tabular-nums text-xs">
                      {r.sample_size_actual != null && r.sample_size_target != null
                        ? `${formatNumber(r.sample_size_actual)}/${formatNumber(r.sample_size_target)}${
                            r.sample_size_pct != null ? ` · ${r.sample_size_pct}%` : ""
                          }`
                        : r.sample_size_target != null
                        ? `0/${formatNumber(r.sample_size_target)}`
                        : "—"}
                    </td>
                    <td className="py-2 pr-3 tabular-nums text-xs text-[var(--color-muted)]">{r.age_days}d</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Discipline — Every shipped product change writes a row here. Designed: hypothesis + primary KPI + expected lift + sample-size
        target before any code merges. Running: keep alive only until sample size hits target OR 45 days (whichever first).
        Analyzing: founder writes decision notes within 7d of stop. Ship/kill: decision_at locked in {"<"} 14d after analyzing.
        Lift realization {">="} 80% = trust the design pipeline; {"<"} 50% = recalibrate hypothesis quality (overclaiming wins).
        Kill-rate of zero is a smell: it means hypotheses are too safe.
      </p>
    </div>
  );
}
