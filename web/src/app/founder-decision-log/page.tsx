import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder decision log — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_decisions: number;
  decisions_last_30d: number;
  decisions_last_7d: number;
  decisions_today: number;
  avg_decisions_per_day_30d: number;
  one_way_door_count: number;
  reversible_count: number;
  high_impact_count: number;
  existential_impact_count: number;
  decisions_due_revisit: number;
  decisions_overdue_revisit: number;
  decisions_reviewed_with_outcome: number;
  last_decision_at: string | null;
  days_since_last_decision: number;
};

type DecisionRow = {
  id: string;
  decided_on: string;
  decision_title: string;
  decision_summary: string;
  decision_kind: string | null;
  confidence_at_decision: string | null;
  reversibility: string | null;
  impact_band: string | null;
  revisit_at: string | null;
  revisited_at: string | null;
  has_outcome: boolean;
  created_at: string;
};

type DueRow = {
  id: string;
  decided_on: string;
  decision_title: string;
  decision_kind: string | null;
  impact_band: string | null;
  reversibility: string | null;
  revisit_at: string;
  days_overdue: number;
};

const KIND_LABEL: Record<string, string> = {
  product: "Product",
  people: "People",
  strategy: "Strategy",
  tactical: "Tactical",
  financial: "Financial",
  partnership: "Partnership",
  regulatory: "Regulatory",
  other: "Other",
};

const REV_LABEL: Record<string, string> = {
  one_way_door: "One-way door",
  reversible_costly: "Reversible (costly)",
  reversible_cheap: "Reversible (cheap)",
  easily_reversible: "Easily reversible",
};

const IMPACT_TONE: Record<string, string> = {
  existential: "text-[var(--color-danger)] border-[var(--color-danger)]",
  high: "text-[var(--color-warn)] border-[var(--color-warn)]",
  medium: "text-[var(--color-info)] border-[var(--color-info)]",
  low: "text-[var(--color-muted)] border-[var(--color-border)]",
};

const CONF_TONE: Record<string, string> = {
  very_high: "text-[var(--color-ok)]",
  high: "text-[var(--color-ok)]",
  medium: "text-[var(--color-info)]",
  low: "text-[var(--color-warn)]",
};

export default async function FounderDecisionLogPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, recRes, dueRes] = await Promise.all([
    supabase.rpc("founder_decisions_summary"),
    supabase.rpc("founder_decisions_recent", { p_limit: 50 }),
    supabase.rpc("founder_decisions_due_revisit"),
  ]);
  if (sumRes.error) throw new Error(`founder_decisions_summary: ${sumRes.error.message}`);
  if (recRes.error) throw new Error(`founder_decisions_recent: ${recRes.error.message}`);
  if (dueRes.error) throw new Error(`founder_decisions_due_revisit: ${dueRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const recent = (recRes.data ?? []) as DecisionRow[];
  const due = (dueRes.data ?? []) as DueRow[];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder decision log ★ r1336</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          3 decisions/day discipline · Bezos reversibility framework · confidence + impact calibration · pre-commit reasoning + post-hoc outcome review · evidence we are thinking, not reacting
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-5">
          <div className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total decisions</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-accent)]">{formatNumber(s.total_decisions)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Today</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${s.decisions_today >= 3 ? "text-[var(--color-ok)]" : "text-[var(--color-warn)]"}`}>{formatNumber(s.decisions_today)}<span className="text-xs text-[var(--color-muted)]"> /3</span></div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Last 7d</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.decisions_last_7d)}<span className="text-xs text-[var(--color-muted)]"> /21</span></div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Last 30d</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.decisions_last_30d)}<span className="text-xs text-[var(--color-muted)]"> /90</span></div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg/day 30d</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${Number(s.avg_decisions_per_day_30d) >= 3 ? "text-[var(--color-ok)]" : "text-[var(--color-warn)]"}`}>{Number(s.avg_decisions_per_day_30d).toFixed(2)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">One-way doors</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{formatNumber(s.one_way_door_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Reversible</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.reversible_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">High impact</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{formatNumber(s.high_impact_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Existential</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{formatNumber(s.existential_impact_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Due revisit</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{formatNumber(s.decisions_due_revisit)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Overdue revisit ({">"}7d)</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{formatNumber(s.decisions_overdue_revisit)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Outcomes written</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.decisions_reviewed_with_outcome)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Days since last</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${s.days_since_last_decision <= 1 ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]"}`}>{formatNumber(s.days_since_last_decision)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Last decision</div>
            <div className="mt-1 text-sm font-semibold tabular-nums">{s.last_decision_at ? new Date(s.last_decision_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" }) : "—"}</div>
          </div>
        </section>
      ) : null}

      {due.length > 0 ? (
        <section>
          <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-danger)]">Decisions due revisit ({due.length})</h2>
          <div className="overflow-x-auto rounded-lg border border-[var(--color-danger)] bg-[color-mix(in_srgb,var(--color-danger)_6%,transparent)]">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 px-3">Revisit due</th>
                  <th className="py-2 pr-3">Decided</th>
                  <th className="py-2 pr-3">Title</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Impact</th>
                  <th className="py-2 pr-3">Reversibility</th>
                  <th className="py-2 pr-3 text-right">Days overdue</th>
                </tr>
              </thead>
              <tbody>
                {due.map(d => (
                  <tr key={d.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 px-3 tabular-nums font-semibold text-[var(--color-danger)]">{d.revisit_at}</td>
                    <td className="py-2 pr-3 tabular-nums text-[var(--color-muted)]">{d.decided_on}</td>
                    <td className="py-2 pr-3 max-w-[280px] truncate" title={d.decision_title}>{d.decision_title}</td>
                    <td className="py-2 pr-3">{d.decision_kind ? KIND_LABEL[d.decision_kind] : <span className="text-[var(--color-muted)]">—</span>}</td>
                    <td className="py-2 pr-3">
                      {d.impact_band ? (
                        <span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${IMPACT_TONE[d.impact_band] ?? ""}`}>{d.impact_band}</span>
                      ) : <span className="text-[var(--color-muted)]">—</span>}
                    </td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{d.reversibility ? REV_LABEL[d.reversibility] : "—"}</td>
                    <td className={`py-2 pr-3 text-right tabular-nums font-semibold ${d.days_overdue > 7 ? "text-[var(--color-danger)]" : "text-[var(--color-warn)]"}`}>{d.days_overdue}d</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Recent 50 decisions</h2>
        {recent.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No decisions logged yet. Target: 3/day. Log via <code className="font-mono">log_founder_decision_record()</code>.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 pr-3">Decided</th>
                  <th className="py-2 pr-3">Title</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Impact</th>
                  <th className="py-2 pr-3">Reversibility</th>
                  <th className="py-2 pr-3">Confidence</th>
                  <th className="py-2 pr-3">Revisit</th>
                  <th className="py-2 pr-3">Outcome</th>
                </tr>
              </thead>
              <tbody>
                {recent.map(d => (
                  <tr key={d.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 whitespace-nowrap text-[var(--color-muted)] tabular-nums">{d.decided_on}</td>
                    <td className="py-2 pr-3 max-w-[280px] truncate" title={d.decision_summary}>{d.decision_title}</td>
                    <td className="py-2 pr-3">{d.decision_kind ? KIND_LABEL[d.decision_kind] : <span className="text-[var(--color-muted)]">—</span>}</td>
                    <td className="py-2 pr-3">
                      {d.impact_band ? (
                        <span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${IMPACT_TONE[d.impact_band] ?? ""}`}>{d.impact_band}</span>
                      ) : <span className="text-[var(--color-muted)]">—</span>}
                    </td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{d.reversibility ? REV_LABEL[d.reversibility] : "—"}</td>
                    <td className={`py-2 pr-3 uppercase text-[10px] tracking-wider ${d.confidence_at_decision ? CONF_TONE[d.confidence_at_decision] ?? "" : "text-[var(--color-muted)]"}`}>{d.confidence_at_decision ?? "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-[var(--color-muted)]">
                      {d.revisit_at ? (
                        d.revisited_at ? (
                          <span className="text-[var(--color-ok)]">✓ {d.revisit_at}</span>
                        ) : (
                          <span>{d.revisit_at}</span>
                        )
                      ) : "—"}
                    </td>
                    <td className="py-2 pr-3">
                      {d.has_outcome ? (
                        <span className="text-[var(--color-ok)] text-[10px] uppercase tracking-wider">written</span>
                      ) : (
                        <span className="text-[var(--color-muted)] text-[10px] uppercase tracking-wider">pending</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
          <h3 className="text-sm font-semibold text-[var(--color-fg)]">3 decisions/day discipline</h3>
          <ul className="list-disc list-inside space-y-1">
            <li>Target: {">="} 3 logged decisions/day, average {">="} 3.0 over rolling 30d window.</li>
            <li>Log WITHIN 24h of making the call — fresh recall, no retrofitting.</li>
            <li>Write reasoning + alternatives + expected outcome BEFORE the result is known. Anti-revisionist.</li>
            <li>Stamp <code className="font-mono">revisit_at</code> at write-time, otherwise we never review.</li>
            <li>At revisit: write actual_outcome via <code className="font-mono">log_founder_decision_record_outcome()</code>, mark revisited via <code className="font-mono">log_founder_decision_revisit()</code>.</li>
          </ul>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
          <h3 className="text-sm font-semibold text-[var(--color-fg)]">Bezos reversibility framework</h3>
          <ul className="list-disc list-inside space-y-1">
            <li><span className="text-[var(--color-danger)] font-semibold">One-way door</span> — irreversible (sell-the-company, fire-the-cofounder). Slow, high rigor, board input.</li>
            <li><span className="text-[var(--color-warn)] font-semibold">Reversible (costly)</span> — undo in months, real cost. Move with care, ship anyway.</li>
            <li><span className="text-[var(--color-info)] font-semibold">Reversible (cheap)</span> — undo in days, low cost. Default speed, biased to act.</li>
            <li><span className="text-[var(--color-ok)] font-semibold">Easily reversible</span> — undo in hours. Ship, observe, iterate. Most decisions live here.</li>
            <li>Impact band (low/medium/high/existential) is orthogonal — high-impact reversible is still fast; low-impact one-way is still slow.</li>
          </ul>
        </div>
      </section>
    </div>
  );
}
