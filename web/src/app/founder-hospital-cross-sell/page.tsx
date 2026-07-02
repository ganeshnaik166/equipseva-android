import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

type Kpi = { label: string; value: string };

export const dynamic = "force-dynamic";

export default async function FounderHospitalCrossSellPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let ladder: any[] = [];
  let queue: any[] = [];
  let byProduct: any[] = [];
  let topHospitals: any[] = [];

  try {
    const r = await sb.rpc("founder_hospital_xsell_overview");
    overview = Array.isArray(r.data) ? r.data[0] : r.data;
  } catch { overview = null; }

  try {
    const r = await sb.rpc("founder_hospital_xsell_ladder_list");
    ladder = Array.isArray(r.data) ? r.data : [];
  } catch { ladder = []; }

  try {
    const r = await sb.rpc("founder_hospital_xsell_queue_list");
    queue = Array.isArray(r.data) ? r.data : [];
  } catch { queue = []; }

  try {
    const r = await sb.rpc("founder_hospital_xsell_by_product");
    byProduct = Array.isArray(r.data) ? r.data : [];
  } catch { byProduct = []; }

  try {
    const r = await sb.rpc("founder_hospital_xsell_top_hospitals");
    topHospitals = Array.isArray(r.data) ? r.data : [];
  } catch { topHospitals = []; }

  const fmtInr = (n: any) => {
    const v = Number(n ?? 0);
    if (!isFinite(v)) return "₹0";
    return "₹" + v.toLocaleString("en-IN");
  };

  const kpis: Kpi[] = [
    { label: "AMC Hospitals",      value: String(overview?.total_amc_hospitals ?? "—") },
    { label: "Hospitals w/ Ladder", value: String(overview?.hospitals_with_ladder ?? "—") },
    { label: "Ladder Rows",        value: String(overview?.total_ladder_rows ?? "—") },
    { label: "Suggested",          value: String(overview?.suggested_rows ?? "—") },
    { label: "Pitched",            value: String(overview?.pitched_rows ?? "—") },
    { label: "Interested",         value: String(overview?.interested_rows ?? "—") },
    { label: "Negotiating",        value: String(overview?.negotiating_rows ?? "—") },
    { label: "Won",                value: String(overview?.won_rows ?? "—") },
    { label: "Lost",               value: String(overview?.lost_rows ?? "—") },
    { label: "Parked",             value: String(overview?.parked_rows ?? "—") },
    { label: "Pipeline",           value: fmtInr(overview?.total_pipeline_rupees) },
    { label: "Won Pipeline",       value: fmtInr(overview?.won_pipeline_rupees) },
    { label: "Open Queue",         value: String(overview?.open_queue_items ?? "—") },
    { label: "Overdue Queue",      value: String(overview?.overdue_queue_items ?? "—") },
    { label: "Urgent Queue",       value: String(overview?.urgent_queue_items ?? "—") },
    { label: "Avg Fit Score",      value: String(overview?.avg_fit_score ?? "—") },
  ];

  const ladderCols: Column<any>[] = [
    { key: "hospital_name",      header: "Hospital",    render: (r: any) => r.hospital_name ?? "—" },
    { key: "product_slug",       header: "Product",     render: (r: any) => r.product_slug ?? "—" },
    { key: "ladder_stage",       header: "Stage",       render: (r: any) => r.ladder_stage ?? "—" },
    { key: "fit_score",          header: "Fit",         render: (r: any) => String(r.fit_score ?? "—") },
    { key: "est_value_rupees",   header: "Est Value",   render: (r: any) => fmtInr(r.est_value_rupees) },
    { key: "days_until_due",     header: "Due (days)",  render: (r: any) => r.days_until_due == null ? "—" : String(r.days_until_due) },
    { key: "open_queue_items",   header: "Open Q",      render: (r: any) => String(r.open_queue_items ?? 0) },
  ];

  const queueCols: Column<any>[] = [
    { key: "hospital_name", header: "Hospital",  render: (r: any) => r.hospital_name ?? "—" },
    { key: "product_slug", header: "Product",   render: (r: any) => r.product_slug ?? "—" },
    { key: "action_kind",  header: "Action",    render: (r: any) => r.action_kind ?? "—" },
    { key: "priority",     header: "Priority",  render: (r: any) => r.priority ?? "—" },
    { key: "status",       header: "Status",    render: (r: any) => r.status ?? "—" },
    { key: "due_at",       header: "Due",       render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleString() : "—" },
    { key: "hours_overdue",header: "Overdue h", render: (r: any) => String(r.hours_overdue ?? 0) },
    { key: "note",         header: "Note",      render: (r: any) => r.note ?? "—" },
  ];

  const productCols: Column<any>[] = [
    { key: "product_slug",     header: "Product",     render: (r: any) => r.product_slug ?? "—" },
    { key: "total_rows",       header: "Total",       render: (r: any) => String(r.total_rows ?? 0) },
    { key: "won_rows",         header: "Won",         render: (r: any) => String(r.won_rows ?? 0) },
    { key: "pipeline_rupees",  header: "Pipeline",    render: (r: any) => fmtInr(r.pipeline_rupees) },
    { key: "avg_fit",          header: "Avg Fit",     render: (r: any) => String(r.avg_fit ?? "—") },
    { key: "open_queue",       header: "Open Q",      render: (r: any) => String(r.open_queue ?? 0) },
  ];

  const hospitalCols: Column<any>[] = [
    { key: "hospital_name",    header: "Hospital",     render: (r: any) => r.hospital_name ?? "—" },
    { key: "ladder_rows",      header: "Ladder Rows",  render: (r: any) => String(r.ladder_rows ?? 0) },
    { key: "won_rows",         header: "Won",          render: (r: any) => String(r.won_rows ?? 0) },
    { key: "pipeline_rupees",  header: "Pipeline",     render: (r: any) => fmtInr(r.pipeline_rupees) },
    { key: "open_queue",       header: "Open Q",       render: (r: any) => String(r.open_queue ?? 0) },
    { key: "avg_fit",          header: "Avg Fit",      render: (r: any) => String(r.avg_fit ?? "—") },
  ];

  return (
    <main style={{ padding: "24px", fontFamily: "system-ui, sans-serif", maxWidth: 1400, margin: "0 auto" }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Cross-Sell Ladder</h1>
      <p style={{ color: "#666", marginBottom: 24, fontSize: 14 }}>
        For each AMC hospital, the next product suggestion (spare parts contract, training, equipment swap, refurbishment),
        current ladder state, and the founder action queue. Stages flow {"suggested"} {">"} {"pitched"} {">"} {"interested"} {">"} {"negotiating"} {">"} {"won"} / {"lost"}.
      </p>

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))", gap: 12, marginBottom: 32 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: "1px solid #e5e5e5", borderRadius: 8, padding: 12, background: "#fafafa" }}>
            <div style={{ fontSize: 11, color: "#666", textTransform: "uppercase", letterSpacing: 0.5 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Ladder Rows</h2>
        <DataTable columns={ladderCols} rows={ladder} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Action Queue</h2>
        <DataTable columns={queueCols} rows={queue} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>By Product</h2>
        <DataTable columns={productCols} rows={byProduct} rowKey={(r: any) => r.product_slug} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Hospitals</h2>
        <DataTable columns={hospitalCols} rows={topHospitals} rowKey={(r: any) => r.hospital_org_id} />
      </section>
    </main>
  );
}
