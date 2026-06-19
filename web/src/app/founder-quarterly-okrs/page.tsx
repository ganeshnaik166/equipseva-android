import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder quarterly OKRs — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  latest_quarter: string | null;
  total_objectives: number;
  achieved_count: number;
  missed_count: number;
  at_risk_count: number;
  off_track_count: number;
  active_count: number;
  avg_confidence_pct: number;
  kr_total: number;
  kr_avg_progress_pct: number;
  kr_complete_count: number;
  kr_at_risk_count: number;
  last_check_in_at: string | null;
  days_since_last_check_in: number;
};

type ObjectiveRow = {
  id: string;
  quarter_label: string;
  objective_title: string;
  objective_kind: string | null;
  priority: string;
  status: string;
  confidence_pct: number;
  kr_count: number;
  kr_avg_progress: number;
  started_at: string | null;
  closed_at: string | null;
  created_at: string;
};

type KrRow = {
  id: string;
  kr_title: string;
  target_value: number | null;
  target_unit: string | null;
  current_value: number;
  progress_pct: number;
  notes: string | null;
  updated_at: string;
};

type CheckInRow = {
  id: string;
  objective_id: string;
  objective_title: string;
  check_in_at: string;
  confidence_pct: number | null;
  summary: string | null;
  blockers: string | null;
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
  draft:     "text-[var(--color-muted)]",
  active:    "text-[var(--color-info)]",
  at_risk:   "text-[var(--color-warn)]",
  off_track: "text-[var(--color-danger)]",
  achieved:  "text-[var(--color-ok)]",
  missed:    "text-[var(--color-danger)]",
};

const PRIORITY_TONE: Record<string, string> = {
  p0: "border-[var(--color-danger)] text-[var(--color-danger)]",
  p1: "border-[var(--color-warn)]   text-[var(--color-warn)]",
  p2: "border-[var(--color-info)]   text-[var(--color-info)]",
  p3: "border-[var(--color-border)] text-[var(--color-muted)]",
};

function confidenceTone(pct: number): string {
  if (pct >= 75) return "text-[var(--color-ok)]";
  if (pct >= 50) return "text-[var(--color-info)]";
  if (pct >= 30) return "text-[var(--color-warn)]";
  return "text-[var(--color-danger)]";
}

function progressTone(pct: number): string {
  if (pct >= 100) return "text-[var(--color-ok)]";
  if (pct >= 70)  return "text-[var(--color-info)]";
  if (pct >= 40)  return "text-[var(--color-warn)]";
  return "text-[var(--color-danger)]";
}

export default async function FounderQuarterlyOkrsPage({
  searchParams,
}: {
  searchParams?: Promise<{ q?: string }>;
}) {
  await requireFounder();
  const sp = (await searchParams) ?? {};
  const quarterParam = sp.q ?? null;

  const supabase = await getSupabaseServerClient();
  const [summaryRes, objectivesRes, checkInsRes] = await Promise.all([
    supabase.rpc("founder_okr_quarterly_summary",  { p_quarter: quarterParam }),
    supabase.rpc("founder_okr_objectives_recent",  { p_quarter: quarterParam, p_limit: 30 }),
    supabase.rpc("founder_okr_check_ins_recent",   { p_quarter: quarterParam, p_limit: 12 }),
  ]);
  if (summaryRes.error)    throw new Error(`founder_okr_quarterly_summary: ${summaryRes.error.message}`);
  if (objectivesRes.error) throw new Error(`founder_okr_objectives_recent: ${objectivesRes.error.message}`);
  if (checkInsRes.error)   throw new Error(`founder_okr_check_ins_recent: ${checkInsRes.error.message}`);

  const s = ((summaryRes.data ?? [])[0] ?? {}) as SummaryRow;
  const objectives = (objectivesRes.data ?? []) as ObjectiveRow[];
  const checkIns = (checkInsRes.data ?? []) as CheckInRow[];
  const quarter = s.latest_quarter ?? quarterParam ?? "—";

  // Fan-out KR fetch for visible objectives (top 30)
  const krMap = new Map<string, KrRow[]>();
  await Promise.all(
    objectives.map(async (o) => {
      const res = await supabase.rpc("founder_okr_key_results_for", { p_objective_id: o.id });
      if (!res.error) krMap.set(o.id, (res.data ?? []) as KrRow[]);
    }),
  );

  const staleCheckIn = (s.days_since_last_check_in ?? 999) >= 8;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder quarterly OKRs ★★★ r1341</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Objective + key-result + check-in tracker for quarter <code className="font-mono">{quarter}</code>.
          Discipline: weekly check-ins (≥1 per objective per 7 days), confidence-banded status, retro at quarter close.
        </p>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Pair with{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-decision-log">/founder-decision-log</a>{" "}
          (judgement quality) ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-weekly-board-pack">/founder-weekly-board-pack</a>{" "}
          (weekly narrative) ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-action-items-cockpit">/founder-action-items-cockpit</a>{" "}
          (execution layer).
        </p>
      </header>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)] mb-2">Quarter selector</div>
        <form method="GET" className="flex flex-wrap items-center gap-2 text-xs">
          <label htmlFor="q" className="text-[var(--color-muted)]">Quarter label</label>
          <input id="q" name="q" defaultValue={quarterParam ?? ""} placeholder="2026Q3"
                 className="rounded border border-[var(--color-border)] bg-[var(--color-bg)] px-2 py-1 font-mono" />
          <button type="submit" className="rounded border border-[var(--color-accent)] text-[var(--color-accent)] px-3 py-1 hover:bg-[var(--color-accent)]/10">
            Filter
          </button>
          <a href="/founder-quarterly-okrs" className="text-[var(--color-muted)] hover:underline">latest</a>
        </form>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Objectives overview</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-7">
          <Card label="Latest quarter" value={quarter} tone="border-[var(--color-accent)]" />
          <Card label="Total objectives" value={formatNumber(s.total_objectives ?? 0)} />
          <Card label="Active" value={formatNumber(s.active_count ?? 0)} tone="border-[var(--color-info)]" />
          <Card label="At risk" value={formatNumber(s.at_risk_count ?? 0)} tone="border-[var(--color-warn)]" />
          <Card label="Off track" value={formatNumber(s.off_track_count ?? 0)} tone="border-[var(--color-danger)]" />
          <Card label="Achieved" value={formatNumber(s.achieved_count ?? 0)} tone="border-[var(--color-ok)]" />
          <Card label="Missed" value={formatNumber(s.missed_count ?? 0)} tone="border-[var(--color-danger)]" />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Key results + check-in cadence</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-7">
          <Card label="Avg confidence" value={`${s.avg_confidence_pct ?? 0}%`} tone="border-[var(--color-info)]" sub="objectives, mean" />
          <Card label="KRs total" value={formatNumber(s.kr_total ?? 0)} />
          <Card label="KR avg progress" value={`${s.kr_avg_progress_pct ?? 0}%`} tone="border-[var(--color-info)]" />
          <Card label="KRs complete" value={formatNumber(s.kr_complete_count ?? 0)} tone="border-[var(--color-ok)]" sub="≥100% target" />
          <Card label="KRs at risk" value={formatNumber(s.kr_at_risk_count ?? 0)} tone="border-[var(--color-warn)]" sub="progress under 50%" />
          <Card label="Last check-in" value={s.last_check_in_at ? new Date(s.last_check_in_at).toLocaleDateString() : "—"} />
          <Card label="Days since check-in"
                value={`${s.days_since_last_check_in ?? 0}d`}
                tone={staleCheckIn ? "border-[var(--color-danger)]" : "border-[var(--color-ok)]"}
                sub={staleCheckIn ? "STALE — weekly cadence missed" : "fresh"} />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Objectives (top 30, priority then newest)</h2>
        {objectives.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-center text-sm">
            <span className="text-[var(--color-muted)]">No objectives logged yet for this quarter.</span>
            <div className="mt-2 text-xs text-[var(--color-muted)]">
              Call <code className="font-mono">log_founder_okr_create_objective(p_quarter, p_title, ...)</code> to start.
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="py-2 pr-3">Priority</th>
                  <th className="py-2 pr-3">Objective</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3 tabular-nums">Confidence</th>
                  <th className="py-2 pr-3 tabular-nums">KRs</th>
                  <th className="py-2 pr-3 tabular-nums">KR avg</th>
                </tr>
              </thead>
              <tbody>
                {objectives.map((o) => {
                  const krs = krMap.get(o.id) ?? [];
                  return (
                    <>
                      <tr key={o.id} className="border-b border-[var(--color-border)]">
                        <td className="py-2 pr-3">
                          <span className={`text-[10px] uppercase tracking-wider font-semibold border rounded px-2 py-0.5 ${PRIORITY_TONE[o.priority] ?? ""}`}>
                            {o.priority}
                          </span>
                        </td>
                        <td className="py-2 pr-3 max-w-md">{o.objective_title}</td>
                        <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{o.objective_kind ?? "—"}</td>
                        <td className={`py-2 pr-3 text-xs uppercase tracking-wider font-semibold ${STATUS_TONE[o.status] ?? "text-[var(--color-muted)]"}`}>
                          {o.status}
                        </td>
                        <td className={`py-2 pr-3 tabular-nums text-xs font-semibold ${confidenceTone(o.confidence_pct ?? 0)}`}>
                          {o.confidence_pct}%
                        </td>
                        <td className="py-2 pr-3 tabular-nums text-xs">{o.kr_count}</td>
                        <td className={`py-2 pr-3 tabular-nums text-xs ${progressTone(Number(o.kr_avg_progress ?? 0))}`}>
                          {o.kr_avg_progress}%
                        </td>
                      </tr>
                      {krs.length > 0 ? (
                        <tr key={`${o.id}-krs`} className="border-b border-[var(--color-border)] bg-[var(--color-bg)]/40">
                          <td colSpan={7} className="py-2 px-3">
                            <details className="text-xs">
                              <summary className="cursor-pointer text-[var(--color-muted)] hover:text-[var(--color-accent)]">
                                Reveal {krs.length} key result{krs.length === 1 ? "" : "s"}
                              </summary>
                              <ul className="mt-2 space-y-1 pl-3">
                                {krs.map((k) => (
                                  <li key={k.id} className="flex flex-wrap items-center gap-2">
                                    <span className="font-mono text-[10px] text-[var(--color-muted)]">KR</span>
                                    <span className="flex-1">{k.kr_title}</span>
                                    <span className="tabular-nums">
                                      {formatNumber(k.current_value)}
                                      {k.target_value != null ? ` / ${formatNumber(k.target_value)}` : ""}
                                      {k.target_unit ? ` ${k.target_unit}` : ""}
                                    </span>
                                    <span className={`tabular-nums font-semibold ${progressTone(Number(k.progress_pct ?? 0))}`}>
                                      {k.progress_pct}%
                                    </span>
                                  </li>
                                ))}
                              </ul>
                            </details>
                          </td>
                        </tr>
                      ) : null}
                    </>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Latest check-ins (top 12)</h2>
        {checkIns.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-center text-sm">
            <span className="text-[var(--color-muted)]">No check-ins logged yet.</span> Weekly cadence — every Monday.
          </div>
        ) : (
          <div className="space-y-2">
            {checkIns.map((c) => (
              <div key={c.id} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3 text-sm">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="font-semibold">{c.objective_title}</div>
                  <div className="flex items-center gap-2 text-xs">
                    <span className={`font-semibold ${confidenceTone(c.confidence_pct ?? 0)}`}>
                      {c.confidence_pct ?? "—"}%
                    </span>
                    <span className="text-[var(--color-muted)]">{new Date(c.check_in_at).toLocaleString()}</span>
                  </div>
                </div>
                {c.summary ? <p className="mt-2 text-xs">{c.summary}</p> : null}
                {c.blockers ? (
                  <p className="mt-1 text-xs text-[var(--color-warn)]">
                    <span className="font-semibold">Blockers:</span> {c.blockers}
                  </p>
                ) : null}
              </div>
            ))}
          </div>
        )}
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Cadence — Quarter kickoff (week 1): draft 3-7 objectives + 2-5 KRs each + baseline confidence.
        Weekly (every Monday): one check-in per objective with confidence delta + summary + blockers.
        Quarter close (week 13): mark achieved/missed, write retro into <code>founder_decisions</code>.
        Confidence under 30% auto-flags off_track; under 60% auto-flags at_risk via <code>log_founder_okr_check_in</code>.
      </p>
    </div>
  );
}
