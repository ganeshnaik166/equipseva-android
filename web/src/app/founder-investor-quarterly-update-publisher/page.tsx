import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_updates: number;
  draft_count: number;
  reviewed_count: number;
  published_count: number;
  sent_count: number;
  latest_quarter: string | null;
  latest_status: string | null;
  latest_mrr_eop_rupees: number | null;
  total_recipients: number;
  unique_firms: number;
  opened_count: number;
  replied_count: number;
  opt_out_count: number;
  open_rate_pct: number;
};

type Update = {
  id: string;
  quarter_label: string;
  period_start: string;
  period_end: string;
  status: string;
  headline: string | null;
  key_wins_summary: string | null;
  key_misses_summary: string | null;
  asks_for_help: string | null;
  mrr_eop_rupees: number | null;
  mrr_delta_qoq_pct: number | null;
  active_amcs: number | null;
  active_engineers: number | null;
  total_gmv_quarter_rupees: number | null;
  total_payouts_quarter_rupees: number | null;
  code_red_count_quarter: number | null;
  dispute_count_quarter: number | null;
  drafted_at: string | null;
  reviewed_at: string | null;
  published_at: string | null;
  sent_at: string | null;
  created_at: string;
};

type Recipient = {
  id: string;
  update_id: string;
  investor_firm_name: string;
  investor_partner_email: string;
  sent_at: string | null;
  opened_at: string | null;
  replied_at: string | null;
  opt_out_at: string | null;
  created_at: string;
};

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [{ data: sumRows }, { data: updates }, { data: recipients }] = await Promise.all([
    sb.rpc("founder_investor_quarterly_update_summary"),
    sb.rpc("founder_investor_quarterly_updates_recent"),
    sb.rpc("founder_investor_quarterly_recipients_recent", { p_update_id: null }),
  ]);

  const s: Summary = (Array.isArray(sumRows) ? sumRows[0] : sumRows) ?? {
    total_updates: 0, draft_count: 0, reviewed_count: 0, published_count: 0, sent_count: 0,
    latest_quarter: null, latest_status: null, latest_mrr_eop_rupees: null,
    total_recipients: 0, unique_firms: 0, opened_count: 0, replied_count: 0, opt_out_count: 0, open_rate_pct: 0,
  };
  const us: Update[] = (updates as Update[]) ?? [];
  const rs: Recipient[] = (recipients as Recipient[]) ?? [];
  const latest = us[0];

  return (
    <main style={{ maxWidth: 1180, margin: "0 auto", padding: 24, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Investor Quarterly Update Publisher</h1>
      <p style={{ color: "#666", marginBottom: 20 }}>Auto-published investor quarterly updates · KPI snapshots · recipient tracking</p>

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 12, marginBottom: 28 }}>
        {[
          ["Total updates", formatNumber(s.total_updates)],
          ["Draft", formatNumber(s.draft_count)],
          ["Reviewed", formatNumber(s.reviewed_count)],
          ["Published", formatNumber(s.published_count)],
          ["Sent", formatNumber(s.sent_count)],
          ["Latest quarter", s.latest_quarter ?? "—"],
          ["Latest status", s.latest_status ?? "—"],
          ["Latest MRR EoP", s.latest_mrr_eop_rupees != null ? `₹${formatNumber(s.latest_mrr_eop_rupees)}` : "—"],
          ["Total recipients", formatNumber(s.total_recipients)],
          ["Unique firms", formatNumber(s.unique_firms)],
          ["Opened", formatNumber(s.opened_count)],
          ["Replied", formatNumber(s.replied_count)],
          ["Opt-outs", formatNumber(s.opt_out_count)],
          ["Open rate", `${s.open_rate_pct ?? 0}%`],
        ].map(([label, value]) => (
          <div key={label as string} style={{ background: "#fff", border: "1px solid #e5e7eb", borderRadius: 10, padding: 14 }}>
            <div style={{ color: "#6b7280", fontSize: 12, fontWeight: 500 }}>{label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Latest update</h2>
        {!latest ? (
          <div style={{ color: "#999", padding: 14, border: "1px dashed #e5e7eb", borderRadius: 10 }}>No updates drafted yet.</div>
        ) : (
          <div style={{ border: "1px solid #e5e7eb", borderRadius: 10, padding: 16, background: "#fff" }}>
            <div style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 8 }}>
              <div>
                <div style={{ fontSize: 20, fontWeight: 700 }}>{latest.quarter_label}</div>
                <div style={{ color: "#6b7280", fontSize: 13 }}>
                  {latest.period_start} → {latest.period_end} · status: <strong>{latest.status}</strong>
                </div>
              </div>
              <div style={{ color: "#6b7280", fontSize: 12 }}>
                drafted {latest.drafted_at?.slice(0,10) ?? "—"} · published {latest.published_at?.slice(0,10) ?? "—"}
              </div>
            </div>
            {latest.headline && <p style={{ marginTop: 12, fontSize: 15 }}>{latest.headline}</p>}
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))", gap: 8, marginTop: 14 }}>
              {[
                ["MRR EoP", latest.mrr_eop_rupees != null ? `₹${formatNumber(latest.mrr_eop_rupees)}` : "—"],
                ["QoQ %", latest.mrr_delta_qoq_pct != null ? `${latest.mrr_delta_qoq_pct}%` : "—"],
                ["Active AMCs", formatNumber(latest.active_amcs ?? 0)],
                ["Engineers", formatNumber(latest.active_engineers ?? 0)],
                ["GMV qtr", latest.total_gmv_quarter_rupees != null ? `₹${formatNumber(latest.total_gmv_quarter_rupees)}` : "—"],
                ["Payouts qtr", latest.total_payouts_quarter_rupees != null ? `₹${formatNumber(latest.total_payouts_quarter_rupees)}` : "—"],
                ["Code Red qtr", formatNumber(latest.code_red_count_quarter ?? 0)],
                ["Disputes qtr", formatNumber(latest.dispute_count_quarter ?? 0)],
              ].map(([l, v]) => (
                <div key={l as string} style={{ background: "#f9fafb", borderRadius: 8, padding: 10 }}>
                  <div style={{ fontSize: 11, color: "#6b7280" }}>{l}</div>
                  <div style={{ fontSize: 15, fontWeight: 600 }}>{v}</div>
                </div>
              ))}
            </div>
            {latest.key_wins_summary && (
              <div style={{ marginTop: 14 }}>
                <div style={{ fontWeight: 600, fontSize: 13, color: "#065f46" }}>Key wins</div>
                <p style={{ marginTop: 4, fontSize: 14, whiteSpace: "pre-wrap" }}>{latest.key_wins_summary}</p>
              </div>
            )}
            {latest.key_misses_summary && (
              <div style={{ marginTop: 12 }}>
                <div style={{ fontWeight: 600, fontSize: 13, color: "#991b1b" }}>Key misses</div>
                <p style={{ marginTop: 4, fontSize: 14, whiteSpace: "pre-wrap" }}>{latest.key_misses_summary}</p>
              </div>
            )}
            {latest.asks_for_help && (
              <div style={{ marginTop: 12 }}>
                <div style={{ fontWeight: 600, fontSize: 13, color: "#1e3a8a" }}>Asks for help</div>
                <p style={{ marginTop: 4, fontSize: 14, whiteSpace: "pre-wrap" }}>{latest.asks_for_help}</p>
              </div>
            )}
          </div>
        )}
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recipients ({rs.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Firm", "Partner email", "Sent", "Opened", "Replied", "Opt-out", "Added"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rs.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No recipients added yet.</td></tr>
              ) : rs.map((r) => (
                <tr key={r.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={{ padding: "10px 12px", fontWeight: 500 }}>{r.investor_firm_name}</td>
                  <td style={{ padding: "10px 12px", color: "#374151" }}>{r.investor_partner_email}</td>
                  <td style={{ padding: "10px 12px" }}>{r.sent_at?.slice(0,10) ?? "—"}</td>
                  <td style={{ padding: "10px 12px" }}>{r.opened_at?.slice(0,10) ?? "—"}</td>
                  <td style={{ padding: "10px 12px" }}>{r.replied_at?.slice(0,10) ?? "—"}</td>
                  <td style={{ padding: "10px 12px" }}>{r.opt_out_at?.slice(0,10) ?? "—"}</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280" }}>{r.created_at.slice(0,10)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
