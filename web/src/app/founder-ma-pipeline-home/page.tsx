import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = {
  title: "M&A Pipeline Cockpit · EquipSeva Founder Console",
  description: "Composite M&A pipeline home — 14 KPIs + top-30 active targets sorted by priority and value.",
};

export const dynamic = "force-dynamic";

type Summary = {
  total_targets: number;
  active_pipeline_count: number;
  closed_deals_count: number;
  passed_deals_count: number;
  conversion_pct_to_closed: number;
  total_estimated_acquisition_rupees: number;
  total_closed_value_rupees: number;
  active_pipeline_value_rupees: number;
  avg_target_revenue_rupees: number;
  most_active_segment: string;
  most_active_segment_count: number;
  activities_last_30d_count: number;
  newest_target_at: string | null;
  generated_at: string;
};

type TopTarget = {
  id: string;
  target_company_name: string;
  industry_segment: string | null;
  deal_status: string | null;
  deal_priority: string | null;
  estimated_acquisition_rupees: number;
  last_activity_at: string | null;
  days_since_activity: number | null;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  if (n >= 10000000) return "Rs " + (n / 10000000).toFixed(2) + " Cr";
  if (n >= 100000) return "Rs " + (n / 100000).toFixed(2) + " L";
  return "Rs " + formatNumber(Math.round(n));
}

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleString("en-IN", {
      day: "2-digit", month: "short", year: "numeric",
      hour: "2-digit", minute: "2-digit",
    });
  } catch {
    return s;
  }
}

function priorityBadgeColor(p: string | null): string {
  const v = (p || "").toLowerCase();
  if (v === "critical") return "#7f1d1d";
  if (v === "high") return "#b91c1c";
  if (v === "medium") return "#a16207";
  if (v === "low") return "#1d4ed8";
  return "#374151";
}

export default async function FounderMaPipelineHomePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, topRes] = await Promise.all([
    supabase.rpc("founder_ma_pipeline_home_summary"),
    supabase.rpc("founder_ma_pipeline_home_top_targets", { p_limit: 30 }),
  ]);

  const summary: Summary | null = (summaryRes.data?.[0] as Summary) ?? null;
  const topTargets: TopTarget[] = (topRes.data as TopTarget[]) ?? [];

  const cards: Array<{ label: string; value: string; sub?: string }> = summary ? [
    { label: "Total targets tracked", value: formatNumber(summary.total_targets) },
    { label: "Active pipeline", value: formatNumber(summary.active_pipeline_count), sub: "status ≠ closed · passed" },
    { label: "Closed deals", value: formatNumber(summary.closed_deals_count) },
    { label: "Passed deals", value: formatNumber(summary.passed_deals_count) },
    { label: "Conversion → closed", value: summary.conversion_pct_to_closed.toFixed(2) + "%", sub: "closed / (closed + passed)" },
    { label: "Total estimated value", value: fmtRupees(summary.total_estimated_acquisition_rupees) },
    { label: "Closed deal value", value: fmtRupees(summary.total_closed_value_rupees) },
    { label: "Active pipeline value", value: fmtRupees(summary.active_pipeline_value_rupees) },
    { label: "Avg target revenue (annual)", value: fmtRupees(summary.avg_target_revenue_rupees) },
    { label: "Most active segment", value: summary.most_active_segment, sub: formatNumber(summary.most_active_segment_count) + " targets" },
    { label: "Activities (last 30d)", value: formatNumber(summary.activities_last_30d_count) },
    { label: "Newest target added", value: fmtDate(summary.newest_target_at) },
    { label: "Snapshot generated", value: fmtDate(summary.generated_at) },
    { label: "Pipeline health", value: summary.active_pipeline_count > 0 ? "Live" : "Empty", sub: summary.active_pipeline_count > 0 ? "ongoing" : "rebuild pipeline" },
  ] : [];

  return (
    <main style={{ maxWidth: 1280, margin: "0 auto", padding: "24px 20px", fontFamily: "system-ui, -apple-system, sans-serif", color: "#111827" }}>
      <header style={{ marginBottom: 20 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700, margin: 0 }}>M&A Pipeline Cockpit</h1>
        <p style={{ color: "#6b7280", marginTop: 6, fontSize: 14 }}>
          Composite founder view of every acquisition target. KPI cards aggregate value, conversion and segment focus · top-30 active targets sorted by priority then deal size.
        </p>
      </header>

      {!summary ? (
        <div style={{ padding: 16, background: "#fef2f2", border: "1px solid #fecaca", borderRadius: 8, color: "#991b1b" }}>
          Snapshot unavailable. RPC returned no rows — confirm founder_ma_targets exists and is_founder() passes.
        </div>
      ) : (
        <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: 12, marginBottom: 28 }}>
          {cards.map((c, i) => (
            <div key={i} style={{ background: "#ffffff", border: "1px solid #e5e7eb", borderRadius: 10, padding: 14, boxShadow: "0 1px 2px rgba(0,0,0,0.03)" }}>
              <div style={{ fontSize: 11, textTransform: "uppercase", letterSpacing: 0.4, color: "#6b7280", fontWeight: 600 }}>{c.label}</div>
              <div style={{ fontSize: 20, fontWeight: 700, marginTop: 6, color: "#111827" }}>{c.value}</div>
              {c.sub ? <div style={{ fontSize: 11, color: "#6b7280", marginTop: 4 }}>{c.sub}</div> : null}
            </div>
          ))}
        </section>
      )}

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 10 }}>Top {topTargets.length} active targets · priority → value</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10, background: "#ffffff" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb", textAlign: "left" }}>
              <tr>
                <th style={{ padding: "10px 12px", borderBottom: "1px solid #e5e7eb", fontWeight: 600 }}>#</th>
                <th style={{ padding: "10px 12px", borderBottom: "1px solid #e5e7eb", fontWeight: 600 }}>Target</th>
                <th style={{ padding: "10px 12px", borderBottom: "1px solid #e5e7eb", fontWeight: 600 }}>Segment</th>
                <th style={{ padding: "10px 12px", borderBottom: "1px solid #e5e7eb", fontWeight: 600 }}>Status</th>
                <th style={{ padding: "10px 12px", borderBottom: "1px solid #e5e7eb", fontWeight: 600 }}>Priority</th>
                <th style={{ padding: "10px 12px", borderBottom: "1px solid #e5e7eb", fontWeight: 600, textAlign: "right" }}>Est. value</th>
                <th style={{ padding: "10px 12px", borderBottom: "1px solid #e5e7eb", fontWeight: 600 }}>Last activity</th>
                <th style={{ padding: "10px 12px", borderBottom: "1px solid #e5e7eb", fontWeight: 600, textAlign: "right" }}>Days idle</th>
              </tr>
            </thead>
            <tbody>
              {topTargets.length === 0 ? (
                <tr><td colSpan={8} style={{ padding: 20, color: "#6b7280", textAlign: "center" }}>No active targets in pipeline.</td></tr>
              ) : topTargets.map((t, i) => (
                <tr key={t.id} style={{ borderBottom: "1px solid #f3f4f6" }}>
                  <td style={{ padding: "10px 12px", color: "#6b7280" }}>{i + 1}</td>
                  <td style={{ padding: "10px 12px", fontWeight: 600 }}>{t.target_company_name}</td>
                  <td style={{ padding: "10px 12px", color: "#374151" }}>{t.industry_segment || "—"}</td>
                  <td style={{ padding: "10px 12px", color: "#374151" }}>{t.deal_status || "—"}</td>
                  <td style={{ padding: "10px 12px" }}>
                    <span style={{ display: "inline-block", padding: "2px 8px", borderRadius: 999, background: priorityBadgeColor(t.deal_priority), color: "#ffffff", fontSize: 11, fontWeight: 600, textTransform: "uppercase" }}>
                      {t.deal_priority || "n/a"}
                    </span>
                  </td>
                  <td style={{ padding: "10px 12px", textAlign: "right", fontVariantNumeric: "tabular-nums" }}>{fmtRupees(t.estimated_acquisition_rupees)}</td>
                  <td style={{ padding: "10px 12px", color: "#374151" }}>{fmtDate(t.last_activity_at)}</td>
                  <td style={{ padding: "10px 12px", textAlign: "right", color: (t.days_since_activity ?? 0) > 14 ? "#b91c1c" : "#374151", fontVariantNumeric: "tabular-nums" }}>
                    {t.days_since_activity === null ? "—" : t.days_since_activity}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ background: "#f9fafb", border: "1px solid #e5e7eb", borderRadius: 10, padding: 16, fontSize: 13, color: "#374151", lineHeight: 1.6 }}>
        <div style={{ fontWeight: 700, color: "#111827", marginBottom: 6 }}>M&A discipline notes</div>
        <ul style={{ margin: 0, paddingLeft: 18 }}>
          <li>Targets idle {">"} 14 days are flagged red — touch them or move to passed; a stale pipeline is a false pipeline.</li>
          <li>Conversion {"<"} 25% from closed/(closed+passed) means top-of-funnel hygiene is broken — tighten qualification before sourcing more.</li>
          <li>Active-pipeline value vs. closed value indicates realism — if active {">>"} 10× closed and nothing moves, mark-to-market by re-pricing.</li>
          <li>Most-active-segment concentration is a thesis signal — confirm it matches the strategic plan, otherwise reallocate sourcing.</li>
          <li>Avg target revenue (annual) anchors deal-size sanity — outliers should be re-checked for diligence.</li>
          <li>All numbers are read-only aggregates · writes happen via the existing r1324 surfaces (target editor + activity log).</li>
        </ul>
      </section>
    </main>
  );
}
