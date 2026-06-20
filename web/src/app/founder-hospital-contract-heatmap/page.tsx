import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "-";
  return "Rs " + Number(n).toLocaleString("en-IN");
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "-";
  return Number(n).toFixed(2) + "%";
}

export default async function FounderHospitalContractHeatmapPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let byHospital: any[] = [];
  let byCategory: any[] = [];
  let cells: any[] = [];
  let gaps: any[] = [];
  let alerts: any[] = [];

  try {
    const r = await sb.rpc("founder_heatmap_kpis");
    kpis = r.data?.[0] ?? null;
  } catch {
    kpis = null;
  }
  try {
    const r = await sb.rpc("founder_heatmap_by_hospital");
    byHospital = (r.data as any[]) ?? [];
  } catch {
    byHospital = [];
  }
  try {
    const r = await sb.rpc("founder_heatmap_by_category");
    byCategory = (r.data as any[]) ?? [];
  } catch {
    byCategory = [];
  }
  try {
    const r = await sb.rpc("founder_heatmap_cells");
    cells = (r.data as any[]) ?? [];
  } catch {
    cells = [];
  }
  try {
    const r = await sb.rpc("founder_heatmap_gaps");
    gaps = (r.data as any[]) ?? [];
  } catch {
    gaps = [];
  }
  try {
    const r = await sb.rpc("founder_heatmap_alerts_list");
    alerts = (r.data as any[]) ?? [];
  } catch {
    alerts = [];
  }
  try {
    await sb.rpc("log_founder_heatmap_view", { p_section: "main" });
  } catch {
    // best-effort
  }

  const cards: Kpi[] = [
    { label: "Active Contracts", value: String(kpis?.total_active_contracts ?? "-") },
    { label: "Hospitals", value: String(kpis?.total_hospitals ?? "-") },
    { label: "Monthly Revenue", value: fmtRupees(kpis?.total_monthly_revenue_rupees) },
    { label: "Annual Revenue", value: fmtRupees(kpis?.total_annual_revenue_rupees) },
    { label: "Top-1 Share", value: fmtPct(kpis?.top1_hospital_share_pct) },
    { label: "Top-5 Share", value: fmtPct(kpis?.top5_hospital_share_pct) },
    { label: "Top-10 Share", value: fmtPct(kpis?.top10_hospital_share_pct) },
    { label: "Herfindahl Index", value: String(kpis?.herfindahl_index ?? "-") },
    { label: "Categories", value: String(kpis?.distinct_categories ?? "-") },
    { label: "Cities", value: String(kpis?.distinct_cities ?? "-") },
    { label: "Open Alerts", value: String(kpis?.open_concentration_alerts ?? "-") },
    { label: "Largest Contract", value: fmtRupees(kpis?.largest_single_contract_rupees) },
    { label: "Median Contract", value: fmtRupees(kpis?.median_contract_rupees) },
    { label: "Single-Category Hospitals", value: String(kpis?.hospitals_with_single_category ?? "-") },
    { label: "3+ Category Hospitals", value: String(kpis?.hospitals_with_three_plus_categories ?? "-") },
    { label: "Diversification Score", value: String(kpis?.diversification_score ?? "-") },
  ];

  const hospitalCols: Column<any>[] = [
    { key: "rn", header: "#", render: (r: any) => r.rn ?? "-" },
    { key: "hospital_name", header: "Hospital", render: (r: any) => r.hospital_name ?? "-" },
    { key: "hospital_city", header: "City", render: (r: any) => r.hospital_city ?? "-" },
    { key: "active_contracts", header: "Contracts", render: (r: any) => r.active_contracts ?? "-" },
    { key: "distinct_categories", header: "Categories", render: (r: any) => r.distinct_categories ?? "-" },
    { key: "monthly_value_rupees", header: "Monthly Value", render: (r: any) => fmtRupees(r.monthly_value_rupees) },
    { key: "annual_value_rupees", header: "Annual Value", render: (r: any) => fmtRupees(r.annual_value_rupees) },
    { key: "revenue_share_pct", header: "Share", render: (r: any) => fmtPct(r.revenue_share_pct) },
  ];

  const categoryCols: Column<any>[] = [
    { key: "equipment_category", header: "Category", render: (r: any) => r.equipment_category ?? "-" },
    { key: "contracts", header: "Contracts", render: (r: any) => r.contracts ?? "-" },
    { key: "hospitals", header: "Hospitals", render: (r: any) => r.hospitals ?? "-" },
    { key: "monthly_value_rupees", header: "Monthly Value", render: (r: any) => fmtRupees(r.monthly_value_rupees) },
    { key: "annual_value_rupees", header: "Annual Value", render: (r: any) => fmtRupees(r.annual_value_rupees) },
    { key: "avg_contract_rupees", header: "Avg Contract", render: (r: any) => fmtRupees(r.avg_contract_rupees) },
    { key: "share_pct", header: "Share", render: (r: any) => fmtPct(r.share_pct) },
  ];

  const cellCols: Column<any>[] = [
    { key: "hospital_name", header: "Hospital", render: (r: any) => r.hospital_name ?? "-" },
    { key: "equipment_category", header: "Category", render: (r: any) => r.equipment_category ?? "-" },
    { key: "contract_count", header: "Count", render: (r: any) => r.contract_count ?? "-" },
    { key: "monthly_value_rupees", header: "Monthly", render: (r: any) => fmtRupees(r.monthly_value_rupees) },
    { key: "amc_tier_mix", header: "Tiers", render: (r: any) => r.amc_tier_mix ?? "-" },
  ];

  const gapCols: Column<any>[] = [
    { key: "hospital_name", header: "Hospital", render: (r: any) => r.hospital_name ?? "-" },
    { key: "hospital_city", header: "City", render: (r: any) => r.hospital_city ?? "-" },
    { key: "current_categories", header: "Has", render: (r: any) => r.current_categories ?? "-" },
    { key: "missing_categories", header: "Missing", render: (r: any) => r.missing_categories ?? "-" },
    { key: "monthly_value_rupees", header: "Monthly Value", render: (r: any) => fmtRupees(r.monthly_value_rupees) },
    { key: "upsell_priority", header: "Priority", render: (r: any) => r.upsell_priority ?? "-" },
  ];

  const alertCols: Column<any>[] = [
    { key: "created_at", header: "When", render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : "-" },
    { key: "hospital_name", header: "Hospital", render: (r: any) => r.hospital_name ?? "-" },
    { key: "alert_kind", header: "Kind", render: (r: any) => r.alert_kind ?? "-" },
    { key: "severity", header: "Severity", render: (r: any) => r.severity ?? "-" },
    { key: "revenue_share_pct", header: "Share", render: (r: any) => fmtPct(r.revenue_share_pct) },
    { key: "acknowledged_at", header: "Ack", render: (r: any) => r.acknowledged_at ? "yes" : "no" },
  ];

  const topShare = Number(kpis?.top5_hospital_share_pct ?? 0);

  return (
    <main style={{ padding: 24, fontFamily: "system-ui, sans-serif" }}>
      <h1 style={{ fontSize: 22, marginBottom: 4 }}>Hospital Contract Heatmap</h1>
      <p style={{ color: "#555", marginBottom: 16 }}>
        Active AMCs plotted by hospital x equipment-category x contract value. Concentration risk fires when top-5 share {">"} 60%.
      </p>

      <section style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12, marginBottom: 24 }}>
        {cards.map((k) => (
          <div key={k.label} style={{ border: "1px solid #e5e7eb", borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 11, color: "#6b7280", textTransform: "uppercase" }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 20 }}>
        <div style={{
          padding: 12, borderRadius: 8,
          background: topShare > 60 ? "#fef2f2" : topShare > 40 ? "#fffbeb" : "#f0fdf4",
          border: "1px solid " + (topShare > 60 ? "#fecaca" : topShare > 40 ? "#fde68a" : "#bbf7d0")
        }}>
          <strong>Concentration check:</strong> Top-5 hospitals = {fmtPct(topShare)} of monthly revenue.
          {" "}{topShare > 60 ? "HIGH RISK — diversify urgently." : topShare > 40 ? "WATCH — monitor monthly." : "Healthy distribution."}
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, marginBottom: 8 }}>Top hospitals by revenue</h2>
        <DataTable columns={hospitalCols} rows={byHospital} rowKey={(r: any) => r.hospital_org_id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, marginBottom: 8 }}>Revenue by equipment category</h2>
        <DataTable columns={categoryCols} rows={byCategory} rowKey={(r: any) => r.equipment_category} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, marginBottom: 8 }}>Heatmap cells (hospital x category)</h2>
        <DataTable columns={cellCols} rows={cells} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, marginBottom: 8 }}>Diversification gaps (upsell targets)</h2>
        <DataTable columns={gapCols} rows={gaps} rowKey={(r: any) => r.hospital_org_id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, marginBottom: 8 }}>Concentration alerts</h2>
        <DataTable columns={alertCols} rows={alerts} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
