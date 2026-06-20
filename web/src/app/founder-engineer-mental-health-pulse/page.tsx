import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_surveys: number;
  draft_surveys: number;
  sent_surveys: number;
  collecting_surveys: number;
  closed_surveys: number;
  total_responses: number;
  unique_respondents: number;
  avg_wellness_score: number | null;
  avg_stress_score: number | null;
  high_risk_count: number;
  medium_risk_count: number;
  low_risk_count: number;
  high_risk_pct: number;
  would_recommend_pct: number;
  responses_last_30d: number;
  latest_survey_label: string | null;
};

type Survey = {
  id: string;
  survey_label: string;
  kind: string;
  period_start: string;
  period_end: string;
  target_count: number;
  sent_count: number;
  response_count: number;
  avg_wellness_score: number | null;
  status: string;
  sent_at: string | null;
  closed_at: string | null;
  created_at: string;
};

type Response = {
  id: string;
  survey_id: string;
  survey_label: string;
  engineer_user_id: string;
  wellness_score: number;
  stress_score: number;
  burnout_risk_band: string;
  top_stressor: string | null;
  top_positive: string | null;
  would_recommend: boolean | null;
  qualitative_feedback: string | null;
  responded_at: string;
};

type AtRisk = {
  engineer_user_id: string;
  wellness_score: number;
  stress_score: number;
  burnout_risk_band: string;
  top_stressor: string | null;
  responded_at: string;
  survey_label: string;
};

function bandColor(band: string): { bg: string; fg: string } {
  if (band === "high") return { bg: "#fee2e2", fg: "#991b1b" };
  if (band === "medium") return { bg: "#fef3c7", fg: "#92400e" };
  return { bg: "#dcfce7", fg: "#065f46" };
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [{ data: sumRows }, { data: surveysRows }, { data: respRows }, { data: atRiskRows }] = await Promise.all([
    sb.rpc("founder_engineer_mental_health_summary"),
    sb.rpc("founder_engineer_mental_health_surveys_recent"),
    sb.rpc("founder_engineer_mental_health_responses_recent"),
    sb.rpc("founder_engineer_mental_health_at_risk_engineers"),
  ]);

  const s: Summary = (Array.isArray(sumRows) ? sumRows[0] : sumRows) ?? {
    total_surveys: 0, draft_surveys: 0, sent_surveys: 0, collecting_surveys: 0, closed_surveys: 0,
    total_responses: 0, unique_respondents: 0, avg_wellness_score: null, avg_stress_score: null,
    high_risk_count: 0, medium_risk_count: 0, low_risk_count: 0,
    high_risk_pct: 0, would_recommend_pct: 0, responses_last_30d: 0, latest_survey_label: null,
  };
  const surveys: Survey[] = (surveysRows as Survey[]) ?? [];
  const responses: Response[] = (respRows as Response[]) ?? [];
  const atRisk: AtRisk[] = (atRiskRows as AtRisk[]) ?? [];

  return (
    <main style={{ maxWidth: 1180, margin: "0 auto", padding: 24, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Engineer Mental Health Pulse</h1>
      <p style={{ color: "#666", marginBottom: 20 }}>Wellness + stress + burnout-risk tracker across pulse surveys · field engineer mental health monitoring</p>

      {atRisk.length > 0 && (
        <div style={{ background: "#fee2e2", border: "1px solid #fca5a5", borderRadius: 10, padding: 14, marginBottom: 20 }}>
          <div style={{ fontWeight: 700, color: "#991b1b", fontSize: 14 }}>
            {atRisk.length} engineer{atRisk.length === 1 ? "" : "s"} flagged at HIGH burnout risk — review feed below.
          </div>
        </div>
      )}

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 12, marginBottom: 28 }}>
        {[
          ["Total surveys", formatNumber(s.total_surveys)],
          ["Draft", formatNumber(s.draft_surveys)],
          ["Sent", formatNumber(s.sent_surveys)],
          ["Collecting", formatNumber(s.collecting_surveys)],
          ["Closed", formatNumber(s.closed_surveys)],
          ["Total responses", formatNumber(s.total_responses)],
          ["Unique respondents", formatNumber(s.unique_respondents)],
          ["Avg wellness (1-10)", s.avg_wellness_score != null ? String(s.avg_wellness_score) : "—"],
          ["Avg stress (1-10)", s.avg_stress_score != null ? String(s.avg_stress_score) : "—"],
          ["High-risk count", formatNumber(s.high_risk_count)],
          ["Medium-risk count", formatNumber(s.medium_risk_count)],
          ["Low-risk count", formatNumber(s.low_risk_count)],
          ["High-risk %", `${s.high_risk_pct ?? 0}%`],
          ["Would-recommend %", `${s.would_recommend_pct ?? 0}%`],
          ["Responses 30d", formatNumber(s.responses_last_30d)],
          ["Latest survey", s.latest_survey_label ?? "—"],
        ].map(([label, value]) => (
          <div key={label as string} style={{ background: "#fff", border: "1px solid #e5e7eb", borderRadius: 10, padding: 14 }}>
            <div style={{ color: "#6b7280", fontSize: 12, fontWeight: 500 }}>{label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>At-risk engineers ({atRisk.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#fef2f2" }}>
              <tr>
                {["Engineer", "Wellness", "Stress", "Band", "Top stressor", "Survey", "Responded"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {atRisk.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: 16, color: "#16a34a", textAlign: "center" }}>No high-risk engineers flagged.</td></tr>
              ) : atRisk.map((r) => (
                <tr key={r.engineer_user_id} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={{ padding: "10px 12px", fontFamily: "monospace", fontSize: 11, color: "#374151" }}>{r.engineer_user_id.slice(0,8)}…</td>
                  <td style={{ padding: "10px 12px", fontWeight: 600 }}>{r.wellness_score}/10</td>
                  <td style={{ padding: "10px 12px", fontWeight: 600 }}>{r.stress_score}/10</td>
                  <td style={{ padding: "10px 12px" }}>
                    <span style={{ background: "#fee2e2", color: "#991b1b", padding: "2px 8px", borderRadius: 6, fontWeight: 600, fontSize: 11 }}>HIGH</span>
                  </td>
                  <td style={{ padding: "10px 12px", color: "#374151" }}>{r.top_stressor ?? "—"}</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280" }}>{r.survey_label}</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280" }}>{r.responded_at.slice(0,10)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Survey ledger ({surveys.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Label", "Kind", "Period", "Status", "Target", "Sent", "Responses", "Avg wellness", "Created"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {surveys.length === 0 ? (
                <tr><td colSpan={9} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No surveys created yet.</td></tr>
              ) : surveys.map((sv) => (
                <tr key={sv.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={{ padding: "10px 12px", fontWeight: 500 }}>{sv.survey_label}</td>
                  <td style={{ padding: "10px 12px", color: "#374151" }}>{sv.kind}</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280", fontSize: 12 }}>{sv.period_start} → {sv.period_end}</td>
                  <td style={{ padding: "10px 12px" }}>
                    <span style={{ background: "#eef2ff", color: "#3730a3", padding: "2px 8px", borderRadius: 6, fontWeight: 600, fontSize: 11 }}>{sv.status}</span>
                  </td>
                  <td style={{ padding: "10px 12px" }}>{formatNumber(sv.target_count)}</td>
                  <td style={{ padding: "10px 12px" }}>{formatNumber(sv.sent_count)}</td>
                  <td style={{ padding: "10px 12px", fontWeight: 600 }}>{formatNumber(sv.response_count)}</td>
                  <td style={{ padding: "10px 12px" }}>{sv.avg_wellness_score != null ? String(sv.avg_wellness_score) : "—"}</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280" }}>{sv.created_at.slice(0,10)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Response feed ({responses.length})</h2>
        <div style={{ display: "grid", gap: 10 }}>
          {responses.length === 0 ? (
            <div style={{ color: "#999", padding: 14, border: "1px dashed #e5e7eb", borderRadius: 10 }}>No responses recorded yet.</div>
          ) : responses.map((r) => {
            const c = bandColor(r.burnout_risk_band);
            return (
              <div key={r.id} style={{ border: "1px solid #e5e7eb", borderRadius: 10, padding: 14, background: "#fff" }}>
                <div style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 8 }}>
                  <div>
                    <div style={{ fontSize: 13, color: "#6b7280" }}>
                      <span style={{ fontFamily: "monospace" }}>{r.engineer_user_id.slice(0,8)}…</span> · {r.survey_label}
                    </div>
                    <div style={{ marginTop: 6, fontSize: 15, fontWeight: 600 }}>
                      Wellness {r.wellness_score}/10 · Stress {r.stress_score}/10
                      <span style={{ marginLeft: 10, background: c.bg, color: c.fg, padding: "2px 8px", borderRadius: 6, fontSize: 11, fontWeight: 700, textTransform: "uppercase" }}>{r.burnout_risk_band}</span>
                    </div>
                  </div>
                  <div style={{ color: "#9ca3af", fontSize: 12 }}>{r.responded_at.slice(0,10)}</div>
                </div>
                {r.top_stressor && (
                  <div style={{ marginTop: 8, fontSize: 13 }}>
                    <span style={{ color: "#991b1b", fontWeight: 600 }}>Top stressor: </span>
                    <span style={{ color: "#374151" }}>{r.top_stressor}</span>
                  </div>
                )}
                {r.top_positive && (
                  <div style={{ marginTop: 4, fontSize: 13 }}>
                    <span style={{ color: "#065f46", fontWeight: 600 }}>Top positive: </span>
                    <span style={{ color: "#374151" }}>{r.top_positive}</span>
                  </div>
                )}
                {r.qualitative_feedback && (
                  <p style={{ marginTop: 8, fontSize: 13, color: "#4b5563", whiteSpace: "pre-wrap", background: "#f9fafb", padding: 10, borderRadius: 6 }}>{r.qualitative_feedback}</p>
                )}
                {r.would_recommend != null && (
                  <div style={{ marginTop: 6, fontSize: 12, color: "#6b7280" }}>
                    Would recommend EquipSeva: <strong>{r.would_recommend ? "yes" : "no"}</strong>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </section>
    </main>
  );
}
