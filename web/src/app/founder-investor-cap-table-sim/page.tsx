import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Math.round(Number(n)).toLocaleString("en-IN");
}
function fmtInr(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (v >= 1e7) return `₹${(v / 1e7).toFixed(2)} Cr`;
  if (v >= 1e5) return `₹${(v / 1e5).toFixed(2)} L`;
  return `₹${Math.round(v).toLocaleString("en-IN")}`;
}
function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return `${Number(n).toFixed(2)}%`;
}
function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  try { return new Date(s).toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" }); } catch { return s; }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpi: any = {};
  let scenarios: any[] = [];
  let trajectory: any[] = [];
  let safeImpact: any[] = [];
  let esop: any[] = [];
  let valGrid: any[] = [];

  try {
    const r = await sb.rpc("founder_cap_table_kpi_snapshot");
    kpi = (r.data && r.data[0]) || {};
  } catch { kpi = {}; }
  try {
    const r = await sb.rpc("founder_cap_table_scenarios_list");
    scenarios = r.data || [];
  } catch { scenarios = []; }
  try {
    const r = await sb.rpc("founder_cap_table_founder_trajectory");
    trajectory = r.data || [];
  } catch { trajectory = []; }
  try {
    const r = await sb.rpc("founder_cap_table_safe_impact");
    safeImpact = r.data || [];
  } catch { safeImpact = []; }
  try {
    const r = await sb.rpc("founder_cap_table_esop_refresh");
    esop = r.data || [];
  } catch { esop = []; }
  try {
    const r = await sb.rpc("founder_cap_table_valuation_grid");
    valGrid = r.data || [];
  } catch { valGrid = []; }

  const kpis: Kpi[] = [
    { label: "Total scenarios", value: fmtInt(kpi.total_scenarios) },
    { label: "Pending review", value: fmtInt(kpi.pending_review_count) },
    { label: "Approved", value: fmtInt(kpi.approved_count) },
    { label: "Rejected", value: fmtInt(kpi.rejected_count) },
    { label: "Archived", value: fmtInt(kpi.archived_count) },
    { label: "Series A modelled", value: fmtInt(kpi.series_a_count) },
    { label: "Series B modelled", value: fmtInt(kpi.series_b_count) },
    { label: "Bridge rounds", value: fmtInt(kpi.bridge_count) },
    { label: "SAFE-only rounds", value: fmtInt(kpi.safe_only_count) },
    { label: "Avg pre-money", value: fmtInr(kpi.avg_pre_money_inr) },
    { label: "Max pre-money", value: fmtInr(kpi.max_pre_money_inr) },
    { label: "Avg new money", value: fmtInr(kpi.avg_new_money_inr) },
    { label: "Total SAFE principal", value: fmtInr(kpi.total_safe_principal_inr) },
    { label: "Avg ESOP refresh", value: fmtPct(kpi.avg_esop_refresh_pct) },
    { label: "Latest scenario", value: fmtDate(kpi.latest_scenario_at) },
    { label: "Scenarios last 30d", value: fmtInt(kpi.scenarios_last_30d) },
  ];

  const scenarioCols: Column<any>[] = [
    { key: "scenario_name", header: "Scenario", render: (r: any) => r.scenario_name ?? "—" },
    { key: "round_type", header: "Round", render: (r: any) => r.round_type ?? "—" },
    { key: "pre_money_valuation_inr", header: "Pre-money", render: (r: any) => fmtInr(r.pre_money_valuation_inr) },
    { key: "new_money_raised_inr", header: "New money", render: (r: any) => fmtInr(r.new_money_raised_inr) },
    { key: "post_money_inr", header: "Post-money", render: (r: any) => fmtInr(r.post_money_inr) },
    { key: "new_investor_pct", header: "New inv %", render: (r: any) => fmtPct(r.new_investor_pct) },
    { key: "esop_refresh_pct", header: "ESOP refresh", render: (r: any) => fmtPct(r.esop_refresh_pct) },
    { key: "founder_review_status", header: "Status", render: (r: any) => r.founder_review_status ?? "—" },
    { key: "created_at", header: "Created", render: (r: any) => fmtDate(r.created_at) },
  ];

  const trajCols: Column<any>[] = [
    { key: "scenario_name", header: "Scenario", render: (r: any) => r.scenario_name ?? "—" },
    { key: "round_type", header: "Round", render: (r: any) => r.round_type ?? "—" },
    { key: "founder_pre_pct", header: "Founder pre %", render: (r: any) => fmtPct(r.founder_pre_pct) },
    { key: "founder_post_pct", header: "Founder post %", render: (r: any) => fmtPct(r.founder_post_pct) },
    { key: "founder_dilution_pct", header: "Dilution %", render: (r: any) => fmtPct(r.founder_dilution_pct) },
  ];

  const safeCols: Column<any>[] = [
    { key: "scenario_name", header: "Scenario", render: (r: any) => r.scenario_name ?? "—" },
    { key: "safe_principal_inr", header: "SAFE principal", render: (r: any) => fmtInr(r.safe_principal_inr) },
    { key: "safe_discount_pct", header: "Discount", render: (r: any) => fmtPct(r.safe_discount_pct) },
    { key: "safe_valuation_cap_inr", header: "Val cap", render: (r: any) => fmtInr(r.safe_valuation_cap_inr) },
    { key: "effective_conversion_price", header: "Conv. price", render: (r: any) => fmtInr(r.effective_conversion_price) },
    { key: "safe_post_shares", header: "SAFE shares", render: (r: any) => fmtInt(r.safe_post_shares) },
  ];

  const esopCols: Column<any>[] = [
    { key: "scenario_name", header: "Scenario", render: (r: any) => r.scenario_name ?? "—" },
    { key: "esop_refresh_pct", header: "Refresh %", render: (r: any) => fmtPct(r.esop_refresh_pct) },
    { key: "esop_pre_pool_pct", header: "Pool pre %", render: (r: any) => fmtPct(r.esop_pre_pool_pct) },
    { key: "esop_post_pool_pct", header: "Pool post %", render: (r: any) => fmtPct(r.esop_post_pool_pct) },
    { key: "esop_new_shares", header: "New ESOP shares", render: (r: any) => fmtInt(r.esop_new_shares) },
  ];

  const gridCols: Column<any>[] = [
    { key: "round_type", header: "Round", render: (r: any) => r.round_type ?? "—" },
    { key: "scenario_count", header: "Count", render: (r: any) => fmtInt(r.scenario_count) },
    { key: "min_pre_money", header: "Min pre", render: (r: any) => fmtInr(r.min_pre_money) },
    { key: "max_pre_money", header: "Max pre", render: (r: any) => fmtInr(r.max_pre_money) },
    { key: "avg_pre_money", header: "Avg pre", render: (r: any) => fmtInr(r.avg_pre_money) },
    { key: "avg_new_money", header: "Avg new", render: (r: any) => fmtInr(r.avg_new_money) },
    { key: "avg_post_money", header: "Avg post", render: (r: any) => fmtInr(r.avg_post_money) },
  ];

  return (
    <div style={{ padding: 24, display: "flex", flexDirection: "column", gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Investor cap-table simulator</h1>
        <p style={{ color: "#666", marginTop: 4 }}>
          Model Series A/B at multiple valuations {">"} simulate SAFE conversion {"<"} run ESOP refresh sizing. Founder reviews each scenario.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Dilution KPIs</h2>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 12 }}>
          {kpis.map((k) => (
            <div key={k.label} style={{ border: "1px solid #e5e7eb", borderRadius: 8, padding: 12, background: "#fff" }}>
              <div style={{ fontSize: 11, color: "#666", textTransform: "uppercase", letterSpacing: 0.4 }}>{k.label}</div>
              <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Scenarios</h2>
        <DataTable columns={scenarioCols} rows={scenarios} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Founder ownership trajectory</h2>
        <DataTable columns={trajCols} rows={trajectory} rowKey={(r: any) => r.scenario_id} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>SAFE conversion impact</h2>
        <DataTable columns={safeCols} rows={safeImpact} rowKey={(r: any) => r.scenario_id} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>ESOP refresh sizing</h2>
        <DataTable columns={esopCols} rows={esop} rowKey={(r: any) => r.scenario_id} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Valuation grid by round type</h2>
        <DataTable columns={gridCols} rows={valGrid} rowKey={(r: any) => r.round_type} />
      </section>
    </div>
  );
}
