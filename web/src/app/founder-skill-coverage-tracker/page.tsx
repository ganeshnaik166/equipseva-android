import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder skill coverage tracker — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_surfaces: number;
  unknown_count: number;
  aware_count: number;
  familiar_count: number;
  expert_count: number;
  obsessed_count: number;
  p0_surfaces_count: number;
  p0_unknown_count: number;
  p0_unfamiliar_count: number;
  reviewed_last_7d: number;
  reviewed_last_30d: number;
  oldest_unreviewed_age_days: number | null;
  surfaces_with_no_review_lifetime: number;
  generated_at: string;
};

type SurfaceRow = {
  id: string;
  surface_href: string;
  surface_label: string;
  surface_kind: string | null;
  confidence_level: string;
  importance: string;
  last_reviewed_at: string | null;
  days_since_review: number | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
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

const CONFIDENCE_TONE: Record<string, string> = {
  unknown:  "text-[var(--color-danger)]",
  aware:    "text-[var(--color-warn)]",
  familiar: "text-[var(--color-info)]",
  expert:   "text-[var(--color-ok)]",
  obsessed: "text-[var(--color-accent)]",
};

const IMPORTANCE_TONE: Record<string, string> = {
  p0: "text-[var(--color-danger)]",
  p1: "text-[var(--color-warn)]",
  p2: "text-[var(--color-info)]",
  p3: "text-[var(--color-muted)]",
};

function p0UnknownTone(n: number): string {
  if (n === 0) return "border-[var(--color-ok)]";
  if (n <= 3)  return "border-[var(--color-warn)]";
  return "border-[var(--color-danger)]";
}

function noReviewTone(n: number): string {
  if (n === 0) return "border-[var(--color-ok)]";
  if (n <= 10) return "border-[var(--color-warn)]";
  return "border-[var(--color-danger)]";
}

function ageTone(days: number | null): string {
  if (days == null) return "border-[var(--color-border)]";
  if (days <= 14) return "border-[var(--color-ok)]";
  if (days <= 45) return "border-[var(--color-warn)]";
  return "border-[var(--color-danger)]";
}

export default async function FounderSkillCoverageTrackerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [summaryRes, recentRes] = await Promise.all([
    supabase.rpc("founder_skill_coverage_summary"),
    supabase.rpc("founder_skill_coverage_recent", { p_confidence: null, p_importance: null, p_limit: 100 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_skill_coverage_summary: ${summaryRes.error.message}`);
  if (recentRes.error)  throw new Error(`founder_skill_coverage_recent: ${recentRes.error.message}`);

  const s = ((summaryRes.data ?? [])[0] ?? {}) as SummaryRow;
  const rows = (recentRes.data ?? []) as SurfaceRow[];

  const coveragePct = s.total_surfaces > 0
    ? Math.round(((s.familiar_count + s.expert_count + s.obsessed_count) / s.total_surfaces) * 100)
    : 0;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder skill coverage tracker · r1381</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Mental coverage of every founder-console surface. Confidence ladder: unknown {"->"} aware {"->"} familiar {"->"} expert {"->"} obsessed.
          Importance ladder: p0 (weekly review) {"->"} p1 (monthly) {"->"} p2/p3 (ad-hoc).
        </p>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Pair with{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/ops-index">/ops-index</a> ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-runbook">/founder-runbook</a> ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/coverage-index">/coverage-index</a>.
        </p>
      </header>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Inventory + confidence mix</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          <Card label="Total surfaces" value={formatNumber(s.total_surfaces ?? 0)} tone="border-[var(--color-accent)]" sub="registered in tracker" />
          <Card label="Unknown"  value={formatNumber(s.unknown_count  ?? 0)} tone="border-[var(--color-danger)]" sub="never opened" />
          <Card label="Aware"    value={formatNumber(s.aware_count    ?? 0)} tone="border-[var(--color-warn)]"   sub="seen but shallow" />
          <Card label="Familiar" value={formatNumber(s.familiar_count ?? 0)} tone="border-[var(--color-info)]"   sub="can navigate" />
          <Card label="Expert"   value={formatNumber(s.expert_count   ?? 0)} tone="border-[var(--color-ok)]"     sub="can explain" />
          <Card label="Obsessed" value={formatNumber(s.obsessed_count ?? 0)} tone="border-[var(--color-accent)]" sub="weekly check" />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">P0 focus + review cadence</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <Card label="P0 surfaces"     value={formatNumber(s.p0_surfaces_count   ?? 0)} sub="must review weekly" />
          <Card label="P0 unknown"      value={formatNumber(s.p0_unknown_count    ?? 0)} tone={p0UnknownTone(s.p0_unknown_count ?? 0)} sub="never opened" />
          <Card label="P0 unfamiliar"   value={formatNumber(s.p0_unfamiliar_count ?? 0)} tone={p0UnknownTone(s.p0_unfamiliar_count ?? 0)} sub="unknown + aware" />
          <Card label="Reviewed 7d"     value={formatNumber(s.reviewed_last_7d    ?? 0)} tone="border-[var(--color-ok)]"   sub="last week" />
          <Card label="Reviewed 30d"    value={formatNumber(s.reviewed_last_30d   ?? 0)} tone="border-[var(--color-info)]" sub="last month" />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Staleness + coverage health</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          <Card
            label="Oldest review age"
            value={s.oldest_unreviewed_age_days != null ? `${s.oldest_unreviewed_age_days}d` : "—"}
            tone={ageTone(s.oldest_unreviewed_age_days)}
            sub="days since most-stale review"
          />
          <Card
            label="No review lifetime"
            value={formatNumber(s.surfaces_with_no_review_lifetime ?? 0)}
            tone={noReviewTone(s.surfaces_with_no_review_lifetime ?? 0)}
            sub="never reviewed once"
          />
          <Card
            label="Familiar+ coverage"
            value={`${coveragePct}%`}
            tone={coveragePct >= 80 ? "border-[var(--color-ok)]" : coveragePct >= 50 ? "border-[var(--color-warn)]" : "border-[var(--color-danger)]"}
            sub="familiar / expert / obsessed"
          />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Surface registry (top 100, p0 + unknown first)</h2>
        {rows.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-center text-sm">
            <span className="text-[var(--color-muted)]">No surfaces registered yet.</span>
            <div className="mt-2 text-xs text-[var(--color-muted)]">
              Register with{" "}
              <code className="font-mono">log_founder_skill_coverage_register(p_href, p_label, p_kind, p_importance)</code>.
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="py-2 pr-3">Surface</th>
                  <th className="py-2 pr-3">Label</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Importance</th>
                  <th className="py-2 pr-3">Confidence</th>
                  <th className="py-2 pr-3 tabular-nums">Days since review</th>
                  <th className="py-2 pr-3">Last reviewed</th>
                  <th className="py-2 pr-3">Notes</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 font-mono text-xs">
                      <a className="text-[var(--color-accent)] hover:underline" href={r.surface_href}>{r.surface_href}</a>
                    </td>
                    <td className="py-2 pr-3 text-xs">{r.surface_label}</td>
                    <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{r.surface_kind ?? "—"}</td>
                    <td className={`py-2 pr-3 text-xs uppercase tracking-wider font-semibold ${IMPORTANCE_TONE[r.importance] ?? "text-[var(--color-muted)]"}`}>
                      {r.importance}
                    </td>
                    <td className={`py-2 pr-3 text-xs uppercase tracking-wider font-semibold ${CONFIDENCE_TONE[r.confidence_level] ?? "text-[var(--color-muted)]"}`}>
                      {r.confidence_level}
                    </td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{r.days_since_review != null ? `${r.days_since_review}d` : "—"}</td>
                    <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">
                      {r.last_reviewed_at ? new Date(r.last_reviewed_at).toLocaleDateString() : "—"}
                    </td>
                    <td className="py-2 pr-3 text-xs max-w-[16rem] truncate" title={r.notes ?? ""}>{r.notes ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Review cadence — P0 surfaces (cockpits + cash + payouts + incidents) get a weekly walkthrough: open the page, scan all
        KPI cards, click one drilldown, leave a note via{" "}
        <code className="font-mono">log_founder_skill_coverage_review(p_id, p_new_confidence, p_notes)</code>. P1 surfaces
        (snapshots + trackers) get a monthly walkthrough. P2/P3 = ad-hoc, but revisit before any board update or fundraise.
        Confidence ladder is self-graded: <i>unknown</i> = never opened, <i>aware</i> = seen but shallow, <i>familiar</i> = can navigate,
        <i> expert</i> = can explain numbers cold, <i>obsessed</i> = check at least weekly without prompt. Healthy console = 0 P0 unknown,
         {"<="} 3 P0 unfamiliar, oldest review age {"<="} 14d, familiar+ coverage {">="} 80%. If P0 unknown {">"} 0 it is the highest-leverage
        founder task this week — beats most ship rounds.
      </p>
    </div>
  );
}
