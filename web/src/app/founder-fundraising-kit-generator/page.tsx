import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_kits: number;
  draft_kits: number;
  final_kits: number;
  published_kits: number;
  sent_kits: number;
  retired_kits: number;
  target_raise_rupees: number;
  total_shares: number;
  active_shares: number;
  expired_shares: number;
  revoked_shares: number;
  total_views: number;
  kits_last_30d: number;
  shares_last_30d: number;
  latest_kit_label: string;
};

type KitRow = {
  id: string;
  kit_label: string;
  kit_kind: string;
  target_raise_rupees: number | null;
  current_status: string;
  generated_at: string | null;
  published_at: string | null;
  created_at: string;
};

type ShareRow = {
  id: string;
  kit_id: string;
  kit_label: string | null;
  investor_firm_name: string;
  investor_partner_email: string | null;
  view_count: number;
  max_views: number;
  status: string;
  sent_at: string | null;
  expires_at: string;
  created_at: string;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" });
  } catch {
    return s;
  }
}

function rupees(n: number | null | undefined): string {
  if (n == null) return "—";
  return "Rs " + formatNumber(Number(n));
}

export default async function FounderFundraisingKitGeneratorPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, kitsRes, sharesRes] = await Promise.all([
    supabase.rpc("founder_fundraising_kit_summary"),
    supabase.rpc("founder_fundraising_kits_recent", { p_limit: 20 }),
    supabase.rpc("founder_fundraising_kit_shares_recent", { p_limit: 50 }),
  ]);

  const summary: Summary = (summaryRes.data as Summary) ?? {
    total_kits: 0, draft_kits: 0, final_kits: 0, published_kits: 0, sent_kits: 0, retired_kits: 0,
    target_raise_rupees: 0, total_shares: 0, active_shares: 0, expired_shares: 0, revoked_shares: 0,
    total_views: 0, kits_last_30d: 0, shares_last_30d: 0, latest_kit_label: "—",
  };

  const kits: KitRow[] = (kitsRes.data as KitRow[]) ?? [];
  const shares: ShareRow[] = (sharesRes.data as ShareRow[]) ?? [];

  const cards: Array<{ label: string; value: string; hint?: string }> = [
    { label: "Total kits", value: formatNumber(summary.total_kits) },
    { label: "Draft kits", value: formatNumber(summary.draft_kits), hint: "in progress" },
    { label: "Final kits", value: formatNumber(summary.final_kits) },
    { label: "Published kits", value: formatNumber(summary.published_kits) },
    { label: "Sent kits", value: formatNumber(summary.sent_kits) },
    { label: "Retired kits", value: formatNumber(summary.retired_kits) },
    { label: "Target raise (active)", value: rupees(summary.target_raise_rupees), hint: "final+published+sent" },
    { label: "Total shares", value: formatNumber(summary.total_shares) },
    { label: "Active shares", value: formatNumber(summary.active_shares) },
    { label: "Expired shares", value: formatNumber(summary.expired_shares) },
    { label: "Revoked shares", value: formatNumber(summary.revoked_shares) },
    { label: "Total investor views", value: formatNumber(summary.total_views) },
    { label: "Kits last 30d", value: formatNumber(summary.kits_last_30d) },
    { label: "Shares last 30d", value: formatNumber(summary.shares_last_30d) },
    { label: "Latest kit label", value: summary.latest_kit_label, hint: "most recent" },
  ];

  return (
    <main style={{ padding: "24px", fontFamily: "system-ui, -apple-system, sans-serif", maxWidth: 1400, margin: "0 auto" }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Founder fundraising kit generator</h1>
        <p style={{ color: "#666", marginTop: 6, fontSize: 14 }}>
          One-click investor pack auto-generator. Snapshot KPIs at create-time, publish, grant time-boxed shares to firms.
        </p>
      </header>

      <section
        aria-label="kpi-cards"
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))",
          gap: 12,
          marginBottom: 32,
        }}
      >
        {cards.map((c) => (
          <div
            key={c.label}
            style={{
              border: "1px solid #e5e7eb",
              borderRadius: 8,
              padding: 14,
              background: "#fff",
            }}
          >
            <div style={{ fontSize: 12, color: "#6b7280", textTransform: "uppercase", letterSpacing: 0.5 }}>
              {c.label}
            </div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6, color: "#111827" }}>{c.value}</div>
            {c.hint ? <div style={{ fontSize: 11, color: "#9ca3af", marginTop: 4 }}>{c.hint}</div> : null}
          </div>
        ))}
      </section>

      <section aria-label="kits" style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>
          Recent kits {"<"}= 20
        </h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 8, background: "#fff" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                <th style={th}>Kit label</th>
                <th style={th}>Kind</th>
                <th style={th}>Target raise</th>
                <th style={th}>Status</th>
                <th style={th}>Generated</th>
                <th style={th}>Published</th>
                <th style={th}>Created</th>
              </tr>
            </thead>
            <tbody>
              {kits.length === 0 ? (
                <tr>
                  <td colSpan={7} style={{ ...td, textAlign: "center", color: "#9ca3af", padding: 24 }}>
                    No kits yet. Use the RPCs to generate one.
                  </td>
                </tr>
              ) : (
                kits.map((k) => (
                  <tr key={k.id} style={{ borderTop: "1px solid #f3f4f6" }}>
                    <td style={td}><strong>{k.kit_label}</strong></td>
                    <td style={td}>{k.kit_kind}</td>
                    <td style={td}>{rupees(k.target_raise_rupees)}</td>
                    <td style={td}>
                      <span style={statusPill(k.current_status)}>{k.current_status}</span>
                    </td>
                    <td style={td}>{fmtDate(k.generated_at)}</td>
                    <td style={td}>{fmtDate(k.published_at)}</td>
                    <td style={td}>{fmtDate(k.created_at)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section aria-label="shares">
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>
          Recent investor shares {"<"}= 50
        </h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 8, background: "#fff" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                <th style={th}>Firm</th>
                <th style={th}>Partner email</th>
                <th style={th}>Kit</th>
                <th style={th}>Views</th>
                <th style={th}>Status</th>
                <th style={th}>Sent</th>
                <th style={th}>Expires</th>
                <th style={th}>Created</th>
              </tr>
            </thead>
            <tbody>
              {shares.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ ...td, textAlign: "center", color: "#9ca3af", padding: 24 }}>
                    No shares granted yet.
                  </td>
                </tr>
              ) : (
                shares.map((s) => (
                  <tr key={s.id} style={{ borderTop: "1px solid #f3f4f6" }}>
                    <td style={td}><strong>{s.investor_firm_name}</strong></td>
                    <td style={td}>{s.investor_partner_email ?? "—"}</td>
                    <td style={td}>{s.kit_label ?? "—"}</td>
                    <td style={td}>{formatNumber(s.view_count)} / {formatNumber(s.max_views)}</td>
                    <td style={td}>
                      <span style={statusPill(s.status)}>{s.status}</span>
                    </td>
                    <td style={td}>{fmtDate(s.sent_at)}</td>
                    <td style={td}>{fmtDate(s.expires_at)}</td>
                    <td style={td}>{fmtDate(s.created_at)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <footer style={{ marginTop: 32, fontSize: 12, color: "#9ca3af" }}>
        r1406 - founder fundraising kit generator - 8 RPCs, 2 tables, founder-gated.
      </footer>
    </main>
  );
}

const th: React.CSSProperties = {
  textAlign: "left",
  padding: "10px 12px",
  fontWeight: 600,
  color: "#374151",
  fontSize: 12,
  textTransform: "uppercase",
  letterSpacing: 0.4,
  whiteSpace: "nowrap",
};

const td: React.CSSProperties = {
  padding: "10px 12px",
  color: "#111827",
  verticalAlign: "top",
  whiteSpace: "nowrap",
};

function statusPill(status: string): React.CSSProperties {
  const m: Record<string, { bg: string; fg: string }> = {
    draft: { bg: "#f3f4f6", fg: "#374151" },
    final: { bg: "#dbeafe", fg: "#1e40af" },
    published: { bg: "#dcfce7", fg: "#166534" },
    sent: { bg: "#fef3c7", fg: "#92400e" },
    retired: { bg: "#fee2e2", fg: "#991b1b" },
    active: { bg: "#dcfce7", fg: "#166534" },
    expired: { bg: "#f3f4f6", fg: "#6b7280" },
    exhausted: { bg: "#fef3c7", fg: "#92400e" },
    revoked: { bg: "#fee2e2", fg: "#991b1b" },
  };
  const c = m[status] ?? { bg: "#f3f4f6", fg: "#374151" };
  return {
    background: c.bg,
    color: c.fg,
    padding: "2px 8px",
    borderRadius: 999,
    fontSize: 11,
    fontWeight: 600,
    display: "inline-block",
  };
}
