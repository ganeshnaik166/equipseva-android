import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder board meeting prep — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_meetings: number;
  scheduled_count: number;
  prepped_count: number;
  held_count: number;
  days_to_next_meeting: number;
  days_since_last_held: number;
  action_items_open_count: number;
  action_items_overdue_count: number;
  action_items_closed_pct: number;
  formal_meetings_ytd: number;
  prep_deadline_overdue_count: number;
  last_decision_at: string | null;
};

type MeetingRow = {
  id: string;
  meeting_label: string;
  scheduled_at: string;
  kind: string | null;
  location: string | null;
  status: string;
  prep_deadline: string | null;
  days_to_prep: number | null;
  attendees_planned: string | null;
  action_items_count: number;
  open_action_items: number;
  materials_url: string | null;
  agenda_summary: string | null;
  created_at: string;
};

type ActionItemRow = {
  id: string;
  meeting_id: string;
  meeting_label: string;
  description: string;
  owner_user_id: string | null;
  due_date: string | null;
  days_to_due: number | null;
  status: string;
  created_at: string;
};

export default async function FounderBoardMeetingPrepPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, meetingsRes, actionItemsRes] = await Promise.all([
    supabase.rpc("founder_board_meeting_prep_summary"),
    supabase.rpc("founder_board_meetings_recent", { p_limit: 20 }),
    supabase.rpc("founder_board_meeting_action_items_open", { p_meeting_id: null, p_limit: 50 }),
  ]);

  const summary: Summary | null = (summaryRes.data?.[0] as Summary) ?? null;
  const meetings: MeetingRow[] = (meetingsRes.data as MeetingRow[]) ?? [];
  const actionItems: ActionItemRow[] = (actionItemsRes.data as ActionItemRow[]) ?? [];

  const nextMeeting = meetings.find((m) => m.status === "scheduled" || m.status === "prepped");

  const cards: Array<{ label: string; value: string; sub?: string }> = summary
    ? [
        { label: "Total meetings", value: formatNumber(summary.total_meetings), sub: "lifetime" },
        { label: "Scheduled", value: formatNumber(summary.scheduled_count), sub: "upcoming" },
        { label: "Prepped", value: formatNumber(summary.prepped_count), sub: "materials sent" },
        { label: "Held", value: formatNumber(summary.held_count), sub: "completed meetings" },
        { label: "Days to next meeting", value: formatNumber(summary.days_to_next_meeting), sub: "earliest scheduled" },
        { label: "Days since last held", value: formatNumber(summary.days_since_last_held), sub: "cadence health" },
        { label: "Open action items", value: formatNumber(summary.action_items_open_count), sub: "open + in_progress" },
        { label: "Overdue action items", value: formatNumber(summary.action_items_overdue_count), sub: "past due_date" },
        { label: "Closed %", value: `${formatNumber(summary.action_items_closed_pct)}%`, sub: "all-time close rate" },
        { label: "Formal meetings YTD", value: formatNumber(summary.formal_meetings_ytd), sub: "kind=formal_board" },
        { label: "Prep overdue", value: formatNumber(summary.prep_deadline_overdue_count), sub: "missed prep deadline" },
        {
          label: "Last decision",
          value: summary.last_decision_at ? new Date(summary.last_decision_at).toISOString().slice(0, 10) : "—",
          sub: "most recent decisions_log",
        },
      ]
    : [];

  return (
    <main style={{ padding: "32px 24px", maxWidth: 1280, margin: "0 auto", fontFamily: "system-ui, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Founder · Board meeting prep</h1>
      <p style={{ color: "#666", marginBottom: 24, fontSize: 14 }}>
        Board hygiene = governance hygiene. Every meeting tracked, every decision logged, every action item owned.
      </p>

      {nextMeeting ? (
        <section
          style={{
            background: "linear-gradient(135deg, #1e3a8a 0%, #312e81 100%)",
            color: "white",
            borderRadius: 12,
            padding: 24,
            marginBottom: 24,
          }}
        >
          <div style={{ fontSize: 12, opacity: 0.8, textTransform: "uppercase", letterSpacing: 1 }}>Next meeting</div>
          <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>{nextMeeting.meeting_label}</div>
          <div style={{ marginTop: 8, fontSize: 14, opacity: 0.9 }}>
            {new Date(nextMeeting.scheduled_at).toISOString().replace("T", " ").slice(0, 16)} UTC
            {nextMeeting.location ? ` · ${nextMeeting.location}` : ""}
            {nextMeeting.kind ? ` · ${nextMeeting.kind}` : ""}
          </div>
          <div style={{ marginTop: 12, display: "flex", gap: 24, flexWrap: "wrap", fontSize: 13 }}>
            <div>
              <span style={{ opacity: 0.7 }}>Status: </span>
              <strong>{nextMeeting.status}</strong>
            </div>
            <div>
              <span style={{ opacity: 0.7 }}>Prep deadline: </span>
              <strong>{nextMeeting.prep_deadline ?? "—"}</strong>
              {typeof nextMeeting.days_to_prep === "number" ? (
                <span style={{ marginLeft: 6, opacity: 0.85 }}>
                  ({nextMeeting.days_to_prep >= 0 ? `${nextMeeting.days_to_prep}d left` : `${-nextMeeting.days_to_prep}d overdue`})
                </span>
              ) : null}
            </div>
            <div>
              <span style={{ opacity: 0.7 }}>Open items: </span>
              <strong>{formatNumber(nextMeeting.open_action_items)}</strong>
            </div>
          </div>
          {nextMeeting.agenda_summary ? (
            <div style={{ marginTop: 14, fontSize: 13, opacity: 0.9, whiteSpace: "pre-wrap" }}>
              <strong>Agenda</strong>
              <div style={{ marginTop: 4 }}>{nextMeeting.agenda_summary}</div>
            </div>
          ) : null}
        </section>
      ) : (
        <section style={{ background: "#fef3c7", border: "1px solid #fbbf24", borderRadius: 8, padding: 16, marginBottom: 24 }}>
          <strong>No upcoming meeting scheduled.</strong> Use log_founder_board_meeting_create to schedule the next board touchpoint.
        </section>
      )}

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 12, marginBottom: 32 }}>
        {cards.map((c) => (
          <div key={c.label} style={{ background: "#fff", border: "1px solid #e5e7eb", borderRadius: 8, padding: 14 }}>
            <div style={{ fontSize: 11, color: "#6b7280", textTransform: "uppercase", letterSpacing: 0.5 }}>{c.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{c.value}</div>
            {c.sub ? <div style={{ fontSize: 11, color: "#9ca3af", marginTop: 2 }}>{c.sub}</div> : null}
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent meetings (20)</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 8 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13, minWidth: 900 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                <th style={{ textAlign: "left", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Label</th>
                <th style={{ textAlign: "left", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Scheduled</th>
                <th style={{ textAlign: "left", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Kind</th>
                <th style={{ textAlign: "left", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Status</th>
                <th style={{ textAlign: "left", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Prep deadline</th>
                <th style={{ textAlign: "right", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Action items</th>
                <th style={{ textAlign: "right", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Open</th>
                <th style={{ textAlign: "left", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Materials</th>
              </tr>
            </thead>
            <tbody>
              {meetings.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ padding: 16, textAlign: "center", color: "#9ca3af" }}>
                    No meetings yet.
                  </td>
                </tr>
              ) : (
                meetings.map((m) => (
                  <tr key={m.id} style={{ borderTop: "1px solid #f3f4f6" }}>
                    <td style={{ padding: "10px 12px", fontWeight: 600 }}>{m.meeting_label}</td>
                    <td style={{ padding: "10px 12px", whiteSpace: "nowrap" }}>{new Date(m.scheduled_at).toISOString().slice(0, 10)}</td>
                    <td style={{ padding: "10px 12px" }}>{m.kind ?? "—"}</td>
                    <td style={{ padding: "10px 12px" }}>{m.status}</td>
                    <td style={{ padding: "10px 12px" }}>
                      {m.prep_deadline ?? "—"}
                      {typeof m.days_to_prep === "number" && m.days_to_prep < 0 ? (
                        <span style={{ color: "#dc2626", marginLeft: 6 }}>({-m.days_to_prep}d overdue)</span>
                      ) : null}
                    </td>
                    <td style={{ padding: "10px 12px", textAlign: "right" }}>{formatNumber(m.action_items_count)}</td>
                    <td style={{ padding: "10px 12px", textAlign: "right" }}>{formatNumber(m.open_action_items)}</td>
                    <td style={{ padding: "10px 12px" }}>{m.materials_url ? "link" : "—"}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Open action items (50)</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 8 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13, minWidth: 800 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                <th style={{ textAlign: "left", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Meeting</th>
                <th style={{ textAlign: "left", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Description</th>
                <th style={{ textAlign: "left", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Status</th>
                <th style={{ textAlign: "left", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Due</th>
                <th style={{ textAlign: "right", padding: "10px 12px", borderBottom: "1px solid #e5e7eb" }}>Days</th>
              </tr>
            </thead>
            <tbody>
              {actionItems.length === 0 ? (
                <tr>
                  <td colSpan={5} style={{ padding: 16, textAlign: "center", color: "#9ca3af" }}>
                    No open action items.
                  </td>
                </tr>
              ) : (
                actionItems.map((a) => (
                  <tr key={a.id} style={{ borderTop: "1px solid #f3f4f6" }}>
                    <td style={{ padding: "10px 12px", whiteSpace: "nowrap" }}>{a.meeting_label}</td>
                    <td style={{ padding: "10px 12px" }}>{a.description}</td>
                    <td style={{ padding: "10px 12px" }}>{a.status}</td>
                    <td style={{ padding: "10px 12px" }}>{a.due_date ?? "—"}</td>
                    <td
                      style={{
                        padding: "10px 12px",
                        textAlign: "right",
                        color:
                          typeof a.days_to_due === "number" && a.days_to_due < 0
                            ? "#dc2626"
                            : "#111827",
                      }}
                    >
                      {typeof a.days_to_due === "number"
                        ? a.days_to_due >= 0
                          ? `${a.days_to_due}d left`
                          : `${-a.days_to_due}d overdue`
                        : "—"}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ background: "#f9fafb", border: "1px solid #e5e7eb", borderRadius: 8, padding: 16, fontSize: 13, color: "#374151", lineHeight: 1.6 }}>
        <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 8 }}>Notes on prep discipline</h3>
        <ul style={{ paddingLeft: 18, margin: 0 }}>
          <li>Materials must land with the board {">"} 72h before scheduled_at — set prep_deadline accordingly.</li>
          <li>Formal_board meetings: ≥ 4 / year is the governance baseline; check formal_meetings_ytd.</li>
          <li>Every decision lands in decisions_log immediately post-meeting — last_decision_at older than 60d signals drift.</li>
          <li>Action items closed % {"<"} 70% means the founder is not enforcing follow-through.</li>
          <li>Overdue prep deadlines are a reputational hazard with institutional LPs · ship the deck on time.</li>
        </ul>
      </section>
    </main>
  );
}
