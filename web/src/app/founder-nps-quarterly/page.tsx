import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder NPS quarterly — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  latest_quarter_label: string;
  latest_nps_score: number;
  latest_response_count: number;
  latest_promoter_pct: number;
  latest_detractor_pct: number;
  response_rate_pct: number;
  prior_quarter_nps: number;
  nps_delta_qoq: number;
  all_time_promoter_count: number;
  all_time_detractor_count: number;
  surveys_sent_count: number;
  surveys_closed_count: number;
  hospitals_promoted_to_promoter_this_q: number;
  hospitals_demoted_to_detractor_this_q: number;
  median_score: number;
};

type Response = {
  id: string;
  survey_id: string;
  quarter_label: string;
  hospital_org_id: string;
  hospital_name: string;
  respondent_name: string | null;
  respondent_role: string | null;
  score: number;
  category: string;
  qualitative_feedback: string | null;
  responded_at: string;
};

type Survey = {
  id: string;
  quarter_label: string;
  period_start: string;
  period_end: string;
  status: string;
  target_recipient_count: number;
  sent_count: number;
  response_count: number;
  promoter_count: number;
  passive_count: number;
  detractor_count: number;
  nps_score: number | null;
  sent_at: string | null;
  closed_at: string | null;
};

function pctColor(pct: number, good = true) {
  if (good) return pct >= 50 ? "text-[var(--color-ok)]" : pct >= 20 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
  return pct >= 30 ? "text-[var(--color-danger)]" : pct >= 15 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
}

function npsColor(score: number) {
  if (score >= 50) return "text-[var(--color-ok)]";
  if (score >= 0) return "text-[var(--color-warn)]";
  return "text-[var(--color-danger)]";
}

function categoryColor(cat: string) {
  if (cat === "promoter") return "text-[var(--color-ok)]";
  if (cat === "detractor") return "text-[var(--color-danger)]";
  return "text-[var(--color-warn)]";
}

export default async function FounderNpsQuarterlyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [sumRes, respRes, trendRes] = await Promise.all([
    supabase.rpc("founder_nps_quarterly_summary"),
    supabase.rpc("founder_nps_responses_recent", { p_survey_id: null, p_limit: 50 }),
    supabase
      .from("founder_nps_surveys")
      .select("id,quarter_label,period_start,period_end,status,target_recipient_count,sent_count,response_count,promoter_count,passive_count,detractor_count,nps_score,sent_at,closed_at")
      .order("period_start", { ascending: false })
      .limit(4),
  ]);

  if (sumRes.error) throw new Error(`founder_nps_quarterly_summary: ${sumRes.error.message}`);
  if (respRes.error) throw new Error(`founder_nps_responses_recent: ${respRes.error.message}`);
  if (trendRes.error) throw new Error(`founder_nps_surveys trend: ${trendRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const responses = (respRes.data ?? []) as Response[];
  const trend = ((trendRes.data ?? []) as Survey[]).slice().reverse();

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder NPS quarterly r1326</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Hospital NPS survey infra · 15 KPIs · latest quarter + QoQ delta + promoter/detractor migration tracking
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Latest quarter</div>
            <div className="text-2xl font-semibold mt-1">{s.latest_quarter_label}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Latest NPS score</div>
            <div className={`text-2xl font-semibold mt-1 ${npsColor(Number(s.latest_nps_score))}`}>
              {Number(s.latest_nps_score).toFixed(1)}
            </div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Latest responses</div>
            <div className="text-2xl font-semibold mt-1">{formatNumber(s.latest_response_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Promoter %</div>
            <div className={`text-2xl font-semibold mt-1 ${pctColor(Number(s.latest_promoter_pct), true)}`}>
              {Number(s.latest_promoter_pct).toFixed(1)}%
            </div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Detractor %</div>
            <div className={`text-2xl font-semibold mt-1 ${pctColor(Number(s.latest_detractor_pct), false)}`}>
              {Number(s.latest_detractor_pct).toFixed(1)}%
            </div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Response rate</div>
            <div className={`text-2xl font-semibold mt-1 ${pctColor(Number(s.response_rate_pct), true)}`}>
              {Number(s.response_rate_pct).toFixed(1)}%
            </div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Prior quarter NPS</div>
            <div className={`text-2xl font-semibold mt-1 ${npsColor(Number(s.prior_quarter_nps))}`}>
              {Number(s.prior_quarter_nps).toFixed(1)}
            </div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">NPS delta QoQ</div>
            <div className={`text-2xl font-semibold mt-1 ${Number(s.nps_delta_qoq) >= 0 ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]"}`}>
              {Number(s.nps_delta_qoq) >= 0 ? "+" : ""}{Number(s.nps_delta_qoq).toFixed(1)}
            </div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">All-time promoters</div>
            <div className="text-2xl font-semibold mt-1 text-[var(--color-ok)]">{formatNumber(s.all_time_promoter_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">All-time detractors</div>
            <div className="text-2xl font-semibold mt-1 text-[var(--color-danger)]">{formatNumber(s.all_time_detractor_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Surveys sent</div>
            <div className="text-2xl font-semibold mt-1">{formatNumber(s.surveys_sent_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Surveys closed</div>
            <div className="text-2xl font-semibold mt-1">{formatNumber(s.surveys_closed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Promoted to promoter this Q</div>
            <div className="text-2xl font-semibold mt-1 text-[var(--color-ok)]">{formatNumber(s.hospitals_promoted_to_promoter_this_q)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Demoted to detractor this Q</div>
            <div className="text-2xl font-semibold mt-1 text-[var(--color-danger)]">{formatNumber(s.hospitals_demoted_to_detractor_this_q)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">Median score</div>
            <div className="text-2xl font-semibold mt-1">{Number(s.median_score).toFixed(1)}</div>
          </div>
        </section>
      ) : (
        <p className="text-sm text-[var(--color-muted)]">No survey data yet — create the first quarter via log_founder_nps_create_quarter().</p>
      )}

      <section>
        <h2 className="text-sm font-semibold mb-2">Quarterly trend (last 4 quarters)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-xs">
            <thead className="bg-[var(--color-surface-2)] text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Quarter</th>
                <th className="px-3 py-2 text-left">Status</th>
                <th className="px-3 py-2 text-right">Sent</th>
                <th className="px-3 py-2 text-right">Responses</th>
                <th className="px-3 py-2 text-right">Promoters</th>
                <th className="px-3 py-2 text-right">Passives</th>
                <th className="px-3 py-2 text-right">Detractors</th>
                <th className="px-3 py-2 text-right">NPS</th>
              </tr>
            </thead>
            <tbody>
              {trend.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-3 text-center text-[var(--color-muted)]">No surveys yet</td></tr>
              ) : (
                trend.map((q) => (
                  <tr key={q.id} className="border-t border-[var(--color-border)]">
                    <td className="px-3 py-2 font-medium">{q.quarter_label}</td>
                    <td className="px-3 py-2 text-[var(--color-muted)]">{q.status}</td>
                    <td className="px-3 py-2 text-right">{formatNumber(q.sent_count)}</td>
                    <td className="px-3 py-2 text-right">{formatNumber(q.response_count)}</td>
                    <td className="px-3 py-2 text-right text-[var(--color-ok)]">{formatNumber(q.promoter_count)}</td>
                    <td className="px-3 py-2 text-right text-[var(--color-warn)]">{formatNumber(q.passive_count)}</td>
                    <td className="px-3 py-2 text-right text-[var(--color-danger)]">{formatNumber(q.detractor_count)}</td>
                    <td className={`px-3 py-2 text-right font-semibold ${npsColor(Number(q.nps_score ?? 0))}`}>
                      {q.nps_score == null ? "-" : Number(q.nps_score).toFixed(1)}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-2">Latest quarter — top 50 responses</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-xs">
            <thead className="bg-[var(--color-surface-2)] text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Responded</th>
                <th className="px-3 py-2 text-left">Quarter</th>
                <th className="px-3 py-2 text-left">Hospital</th>
                <th className="px-3 py-2 text-left">Respondent</th>
                <th className="px-3 py-2 text-left">Role</th>
                <th className="px-3 py-2 text-right">Score</th>
                <th className="px-3 py-2 text-left">Category</th>
                <th className="px-3 py-2 text-left">Feedback</th>
              </tr>
            </thead>
            <tbody>
              {responses.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-3 text-center text-[var(--color-muted)]">No responses yet</td></tr>
              ) : (
                responses.map((r) => (
                  <tr key={r.id} className="border-t border-[var(--color-border)] align-top">
                    <td className="px-3 py-2 whitespace-nowrap text-[var(--color-muted)]">
                      {new Date(r.responded_at).toISOString().slice(0, 16).replace("T", " ")}
                    </td>
                    <td className="px-3 py-2">{r.quarter_label}</td>
                    <td className="px-3 py-2 font-medium">{r.hospital_name}</td>
                    <td className="px-3 py-2">{r.respondent_name ?? "-"}</td>
                    <td className="px-3 py-2 text-[var(--color-muted)]">{r.respondent_role ?? "-"}</td>
                    <td className="px-3 py-2 text-right font-semibold">{r.score}</td>
                    <td className={`px-3 py-2 capitalize ${categoryColor(r.category)}`}>{r.category}</td>
                    <td className="px-3 py-2 text-[var(--color-muted)] max-w-md">
                      {r.qualitative_feedback ? r.qualitative_feedback : <span className="text-[var(--color-muted)]">-</span>}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
        <p className="font-semibold text-[var(--color-text)]">Notes</p>
        <p>
          Send-mechanism is offline-driven for now (email + SMS); responses logged via this RPC.
          Workflow: founder calls log_founder_nps_create_quarter() to open a draft, sends survey
          out-of-band, then log_founder_nps_record_response() records each reply (status flips
          draft → collecting on first response).
        </p>
        <p>
          When a quarter is done, call log_founder_nps_close_quarter() to recompute nps_score and
          set status='closed'. NPS = (promoter% − detractor%); promoter = score {">="} 9,
          detractor = score {"<="} 6, passive in between.
        </p>
      </section>
    </div>
  );
}
