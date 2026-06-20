import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_recipients: number;
  lifetime_emails_sent: number;
  recipients_opened_30d: number;
  recipients_opened_lifetime: number;
  open_rate_pct_30d: number;
  open_rate_pct_lifetime: number;
  replied_30d: number;
  replied_lifetime: number;
  reply_rate_pct: number;
  opt_out_count: number;
  opt_out_rate_pct: number;
  data_room_views_30d: number;
  data_room_views_lifetime: number;
  distinct_investor_viewers: number;
  top_engaged_firm: string | null;
  top_engaged_views_count: number;
  unique_firms_total: number;
  last_open_at: string | null;
  generated_at: string;
};

type Engaged = {
  investor_firm_name: string;
  emails_sent: number;
  emails_opened: number;
  emails_replied: number;
  data_room_views: number;
  engagement_score: number;
  last_touch_at: string | null;
};

type Dormant = {
  investor_firm_name: string;
  investor_partner_email: string;
  last_sent_at: string | null;
  last_opened_at: string | null;
  days_since_open: number;
  emails_sent_total: number;
};

type Event = {
  event_kind: string;
  investor_firm_name: string;
  detail: string | null;
  happened_at: string | null;
};

type QtrRoll = {
  quarter_label: string;
  period_start: string;
  status: string;
  recipients_count: number;
  sent_count: number;
  opened_count: number;
  replied_count: number;
  open_rate_pct: number;
  reply_rate_pct: number;
};

const EVENT_COLOR: Record<string, string> = {
  email_open: "#0ea5e9",
  email_reply: "#059669",
  opt_out: "#b91c1c",
  dataroom_view: "#7c3aed",
};

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [sumR, engR, dormR, evtR, qtrR] = await Promise.all([
    sb.rpc("founder_investor_open_tracker_summary"),
    sb.rpc("founder_investor_open_tracker_engaged_investors"),
    sb.rpc("founder_investor_open_tracker_dormant_investors"),
    sb.rpc("founder_investor_open_tracker_recent_events"),
    sb.rpc("founder_investor_open_tracker_quarterly_rollup"),
  ]);

  const s: Summary = (Array.isArray(sumR.data) ? sumR.data[0] : sumR.data) ?? {
    total_recipients: 0, lifetime_emails_sent: 0, recipients_opened_30d: 0,
    recipients_opened_lifetime: 0, open_rate_pct_30d: 0, open_rate_pct_lifetime: 0,
    replied_30d: 0, replied_lifetime: 0, reply_rate_pct: 0, opt_out_count: 0,
    opt_out_rate_pct: 0, data_room_views_30d: 0, data_room_views_lifetime: 0,
    distinct_investor_viewers: 0, top_engaged_firm: null, top_engaged_views_count: 0,
    unique_firms_total: 0, last_open_at: null, generated_at: new Date().toISOString(),
  };
  const engaged: Engaged[] = (engR.data as Engaged[]) ?? [];
  const dormant: Dormant[] = (dormR.data as Dormant[]) ?? [];
  const events: Event[] = (evtR.data as Event[]) ?? [];
  const rolls: QtrRoll[] = (qtrR.data as QtrRoll[]) ?? [];

  const kpis: Array<[string, string | number, string?]> = [
    ["Total recipients", formatNumber(s.total_recipients)],
    ["Lifetime emails sent", formatNumber(s.lifetime_emails_sent)],
    ["Opened 30d", formatNumber(s.recipients_opened_30d)],
    ["Opened lifetime", formatNumber(s.recipients_opened_lifetime)],
    ["Open rate 30d", `${s.open_rate_pct_30d}%`, s.open_rate_pct_30d >= 30 ? "#065f46" : s.open_rate_pct_30d >= 15 ? "#a16207" : "#991b1b"],
    ["Open rate lifetime", `${s.open_rate_pct_lifetime}%`],
    ["Replied 30d", formatNumber(s.replied_30d)],
    ["Replied lifetime", formatNumber(s.replied_lifetime)],
    ["Reply rate", `${s.reply_rate_pct}%`, s.reply_rate_pct >= 10 ? "#065f46" : "#374151"],
    ["Opt-outs", formatNumber(s.opt_out_count), s.opt_out_count > 0 ? "#991b1b" : "#374151"],
    ["Opt-out rate", `${s.opt_out_rate_pct}%`],
    ["Data room views 30d", formatNumber(s.data_room_views_30d)],
    ["Data room views lifetime", formatNumber(s.data_room_views_lifetime)],
    ["Distinct DR viewers", formatNumber(s.distinct_investor_viewers)],
    ["Top engaged firm", s.top_engaged_firm ?? "—"],
    ["Top firm DR views", formatNumber(s.top_engaged_views_count)],
  ];

  const dormantCount = dormant.length;

  return (
    <main style={{ maxWidth: 1200, margin: "0 auto", padding: 24, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Investor open tracker</h1>
      <p style={{ color: "#666", marginBottom: 20 }}>
        Engagement signal across r1419 quarterly updates + r1390 data room ·{" "}
        {s.unique_firms_total} firms tracked · last open{" "}
        {s.last_open_at ? new Date(s.last_open_at).toLocaleDateString() : "—"} ·{" "}
        generated {new Date(s.generated_at).toLocaleString()}
      </p>

      {dormantCount > 0 && (
        <div style={{ background: "#fef3c7", border: "1px solid #fcd34d", borderRadius: 10, padding: 14, marginBottom: 20 }}>
          <div style={{ fontWeight: 700, color: "#92400e", fontSize: 14 }}>
            ⚠ {dormantCount} dormant investor{dormantCount === 1 ? "" : "s"} — no open in 60 days
          </div>
          <div style={{ color: "#92400e", fontSize: 12, marginTop: 4 }}>
            Consider follow-up or removing from list to protect sender reputation.
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
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Top engaged investors ({engaged.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Firm", "Sent", "Opened", "Replied", "DR views", "Score", "Last touch"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {engaged.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No engagement recorded yet.</td></tr>
              ) : engaged.map((e, i) => (
                <tr key={e.investor_firm_name + i} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={{ padding: "10px 12px", fontWeight: 500 }}>{e.investor_firm_name}</td>
                  <td style={{ padding: "10px 12px" }}>{formatNumber(e.emails_sent)}</td>
                  <td style={{ padding: "10px 12px" }}>{formatNumber(e.emails_opened)}</td>
                  <td style={{ padding: "10px 12px", color: e.emails_replied > 0 ? "#065f46" : "#374151", fontWeight: e.emails_replied > 0 ? 600 : 400 }}>{formatNumber(e.emails_replied)}</td>
                  <td style={{ padding: "10px 12px" }}>{formatNumber(e.data_room_views)}</td>
                  <td style={{ padding: "10px 12px", fontWeight: 700, color: e.engagement_score >= 20 ? "#065f46" : e.engagement_score >= 5 ? "#a16207" : "#6b7280" }}>{formatNumber(e.engagement_score)}</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280" }}>{e.last_touch_at ? new Date(e.last_touch_at).toLocaleDateString() : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div style={{ fontSize: 11, color: "#6b7280", marginTop: 6 }}>
          Engagement score = opens × 1 + replies × 5 + data-room views × 3
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Dormant investors ({dormant.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Firm", "Partner email", "Last sent", "Last opened", "Days since open", "Emails sent"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {dormant.length === 0 ? (
                <tr><td colSpan={6} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No dormant investors — every active recipient opened in last 60d. Nice.</td></tr>
              ) : dormant.map((d, i) => (
                <tr key={d.investor_partner_email + i} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={{ padding: "10px 12px", fontWeight: 500 }}>{d.investor_firm_name}</td>
                  <td style={{ padding: "10px 12px", color: "#374151" }}>{d.investor_partner_email}</td>
                  <td style={{ padding: "10px 12px" }}>{d.last_sent_at ? d.last_sent_at.slice(0, 10) : "—"}</td>
                  <td style={{ padding: "10px 12px" }}>{d.last_opened_at ? d.last_opened_at.slice(0, 10) : "never"}</td>
                  <td style={{ padding: "10px 12px", color: d.days_since_open >= 90 ? "#991b1b" : "#a16207", fontWeight: 600 }}>
                    {d.days_since_open >= 9999 ? "never" : `${d.days_since_open}d`}
                  </td>
                  <td style={{ padding: "10px 12px" }}>{formatNumber(d.emails_sent_total)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Quarterly open-rate rollup ({rolls.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Quarter", "Period start", "Status", "Recipients", "Sent", "Opened", "Replied", "Open %", "Reply %"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rolls.length === 0 ? (
                <tr><td colSpan={9} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No quarterly updates yet.</td></tr>
              ) : rolls.map((q) => (
                <tr key={q.quarter_label} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={{ padding: "10px 12px", fontWeight: 500 }}>{q.quarter_label}</td>
                  <td style={{ padding: "10px 12px" }}>{q.period_start}</td>
                  <td style={{ padding: "10px 12px" }}>{q.status}</td>
                  <td style={{ padding: "10px 12px" }}>{formatNumber(q.recipients_count)}</td>
                  <td style={{ padding: "10px 12px" }}>{formatNumber(q.sent_count)}</td>
                  <td style={{ padding: "10px 12px" }}>{formatNumber(q.opened_count)}</td>
                  <td style={{ padding: "10px 12px" }}>{formatNumber(q.replied_count)}</td>
                  <td style={{ padding: "10px 12px", color: q.open_rate_pct >= 30 ? "#065f46" : q.open_rate_pct >= 15 ? "#a16207" : "#991b1b", fontWeight: 600 }}>{q.open_rate_pct}%</td>
                  <td style={{ padding: "10px 12px" }}>{q.reply_rate_pct}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent events ({events.length})</h2>
        <div style={{ border: "1px solid #e5e7eb", borderRadius: 10, background: "#fff" }}>
          {events.length === 0 ? (
            <div style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No engagement events recorded.</div>
          ) : events.map((e, i) => (
            <div key={i} style={{ display: "flex", justifyContent: "space-between", gap: 12, padding: "10px 14px", borderTop: i === 0 ? "none" : "1px solid #f1f5f9", flexWrap: "wrap" }}>
              <div style={{ display: "flex", gap: 10, alignItems: "center", flex: 1, minWidth: 0 }}>
                <span style={{ background: EVENT_COLOR[e.event_kind] ?? "#6b7280", color: "#fff", padding: "2px 8px", borderRadius: 12, fontSize: 11, fontWeight: 600, whiteSpace: "nowrap" }}>{e.event_kind}</span>
                <span style={{ fontWeight: 500 }}>{e.investor_firm_name}</span>
                {e.detail && <span style={{ color: "#6b7280", fontSize: 13 }}>· {e.detail}</span>}
              </div>
              <div style={{ color: "#6b7280", fontSize: 12 }}>{e.happened_at ? new Date(e.happened_at).toLocaleString() : "—"}</div>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
