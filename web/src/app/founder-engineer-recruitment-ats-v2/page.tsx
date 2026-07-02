import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder engineer recruitment ATS v2 — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_candidates: number;
  candidates_with_panels: number;
  panels_scheduled: number;
  panels_completed: number;
  panels_cancelled: number;
  panels_rescheduled: number;
  panels_upcoming_7d: number;
  avg_aggregate_score: number;
  offers_total: number;
  offers_drafted: number;
  offers_sent: number;
  offers_negotiating: number;
  offers_accepted: number;
  offers_rejected_or_withdrawn: number;
  offer_acceptance_pct: number;
  avg_offered_ctc_rupees: number;
};

type PanelRow = {
  id: string;
  candidate_id: string;
  candidate_name: string;
  candidate_role: string;
  panel_label: string;
  panel_kind: string;
  scheduled_at: string | null;
  status: string;
  aggregate_score: number | null;
  completed_at: string | null;
  panelist_count: number;
  notes: string | null;
};

type OfferRow = {
  id: string;
  candidate_id: string;
  candidate_name: string;
  offered_role: string | null;
  offered_ctc_rupees: number | null;
  offered_band: string | null;
  offered_start_date: string | null;
  status: string;
  sent_at: string | null;
  response_at: string | null;
  signed_at: string | null;
  signing_bonus_rupees: number | null;
  days_since_sent: number | null;
  notes: string | null;
};

type UpcomingRow = {
  id: string;
  candidate_id: string;
  candidate_name: string;
  candidate_role: string;
  panel_label: string;
  panel_kind: string;
  scheduled_at: string;
  hours_until: number;
  panelist_count: number;
};

const PANEL_STATUS_TONE: Record<string, string> = {
  scheduled:   "text-[var(--color-info)]",
  completed:   "text-[var(--color-ok)]",
  cancelled:   "text-[var(--color-danger)]",
  rescheduled: "text-[var(--color-warn)]",
};

const OFFER_STATUS_TONE: Record<string, string> = {
  drafted:     "text-[var(--color-muted)]",
  sent:        "text-[var(--color-info)]",
  negotiating: "text-[var(--color-warn)]",
  accepted:    "text-[var(--color-ok)]",
  rejected:    "text-[var(--color-danger)]",
  withdrawn:   "text-[var(--color-danger)]",
  expired:     "text-[var(--color-muted)]",
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  return new Date(s).toISOString().slice(0, 10);
}

function fmtDateTime(s: string | null): string {
  if (!s) return "—";
  const d = new Date(s);
  return `${d.toISOString().slice(0, 10)} ${d.toISOString().slice(11, 16)}Z`;
}

function fmtRupees(n: number | null): string {
  if (n == null) return "—";
  return "Rs " + formatNumber(Math.round(n));
}

export default async function FounderEngineerRecruitmentAtsV2Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [summaryRes, panelsRes, offersRes, upcomingRes] = await Promise.all([
    supabase.rpc("founder_ats_v2_summary"),
    supabase.rpc("founder_ats_v2_panels_recent", { p_limit: 50 }),
    supabase.rpc("founder_ats_v2_offers_recent", { p_limit: 50 }),
    supabase.rpc("founder_ats_v2_panels_upcoming", { p_days_ahead: 14 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_ats_v2_summary: ${summaryRes.error.message}`);
  if (panelsRes.error) throw new Error(`founder_ats_v2_panels_recent: ${panelsRes.error.message}`);
  if (offersRes.error) throw new Error(`founder_ats_v2_offers_recent: ${offersRes.error.message}`);
  if (upcomingRes.error) throw new Error(`founder_ats_v2_panels_upcoming: ${upcomingRes.error.message}`);

  const s = (summaryRes.data?.[0] ?? null) as SummaryRow | null;
  const panels = (panelsRes.data ?? []) as PanelRow[];
  const offers = (offersRes.data ?? []) as OfferRow[];
  const upcoming = (upcomingRes.data ?? []) as UpcomingRow[];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder engineer recruitment ATS v2 ★★★★ r1432</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Full ATS extending r1346 hiring pipeline. Interview panels with aggregate scoring + offer tracker.
          Strictly founder-only. Not customer-facing.
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total candidates</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(s.total_candidates)}</div>
            <div className="text-xs text-[var(--color-muted)]">from r1346 pipeline</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Candidates with panels</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(s.candidates_with_panels)}</div>
            <div className="text-xs text-[var(--color-muted)]">at least one session</div>
          </div>
          <div className="rounded-lg border border-[var(--color-info)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Panels scheduled</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-info)]">{formatNumber(s.panels_scheduled)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-ok)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Panels completed</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-ok)]">{formatNumber(s.panels_completed)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-danger)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Panels cancelled</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-danger)]">{formatNumber(s.panels_cancelled)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-warn)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Panels rescheduled</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-warn)]">{formatNumber(s.panels_rescheduled)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Upcoming 7d</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-accent)]">{formatNumber(s.panels_upcoming_7d)}</div>
            <div className="text-xs text-[var(--color-muted)]">scheduled in next week</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg aggregate score</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{Number(s.avg_aggregate_score ?? 0).toFixed(2)}</div>
            <div className="text-xs text-[var(--color-muted)]">completed panels · 0–10</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Offers total</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(s.offers_total)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-muted)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Offers drafted</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-muted)]">{formatNumber(s.offers_drafted)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-info)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Offers sent</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-info)]">{formatNumber(s.offers_sent)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-warn)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Negotiating</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-warn)]">{formatNumber(s.offers_negotiating)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-ok)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Offers accepted</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-ok)]">{formatNumber(s.offers_accepted)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-danger)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Rejected/withdrawn</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-danger)]">{formatNumber(s.offers_rejected_or_withdrawn)}</div>
            <div className="text-xs text-[var(--color-muted)]">incl. expired</div>
          </div>
          <div className="rounded-lg border border-[var(--color-ok)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Offer acceptance %</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-ok)]">{Number(s.offer_acceptance_pct ?? 0).toFixed(2)}%</div>
            <div className="text-xs text-[var(--color-muted)]">of resolved offers</div>
          </div>
          <div className="rounded-lg border border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg offered CTC</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-accent)]">{fmtRupees(s.avg_offered_ctc_rupees)}</div>
            <div className="text-xs text-[var(--color-muted)]">annualised</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">
          Upcoming panels — next 14 days
        </h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-accent)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr className="border-b border-[var(--color-border)]">
                <th className="text-left px-3 py-2">Scheduled (UTC)</th>
                <th className="text-right px-3 py-2">Hours until</th>
                <th className="text-left px-3 py-2">Candidate</th>
                <th className="text-left px-3 py-2">Role</th>
                <th className="text-left px-3 py-2">Panel label</th>
                <th className="text-left px-3 py-2">Kind</th>
                <th className="text-right px-3 py-2">Panelists</th>
              </tr>
            </thead>
            <tbody>
              {upcoming.length === 0 ? (
                <tr><td colSpan={7} className="px-3 py-6 text-center text-[var(--color-muted)]">No upcoming panels in the next 14 days.</td></tr>
              ) : upcoming.map((r) => (
                <tr key={r.id} className="border-b border-[var(--color-border)]/40">
                  <td className="px-3 py-2 font-medium">{fmtDateTime(r.scheduled_at)}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--color-accent)]">{Number(r.hours_until ?? 0).toFixed(1)}h</td>
                  <td className="px-3 py-2">{r.candidate_name}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.candidate_role}</td>
                  <td className="px-3 py-2">{r.panel_label}</td>
                  <td className="px-3 py-2 text-[var(--color-info)]">{r.panel_kind}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.panelist_count)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">
          Interview panel ledger (most recent 50)
        </h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr className="border-b border-[var(--color-border)]">
                <th className="text-left px-3 py-2">Scheduled</th>
                <th className="text-left px-3 py-2">Candidate</th>
                <th className="text-left px-3 py-2">Role</th>
                <th className="text-left px-3 py-2">Panel label</th>
                <th className="text-left px-3 py-2">Kind</th>
                <th className="text-left px-3 py-2">Status</th>
                <th className="text-right px-3 py-2">Score</th>
                <th className="text-right px-3 py-2">Panelists</th>
                <th className="text-left px-3 py-2">Completed</th>
                <th className="text-left px-3 py-2">Notes</th>
              </tr>
            </thead>
            <tbody>
              {panels.length === 0 ? (
                <tr><td colSpan={10} className="px-3 py-6 text-center text-[var(--color-muted)]">No interview panels recorded yet.</td></tr>
              ) : panels.map((r) => (
                <tr key={r.id} className="border-b border-[var(--color-border)]/40">
                  <td className="px-3 py-2 text-[var(--color-muted)]">{fmtDate(r.scheduled_at)}</td>
                  <td className="px-3 py-2 font-medium">{r.candidate_name}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.candidate_role}</td>
                  <td className="px-3 py-2">{r.panel_label}</td>
                  <td className="px-3 py-2 text-[var(--color-info)]">{r.panel_kind}</td>
                  <td className={`px-3 py-2 font-medium ${PANEL_STATUS_TONE[r.status] ?? ""}`}>{r.status}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{r.aggregate_score == null ? "—" : Number(r.aggregate_score).toFixed(2)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.panelist_count)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{fmtDate(r.completed_at)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)] max-w-xs truncate">{r.notes ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">
          Offers feed (sorted by urgency — negotiating first)
        </h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr className="border-b border-[var(--color-border)]">
                <th className="text-left px-3 py-2">Candidate</th>
                <th className="text-left px-3 py-2">Offered role</th>
                <th className="text-left px-3 py-2">Band</th>
                <th className="text-right px-3 py-2">CTC</th>
                <th className="text-right px-3 py-2">Signing bonus</th>
                <th className="text-left px-3 py-2">Start date</th>
                <th className="text-left px-3 py-2">Status</th>
                <th className="text-left px-3 py-2">Sent</th>
                <th className="text-left px-3 py-2">Response</th>
                <th className="text-left px-3 py-2">Signed</th>
                <th className="text-right px-3 py-2">Days pending</th>
              </tr>
            </thead>
            <tbody>
              {offers.length === 0 ? (
                <tr><td colSpan={11} className="px-3 py-6 text-center text-[var(--color-muted)]">No offers issued yet.</td></tr>
              ) : offers.map((r) => (
                <tr key={r.id} className="border-b border-[var(--color-border)]/40">
                  <td className="px-3 py-2 font-medium">{r.candidate_name}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.offered_role ?? "—"}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.offered_band ?? "—"}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--color-accent)]">{fmtRupees(r.offered_ctc_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{fmtRupees(r.signing_bonus_rupees)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.offered_start_date ?? "—"}</td>
                  <td className={`px-3 py-2 font-medium ${OFFER_STATUS_TONE[r.status] ?? ""}`}>{r.status}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{fmtDate(r.sent_at)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{fmtDate(r.response_at)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{fmtDate(r.signed_at)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{r.days_since_sent == null ? "—" : Number(r.days_since_sent).toFixed(1)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="text-xs text-[var(--color-muted)] border-t border-[var(--color-border)] pt-3 space-y-1">
        <div>
          Benchmark · panel completion ≥ 80% (cancellation drag {"<"} 10%) · offer acceptance ≥ 65% post-send · sent→signed median ≤ 5 days for field-eng, ≤ 14 days for ops-lead · avg aggregate score for hired ≥ 6.5/10.
        </div>
        <div>
          Writers · log_founder_ats_v2_schedule_panel · log_founder_ats_v2_record_panel_outcome · log_founder_ats_v2_send_offer. Strict founder-gate via SECURITY DEFINER + is_founder(). Stacks on r1346 funnel — candidate_id FK ON DELETE CASCADE keeps the ATS clean when funnel entries are pruned.
        </div>
      </footer>
    </div>
  );
}
