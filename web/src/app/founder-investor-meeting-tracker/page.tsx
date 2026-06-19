import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder investor meeting tracker — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_targets: number;
  identified_count: number;
  first_meeting_count: number;
  partner_review_count: number;
  dd_count: number;
  term_sheet_count: number;
  closed_won_count: number;
  passed_count: number;
  total_meetings: number;
  meetings_last_30d: number;
  meetings_this_week: number;
  overdue_followups_count: number;
  avg_sentiment_score: number;
  top_priority_targets: number;
  days_to_next_meeting_min: number;
};

type TargetRow = {
  id: string;
  investor_firm_name: string;
  investor_partner_name: string | null;
  deal_status: string;
  priority: string;
  stage_preference: string | null;
  check_size_min_rupees: number | null;
  check_size_max_rupees: number | null;
  first_meeting_at: string | null;
  last_meeting_at: string | null;
  next_followup_due_at: string | null;
  days_since_last_meeting: number | null;
  meetings_count: number;
  referred_by: string | null;
  created_at: string;
};

type MeetingRow = {
  id: string;
  target_id: string;
  firm_name: string;
  partner_name: string | null;
  meeting_at: string;
  meeting_kind: string | null;
  attendees: string | null;
  summary: string | null;
  sentiment: string | null;
  follow_up_needed: boolean;
  follow_up_action: string | null;
  follow_up_due: string | null;
  created_at: string;
};

type OverdueRow = {
  id: string;
  investor_firm_name: string;
  investor_partner_name: string | null;
  deal_status: string;
  priority: string;
  next_followup_due_at: string;
  days_overdue: number;
  last_meeting_at: string | null;
};

const STATUS_LABEL: Record<string, string> = {
  identified: "Identified",
  first_meeting: "First meeting",
  partner_review: "Partner review",
  dd_in_progress: "DD",
  term_sheet: "Term sheet",
  passed: "Passed",
  closed_won: "Closed won",
};

const STATUS_TONE: Record<string, string> = {
  identified: "text-[var(--color-muted)] border-[var(--color-border)]",
  first_meeting: "text-[var(--color-info)] border-[var(--color-info)]",
  partner_review: "text-[var(--color-info)] border-[var(--color-info)]",
  dd_in_progress: "text-[var(--color-warn)] border-[var(--color-warn)]",
  term_sheet: "text-[var(--color-ok)] border-[var(--color-ok)]",
  passed: "text-[var(--color-danger)] border-[var(--color-danger)]",
  closed_won: "text-[var(--color-ok)] border-[var(--color-ok)]",
};

const PRIORITY_TONE: Record<string, string> = {
  high: "text-[var(--color-danger)]",
  medium: "text-[var(--color-warn)]",
  low: "text-[var(--color-muted)]",
};

const KIND_LABEL: Record<string, string> = {
  intro: "Intro",
  pitch: "Pitch",
  deep_dive: "Deep dive",
  partner_meeting: "Partner mtg",
  dd_call: "DD call",
  term_negotiation: "Term nego",
  closing: "Closing",
  social: "Social",
};

const SENTIMENT_LABEL: Record<string, string> = {
  strongly_positive: "++",
  positive: "+",
  neutral: "=",
  cool: "-",
  negative: "--",
};

const SENTIMENT_TONE: Record<string, string> = {
  strongly_positive: "text-[var(--color-ok)]",
  positive: "text-[var(--color-ok)]",
  neutral: "text-[var(--color-muted)]",
  cool: "text-[var(--color-warn)]",
  negative: "text-[var(--color-danger)]",
};

function formatLakh(n: number | null): string {
  if (n === null || n === undefined || Number.isNaN(Number(n))) return "—";
  const v = Number(n);
  if (v >= 10000000) return `${(v / 10000000).toFixed(1)}Cr`;
  if (v >= 100000) return `${(v / 100000).toFixed(1)}L`;
  return formatNumber(v);
}

export default async function FounderInvestorMeetingTrackerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, tgtRes, mtgRes, ovdRes] = await Promise.all([
    supabase.rpc("founder_investor_meeting_tracker_summary"),
    supabase.rpc("founder_investor_targets_recent", { p_limit: 30 }),
    supabase.rpc("founder_investor_meetings_recent", { p_target_id: null, p_limit: 50 }),
    supabase.rpc("founder_investor_overdue_followups"),
  ]);
  if (sumRes.error) throw new Error(`founder_investor_meeting_tracker_summary: ${sumRes.error.message}`);
  if (tgtRes.error) throw new Error(`founder_investor_targets_recent: ${tgtRes.error.message}`);
  if (mtgRes.error) throw new Error(`founder_investor_meetings_recent: ${mtgRes.error.message}`);
  if (ovdRes.error) throw new Error(`founder_investor_overdue_followups: ${ovdRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const targets = (tgtRes.data ?? []) as TargetRow[];
  const meetings = (mtgRes.data ?? []) as MeetingRow[];
  const overdue = (ovdRes.data ?? []) as OverdueRow[];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder investor meeting tracker ★ r1343</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Fundraise institutional memory · funnel from identified → closed_won · meeting cadence · sentiment trend · overdue follow-up triage · 15 KPIs
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-5">
          <div className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total targets</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-accent)]">{formatNumber(s.total_targets)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Identified</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-muted)]">{formatNumber(s.identified_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">First meeting</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-info)]">{formatNumber(s.first_meeting_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Partner review</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-info)]">{formatNumber(s.partner_review_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">DD in progress</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{formatNumber(s.dd_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Term sheet</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.term_sheet_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Closed won</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.closed_won_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Passed</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{formatNumber(s.passed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total meetings</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.total_meetings)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Mtgs last 30d</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.meetings_last_30d)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Mtgs this week</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${s.meetings_this_week >= 3 ? "text-[var(--color-ok)]" : "text-[var(--color-warn)]"}`}>{formatNumber(s.meetings_this_week)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Overdue follow-ups</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${s.overdue_followups_count > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-ok)]"}`}>{formatNumber(s.overdue_followups_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg sentiment 90d (-2 to +2)</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${Number(s.avg_sentiment_score) > 0 ? "text-[var(--color-ok)]" : Number(s.avg_sentiment_score) < 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>{Number(s.avg_sentiment_score).toFixed(2)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">High-priority active</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{formatNumber(s.top_priority_targets)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Days to next mtg</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.days_to_next_meeting_min)}<span className="text-xs text-[var(--color-muted)]">d</span></div>
          </div>
        </section>
      ) : null}

      {overdue.length > 0 ? (
        <section>
          <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-danger)]">Overdue follow-ups ({overdue.length}) — chase TODAY</h2>
          <div className="overflow-x-auto rounded-lg border border-[var(--color-danger)] bg-[color-mix(in_srgb,var(--color-danger)_6%,transparent)]">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 px-3">Firm</th>
                  <th className="py-2 pr-3">Partner</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3">Priority</th>
                  <th className="py-2 pr-3">Follow-up due</th>
                  <th className="py-2 pr-3 text-right">Days overdue</th>
                  <th className="py-2 pr-3">Last mtg</th>
                </tr>
              </thead>
              <tbody>
                {overdue.map(o => (
                  <tr key={o.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 px-3 font-semibold">{o.investor_firm_name}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{o.investor_partner_name ?? "—"}</td>
                    <td className="py-2 pr-3">
                      <span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${STATUS_TONE[o.deal_status] ?? ""}`}>{STATUS_LABEL[o.deal_status] ?? o.deal_status}</span>
                    </td>
                    <td className={`py-2 pr-3 uppercase text-[10px] tracking-wider ${PRIORITY_TONE[o.priority] ?? ""}`}>{o.priority}</td>
                    <td className="py-2 pr-3 tabular-nums">{o.next_followup_due_at}</td>
                    <td className={`py-2 pr-3 text-right tabular-nums font-semibold ${o.days_overdue > 7 ? "text-[var(--color-danger)]" : "text-[var(--color-warn)]"}`}>{o.days_overdue}d</td>
                    <td className="py-2 pr-3 tabular-nums text-[var(--color-muted)]">{o.last_meeting_at ? new Date(o.last_meeting_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" }) : "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Investor targets (top 30 by priority + recency)</h2>
        {targets.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No investor targets registered. Use <code className="font-mono">log_founder_investor_register_target()</code>.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 pr-3">Firm</th>
                  <th className="py-2 pr-3">Partner</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3">Priority</th>
                  <th className="py-2 pr-3">Stage</th>
                  <th className="py-2 pr-3 text-right">Check (min–max)</th>
                  <th className="py-2 pr-3 text-right">Mtgs</th>
                  <th className="py-2 pr-3">Last mtg</th>
                  <th className="py-2 pr-3 text-right">Days since</th>
                  <th className="py-2 pr-3">Follow-up due</th>
                  <th className="py-2 pr-3">Ref</th>
                </tr>
              </thead>
              <tbody>
                {targets.map(t => (
                  <tr key={t.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 font-semibold max-w-[180px] truncate" title={t.investor_firm_name}>{t.investor_firm_name}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)] max-w-[140px] truncate" title={t.investor_partner_name ?? ""}>{t.investor_partner_name ?? "—"}</td>
                    <td className="py-2 pr-3">
                      <span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${STATUS_TONE[t.deal_status] ?? ""}`}>{STATUS_LABEL[t.deal_status] ?? t.deal_status}</span>
                    </td>
                    <td className={`py-2 pr-3 uppercase text-[10px] tracking-wider ${PRIORITY_TONE[t.priority] ?? ""}`}>{t.priority}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{t.stage_preference ?? "—"}</td>
                    <td className="py-2 pr-3 text-right tabular-nums">{formatLakh(t.check_size_min_rupees)}{t.check_size_max_rupees ? ` – ${formatLakh(t.check_size_max_rupees)}` : ""}</td>
                    <td className="py-2 pr-3 text-right tabular-nums">{formatNumber(t.meetings_count)}</td>
                    <td className="py-2 pr-3 tabular-nums text-[var(--color-muted)]">{t.last_meeting_at ? new Date(t.last_meeting_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" }) : "—"}</td>
                    <td className={`py-2 pr-3 text-right tabular-nums ${t.days_since_last_meeting !== null && t.days_since_last_meeting > 30 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]"}`}>{t.days_since_last_meeting ?? "—"}</td>
                    <td className={`py-2 pr-3 tabular-nums ${t.next_followup_due_at && new Date(t.next_followup_due_at) < new Date() ? "text-[var(--color-danger)] font-semibold" : "text-[var(--color-muted)]"}`}>{t.next_followup_due_at ?? "—"}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)] max-w-[120px] truncate" title={t.referred_by ?? ""}>{t.referred_by ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Recent 50 meetings</h2>
        {meetings.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No meetings logged yet. Use <code className="font-mono">log_founder_investor_log_meeting()</code>.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 pr-3">When</th>
                  <th className="py-2 pr-3">Firm</th>
                  <th className="py-2 pr-3">Partner</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Sentiment</th>
                  <th className="py-2 pr-3">Summary</th>
                  <th className="py-2 pr-3">Follow-up</th>
                  <th className="py-2 pr-3">Due</th>
                </tr>
              </thead>
              <tbody>
                {meetings.map(m => (
                  <tr key={m.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 whitespace-nowrap text-[var(--color-muted)] tabular-nums">{new Date(m.meeting_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" })}</td>
                    <td className="py-2 pr-3 font-semibold max-w-[160px] truncate" title={m.firm_name}>{m.firm_name}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)] max-w-[140px] truncate" title={m.partner_name ?? ""}>{m.partner_name ?? "—"}</td>
                    <td className="py-2 pr-3">{m.meeting_kind ? KIND_LABEL[m.meeting_kind] ?? m.meeting_kind : <span className="text-[var(--color-muted)]">—</span>}</td>
                    <td className={`py-2 pr-3 tabular-nums font-bold ${m.sentiment ? SENTIMENT_TONE[m.sentiment] ?? "" : "text-[var(--color-muted)]"}`}>{m.sentiment ? SENTIMENT_LABEL[m.sentiment] ?? m.sentiment : "—"}</td>
                    <td className="py-2 pr-3 max-w-[280px] truncate" title={m.summary ?? ""}>{m.summary ?? <span className="text-[var(--color-muted)]">—</span>}</td>
                    <td className="py-2 pr-3 max-w-[200px] truncate" title={m.follow_up_action ?? ""}>{m.follow_up_needed ? (m.follow_up_action ?? <span className="text-[var(--color-warn)]">needed</span>) : <span className="text-[var(--color-muted)]">—</span>}</td>
                    <td className={`py-2 pr-3 tabular-nums ${m.follow_up_due && new Date(m.follow_up_due) < new Date() ? "text-[var(--color-danger)] font-semibold" : "text-[var(--color-muted)]"}`}>{m.follow_up_due ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
          <h3 className="text-sm font-semibold text-[var(--color-fg)]">Fundraise discipline</h3>
          <ul className="list-disc list-inside space-y-1">
            <li>Every conversation is a multi-meeting arc. Log within 24h — fresh recall, no retrofitting sentiment after the term sheet.</li>
            <li>Always stamp <code className="font-mono">follow_up_due</code>. If nothing is due, the deal is dying — mark passed or escalate to high.</li>
            <li>Sentiment score is a leading indicator. Cool/negative for 2+ meetings = either reposition or move on; do not let dead deals consume calendar.</li>
            <li>Days-since-last-meeting {">"} 30d on an active deal = warning. {">"} 60d = the partner has moved on; you just have not noticed.</li>
            <li>High-priority targets get weekly touch (call/note/update). Medium fortnightly. Low monthly.</li>
          </ul>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
          <h3 className="text-sm font-semibold text-[var(--color-fg)]">Cadence + funnel math</h3>
          <ul className="list-disc list-inside space-y-1">
            <li>Healthy seed funnel: {">="} 30 identified → {">="} 15 first meetings → {">="} 6 partner reviews → {">="} 3 DDs → 1–2 term sheets.</li>
            <li>Target {">="} 3 meetings/week while raising. Below that = pipeline death spiral.</li>
            <li>State machine: identified → first_meeting → partner_review → dd_in_progress → term_sheet → closed_won. Or → passed at any node.</li>
            <li>"Passed" is a feature, not a failure — fast no beats slow maybe. Update via <code className="font-mono">log_founder_investor_status_change()</code> the same day.</li>
            <li>Referred-by column tracks warm-intro source quality. Best referrers get more asks; cold-list converts {"<"} 5%.</li>
          </ul>
        </div>
      </section>
    </div>
  );
}
