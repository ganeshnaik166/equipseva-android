import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type Kpi = { label: string; value: string };

function inr(n: number | null | undefined): string {
  if (n == null) return "—";
  return "₹ " + Number(n).toLocaleString("en-IN");
}

export default async function FounderStrategicBetsLedgerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = {};
  let bets: any[] = [];
  let byQuarter: any[] = [];
  let recipes: any[] = [];
  let byCategory: any[] = [];
  let watchlist: any[] = [];
  let gradeDist: any[] = [];

  try {
    const r = await sb.rpc("founder_bets_overview");
    overview = (r.data as any) ?? {};
  } catch {
    overview = {};
  }
  try {
    const r = await sb.rpc("founder_bets_list");
    bets = (r.data as any[]) ?? [];
  } catch {
    bets = [];
  }
  try {
    const r = await sb.rpc("founder_bets_by_quarter");
    byQuarter = (r.data as any[]) ?? [];
  } catch {
    byQuarter = [];
  }
  try {
    const r = await sb.rpc("founder_bets_winning_recipes");
    recipes = (r.data as any[]) ?? [];
  } catch {
    recipes = [];
  }
  try {
    const r = await sb.rpc("founder_bets_by_category");
    byCategory = (r.data as any[]) ?? [];
  } catch {
    byCategory = [];
  }
  try {
    const r = await sb.rpc("founder_bets_live_watchlist");
    watchlist = (r.data as any[]) ?? [];
  } catch {
    watchlist = [];
  }
  try {
    const r = await sb.rpc("founder_bets_grade_distribution");
    gradeDist = (r.data as any[]) ?? [];
  } catch {
    gradeDist = [];
  }

  const kpis: Kpi[] = [
    { label: "Total Bets", value: String(overview.total_bets ?? 0) },
    { label: "Live", value: String(overview.live_bets ?? 0) },
    { label: "Graded", value: String(overview.graded_bets ?? 0) },
    { label: "Cancelled", value: String(overview.cancelled_bets ?? 0) },
    { label: "Wins", value: String(overview.wins ?? 0) },
    { label: "Losses", value: String(overview.losses ?? 0) },
    { label: "Draws", value: String(overview.draws ?? 0) },
    { label: "Win Rate", value: (overview.win_rate_pct ?? 0) + "%" },
    { label: "Total Cost", value: inr(overview.total_cost_rupees) },
    { label: "Expected Payoff", value: inr(overview.expected_payoff_rupees) },
    { label: "Actual Payoff", value: inr(overview.actual_payoff_rupees) },
    { label: "Portfolio ROI", value: (overview.roi_pct ?? 0) + "%" },
    { label: "Avg Confidence", value: (overview.avg_confidence ?? 0) + "%" },
    { label: "Bet-the-Company", value: String(overview.bet_the_company_count ?? 0) },
    { label: "Quarters Tracked", value: String(overview.quarters_tracked ?? 0) },
    { label: "Milestone Hit Rate", value: (overview.milestone_hit_rate_pct ?? 0) + "%" },
  ];

  const betsCols: Column<any>[] = [
    { key: "quarter_label", header: "Quarter", render: (r: any) => r.quarter_label ?? "—" },
    { key: "bet_title", header: "Bet", render: (r: any) => r.bet_title ?? "—" },
    { key: "bet_category", header: "Category", render: (r: any) => r.bet_category ?? "—" },
    { key: "risk_level", header: "Risk", render: (r: any) => r.risk_level ?? "—" },
    { key: "confidence_pct", header: "Conf %", render: (r: any) => String(r.confidence_pct ?? "—") },
    { key: "cost_rupees", header: "Cost", render: (r: any) => inr(r.cost_rupees) },
    { key: "expected_payoff_rupees", header: "Expected", render: (r: any) => inr(r.expected_payoff_rupees) },
    { key: "status", header: "Status", render: (r: any) => r.status ?? "—" },
    { key: "grade", header: "Grade", render: (r: any) => r.grade ?? "—" },
    { key: "actual_payoff_rupees", header: "Actual", render: (r: any) => inr(r.actual_payoff_rupees) },
  ];

  const quarterCols: Column<any>[] = [
    { key: "quarter_label", header: "Quarter", render: (r: any) => r.quarter_label ?? "—" },
    { key: "bet_count", header: "Bets", render: (r: any) => String(r.bet_count ?? 0) },
    { key: "wins", header: "Wins", render: (r: any) => String(r.wins ?? 0) },
    { key: "losses", header: "Losses", render: (r: any) => String(r.losses ?? 0) },
    { key: "win_rate_pct", header: "Win %", render: (r: any) => (r.win_rate_pct ?? 0) + "%" },
    { key: "total_cost", header: "Cost", render: (r: any) => inr(r.total_cost) },
    { key: "total_expected", header: "Expected", render: (r: any) => inr(r.total_expected) },
    { key: "total_actual", header: "Actual", render: (r: any) => inr(r.total_actual) },
  ];

  const recipeCols: Column<any>[] = [
    { key: "recipe_tag", header: "Recipe Tag", render: (r: any) => r.recipe_tag ?? "—" },
    { key: "win_count", header: "Wins", render: (r: any) => String(r.win_count ?? 0) },
    { key: "loss_count", header: "Losses", render: (r: any) => String(r.loss_count ?? 0) },
    { key: "draw_count", header: "Draws", render: (r: any) => String(r.draw_count ?? 0) },
    { key: "total_appearances", header: "Appearances", render: (r: any) => String(r.total_appearances ?? 0) },
    { key: "win_rate_pct", header: "Win Rate", render: (r: any) => (r.win_rate_pct ?? 0) + "%" },
    { key: "avg_roi_pct", header: "Avg ROI", render: (r: any) => (r.avg_roi_pct ?? 0) + "%" },
  ];

  const categoryCols: Column<any>[] = [
    { key: "bet_category", header: "Category", render: (r: any) => r.bet_category ?? "—" },
    { key: "bet_count", header: "Bets", render: (r: any) => String(r.bet_count ?? 0) },
    { key: "wins", header: "Wins", render: (r: any) => String(r.wins ?? 0) },
    { key: "losses", header: "Losses", render: (r: any) => String(r.losses ?? 0) },
    { key: "win_rate_pct", header: "Win %", render: (r: any) => (r.win_rate_pct ?? 0) + "%" },
    { key: "total_cost", header: "Cost", render: (r: any) => inr(r.total_cost) },
    { key: "total_actual_payoff", header: "Actual", render: (r: any) => inr(r.total_actual_payoff) },
    { key: "roi_pct", header: "ROI", render: (r: any) => (r.roi_pct ?? 0) + "%" },
  ];

  const watchlistCols: Column<any>[] = [
    { key: "bet_title", header: "Live Bet", render: (r: any) => r.bet_title ?? "—" },
    { key: "quarter_label", header: "Quarter", render: (r: any) => r.quarter_label ?? "—" },
    { key: "risk_level", header: "Risk", render: (r: any) => r.risk_level ?? "—" },
    { key: "confidence_pct", header: "Conf %", render: (r: any) => String(r.confidence_pct ?? "—") },
    { key: "age_days", header: "Age (days)", render: (r: any) => String(r.age_days ?? "—") },
    { key: "milestones_hit", header: "Milestones", render: (r: any) => (r.milestones_hit ?? 0) + " / " + (r.milestones_total ?? 0) },
    { key: "next_milestone", header: "Next Checkpoint", render: (r: any) => r.next_milestone ?? "—" },
    { key: "next_due_date", header: "Due", render: (r: any) => r.next_due_date ?? "—" },
  ];

  return (
    <div style={{ padding: 24, fontFamily: "system-ui, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
        Founder Strategic Bets Ledger
      </h1>
      <p style={{ color: "#666", marginBottom: 20 }}>
        Quarterly strategic bets {">"} cost, expected payoff, risk, confidence {">"} ex-post grading (win / loss / draw) {">"} winning-recipe tag analysis.
      </p>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12, marginBottom: 28 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: "1px solid #e5e7eb", borderRadius: 8, padding: 12, background: "#fff" }}>
            <div style={{ fontSize: 11, color: "#6b7280", textTransform: "uppercase", letterSpacing: 0.5 }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: "20px 0 8px" }}>Live Bet Watchlist</h2>
      <DataTable columns={watchlistCols} rows={watchlist} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: "24px 0 8px" }}>All Bets (latest first)</h2>
      <DataTable columns={betsCols} rows={bets} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: "24px 0 8px" }}>By Quarter</h2>
      <DataTable columns={quarterCols} rows={byQuarter} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: "24px 0 8px" }}>Winning-Bet Recipe Tags</h2>
      <DataTable columns={recipeCols} rows={recipes} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: "24px 0 8px" }}>By Category & Risk Distribution</h2>
      <DataTable columns={categoryCols} rows={byCategory} rowKey={(r: any) => r.id} />

      <h3 style={{ fontSize: 14, fontWeight: 600, margin: "16px 0 6px", color: "#374151" }}>Grade × Risk</h3>
      <ul style={{ fontSize: 13, color: "#374151", lineHeight: 1.6 }}>
        {gradeDist.map((g: any) => (
          <li key={g.id}>
            {g.risk_level ?? "—"}: {g.wins ?? 0} W / {g.losses ?? 0} L / {g.draws ?? 0} D — {(g.win_rate_pct ?? 0)}% win rate, avg conf {(g.avg_confidence ?? 0)}%
          </li>
        ))}
      </ul>
    </div>
  );
}
