import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

type Kpi = { label: string; value: string };

function fmt(n: any): string {
  if (n === null || n === undefined) return "—";
  const num = Number(n);
  if (Number.isNaN(num)) return String(n);
  return num.toLocaleString("en-IN");
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return "—";
  return `${Number(n).toFixed(1)}%`;
}

function fmtHours(n: any): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (v < 0) return `${Math.abs(v).toFixed(1)}h overdue`;
  if (v < 48) return `${v.toFixed(1)}h`;
  return `${(v/24).toFixed(1)}d`;
}

function fmtTs(s: any): string {
  if (!s) return "—";
  try { return new Date(s).toLocaleString("en-IN"); } catch { return String(s); }
}

export default async function FounderBoardPrepChecklistPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let meetings: any[] = [];
  let items: any[] = [];
  let alerts: any[] = [];
  let categories: any[] = [];

  try {
    const r = await sb.rpc("founder_board_prep_overview");
    overview = (r.data && r.data[0]) || null;
  } catch {}
  try {
    const r = await sb.rpc("founder_board_meetings_list");
    meetings = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc("founder_board_checklist_for_next");
    items = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc("founder_board_imminent_alerts");
    alerts = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc("founder_board_category_breakdown");
    categories = r.data || [];
  } catch {}

  const kpis: Kpi[] = [
    { label: "Total meetings", value: fmt(overview?.total_meetings) },
    { label: "Upcoming", value: fmt(overview?.upcoming_meetings) },
    { label: "Closed", value: fmt(overview?.closed_meetings) },
    { label: "Next meeting", value: fmtTs(overview?.next_meeting_at) },
    { label: "Hours to next", value: fmtHours(overview?.hours_to_next) },
    { label: "Total items", value: fmt(overview?.total_items) },
    { label: "Done items", value: fmt(overview?.done_items) },
    { label: "Open items", value: fmt(overview?.open_items) },
    { label: "Pct done", value: fmtPct(overview?.pct_done) },
    { label: "In 48h", value: fmt(overview?.meetings_in_48h) },
    { label: "Unsent alerts", value: fmt(overview?.meetings_with_unsent_alert) },
    { label: "Avg completion", value: fmtPct(overview?.avg_completion_pct) },
    { label: "Fully ready", value: fmt(overview?.fully_ready_meetings) },
    { label: "At risk", value: fmt(overview?.at_risk_meetings) },
    { label: "Items due 48h", value: fmt(overview?.items_due_in_48h) },
    { label: "Alerts fired", value: fmt(overview?.alerts_fired_total) },
  ];

  const meetingCols: Column<any>[] = [
    { key: "meeting_title", header: "Meeting", render: (r: any) => r.meeting_title ?? "—" },
    { key: "scheduled_at", header: "Scheduled", render: (r: any) => fmtTs(r.scheduled_at) },
    { key: "hours_until", header: "Hours until", render: (r: any) => fmtHours(r.hours_until) },
    { key: "pct_done", header: "Pct done", render: (r: any) => fmtPct(r.pct_done) },
    { key: "done_items", header: "Done/Total", render: (r: any) => `${fmt(r.done_items)} / ${fmt(r.total_items)}` },
    { key: "status", header: "Status", render: (r: any) => r.status ?? "—" },
    { key: "alert_48h_sent_at", header: "48h alert", render: (r: any) => fmtTs(r.alert_48h_sent_at) },
    { key: "location", header: "Location", render: (r: any) => r.location ?? "—" },
  ];

  const itemCols: Column<any>[] = [
    { key: "slot", header: "Slot", render: (r: any) => fmt(r.slot) },
    { key: "category", header: "Category", render: (r: any) => r.category ?? "—" },
    { key: "title", header: "Title", render: (r: any) => r.title ?? "—" },
    { key: "is_done", header: "Done", render: (r: any) => (r.is_done ? "yes" : "no") },
    { key: "done_at", header: "Done at", render: (r: any) => fmtTs(r.done_at) },
    { key: "artifact_url", header: "Artifact", render: (r: any) => r.artifact_url ?? "—" },
  ];

  const alertCols: Column<any>[] = [
    { key: "meeting_title", header: "Meeting", render: (r: any) => r.meeting_title ?? "—" },
    { key: "scheduled_at", header: "Scheduled", render: (r: any) => fmtTs(r.scheduled_at) },
    { key: "hours_until", header: "Hours until", render: (r: any) => fmtHours(r.hours_until) },
    { key: "pct_done", header: "Pct done", render: (r: any) => fmtPct(r.pct_done) },
    { key: "open_items", header: "Open items", render: (r: any) => fmt(r.open_items) },
    { key: "alert_48h_sent_at", header: "Alert sent", render: (r: any) => fmtTs(r.alert_48h_sent_at) },
  ];

  const catCols: Column<any>[] = [
    { key: "category", header: "Category", render: (r: any) => r.category ?? "—" },
    { key: "total_items", header: "Total", render: (r: any) => fmt(r.total_items) },
    { key: "done_items", header: "Done", render: (r: any) => fmt(r.done_items) },
    { key: "open_items", header: "Open", render: (r: any) => fmt(r.open_items) },
    { key: "pct_done", header: "Pct done", render: (r: any) => fmtPct(r.pct_done) },
  ];

  return (
    <div style={{ padding: 24, display: "flex", flexDirection: "column", gap: 24 }}>
      <div>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Founder board prep checklist</h1>
        <p style={{ color: "#666", marginTop: 4 }}>
          Every board meeting gets a 12-item checklist. Track per-meeting completion. 48h-before alert fires when prep is behind.
        </p>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, minmax(0, 1fr))", gap: 12 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: "1px solid #e5e7eb", borderRadius: 8, padding: 12, background: "#fafafa" }}>
            <div style={{ fontSize: 11, color: "#666", textTransform: "uppercase", letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Board meetings</h2>
        <DataTable columns={meetingCols} rows={meetings} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Next meeting checklist</h2>
        <DataTable columns={itemCols} rows={items} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Imminent alerts (next 72h)</h2>
        <DataTable columns={alertCols} rows={alerts} rowKey={(r: any) => r.meeting_id} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Category breakdown (open meetings)</h2>
        <DataTable columns={catCols} rows={categories} rowKey={(r: any) => r.category} />
      </section>
    </div>
  );
}
