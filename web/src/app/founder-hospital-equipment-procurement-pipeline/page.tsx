import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRupees } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_pipeline_count: number;
  active_count: number;
  need_identified_count: number;
  rfq_sent_count: number;
  quotes_received_count: number;
  negotiation_count: number;
  po_issued_count: number;
  delivery_pending_count: number;
  delivered_count: number;
  commissioned_count: number;
  cancelled_count: number;
  overdue_count: number;
  total_pipeline_value_rupees: number;
  active_pipeline_value_rupees: number;
  commissioned_value_rupees: number;
  avg_days_to_commission: number;
  generated_at: string;
};

type PipelineRow = {
  id: string;
  equipment_label: string;
  equipment_category: string | null;
  procurement_stage: string;
  expected_value_rupees: number;
  vendor_org_id: string | null;
  hospital_label: string;
  expected_delivery_date: string | null;
  actual_delivery_date: string | null;
  days_in_stage: number;
  is_overdue: boolean;
  created_at: string;
  updated_at: string;
};

type Milestone = {
  id: string;
  procurement_id: string;
  equipment_label: string;
  milestone_kind: string;
  description: string | null;
  value_rupees: number;
  happened_at: string;
};

type Overdue = {
  id: string;
  equipment_label: string;
  procurement_stage: string;
  expected_value_rupees: number;
  expected_delivery_date: string;
  days_overdue: number;
  hospital_label: string;
};

const STAGE_COLOR: Record<string, string> = {
  need_identified: "#6b7280",
  rfq_sent: "#0ea5e9",
  quotes_received: "#0891b2",
  negotiation: "#a16207",
  po_issued: "#7c3aed",
  delivery_pending: "#db2777",
  delivered: "#0f766e",
  installed: "#047857",
  commissioned: "#065f46",
  cancelled: "#991b1b",
};

const MILESTONE_COLOR: Record<string, string> = {
  rfq_sent: "#0ea5e9",
  quotes_received: "#0891b2",
  negotiation_start: "#a16207",
  po_issued: "#7c3aed",
  part_payment: "#059669",
  delivery_arrived: "#0f766e",
  installation_started: "#047857",
  commissioned: "#065f46",
  escalation: "#b91c1c",
  cancelled: "#991b1b",
};

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [sumR, recR, mileR, overR] = await Promise.all([
    sb.rpc("founder_equipment_procurement_summary"),
    sb.rpc("founder_equipment_procurement_recent"),
    sb.rpc("founder_equipment_procurement_milestones_recent"),
    sb.rpc("founder_equipment_procurement_overdue"),
  ]);

  const s: Summary = (Array.isArray(sumR.data) ? sumR.data[0] : sumR.data) ?? {
    total_pipeline_count: 0, active_count: 0, need_identified_count: 0,
    rfq_sent_count: 0, quotes_received_count: 0, negotiation_count: 0,
    po_issued_count: 0, delivery_pending_count: 0, delivered_count: 0,
    commissioned_count: 0, cancelled_count: 0, overdue_count: 0,
    total_pipeline_value_rupees: 0, active_pipeline_value_rupees: 0,
    commissioned_value_rupees: 0, avg_days_to_commission: 0,
    generated_at: new Date().toISOString(),
  };
  const rows: PipelineRow[] = (recR.data as PipelineRow[]) ?? [];
  const milestones: Milestone[] = (mileR.data as Milestone[]) ?? [];
  const overdue: Overdue[] = (overR.data as Overdue[]) ?? [];

  const kpis: Array<[string, string | number, string?]> = [
    ["Pipeline total", formatNumber(s.total_pipeline_count)],
    ["Active deals", formatNumber(s.active_count), s.active_count > 0 ? "#065f46" : "#374151"],
    ["Need identified", formatNumber(s.need_identified_count)],
    ["RFQ sent", formatNumber(s.rfq_sent_count)],
    ["Quotes received", formatNumber(s.quotes_received_count)],
    ["Negotiation", formatNumber(s.negotiation_count)],
    ["PO issued", formatNumber(s.po_issued_count), s.po_issued_count > 0 ? "#7c3aed" : "#374151"],
    ["Delivery pending", formatNumber(s.delivery_pending_count)],
    ["Delivered", formatNumber(s.delivered_count)],
    ["Commissioned", formatNumber(s.commissioned_count), s.commissioned_count > 0 ? "#065f46" : "#374151"],
    ["Cancelled", formatNumber(s.cancelled_count), s.cancelled_count > 0 ? "#991b1b" : "#374151"],
    ["Overdue", formatNumber(s.overdue_count), s.overdue_count > 0 ? "#991b1b" : "#374151"],
    ["Total pipeline value", formatRupees(s.total_pipeline_value_rupees)],
    ["Active pipeline value", formatRupees(s.active_pipeline_value_rupees)],
    ["Commissioned value", formatRupees(s.commissioned_value_rupees)],
    ["Avg days to commission", `${s.avg_days_to_commission}d`],
  ];

  const overdueCount = overdue.length;

  return (
    <main style={{ maxWidth: 1200, margin: "0 auto", padding: 24, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Hospital equipment procurement pipeline</h1>
      <p style={{ color: "#666", marginBottom: 20 }}>
        Hospital-side equipment purchase deals · RFQ {"->"} vendor {"->"} PO {"->"} delivery {"->"} commissioned ·{" "}
        {formatNumber(s.active_count)} active of {formatNumber(s.total_pipeline_count)} total · generated{" "}
        {new Date(s.generated_at).toLocaleString()}
      </p>

      {overdueCount > 0 && (
        <div style={{ background: "#fee2e2", border: "1px solid #fecaca", borderRadius: 10, padding: 14, marginBottom: 20 }}>
          <div style={{ fontWeight: 700, color: "#991b1b", fontSize: 14 }}>
            {overdueCount} overdue procurement{overdueCount === 1 ? "" : "s"} past expected delivery date
          </div>
          <div style={{ color: "#991b1b", fontSize: 12, marginTop: 6, display: "flex", gap: 16, flexWrap: "wrap" }}>
            {overdue.slice(0, 5).map((o) => (
              <span key={o.id}>
                <strong>{o.equipment_label}</strong> ({o.hospital_label}) · {o.days_overdue}d late
              </span>
            ))}
            {overdue.length > 5 && <span>+{overdue.length - 5} more</span>}
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
                {["Equipment", "Category", "Hospital", "Stage", "Value", "Expected delivery", "Days in stage", "Updated"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 ? (
                <tr><td colSpan={8} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No procurement deals yet.</td></tr>
              ) : rows.map((r) => (
                <tr key={r.id} style={{ borderTop: "1px solid #f1f5f9", background: r.is_overdue ? "#fef2f2" : undefined }}>
                  <td style={{ padding: "10px 12px", fontWeight: 600 }}>{r.equipment_label}</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280" }}>{r.equipment_category ?? "-"}</td>
                  <td style={{ padding: "10px 12px" }}>{r.hospital_label}</td>
                  <td style={{ padding: "10px 12px" }}>
                    <span style={{ background: STAGE_COLOR[r.procurement_stage] ?? "#6b7280", color: "#fff", padding: "2px 8px", borderRadius: 12, fontSize: 11, fontWeight: 600, whiteSpace: "nowrap" }}>
                      {r.procurement_stage}
                    </span>
                  </td>
                  <td style={{ padding: "10px 12px", fontWeight: 500 }}>{formatRupees(r.expected_value_rupees)}</td>
                  <td style={{ padding: "10px 12px", color: r.is_overdue ? "#991b1b" : "#374151", fontWeight: r.is_overdue ? 700 : 400 }}>
                    {r.expected_delivery_date ?? "-"}
                  </td>
                  <td style={{ padding: "10px 12px" }}>{r.days_in_stage}d</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280" }}>{new Date(r.updated_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Milestone feed ({milestones.length})</h2>
        <div style={{ border: "1px solid #e5e7eb", borderRadius: 10, background: "#fff" }}>
          {milestones.length === 0 ? (
            <div style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No milestones logged yet.</div>
          ) : milestones.map((m, i) => (
            <div key={m.id} style={{ display: "flex", justifyContent: "space-between", gap: 12, padding: "10px 14px", borderTop: i === 0 ? "none" : "1px solid #f1f5f9", flexWrap: "wrap" }}>
              <div style={{ display: "flex", gap: 10, alignItems: "center", flex: 1, minWidth: 0 }}>
                <span style={{ background: MILESTONE_COLOR[m.milestone_kind] ?? "#6b7280", color: "#fff", padding: "2px 8px", borderRadius: 12, fontSize: 11, fontWeight: 600, whiteSpace: "nowrap" }}>
                  {m.milestone_kind}
                </span>
                <span style={{ fontWeight: 500 }}>{m.equipment_label}</span>
                {m.description && <span style={{ color: "#6b7280", fontSize: 13 }}>· {m.description}</span>}
                {m.value_rupees > 0 && <span style={{ color: "#065f46", fontSize: 12, fontWeight: 600 }}>· {formatRupees(m.value_rupees)}</span>}
              </div>
              <div style={{ color: "#6b7280", fontSize: 12 }}>{new Date(m.happened_at).toLocaleString()}</div>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
