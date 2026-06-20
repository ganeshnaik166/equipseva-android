import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRupees } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_pipeline_count: number;
  active_count: number;
  proposed_count: number;
  approved_count: number;
  disconnected_count: number;
  staged_count: number;
  disposed_count: number;
  salvaged_count: number;
  rejected_count: number;
  high_environmental_impact_count: number;
  missing_certificate_count: number;
  e_waste_certified_count: number;
  total_salvage_recovered_rupees: number;
  avg_days_propose_to_dispose: number;
  proposed_last_30d: number;
  disposed_last_30d: number;
  generated_at: string;
};

type PipelineRow = {
  id: string;
  equipment_id: string;
  equipment_label: string;
  decommission_reason: string;
  status: string;
  disposal_method: string;
  environmental_impact_band: string;
  salvage_value_recovered_rupees: number;
  proposed_at: string;
  approved_at: string | null;
  disposed_at: string | null;
  days_since_propose: number;
  has_certificate: boolean;
  created_at: string;
  updated_at: string;
};

type EventRow = {
  id: string;
  decomm_id: string;
  equipment_label: string;
  event_kind: string;
  description: string | null;
  value_rupees: number;
  happened_at: string;
};

type AtRiskRow = {
  id: string;
  equipment_label: string;
  status: string;
  decommission_reason: string;
  disposal_method: string;
  environmental_impact_band: string;
  days_in_status: number;
  risk_reason: string;
  proposed_at: string;
};

const STATUS_COLOR: Record<string, string> = {
  proposed: "#6b7280",
  approved: "#0ea5e9",
  disconnected: "#a16207",
  staged: "#7c3aed",
  disposed: "#0f766e",
  salvaged: "#065f46",
  rejected: "#991b1b",
};

const EVENT_COLOR: Record<string, string> = {
  proposed: "#6b7280",
  approved: "#0ea5e9",
  disconnect_scheduled: "#a16207",
  disconnected: "#a16207",
  staged: "#7c3aed",
  disposed: "#0f766e",
  certificate_received: "#059669",
  salvage_revenue: "#065f46",
  rejected: "#991b1b",
};

const IMPACT_COLOR: Record<string, string> = {
  low: "#065f46",
  medium: "#a16207",
  high: "#991b1b",
  unknown: "#6b7280",
};

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [sumR, recR, evR, riskR] = await Promise.all([
    sb.rpc("founder_decommissioning_pipeline_summary"),
    sb.rpc("founder_decommissioning_pipeline_recent"),
    sb.rpc("founder_decommissioning_events_recent"),
    sb.rpc("founder_decommissioning_at_risk"),
  ]);

  const s: Summary = (Array.isArray(sumR.data) ? sumR.data[0] : sumR.data) ?? {
    total_pipeline_count: 0, active_count: 0, proposed_count: 0, approved_count: 0,
    disconnected_count: 0, staged_count: 0, disposed_count: 0, salvaged_count: 0,
    rejected_count: 0, high_environmental_impact_count: 0, missing_certificate_count: 0,
    e_waste_certified_count: 0, total_salvage_recovered_rupees: 0,
    avg_days_propose_to_dispose: 0, proposed_last_30d: 0, disposed_last_30d: 0,
    generated_at: new Date().toISOString(),
  };
  const rows: PipelineRow[] = (recR.data as PipelineRow[]) ?? [];
  const events: EventRow[] = (evR.data as EventRow[]) ?? [];
  const risks: AtRiskRow[] = (riskR.data as AtRiskRow[]) ?? [];

  const kpis: Array<[string, string | number, string?]> = [
    ["Total in pipeline", formatNumber(s.total_pipeline_count)],
    ["Active", formatNumber(s.active_count), s.active_count > 0 ? "#0ea5e9" : "#374151"],
    ["Proposed", formatNumber(s.proposed_count)],
    ["Approved", formatNumber(s.approved_count)],
    ["Disconnected", formatNumber(s.disconnected_count)],
    ["Staged", formatNumber(s.staged_count), s.staged_count > 0 ? "#7c3aed" : "#374151"],
    ["Disposed", formatNumber(s.disposed_count), s.disposed_count > 0 ? "#0f766e" : "#374151"],
    ["Salvaged", formatNumber(s.salvaged_count), s.salvaged_count > 0 ? "#065f46" : "#374151"],
    ["Rejected", formatNumber(s.rejected_count), s.rejected_count > 0 ? "#991b1b" : "#374151"],
    ["High env impact", formatNumber(s.high_environmental_impact_count), s.high_environmental_impact_count > 0 ? "#991b1b" : "#374151"],
    ["Missing certificate", formatNumber(s.missing_certificate_count), s.missing_certificate_count > 0 ? "#991b1b" : "#374151"],
    ["E-waste certified", formatNumber(s.e_waste_certified_count), s.e_waste_certified_count > 0 ? "#065f46" : "#374151"],
    ["Salvage recovered", formatRupees(s.total_salvage_recovered_rupees)],
    ["Avg days propose to dispose", `${s.avg_days_propose_to_dispose}d`],
    ["Proposed last 30d", formatNumber(s.proposed_last_30d)],
    ["Disposed last 30d", formatNumber(s.disposed_last_30d)],
  ];

  const riskCount = risks.length;

  return (
    <main style={{ maxWidth: 1200, margin: "0 auto", padding: 24, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Equipment decommissioning pipeline</h1>
      <p style={{ color: "#666", marginBottom: 20 }}>
        Retirement + disposal board · propose {"->"} approve {"->"} disconnect {"->"} stage {"->"} dispose {"->"} salvage ·{" "}
        {formatNumber(s.active_count)} active of {formatNumber(s.total_pipeline_count)} total · generated{" "}
        {new Date(s.generated_at).toLocaleString()}
      </p>

      {riskCount > 0 && (
        <div style={{ background: "#fee2e2", border: "1px solid #fecaca", borderRadius: 10, padding: 14, marginBottom: 20 }}>
          <div style={{ fontWeight: 700, color: "#991b1b", fontSize: 14 }}>
            {riskCount} at-risk decommissioning{riskCount === 1 ? "" : "s"} (staged too long / missing certificate / high impact)
          </div>
          <div style={{ color: "#991b1b", fontSize: 12, marginTop: 6, display: "flex", gap: 16, flexWrap: "wrap" }}>
            {risks.slice(0, 5).map((r) => (
              <span key={r.id}>
                <strong>{r.equipment_label}</strong> · {r.risk_reason} ({r.days_in_status}d)
              </span>
            ))}
            {risks.length > 5 && <span>+{risks.length - 5} more</span>}
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
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Pipeline ({rows.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Equipment", "Reason", "Status", "Disposal", "Env impact", "Salvage", "Days since propose", "Cert", "Updated"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 ? (
                <tr><td colSpan={9} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No decommissioning rows yet.</td></tr>
              ) : rows.map((r) => {
                const isStuck =
                  (r.status === "proposed" && r.days_since_propose > 14) ||
                  (r.status === "staged" && r.days_since_propose > 30);
                const certMissing =
                  (r.status === "disposed" || r.status === "salvaged") && !r.has_certificate;
                return (
                  <tr key={r.id} style={{ borderTop: "1px solid #f1f5f9", background: isStuck || certMissing ? "#fef2f2" : undefined }}>
                    <td style={{ padding: "10px 12px", fontWeight: 600 }}>{r.equipment_label}</td>
                    <td style={{ padding: "10px 12px", color: "#374151" }}>{r.decommission_reason}</td>
                    <td style={{ padding: "10px 12px" }}>
                      <span style={{ background: STATUS_COLOR[r.status] ?? "#6b7280", color: "#fff", padding: "2px 8px", borderRadius: 12, fontSize: 11, fontWeight: 600, whiteSpace: "nowrap" }}>
                        {r.status}
                      </span>
                    </td>
                    <td style={{ padding: "10px 12px", color: "#374151" }}>{r.disposal_method}</td>
                    <td style={{ padding: "10px 12px" }}>
                      <span style={{ color: IMPACT_COLOR[r.environmental_impact_band] ?? "#374151", fontWeight: 600 }}>
                        {r.environmental_impact_band}
                      </span>
                    </td>
                    <td style={{ padding: "10px 12px", fontWeight: 500 }}>{formatRupees(r.salvage_value_recovered_rupees)}</td>
                    <td style={{ padding: "10px 12px", color: isStuck ? "#991b1b" : "#374151", fontWeight: isStuck ? 700 : 400 }}>{r.days_since_propose}d</td>
                    <td style={{ padding: "10px 12px", color: certMissing ? "#991b1b" : "#065f46", fontWeight: 600 }}>
                      {r.has_certificate ? "yes" : (r.status === "disposed" || r.status === "salvaged") ? "MISSING" : "-"}
                    </td>
                    <td style={{ padding: "10px 12px", color: "#6b7280" }}>{new Date(r.updated_at).toLocaleDateString()}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Event feed ({events.length})</h2>
        <div style={{ border: "1px solid #e5e7eb", borderRadius: 10, background: "#fff" }}>
          {events.length === 0 ? (
            <div style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No events logged yet.</div>
          ) : events.map((e, i) => (
            <div key={e.id} style={{ display: "flex", justifyContent: "space-between", gap: 12, padding: "10px 14px", borderTop: i === 0 ? "none" : "1px solid #f1f5f9", flexWrap: "wrap" }}>
              <div style={{ display: "flex", gap: 10, alignItems: "center", flex: 1, minWidth: 0 }}>
                <span style={{ background: EVENT_COLOR[e.event_kind] ?? "#6b7280", color: "#fff", padding: "2px 8px", borderRadius: 12, fontSize: 11, fontWeight: 600, whiteSpace: "nowrap" }}>
                  {e.event_kind}
                </span>
                <span style={{ fontWeight: 500 }}>{e.equipment_label}</span>
                {e.description && <span style={{ color: "#6b7280", fontSize: 13 }}>· {e.description}</span>}
                {e.value_rupees > 0 && <span style={{ color: "#065f46", fontSize: 12, fontWeight: 600 }}>· {formatRupees(e.value_rupees)}</span>}
              </div>
              <div style={{ color: "#6b7280", fontSize: 12 }}>{new Date(e.happened_at).toLocaleString()}</div>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
