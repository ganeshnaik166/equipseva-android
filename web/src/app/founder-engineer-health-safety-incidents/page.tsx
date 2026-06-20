import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_incidents: number;
  reported_incidents: number;
  investigating_incidents: number;
  root_cause_incidents: number;
  closed_incidents: number;
  escalated_incidents: number;
  fatal_count: number;
  critical_count: number;
  serious_count: number;
  near_miss_count: number;
  total_downtime_days: number;
  total_medical_cost_rupees: number;
  open_actions: number;
  overdue_actions: number;
  incidents_last_30d: number;
  latest_incident_date: string | null;
};

type Incident = {
  id: string;
  engineer_user_id: string;
  incident_kind: string;
  severity: string;
  incident_date: string;
  location_label: string | null;
  description: string | null;
  equipment_label: string | null;
  downtime_days: number;
  medical_cost_rupees: number;
  reported_to_authority: boolean;
  status: string;
  reported_at: string;
  closed_at: string | null;
};

type Action = {
  id: string;
  incident_id: string;
  action_kind: string;
  description: string | null;
  owner_user_id: string | null;
  due_date: string | null;
  status: string;
  closed_at: string | null;
  created_at: string;
  incident_severity: string | null;
  incident_kind: string | null;
};

type OpenCritical = {
  id: string;
  engineer_user_id: string;
  incident_kind: string;
  severity: string;
  incident_date: string;
  status: string;
  description: string | null;
  downtime_days: number;
  medical_cost_rupees: number;
};

function sevColor(sev: string): { bg: string; fg: string } {
  if (sev === "fatal") return { bg: "#1f2937", fg: "#fef2f2" };
  if (sev === "critical") return { bg: "#fee2e2", fg: "#991b1b" };
  if (sev === "serious") return { bg: "#ffedd5", fg: "#9a3412" };
  if (sev === "moderate") return { bg: "#fef3c7", fg: "#92400e" };
  if (sev === "minor") return { bg: "#e0f2fe", fg: "#075985" };
  return { bg: "#dcfce7", fg: "#065f46" };
}

function statusColor(s: string): { bg: string; fg: string } {
  if (s === "closed") return { bg: "#dcfce7", fg: "#065f46" };
  if (s === "escalated_to_authority") return { bg: "#fee2e2", fg: "#991b1b" };
  if (s === "investigating") return { bg: "#fef3c7", fg: "#92400e" };
  if (s === "root_cause_found") return { bg: "#e0e7ff", fg: "#3730a3" };
  return { bg: "#eef2ff", fg: "#3730a3" };
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [{ data: sumRows }, { data: incRows }, { data: actRows }, { data: critRows }] = await Promise.all([
    sb.rpc("founder_health_safety_summary"),
    sb.rpc("founder_health_safety_incidents_recent"),
    sb.rpc("founder_health_safety_corrective_actions_recent"),
    sb.rpc("founder_health_safety_open_critical"),
  ]);

  const s: Summary = (Array.isArray(sumRows) ? sumRows[0] : sumRows) ?? {
    total_incidents: 0, reported_incidents: 0, investigating_incidents: 0, root_cause_incidents: 0,
    closed_incidents: 0, escalated_incidents: 0, fatal_count: 0, critical_count: 0, serious_count: 0,
    near_miss_count: 0, total_downtime_days: 0, total_medical_cost_rupees: 0,
    open_actions: 0, overdue_actions: 0, incidents_last_30d: 0, latest_incident_date: null,
  };
  const incidents: Incident[] = (incRows as Incident[]) ?? [];
  const actions: Action[] = (actRows as Action[]) ?? [];
  const openCritical: OpenCritical[] = (critRows as OpenCritical[]) ?? [];

  return (
    <main style={{ maxWidth: 1200, margin: "0 auto", padding: 24, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Engineer Health & Safety Incidents</h1>
      <p style={{ color: "#666", marginBottom: 20 }}>Field-engineer injury, exposure, and near-miss ledger with corrective-action tracking — DGFASLI-ready register.</p>

      {openCritical.length > 0 && (
        <div style={{ background: "#fee2e2", border: "1px solid #fca5a5", borderRadius: 10, padding: 14, marginBottom: 20 }}>
          <div style={{ fontWeight: 700, color: "#991b1b", fontSize: 14 }}>
            {openCritical.length} serious/critical/fatal incident{openCritical.length === 1 ? "" : "s"} still OPEN — root-cause + corrective action required.
          </div>
        </div>
      )}

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 12, marginBottom: 28 }}>
        {[
          ["Total incidents", formatNumber(s.total_incidents)],
          ["Reported (new)", formatNumber(s.reported_incidents)],
          ["Investigating", formatNumber(s.investigating_incidents)],
          ["Root cause found", formatNumber(s.root_cause_incidents)],
          ["Closed", formatNumber(s.closed_incidents)],
          ["Escalated to authority", formatNumber(s.escalated_incidents)],
          ["Fatal", formatNumber(s.fatal_count)],
          ["Critical", formatNumber(s.critical_count)],
          ["Serious", formatNumber(s.serious_count)],
          ["Near miss", formatNumber(s.near_miss_count)],
          ["Total downtime (days)", formatNumber(s.total_downtime_days)],
          ["Total medical cost", `Rs ${formatNumber(s.total_medical_cost_rupees)}`],
          ["Open actions", formatNumber(s.open_actions)],
          ["Overdue actions", formatNumber(s.overdue_actions)],
          ["Incidents 30d", formatNumber(s.incidents_last_30d)],
          ["Latest incident", s.latest_incident_date ?? "None"],
        ].map(([label, value]) => (
          <div key={label as string} style={{ background: "#fff", border: "1px solid #e5e7eb", borderRadius: 10, padding: 14 }}>
            <div style={{ color: "#6b7280", fontSize: 12, fontWeight: 500 }}>{label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Open critical/fatal ({openCritical.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#fef2f2" }}>
              <tr>
                {["Engineer", "Kind", "Severity", "Date", "Status", "Downtime", "Medical Rs"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {openCritical.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: 16, color: "#16a34a", textAlign: "center" }}>No open critical incidents.</td></tr>
              ) : openCritical.map((c) => {
                const sc = sevColor(c.severity);
                return (
                  <tr key={c.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                    <td style={{ padding: "10px 12px", fontFamily: "monospace", fontSize: 11, color: "#374151" }}>{c.engineer_user_id.slice(0,8)}…</td>
                    <td style={{ padding: "10px 12px", color: "#374151" }}>{c.incident_kind}</td>
                    <td style={{ padding: "10px 12px" }}>
                      <span style={{ background: sc.bg, color: sc.fg, padding: "2px 8px", borderRadius: 6, fontWeight: 700, fontSize: 11, textTransform: "uppercase" }}>{c.severity}</span>
                    </td>
                    <td style={{ padding: "10px 12px", color: "#6b7280" }}>{c.incident_date}</td>
                    <td style={{ padding: "10px 12px", color: "#374151" }}>{c.status}</td>
                    <td style={{ padding: "10px 12px" }}>{formatNumber(c.downtime_days)}</td>
                    <td style={{ padding: "10px 12px" }}>{formatNumber(c.medical_cost_rupees)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Incident ledger ({incidents.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Date", "Engineer", "Kind", "Severity", "Status", "Location", "Equipment", "Downtime", "Medical Rs", "Authority?"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {incidents.length === 0 ? (
                <tr><td colSpan={10} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No incidents recorded.</td></tr>
              ) : incidents.map((i) => {
                const sc = sevColor(i.severity);
                const st = statusColor(i.status);
                return (
                  <tr key={i.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                    <td style={{ padding: "10px 12px", color: "#6b7280" }}>{i.incident_date}</td>
                    <td style={{ padding: "10px 12px", fontFamily: "monospace", fontSize: 11, color: "#374151" }}>{i.engineer_user_id.slice(0,8)}…</td>
                    <td style={{ padding: "10px 12px", color: "#374151" }}>{i.incident_kind}</td>
                    <td style={{ padding: "10px 12px" }}>
                      <span style={{ background: sc.bg, color: sc.fg, padding: "2px 8px", borderRadius: 6, fontWeight: 700, fontSize: 11, textTransform: "uppercase" }}>{i.severity}</span>
                    </td>
                    <td style={{ padding: "10px 12px" }}>
                      <span style={{ background: st.bg, color: st.fg, padding: "2px 8px", borderRadius: 6, fontWeight: 600, fontSize: 11 }}>{i.status}</span>
                    </td>
                    <td style={{ padding: "10px 12px", color: "#374151" }}>{i.location_label ?? "—"}</td>
                    <td style={{ padding: "10px 12px", color: "#374151" }}>{i.equipment_label ?? "—"}</td>
                    <td style={{ padding: "10px 12px" }}>{formatNumber(i.downtime_days)}</td>
                    <td style={{ padding: "10px 12px" }}>{formatNumber(i.medical_cost_rupees)}</td>
                    <td style={{ padding: "10px 12px", color: i.reported_to_authority ? "#991b1b" : "#6b7280", fontWeight: i.reported_to_authority ? 700 : 400 }}>
                      {i.reported_to_authority ? "YES" : "no"}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Corrective action feed ({actions.length})</h2>
        <div style={{ display: "grid", gap: 10 }}>
          {actions.length === 0 ? (
            <div style={{ color: "#999", padding: 14, border: "1px dashed #e5e7eb", borderRadius: 10 }}>No corrective actions logged yet.</div>
          ) : actions.map((a) => {
            const overdue = a.due_date != null && a.status !== "closed" && a.status !== "cancelled" && new Date(a.due_date) < new Date();
            const sc = a.incident_severity ? sevColor(a.incident_severity) : { bg: "#f3f4f6", fg: "#374151" };
            const st = statusColor(a.status);
            return (
              <div key={a.id} style={{ border: "1px solid #e5e7eb", borderRadius: 10, padding: 14, background: "#fff" }}>
                <div style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 8 }}>
                  <div>
                    <div style={{ fontSize: 13, color: "#6b7280" }}>
                      <span style={{ background: sc.bg, color: sc.fg, padding: "2px 8px", borderRadius: 6, fontSize: 11, fontWeight: 700, textTransform: "uppercase" }}>
                        {a.incident_severity ?? "—"}
                      </span>
                      <span style={{ marginLeft: 8 }}>{a.incident_kind ?? "—"}</span>
                    </div>
                    <div style={{ marginTop: 6, fontSize: 15, fontWeight: 600 }}>
                      {a.action_kind.replace(/_/g, " ")}
                      <span style={{ marginLeft: 10, background: st.bg, color: st.fg, padding: "2px 8px", borderRadius: 6, fontSize: 11, fontWeight: 600 }}>{a.status}</span>
                      {overdue && (
                        <span style={{ marginLeft: 8, background: "#fee2e2", color: "#991b1b", padding: "2px 8px", borderRadius: 6, fontSize: 11, fontWeight: 700 }}>OVERDUE</span>
                      )}
                    </div>
                  </div>
                  <div style={{ color: "#9ca3af", fontSize: 12, textAlign: "right" }}>
                    <div>Due: {a.due_date ?? "—"}</div>
                    <div>Created: {a.created_at.slice(0,10)}</div>
                  </div>
                </div>
                {a.description && (
                  <p style={{ marginTop: 8, fontSize: 13, color: "#4b5563", whiteSpace: "pre-wrap", background: "#f9fafb", padding: 10, borderRadius: 6 }}>{a.description}</p>
                )}
                {a.owner_user_id && (
                  <div style={{ marginTop: 6, fontSize: 12, color: "#6b7280" }}>
                    Owner: <span style={{ fontFamily: "monospace" }}>{a.owner_user_id.slice(0,8)}…</span>
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
