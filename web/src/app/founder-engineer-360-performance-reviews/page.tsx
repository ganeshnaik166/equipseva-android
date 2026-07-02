import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_cycles: number;
  draft_cycles: number;
  in_progress_cycles: number;
  collecting_cycles: number;
  complete_cycles: number;
  published_cycles: number;
  total_responses: number;
  unique_subjects: number;
  self_response_count: number;
  peer_response_count: number;
  supervisor_response_count: number;
  customer_response_count: number;
  avg_overall_score: number | null;
  avg_technical_score: number | null;
  avg_customer_service_score: number | null;
  responses_last_30d: number;
};

type Cycle = {
  id: string;
  cycle_label: string;
  period_start: string;
  period_end: string;
  status: string;
  target_engineer_count: number;
  responses_collected: number;
  created_at: string;
};

type Response = {
  id: string;
  cycle_id: string;
  cycle_label: string;
  subject_engineer_user_id: string;
  reviewer_kind: string;
  reviewer_user_id: string | null;
  technical_skill_score: number;
  customer_service_score: number;
  team_collaboration_score: number;
  reliability_score: number;
  avg_score: number | null;
  strength_text: string | null;
  growth_area_text: string | null;
  qualitative_feedback: string | null;
  responded_at: string;
};

type TopPerformer = {
  subject_engineer_user_id: string;
  response_count: number;
  avg_overall_score: number | null;
  avg_technical: number | null;
  avg_customer_service: number | null;
  avg_collab: number | null;
  avg_reliability: number | null;
};

function statusColor(status: string): { bg: string; fg: string } {
  if (status === "published") return { bg: "#dcfce7", fg: "#065f46" };
  if (status === "complete") return { bg: "#dbeafe", fg: "#1e40af" };
  if (status === "collecting") return { bg: "#fef3c7", fg: "#92400e" };
  if (status === "in_progress") return { bg: "#fce7f3", fg: "#9d174d" };
  return { bg: "#f3f4f6", fg: "#374151" };
}

function kindColor(kind: string): { bg: string; fg: string } {
  if (kind === "self") return { bg: "#eef2ff", fg: "#3730a3" };
  if (kind === "peer") return { bg: "#ecfeff", fg: "#155e75" };
  if (kind === "supervisor") return { bg: "#fef3c7", fg: "#92400e" };
  if (kind === "customer") return { bg: "#fae8ff", fg: "#86198f" };
  return { bg: "#f3f4f6", fg: "#374151" };
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [{ data: sumRows }, { data: cycleRows }, { data: respRows }, { data: topRows }] = await Promise.all([
    sb.rpc("founder_engineer_360_perf_summary"),
    sb.rpc("founder_engineer_360_perf_cycles_recent"),
    sb.rpc("founder_engineer_360_perf_responses_recent"),
    sb.rpc("founder_engineer_360_perf_top_performers"),
  ]);

  const s: Summary = (Array.isArray(sumRows) ? sumRows[0] : sumRows) ?? {
    total_cycles: 0, draft_cycles: 0, in_progress_cycles: 0, collecting_cycles: 0,
    complete_cycles: 0, published_cycles: 0, total_responses: 0, unique_subjects: 0,
    self_response_count: 0, peer_response_count: 0, supervisor_response_count: 0, customer_response_count: 0,
    avg_overall_score: null, avg_technical_score: null, avg_customer_service_score: null, responses_last_30d: 0,
  };
  const cycles: Cycle[] = (cycleRows as Cycle[]) ?? [];
  const responses: Response[] = (respRows as Response[]) ?? [];
  const top: TopPerformer[] = (topRows as TopPerformer[]) ?? [];

  return (
    <main style={{ maxWidth: 1180, margin: "0 auto", padding: 24, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Engineer 360 Performance Reviews</h1>
      <p style={{ color: "#666", marginBottom: 20 }}>Self + peer + supervisor + customer feedback across review cycles. Aggregated KPIs, ranked performers, raw feed.</p>

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 12, marginBottom: 28 }}>
        {[
          ["Total cycles", formatNumber(s.total_cycles)],
          ["Draft", formatNumber(s.draft_cycles)],
          ["In progress", formatNumber(s.in_progress_cycles)],
          ["Collecting", formatNumber(s.collecting_cycles)],
          ["Complete", formatNumber(s.complete_cycles)],
          ["Published", formatNumber(s.published_cycles)],
          ["Total responses", formatNumber(s.total_responses)],
          ["Unique subjects", formatNumber(s.unique_subjects)],
          ["Self responses", formatNumber(s.self_response_count)],
          ["Peer responses", formatNumber(s.peer_response_count)],
          ["Supervisor responses", formatNumber(s.supervisor_response_count)],
          ["Customer responses", formatNumber(s.customer_response_count)],
          ["Avg overall (1-10)", s.avg_overall_score != null ? String(s.avg_overall_score) : "—"],
          ["Avg technical (1-10)", s.avg_technical_score != null ? String(s.avg_technical_score) : "—"],
          ["Avg customer-svc (1-10)", s.avg_customer_service_score != null ? String(s.avg_customer_service_score) : "—"],
          ["Responses 30d", formatNumber(s.responses_last_30d)],
        ].map(([label, value]) => (
          <div key={label as string} style={{ background: "#fff", border: "1px solid #e5e7eb", borderRadius: 10, padding: 14 }}>
            <div style={{ color: "#6b7280", fontSize: 12, fontWeight: 500 }}>{label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Top performers ({top.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f0fdf4" }}>
              <tr>
                {["Engineer", "Responses", "Overall", "Technical", "Customer svc", "Collab", "Reliability"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {top.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No ranked performers yet — collect responses first.</td></tr>
              ) : top.map((t) => (
                <tr key={t.subject_engineer_user_id} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={{ padding: "10px 12px", fontFamily: "monospace", fontSize: 11, color: "#374151" }}>{t.subject_engineer_user_id.slice(0,8)}…</td>
                  <td style={{ padding: "10px 12px" }}>{formatNumber(t.response_count)}</td>
                  <td style={{ padding: "10px 12px", fontWeight: 700, color: "#065f46" }}>{t.avg_overall_score != null ? `${t.avg_overall_score}/10` : "—"}</td>
                  <td style={{ padding: "10px 12px" }}>{t.avg_technical != null ? String(t.avg_technical) : "—"}</td>
                  <td style={{ padding: "10px 12px" }}>{t.avg_customer_service != null ? String(t.avg_customer_service) : "—"}</td>
                  <td style={{ padding: "10px 12px" }}>{t.avg_collab != null ? String(t.avg_collab) : "—"}</td>
                  <td style={{ padding: "10px 12px" }}>{t.avg_reliability != null ? String(t.avg_reliability) : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Review cycles ({cycles.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Label", "Period", "Status", "Target", "Collected", "Created"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {cycles.length === 0 ? (
                <tr><td colSpan={6} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No cycles created yet.</td></tr>
              ) : cycles.map((c) => {
                const sc = statusColor(c.status);
                return (
                  <tr key={c.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                    <td style={{ padding: "10px 12px", fontWeight: 500 }}>{c.cycle_label}</td>
                    <td style={{ padding: "10px 12px", color: "#6b7280", fontSize: 12 }}>{c.period_start} → {c.period_end}</td>
                    <td style={{ padding: "10px 12px" }}>
                      <span style={{ background: sc.bg, color: sc.fg, padding: "2px 8px", borderRadius: 6, fontWeight: 600, fontSize: 11 }}>{c.status}</span>
                    </td>
                    <td style={{ padding: "10px 12px" }}>{formatNumber(c.target_engineer_count)}</td>
                    <td style={{ padding: "10px 12px", fontWeight: 600 }}>{formatNumber(c.responses_collected)}</td>
                    <td style={{ padding: "10px 12px", color: "#6b7280" }}>{c.created_at.slice(0,10)}</td>
                  </tr>
                );
              })}
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
            const kc = kindColor(r.reviewer_kind);
            return (
              <div key={r.id} style={{ border: "1px solid #e5e7eb", borderRadius: 10, padding: 14, background: "#fff" }}>
                <div style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 8 }}>
                  <div>
                    <div style={{ fontSize: 13, color: "#6b7280" }}>
                      Subject <span style={{ fontFamily: "monospace" }}>{r.subject_engineer_user_id.slice(0,8)}…</span> · {r.cycle_label}
                    </div>
                    <div style={{ marginTop: 6, fontSize: 15, fontWeight: 600 }}>
                      Overall {r.avg_score != null ? `${r.avg_score}/10` : "—"}
                      <span style={{ marginLeft: 10, background: kc.bg, color: kc.fg, padding: "2px 8px", borderRadius: 6, fontSize: 11, fontWeight: 700, textTransform: "uppercase" }}>{r.reviewer_kind}</span>
                    </div>
                  </div>
                  <div style={{ color: "#9ca3af", fontSize: 12 }}>{r.responded_at.slice(0,10)}</div>
                </div>
                <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))", gap: 8, marginTop: 10 }}>
                  <div style={{ background: "#f9fafb", borderRadius: 6, padding: 8, fontSize: 12 }}>
                    <div style={{ color: "#6b7280" }}>Technical</div>
                    <div style={{ fontWeight: 600 }}>{r.technical_skill_score}/10</div>
                  </div>
                  <div style={{ background: "#f9fafb", borderRadius: 6, padding: 8, fontSize: 12 }}>
                    <div style={{ color: "#6b7280" }}>Customer svc</div>
                    <div style={{ fontWeight: 600 }}>{r.customer_service_score}/10</div>
                  </div>
                  <div style={{ background: "#f9fafb", borderRadius: 6, padding: 8, fontSize: 12 }}>
                    <div style={{ color: "#6b7280" }}>Collaboration</div>
                    <div style={{ fontWeight: 600 }}>{r.team_collaboration_score}/10</div>
                  </div>
                  <div style={{ background: "#f9fafb", borderRadius: 6, padding: 8, fontSize: 12 }}>
                    <div style={{ color: "#6b7280" }}>Reliability</div>
                    <div style={{ fontWeight: 600 }}>{r.reliability_score}/10</div>
                  </div>
                </div>
                {r.strength_text && (
                  <div style={{ marginTop: 8, fontSize: 13 }}>
                    <span style={{ color: "#065f46", fontWeight: 600 }}>Strength: </span>
                    <span style={{ color: "#374151" }}>{r.strength_text}</span>
                  </div>
                )}
                {r.growth_area_text && (
                  <div style={{ marginTop: 4, fontSize: 13 }}>
                    <span style={{ color: "#92400e", fontWeight: 600 }}>Growth area: </span>
                    <span style={{ color: "#374151" }}>{r.growth_area_text}</span>
                  </div>
                )}
                {r.qualitative_feedback && (
                  <p style={{ marginTop: 8, fontSize: 13, color: "#4b5563", whiteSpace: "pre-wrap", background: "#f9fafb", padding: 10, borderRadius: 6 }}>{r.qualitative_feedback}</p>
                )}
              </div>
            );
          })}
        </div>
      </section>
    </main>
  );
}
