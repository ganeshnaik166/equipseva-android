import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_accounts: number;
  strategic_count: number;
  enterprise_count: number;
  growth_count: number;
  priority_count: number;
  watch_count: number;
  green_count: number;
  yellow_count: number;
  orange_count: number;
  red_count: number;
  overdue_check_in_count: number;
  due_within_14d_count: number;
  total_touchpoints_90d: number;
  unique_accounts_touched_90d: number;
  total_annual_revenue_rupees: number;
  accounts_with_csm_count: number;
};

type Account = {
  id: string;
  hospital_user_id: string;
  tier_band: string;
  assigned_csm_user_id: string | null;
  quarterly_check_in_cadence_days: number;
  last_check_in_at: string | null;
  next_check_in_due_at: string | null;
  account_health_band: string;
  executive_sponsor_at_hospital: string | null;
  annual_revenue_rupees: number | null;
  escalation_path: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

type Touchpoint = {
  id: string;
  account_id: string;
  touchpoint_kind: string;
  description: string | null;
  sentiment: string | null;
  happened_at: string;
  performed_by: string | null;
  created_at: string;
};

const tierBadge: Record<string, string> = {
  strategic: "#7c3aed",
  enterprise: "#0ea5e9",
  growth: "#16a34a",
  priority: "#f59e0b",
  watch: "#dc2626",
};

const healthBadge: Record<string, string> = {
  green: "#16a34a",
  yellow: "#facc15",
  orange: "#f97316",
  red: "#dc2626",
};

const sentimentBadge: Record<string, string> = {
  very_positive: "#16a34a",
  positive: "#65a30d",
  neutral: "#64748b",
  cool: "#f59e0b",
  negative: "#dc2626",
};

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [sumRes, acctRes, tpRes, overdueRes] = await Promise.all([
    supabase.rpc("founder_vip_hospital_summary"),
    supabase.rpc("founder_vip_hospital_accounts_recent"),
    supabase.rpc("founder_vip_hospital_touchpoints_recent", { p_account_id: null }),
    supabase.rpc("founder_vip_hospital_overdue_check_ins"),
  ]);

  const s: Summary = (sumRes.data?.[0] as Summary) ?? {
    total_accounts: 0, strategic_count: 0, enterprise_count: 0, growth_count: 0,
    priority_count: 0, watch_count: 0, green_count: 0, yellow_count: 0,
    orange_count: 0, red_count: 0, overdue_check_in_count: 0, due_within_14d_count: 0,
    total_touchpoints_90d: 0, unique_accounts_touched_90d: 0,
    total_annual_revenue_rupees: 0, accounts_with_csm_count: 0,
  };
  const accounts: Account[] = (acctRes.data as Account[]) ?? [];
  const touchpoints: Touchpoint[] = (tpRes.data as Touchpoint[]) ?? [];
  const overdue: Account[] = (overdueRes.data as Account[]) ?? [];

  const cards: Array<{ label: string; value: string; tone?: string }> = [
    { label: "Total VIP accounts", value: formatNumber(s.total_accounts) },
    { label: "Strategic", value: formatNumber(s.strategic_count) },
    { label: "Enterprise", value: formatNumber(s.enterprise_count) },
    { label: "Growth", value: formatNumber(s.growth_count) },
    { label: "Priority", value: formatNumber(s.priority_count) },
    { label: "Watch", value: formatNumber(s.watch_count), tone: "#dc2626" },
    { label: "Green health", value: formatNumber(s.green_count), tone: "#16a34a" },
    { label: "Yellow health", value: formatNumber(s.yellow_count), tone: "#facc15" },
    { label: "Orange health", value: formatNumber(s.orange_count), tone: "#f97316" },
    { label: "Red health", value: formatNumber(s.red_count), tone: "#dc2626" },
    { label: "Overdue check-ins", value: formatNumber(s.overdue_check_in_count), tone: "#dc2626" },
    { label: "Due in 14d", value: formatNumber(s.due_within_14d_count), tone: "#f59e0b" },
    { label: "Touchpoints (90d)", value: formatNumber(s.total_touchpoints_90d) },
    { label: "Accts touched (90d)", value: formatNumber(s.unique_accounts_touched_90d) },
    { label: "Annual revenue (₹)", value: formatNumber(Number(s.total_annual_revenue_rupees ?? 0)) },
    { label: "Has CSM assigned", value: formatNumber(s.accounts_with_csm_count) },
  ];

  return (
    <main style={{ maxWidth: 1280, margin: "0 auto", padding: 24, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>VIP Hospital Account Manager</h1>
      <p style={{ color: "#64748b", marginBottom: 20, fontSize: 14 }}>
        Strategic hospital portfolio. Tier banding, CSM coverage, quarterly cadence, executive sponsor map, health-band escalation.
      </p>

      {overdue.length > 0 && (
        <div style={{ marginBottom: 20, padding: 14, border: "1px solid #fecaca", background: "#fef2f2", borderRadius: 10 }}>
          <div style={{ fontWeight: 700, color: "#991b1b", marginBottom: 8, fontSize: 14 }}>
            {overdue.length} overdue check-in{overdue.length === 1 ? "" : "s"}
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 4, fontSize: 12, color: "#7f1d1d" }}>
            {overdue.slice(0, 6).map((o) => (
              <div key={o.id}>
                <span style={{ fontFamily: "ui-monospace, monospace" }}>{o.hospital_user_id.slice(0, 8)}</span>
                <span style={{ marginLeft: 8 }}>{o.tier_band}</span>
                <span style={{ marginLeft: 8 }}>due {o.next_check_in_due_at ?? "—"}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(170px, 1fr))", gap: 10, marginBottom: 28 }}>
        {cards.map((c) => (
          <div key={c.label} style={{ border: "1px solid #e2e8f0", borderRadius: 10, padding: 12, background: "#fff" }}>
            <div style={{ fontSize: 11, color: "#64748b", textTransform: "uppercase", letterSpacing: 0.4 }}>{c.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4, color: c.tone ?? "#0f172a" }}>{c.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 10 }}>Account ledger</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e2e8f0", borderRadius: 10, background: "#fff" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f8fafc", textAlign: "left" }}>
              <tr>
                <th style={{ padding: 10 }}>Hospital</th>
                <th style={{ padding: 10 }}>Tier</th>
                <th style={{ padding: 10 }}>Health</th>
                <th style={{ padding: 10 }}>Sponsor</th>
                <th style={{ padding: 10 }}>Cadence</th>
                <th style={{ padding: 10 }}>Last check-in</th>
                <th style={{ padding: 10 }}>Next due</th>
                <th style={{ padding: 10, textAlign: "right" }}>Annual ₹</th>
              </tr>
            </thead>
            <tbody>
              {accounts.length === 0 && (
                <tr><td colSpan={8} style={{ padding: 16, textAlign: "center", color: "#94a3b8" }}>No VIP accounts registered yet.</td></tr>
              )}
              {accounts.map((a) => (
                <tr key={a.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={{ padding: 10, fontFamily: "ui-monospace, monospace", fontSize: 12 }}>{a.hospital_user_id.slice(0, 12)}</td>
                  <td style={{ padding: 10 }}>
                    <span style={{ display: "inline-block", padding: "2px 8px", borderRadius: 999, fontSize: 11, color: "#fff", background: tierBadge[a.tier_band] ?? "#64748b" }}>
                      {a.tier_band}
                    </span>
                  </td>
                  <td style={{ padding: 10 }}>
                    <span style={{ display: "inline-block", padding: "2px 8px", borderRadius: 999, fontSize: 11, color: "#0f172a", background: healthBadge[a.account_health_band] ?? "#cbd5e1" }}>
                      {a.account_health_band}
                    </span>
                  </td>
                  <td style={{ padding: 10, fontSize: 12 }}>{a.executive_sponsor_at_hospital ?? "—"}</td>
                  <td style={{ padding: 10 }}>{a.quarterly_check_in_cadence_days}d</td>
                  <td style={{ padding: 10, fontSize: 12 }}>{a.last_check_in_at ? new Date(a.last_check_in_at).toLocaleDateString() : "—"}</td>
                  <td style={{ padding: 10, fontSize: 12, color: a.next_check_in_due_at && new Date(a.next_check_in_due_at) < new Date() ? "#dc2626" : "#0f172a" }}>
                    {a.next_check_in_due_at ?? "—"}
                  </td>
                  <td style={{ padding: 10, textAlign: "right", fontVariantNumeric: "tabular-nums" }}>
                    {a.annual_revenue_rupees != null ? formatNumber(Number(a.annual_revenue_rupees)) : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 10 }}>Touchpoint feed</h2>
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {touchpoints.length === 0 && (
            <div style={{ padding: 14, color: "#94a3b8", fontSize: 13, border: "1px dashed #e2e8f0", borderRadius: 10, textAlign: "center" }}>
              No touchpoints logged yet.
            </div>
          )}
          {touchpoints.map((t) => (
            <div key={t.id} style={{ border: "1px solid #e2e8f0", borderRadius: 10, padding: 12, background: "#fff" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 6 }}>
                <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                  <span style={{ fontSize: 12, fontWeight: 600 }}>{t.touchpoint_kind.replaceAll("_", " ")}</span>
                  {t.sentiment && (
                    <span style={{ display: "inline-block", padding: "2px 8px", borderRadius: 999, fontSize: 11, color: "#fff", background: sentimentBadge[t.sentiment] ?? "#64748b" }}>
                      {t.sentiment.replaceAll("_", " ")}
                    </span>
                  )}
                </div>
                <span style={{ fontSize: 12, color: "#64748b" }}>{new Date(t.happened_at).toLocaleString()}</span>
              </div>
              <div style={{ fontSize: 13, color: "#334155" }}>{t.description ?? <em style={{ color: "#94a3b8" }}>no description</em>}</div>
              <div style={{ fontSize: 11, color: "#94a3b8", marginTop: 6, fontFamily: "ui-monospace, monospace" }}>account {t.account_id.slice(0, 8)}</div>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
