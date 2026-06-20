import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_meetings_lifetime: number;
  meetings_scheduled: number;
  meetings_completed: number;
  meetings_cancelled_or_no_show: number;
  meetings_upcoming_7d: number;
  meetings_upcoming_30d: number;
  meetings_completed_30d: number;
  meetings_completed_90d: number;
  distinct_firms_total: number;
  distinct_firms_active_90d: number;
  overdue_followups: number;
  followups_due_7d: number;
  active_diligence_count: number;
  term_sheet_count: number;
  pass_count: number;
  positive_sentiment_pct: number;
};

type Recent = {
  id: string;
  investor_firm_name: string;
  investor_partner_name: string | null;
  meeting_at: string;
  meeting_kind: string;
  status: string;
  sentiment: string | null;
  deal_track: string | null;
  outcome_summary: string | null;
  follow_up_required: boolean;
  follow_up_due_date: string | null;
  notes_count: number;
};

type Upcoming = {
  id: string;
  investor_firm_name: string;
  investor_partner_name: string | null;
  meeting_at: string;
  meeting_kind: string;
  location: string | null;
  virtual_meeting_url: string | null;
  duration_minutes: number | null;
  days_until: number;
};

type Overdue = {
  id: string;
  investor_firm_name: string;
  investor_partner_name: string | null;
  meeting_at: string;
  follow_up_due_date: string;
  days_overdue: number;
  follow_up_action_text: string | null;
  deal_track: string | null;
};

const SENTIMENT_COLOR: Record<string, string> = {
  strongly_positive: "#065f46",
  positive: "#15803d",
  neutral: "#6b7280",
  cool: "#a16207",
  negative: "#991b1b",
};

const DEAL_COLOR: Record<string, string> = {
  pure_relationship: "#6b7280",
  warm_lead: "#0ea5e9",
  active_diligence: "#7c3aed",
  term_sheet: "#065f46",
  pass: "#991b1b",
  no_response: "#a16207",
};

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [sumR, recR, upR, ovR] = await Promise.all([
    sb.rpc("founder_investor_coffee_calendar_summary"),
    sb.rpc("founder_investor_coffee_meetings_recent"),
    sb.rpc("founder_investor_coffee_meetings_upcoming"),
    sb.rpc("founder_investor_coffee_overdue_followups"),
  ]);

  const s: Summary = (Array.isArray(sumR.data) ? sumR.data[0] : sumR.data) ?? {
    total_meetings_lifetime: 0, meetings_scheduled: 0, meetings_completed: 0,
    meetings_cancelled_or_no_show: 0, meetings_upcoming_7d: 0, meetings_upcoming_30d: 0,
    meetings_completed_30d: 0, meetings_completed_90d: 0, distinct_firms_total: 0,
    distinct_firms_active_90d: 0, overdue_followups: 0, followups_due_7d: 0,
    active_diligence_count: 0, term_sheet_count: 0, pass_count: 0, positive_sentiment_pct: 0,
  };
  const recent: Recent[] = (recR.data as Recent[]) ?? [];
  const upcoming: Upcoming[] = (upR.data as Upcoming[]) ?? [];
  const overdue: Overdue[] = (ovR.data as Overdue[]) ?? [];

  const kpis: Array<[string, string | number, string?]> = [
    ["Total meetings", formatNumber(s.total_meetings_lifetime)],
    ["Scheduled", formatNumber(s.meetings_scheduled), "#0ea5e9"],
    ["Completed", formatNumber(s.meetings_completed), "#065f46"],
    ["Cancelled/no-show", formatNumber(s.meetings_cancelled_or_no_show), s.meetings_cancelled_or_no_show > 0 ? "#a16207" : "#374151"],
    ["Upcoming 7d", formatNumber(s.meetings_upcoming_7d), s.meetings_upcoming_7d > 0 ? "#065f46" : "#6b7280"],
    ["Upcoming 30d", formatNumber(s.meetings_upcoming_30d)],
    ["Completed 30d", formatNumber(s.meetings_completed_30d)],
    ["Completed 90d", formatNumber(s.meetings_completed_90d)],
    ["Distinct firms", formatNumber(s.distinct_firms_total)],
    ["Active firms 90d", formatNumber(s.distinct_firms_active_90d)],
    ["Overdue follow-ups", formatNumber(s.overdue_followups), s.overdue_followups > 0 ? "#991b1b" : "#065f46"],
    ["Follow-ups due 7d", formatNumber(s.followups_due_7d), s.followups_due_7d > 0 ? "#a16207" : "#374151"],
    ["Active diligence", formatNumber(s.active_diligence_count), s.active_diligence_count > 0 ? "#7c3aed" : "#6b7280"],
    ["Term sheet", formatNumber(s.term_sheet_count), s.term_sheet_count > 0 ? "#065f46" : "#6b7280"],
    ["Passed", formatNumber(s.pass_count), "#6b7280"],
    ["Positive sentiment", `${s.positive_sentiment_pct}%`, s.positive_sentiment_pct >= 60 ? "#065f46" : s.positive_sentiment_pct >= 40 ? "#a16207" : "#991b1b"],
  ];

  return (
    <main style={{ maxWidth: 1200, margin: "0 auto", padding: 24, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Investor coffee calendar</h1>
      <p style={{ color: "#666", marginBottom: 20 }}>
        Coffee chats + intro meetings + diligence calls. {s.distinct_firms_total} firms tracked ·{" "}
        {s.meetings_upcoming_7d} meeting{s.meetings_upcoming_7d === 1 ? "" : "s"} this week.
      </p>

      {overdue.length > 0 && (
        <div style={{ background: "#fee2e2", border: "1px solid #fca5a5", borderRadius: 10, padding: 14, marginBottom: 12 }}>
          <div style={{ fontWeight: 700, color: "#991b1b", fontSize: 14 }}>
            {overdue.length} overdue follow-up{overdue.length === 1 ? "" : "s"} — relationship at risk
          </div>
          <div style={{ color: "#991b1b", fontSize: 12, marginTop: 4 }}>
            Investors expect timely follow-up. Send promised materials or response now.
          </div>
        </div>
      )}

      {s.followups_due_7d > 0 && (
        <div style={{ background: "#fef3c7", border: "1px solid #fcd34d", borderRadius: 10, padding: 14, marginBottom: 20 }}>
          <div style={{ fontWeight: 700, color: "#92400e", fontSize: 14 }}>
            {s.followups_due_7d} follow-up{s.followups_due_7d === 1 ? "" : "s"} due in next 7 days
          </div>
        </div>
      )}

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 12, marginBottom: 28 }}>
        {kpis.map(([label, value, color]) => (
          <div key={label as string} style={{ background: "#fff", border: "1px solid #e5e7eb", borderRadius: 10, padding: 14 }}>
            <div style={{ color: "#6b7280", fontSize: 12, fontWeight: 500 }}>{label}</div>
            <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4, color: (color as string) ?? "#111827" }}>{value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Upcoming meetings ({upcoming.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Firm", "Partner", "When", "Kind", "Where", "Duration", "In"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {upcoming.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No upcoming meetings.</td></tr>
              ) : upcoming.map((u) => (
                <tr key={u.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={{ padding: "10px 12px", fontWeight: 600 }}>{u.investor_firm_name}</td>
                  <td style={{ padding: "10px 12px", color: "#374151" }}>{u.investor_partner_name ?? "—"}</td>
                  <td style={{ padding: "10px 12px" }}>{new Date(u.meeting_at).toLocaleString()}</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280", fontSize: 12 }}>{u.meeting_kind.replace(/_/g, " ")}</td>
                  <td style={{ padding: "10px 12px", color: "#374151", fontSize: 12 }}>{u.virtual_meeting_url ? "virtual" : (u.location ?? "—")}</td>
                  <td style={{ padding: "10px 12px" }}>{u.duration_minutes ? `${u.duration_minutes}m` : "—"}</td>
                  <td style={{ padding: "10px 12px", fontWeight: 600, color: u.days_until <= 1 ? "#991b1b" : u.days_until <= 7 ? "#a16207" : "#374151" }}>
                    {u.days_until === 0 ? "today" : `${u.days_until}d`}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Overdue follow-ups ({overdue.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Firm", "Partner", "Meeting", "Due", "Days overdue", "Action", "Deal track"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {overdue.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: 16, color: "#065f46", textAlign: "center" }}>All follow-ups on track.</td></tr>
              ) : overdue.map((o) => (
                <tr key={o.id} style={{ borderTop: "1px solid #f1f5f9", background: o.days_overdue >= 14 ? "#fef2f2" : undefined }}>
                  <td style={{ padding: "10px 12px", fontWeight: 600 }}>{o.investor_firm_name}</td>
                  <td style={{ padding: "10px 12px", color: "#374151" }}>{o.investor_partner_name ?? "—"}</td>
                  <td style={{ padding: "10px 12px" }}>{new Date(o.meeting_at).toLocaleDateString()}</td>
                  <td style={{ padding: "10px 12px" }}>{o.follow_up_due_date}</td>
                  <td style={{ padding: "10px 12px", color: "#991b1b", fontWeight: 700 }}>{o.days_overdue}d</td>
                  <td style={{ padding: "10px 12px", color: "#374151", fontSize: 12, maxWidth: 280 }}>{o.follow_up_action_text ?? "—"}</td>
                  <td style={{ padding: "10px 12px" }}>
                    {o.deal_track ? (
                      <span style={{ background: DEAL_COLOR[o.deal_track] ?? "#6b7280", color: "#fff", padding: "2px 8px", borderRadius: 10, fontSize: 11, fontWeight: 600 }}>
                        {o.deal_track.replace(/_/g, " ")}
                      </span>
                    ) : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent meetings ({recent.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Firm", "Partner", "When", "Kind", "Status", "Sentiment", "Deal track", "Outcome", "Notes"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {recent.length === 0 ? (
                <tr><td colSpan={9} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No meetings recorded yet.</td></tr>
              ) : recent.map((m) => (
                <tr key={m.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={{ padding: "10px 12px", fontWeight: 600 }}>{m.investor_firm_name}</td>
                  <td style={{ padding: "10px 12px", color: "#374151" }}>{m.investor_partner_name ?? "—"}</td>
                  <td style={{ padding: "10px 12px" }}>{new Date(m.meeting_at).toLocaleDateString()}</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280", fontSize: 12 }}>{m.meeting_kind.replace(/_/g, " ")}</td>
                  <td style={{ padding: "10px 12px", color: m.status === "completed" ? "#065f46" : m.status === "no_show" ? "#991b1b" : "#374151", fontWeight: 600, fontSize: 12 }}>
                    {m.status.replace(/_/g, " ")}
                  </td>
                  <td style={{ padding: "10px 12px" }}>
                    {m.sentiment ? (
                      <span style={{ color: SENTIMENT_COLOR[m.sentiment] ?? "#6b7280", fontWeight: 600, fontSize: 12 }}>
                        {m.sentiment.replace(/_/g, " ")}
                      </span>
                    ) : "—"}
                  </td>
                  <td style={{ padding: "10px 12px" }}>
                    {m.deal_track ? (
                      <span style={{ background: DEAL_COLOR[m.deal_track] ?? "#6b7280", color: "#fff", padding: "2px 8px", borderRadius: 10, fontSize: 11, fontWeight: 600 }}>
                        {m.deal_track.replace(/_/g, " ")}
                      </span>
                    ) : "—"}
                  </td>
                  <td style={{ padding: "10px 12px", color: "#374151", fontSize: 12, maxWidth: 320, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {m.outcome_summary ?? "—"}
                  </td>
                  <td style={{ padding: "10px 12px", color: m.notes_count > 0 ? "#065f46" : "#9ca3af", fontWeight: 600 }}>{m.notes_count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div style={{ fontSize: 11, color: "#6b7280", marginTop: 6 }}>
          Conversation notes captured per meeting against PMF / traction / team / market / competition / financials / use-of-funds / DD-questions / intros / other.
        </div>
      </section>
    </main>
  );
}
