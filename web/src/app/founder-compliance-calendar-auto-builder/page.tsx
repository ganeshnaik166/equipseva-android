import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_events: number;
  upcoming_count: number;
  due_soon_count: number;
  overdue_count: number;
  completed_count: number;
  waived_count: number;
  rescheduled_count: number;
  gst_filing_count: number;
  tds_filing_count: number;
  it_return_count: number;
  renewal_count: number;
  board_audit_count: number;
  privacy_dpdp_count: number;
  due_next_7d_count: number;
  due_next_30d_count: number;
  next_due_date: string | null;
};

type EventRow = {
  id: string;
  event_label: string;
  event_kind: string;
  due_date: string;
  frequency: string;
  status: string;
  source_table: string | null;
  source_record_id: string | null;
  days_until_due: number;
  is_overdue: boolean;
  completed_at: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

type Overdue = {
  id: string;
  event_label: string;
  event_kind: string;
  due_date: string;
  days_overdue: number;
};

type Due30 = {
  id: string;
  event_label: string;
  event_kind: string;
  due_date: string;
  days_until: number;
};

const KIND_COLOR: Record<string, string> = {
  gst_filing: "#7c3aed",
  tds_filing: "#0ea5e9",
  it_return: "#a16207",
  udyam_renewal: "#059669",
  msme_renewal: "#0f766e",
  cdsco_renewal: "#b91c1c",
  nabh_renewal: "#9333ea",
  board_meeting: "#1f2937",
  statutory_audit: "#dc2626",
  privacy_notice_review: "#0891b2",
  dpdp_quarterly_report: "#06b6d4",
  other: "#6b7280",
};

const STATUS_COLOR: Record<string, string> = {
  upcoming: "#6b7280",
  due_soon: "#a16207",
  overdue: "#991b1b",
  completed: "#065f46",
  waived: "#4b5563",
  rescheduled: "#7c3aed",
};

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [sumR, recR, overR, dueR] = await Promise.all([
    sb.rpc("founder_compliance_calendar_summary"),
    sb.rpc("founder_compliance_calendar_events_recent"),
    sb.rpc("founder_compliance_calendar_overdue"),
    sb.rpc("founder_compliance_calendar_due_30d"),
  ]);

  const s: Summary = (Array.isArray(sumR.data) ? sumR.data[0] : sumR.data) ?? {
    total_events: 0, upcoming_count: 0, due_soon_count: 0, overdue_count: 0,
    completed_count: 0, waived_count: 0, rescheduled_count: 0,
    gst_filing_count: 0, tds_filing_count: 0, it_return_count: 0,
    renewal_count: 0, board_audit_count: 0, privacy_dpdp_count: 0,
    due_next_7d_count: 0, due_next_30d_count: 0, next_due_date: null,
  };
  const rows: EventRow[] = (recR.data as EventRow[]) ?? [];
  const overdue: Overdue[] = (overR.data as Overdue[]) ?? [];
  const due30: Due30[] = (dueR.data as Due30[]) ?? [];

  const kpis: Array<[string, string | number, string?]> = [
    ["Total events", formatNumber(s.total_events)],
    ["Upcoming", formatNumber(s.upcoming_count)],
    ["Due soon", formatNumber(s.due_soon_count), s.due_soon_count > 0 ? "#a16207" : "#374151"],
    ["Overdue", formatNumber(s.overdue_count), s.overdue_count > 0 ? "#991b1b" : "#374151"],
    ["Completed", formatNumber(s.completed_count), s.completed_count > 0 ? "#065f46" : "#374151"],
    ["Waived", formatNumber(s.waived_count)],
    ["Rescheduled", formatNumber(s.rescheduled_count)],
    ["GST filings", formatNumber(s.gst_filing_count)],
    ["TDS filings", formatNumber(s.tds_filing_count)],
    ["IT return", formatNumber(s.it_return_count)],
    ["Renewals (Udyam/MSME/CDSCO/NABH)", formatNumber(s.renewal_count)],
    ["Board + audit", formatNumber(s.board_audit_count)],
    ["Privacy + DPDP", formatNumber(s.privacy_dpdp_count)],
    ["Due next 7d", formatNumber(s.due_next_7d_count), s.due_next_7d_count > 0 ? "#a16207" : "#374151"],
    ["Due next 30d", formatNumber(s.due_next_30d_count)],
    ["Next due date", s.next_due_date ?? "-", s.next_due_date ? "#1f2937" : "#9ca3af"],
  ];

  const overdueCount = overdue.length;
  const due30Count = due30.length;

  return (
    <main style={{ maxWidth: 1200, margin: "0 auto", padding: 24, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Compliance calendar auto-builder</h1>
      <p style={{ color: "#666", marginBottom: 20 }}>
        Auto-seeded regulatory filing calendar · GST quarters + monthly TDS + annual IT/audit + renewals from r1358 · seeded via{" "}
        <code>founder_compliance_calendar_auto_seed_year()</code> · {formatNumber(s.total_events)} events total ·{" "}
        next due {s.next_due_date ?? "-"}
      </p>

      {overdueCount > 0 && (
        <div style={{ background: "#fee2e2", border: "1px solid #fecaca", borderRadius: 10, padding: 14, marginBottom: 16 }}>
          <div style={{ fontWeight: 700, color: "#991b1b", fontSize: 14 }}>
            {overdueCount} overdue filing{overdueCount === 1 ? "" : "s"} past due date
          </div>
          <div style={{ color: "#991b1b", fontSize: 12, marginTop: 6, display: "flex", gap: 16, flexWrap: "wrap" }}>
            {overdue.slice(0, 6).map((o) => (
              <span key={o.id}>
                <strong>{o.event_label}</strong> · {o.days_overdue}d late
              </span>
            ))}
            {overdue.length > 6 && <span>+{overdue.length - 6} more</span>}
          </div>
        </div>
      )}

      {due30Count > 0 && (
        <div style={{ background: "#fef3c7", border: "1px solid #fde68a", borderRadius: 10, padding: 14, marginBottom: 20 }}>
          <div style={{ fontWeight: 700, color: "#92400e", fontSize: 14 }}>
            {due30Count} filing{due30Count === 1 ? "" : "s"} due in next 30 days
          </div>
          <div style={{ color: "#92400e", fontSize: 12, marginTop: 6, display: "flex", gap: 16, flexWrap: "wrap" }}>
            {due30.slice(0, 6).map((d) => (
              <span key={d.id}>
                <strong>{d.event_label}</strong> · in {d.days_until}d ({d.due_date})
              </span>
            ))}
            {due30.length > 6 && <span>+{due30.length - 6} more</span>}
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
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Event ledger ({rows.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Event", "Kind", "Due date", "Frequency", "Status", "Days until / overdue", "Source", "Notes"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 ? (
                <tr><td colSpan={8} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No calendar events yet — call founder_compliance_calendar_auto_seed_year().</td></tr>
              ) : rows.map((r) => (
                <tr key={r.id} style={{ borderTop: "1px solid #f1f5f9", background: r.is_overdue ? "#fef2f2" : undefined }}>
                  <td style={{ padding: "10px 12px", fontWeight: 600 }}>{r.event_label}</td>
                  <td style={{ padding: "10px 12px" }}>
                    <span style={{ background: KIND_COLOR[r.event_kind] ?? "#6b7280", color: "#fff", padding: "2px 8px", borderRadius: 12, fontSize: 11, fontWeight: 600, whiteSpace: "nowrap" }}>
                      {r.event_kind}
                    </span>
                  </td>
                  <td style={{ padding: "10px 12px", color: r.is_overdue ? "#991b1b" : "#374151", fontWeight: r.is_overdue ? 700 : 400 }}>
                    {r.due_date}
                  </td>
                  <td style={{ padding: "10px 12px", color: "#6b7280" }}>{r.frequency}</td>
                  <td style={{ padding: "10px 12px" }}>
                    <span style={{ background: STATUS_COLOR[r.status] ?? "#6b7280", color: "#fff", padding: "2px 8px", borderRadius: 12, fontSize: 11, fontWeight: 600, whiteSpace: "nowrap" }}>
                      {r.status}
                    </span>
                  </td>
                  <td style={{ padding: "10px 12px", color: r.is_overdue ? "#991b1b" : "#374151", fontWeight: r.is_overdue ? 700 : 400 }}>
                    {r.is_overdue ? `${Math.abs(r.days_until_due)}d overdue` : `${r.days_until_due}d`}
                  </td>
                  <td style={{ padding: "10px 12px", color: "#6b7280", fontSize: 11 }}>{r.source_table ?? "manual"}</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280", fontSize: 12, maxWidth: 200, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{r.notes ?? "-"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ background: "#f9fafb", border: "1px solid #e5e7eb", borderRadius: 10, padding: 16 }}>
        <h3 style={{ fontSize: 14, fontWeight: 600, marginBottom: 8 }}>How auto-seed works</h3>
        <ul style={{ color: "#4b5563", fontSize: 13, lineHeight: 1.7, margin: 0, paddingLeft: 18 }}>
          <li>Cron-callable <code>founder_compliance_calendar_auto_seed_year()</code> seeds 12mo of monthly TDS + quarterly GST + DPDP + board + annual IT/audit/privacy review</li>
          <li>Pulls renewal_due_date rows from <code>founder_compliance_documents</code> (r1358) and joins them as Udyam/MSME/CDSCO/NABH renewal events</li>
          <li>Dedup unique index on (event_kind, due_date, event_label) so re-seeding is idempotent</li>
          <li>Rolls up status: anything past due_date flips to <code>overdue</code>, anything within 7d flips to <code>due_soon</code></li>
          <li>Manual events via <code>log_founder_compliance_calendar_register_event()</code>; mark done via <code>log_founder_compliance_calendar_complete_event()</code></li>
        </ul>
      </section>
    </main>
  );
}
