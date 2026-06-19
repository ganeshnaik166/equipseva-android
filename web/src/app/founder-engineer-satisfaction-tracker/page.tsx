import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder engineer satisfaction tracker — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  latest_survey_label: string | null;
  latest_nps: number | null;
  latest_csat: number | null;
  latest_response_rate_pct: number | null;
  latest_promoter_pct: number | null;
  latest_detractor_pct: number | null;
  all_time_response_count: number;
  surveys_sent_count: number;
  surveys_closed_count: number;
  qoq_nps_delta: number | null;
  top_friction_category: string | null;
  top_motivator_category: string | null;
  engineers_consistently_detractor_30d: number;
  last_survey_at: string | null;
  days_since_last_survey: number | null;
};

type ResponseRow = {
  id: string;
  survey_id: string;
  survey_label: string;
  engineer_user_id: string;
  nps_score: number | null;
  csat_score: number | null;
  category: string | null;
  top_friction: string | null;
  top_motivator: string | null;
  suggested_improvement: string | null;
  would_recommend: boolean | null;
  responded_at: string;
};

type SurveyRow = {
  id: string;
  survey_label: string;
  kind: string;
  status: string;
  period_start: string | null;
  period_end: string | null;
  target_recipient_count: number;
  sent_count: number;
  response_count: number;
  response_rate_pct: number | null;
  nps_score: number | null;
  csat_score: number | null;
  sent_at: string | null;
  closed_at: string | null;
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

const CATEGORY_TONE: Record<string, string> = {
  promoter:  "text-[var(--color-ok)]",
  passive:   "text-[var(--color-warn)]",
  detractor: "text-[var(--color-danger)]",
};

const STATUS_TONE: Record<string, string> = {
  draft:      "text-[var(--color-muted)]",
  sent:       "text-[var(--color-info)]",
  collecting: "text-[var(--color-warn)]",
  closed:     "text-[var(--color-ok)]",
};

function npsTone(nps: number | null): string {
  if (nps == null) return "border-[var(--color-border)]";
  if (nps >= 50) return "border-[var(--color-ok)]";
  if (nps >= 0)  return "border-[var(--color-warn)]";
  return "border-[var(--color-danger)]";
}

function deltaTone(delta: number | null): string {
  if (delta == null) return "border-[var(--color-border)]";
  if (delta > 0)  return "border-[var(--color-ok)]";
  if (delta < 0)  return "border-[var(--color-danger)]";
  return "border-[var(--color-border)]";
}

function staleTone(days: number | null): string {
  if (days == null) return "border-[var(--color-border)]";
  if (days <= 30) return "border-[var(--color-ok)]";
  if (days <= 60) return "border-[var(--color-warn)]";
  return "border-[var(--color-danger)]";
}

export default async function FounderEngineerSatisfactionTrackerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [summaryRes, responsesRes, surveysRes] = await Promise.all([
    supabase.rpc("founder_engineer_satisfaction_summary"),
    supabase.rpc("founder_engineer_pulse_responses_recent", { p_survey_id: null, p_limit: 100 }),
    supabase.rpc("founder_engineer_pulse_surveys_recent", { p_limit: 20 }),
  ]);
  if (summaryRes.error)   throw new Error(`founder_engineer_satisfaction_summary: ${summaryRes.error.message}`);
  if (responsesRes.error) throw new Error(`founder_engineer_pulse_responses_recent: ${responsesRes.error.message}`);
  if (surveysRes.error)   throw new Error(`founder_engineer_pulse_surveys_recent: ${surveysRes.error.message}`);

  const s = ((summaryRes.data ?? [])[0] ?? {}) as SummaryRow;
  const responses = (responsesRes.data ?? []) as ResponseRow[];
  const surveys = (surveysRes.data ?? []) as SurveyRow[];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder engineer satisfaction tracker · r1357</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Engineer NPS + CSAT pulse-survey ledger. Cadence: monthly pulse {"->"} quarterly NPS {"->"} tier-promo + offboarding ad-hoc.
          Detractor concentration {">="} 2 surveys in 30d = retention risk: triage with{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-action-items-cockpit">/founder-action-items-cockpit</a>.
        </p>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Pair with{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/engineer-retention">/engineer-retention</a> ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-hiring-pipeline">/founder-hiring-pipeline</a> ·{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-customer-success-playbook">/founder-customer-success-playbook</a>.
        </p>
      </header>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Latest survey snapshot</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          <Card label="Latest survey" value={s.latest_survey_label ?? "—"} tone="border-[var(--color-accent)]" sub="most recent campaign" />
          <Card label="Latest NPS"  value={s.latest_nps  != null ? s.latest_nps.toString()  : "—"} tone={npsTone(s.latest_nps)}  sub=">= 50 ok · >= 0 warn · < 0 danger" />
          <Card label="Latest CSAT" value={s.latest_csat != null ? `${s.latest_csat}/5`     : "—"} sub="1-5 scale" />
          <Card label="Response rate"  value={s.latest_response_rate_pct != null ? `${s.latest_response_rate_pct}%` : "—"} sub="responses / target" />
          <Card label="Promoter %"  value={s.latest_promoter_pct  != null ? `${s.latest_promoter_pct}%`  : "—"} tone="border-[var(--color-ok)]" />
          <Card label="Detractor %" value={s.latest_detractor_pct != null ? `${s.latest_detractor_pct}%` : "—"} tone="border-[var(--color-danger)]" />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Program cadence + signals</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <Card label="All-time responses" value={formatNumber(s.all_time_response_count ?? 0)} />
          <Card label="Surveys sent"   value={formatNumber(s.surveys_sent_count   ?? 0)} sub="status sent+collecting+closed" />
          <Card label="Surveys closed" value={formatNumber(s.surveys_closed_count ?? 0)} sub="program completed" />
          <Card label="QoQ NPS delta"  value={s.qoq_nps_delta != null ? (s.qoq_nps_delta > 0 ? `+${s.qoq_nps_delta}` : s.qoq_nps_delta.toString()) : "—"} tone={deltaTone(s.qoq_nps_delta)} sub="latest vs prior" />
          <Card
            label="Days since last survey"
            value={s.days_since_last_survey != null ? `${s.days_since_last_survey}d` : "—"}
            tone={staleTone(s.days_since_last_survey)}
            sub="cadence health"
          />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Qualitative + risk surface</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card label="Top friction"  value={s.top_friction_category  ?? "—"} sub="most-named pain point" />
          <Card label="Top motivator" value={s.top_motivator_category ?? "—"} sub="most-named lever" />
          <Card
            label="Repeat detractors 30d"
            value={formatNumber(s.engineers_consistently_detractor_30d ?? 0)}
            tone={s.engineers_consistently_detractor_30d > 0 ? "border-[var(--color-danger)]" : "border-[var(--color-ok)]"}
            sub=">= 2 detractor responses"
          />
          <Card label="Last survey at" value={s.last_survey_at ? new Date(s.last_survey_at).toLocaleDateString() : "—"} sub="most recent send" />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Latest responses (top 100, newest first)</h2>
        {responses.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-center text-sm">
            <span className="text-[var(--color-muted)]">No responses recorded yet.</span>
            <div className="mt-2 text-xs text-[var(--color-muted)]">
              Record with{" "}
              <code className="font-mono">log_founder_engineer_pulse_record_response(p_survey_id, p_engineer_user_id, ...)</code>.
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="py-2 pr-3">Survey</th>
                  <th className="py-2 pr-3">Engineer</th>
                  <th className="py-2 pr-3 tabular-nums">NPS</th>
                  <th className="py-2 pr-3 tabular-nums">CSAT</th>
                  <th className="py-2 pr-3">Category</th>
                  <th className="py-2 pr-3">Top friction</th>
                  <th className="py-2 pr-3">Top motivator</th>
                  <th className="py-2 pr-3">Recommend</th>
                  <th className="py-2 pr-3">Responded</th>
                </tr>
              </thead>
              <tbody>
                {responses.map((r) => (
                  <tr key={r.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 font-mono text-xs">{r.survey_label}</td>
                    <td className="py-2 pr-3 font-mono text-xs text-[var(--color-muted)]">{r.engineer_user_id.slice(0, 8)}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs font-semibold">{r.nps_score != null ? r.nps_score : "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{r.csat_score != null ? `${r.csat_score}/5` : "—"}</td>
                    <td className={`py-2 pr-3 text-xs uppercase tracking-wider font-semibold ${CATEGORY_TONE[r.category ?? ""] ?? "text-[var(--color-muted)]"}`}>
                      {r.category ?? "—"}
                    </td>
                    <td className="py-2 pr-3 text-xs max-w-[12rem] truncate" title={r.top_friction ?? ""}>{r.top_friction ?? "—"}</td>
                    <td className="py-2 pr-3 text-xs max-w-[12rem] truncate" title={r.top_motivator ?? ""}>{r.top_motivator ?? "—"}</td>
                    <td className="py-2 pr-3 text-xs">{r.would_recommend == null ? "—" : r.would_recommend ? "yes" : "no"}</td>
                    <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{new Date(r.responded_at).toLocaleDateString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Survey history (top 20, newest first)</h2>
        {surveys.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-center text-sm">
            <span className="text-[var(--color-muted)]">No surveys created yet.</span>
            <div className="mt-2 text-xs text-[var(--color-muted)]">
              Create with{" "}
              <code className="font-mono">log_founder_engineer_pulse_create_survey(p_survey_label, p_kind, ...)</code>.
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="py-2 pr-3">Label</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3">Period</th>
                  <th className="py-2 pr-3 tabular-nums">Target</th>
                  <th className="py-2 pr-3 tabular-nums">Responses</th>
                  <th className="py-2 pr-3 tabular-nums">Rate</th>
                  <th className="py-2 pr-3 tabular-nums">NPS</th>
                  <th className="py-2 pr-3 tabular-nums">CSAT</th>
                  <th className="py-2 pr-3">Sent</th>
                </tr>
              </thead>
              <tbody>
                {surveys.map((sv) => (
                  <tr key={sv.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 font-mono text-xs">{sv.survey_label}</td>
                    <td className="py-2 pr-3 text-xs">{sv.kind}</td>
                    <td className={`py-2 pr-3 text-xs uppercase tracking-wider font-semibold ${STATUS_TONE[sv.status] ?? "text-[var(--color-muted)]"}`}>
                      {sv.status}
                    </td>
                    <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">
                      {sv.period_start && sv.period_end ? `${sv.period_start} · ${sv.period_end}` : "—"}
                    </td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{formatNumber(sv.target_recipient_count)}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{formatNumber(sv.response_count)}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{sv.response_rate_pct != null ? `${sv.response_rate_pct}%` : "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs font-semibold">{sv.nps_score  != null ? sv.nps_score.toString()  : "—"}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{sv.csat_score != null ? `${sv.csat_score}/5` : "—"}</td>
                    <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{sv.sent_at ? new Date(sv.sent_at).toLocaleDateString() : "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Cadence notes — Monthly pulse: 3 questions max (NPS + top friction + top motivator), {">="} 60% response rate target.
        Quarterly NPS: full survey, anonymized, {">="} 80% target. Tier-promo: triggered post-promotion. Offboarding: mandatory.
        Detractor concentration ({">="} 2 detractor responses in 30d) auto-triages to retention 1:1. Days-since-last-survey
        {" >"} 60 is a program-health red flag (engineer voice goes silent). Pair qualitative themes here with quantitative
        churn signal in /engineer-retention — if friction theme matches churn driver, prioritize it on /founder-tech-debt-ledger.
      </p>
    </div>
  );
}