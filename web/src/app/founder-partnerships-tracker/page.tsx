import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder Partnerships Tracker · EquipSeva Ops" };
export const dynamic = "force-dynamic";

type Summary = {
  total_partnerships: number;
  identified_count: number;
  intro_count: number;
  nda_count: number;
  negotiation_count: number;
  active_count: number;
  dormant_count: number;
  dissolved_count: number;
  conversion_pct_to_active: number;
  total_revenue_attributed_rupees: number;
  top_partner_by_revenue: string | null;
  top_kind: string | null;
  top_kind_count: number;
  recent_activities_30d_count: number;
};

type Partnership = {
  id: string;
  partner_name: string;
  partner_kind: string | null;
  partnership_status: string;
  integration_kind: string | null;
  primary_contact_name: string | null;
  primary_contact_email: string | null;
  revenue_share_pct: number | null;
  total_revenue_attributed_rupees: number | null;
  first_contact_at: string | null;
  signed_at: string | null;
  updated_at: string;
};

type Activity = {
  id: string;
  partnership_id: string;
  partner_name: string;
  activity_kind: string;
  description: string;
  happened_at: string;
};

function statusBadge(s: string) {
  const palette: Record<string, string> = {
    identified: "#e5e7eb",
    intro_call: "#bfdbfe",
    nda_signed: "#fde68a",
    term_negotiation: "#fdba74",
    active: "#86efac",
    dormant: "#d1d5db",
    dissolved: "#fca5a5",
  };
  return (
    <span style={{ background: palette[s] ?? "#e5e7eb", padding: "2px 8px", borderRadius: 12, fontSize: 12, fontWeight: 600 }}>
      {s}
    </span>
  );
}

function kindTag(k: string | null) {
  if (!k) return <span style={{ color: "#9ca3af" }}>—</span>;
  return (
    <span style={{ background: "#f3f4f6", padding: "2px 8px", borderRadius: 8, fontSize: 11, fontFamily: "ui-monospace,monospace" }}>
      {k}
    </span>
  );
}

function Card({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div style={{ border: "1px solid #e5e7eb", borderRadius: 12, padding: 16, background: "#fff" }}>
      <div style={{ fontSize: 11, textTransform: "uppercase", color: "#6b7280", letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>{value}</div>
      {sub && <div style={{ fontSize: 11, color: "#9ca3af", marginTop: 4 }}>{sub}</div>}
    </div>
  );
}

export default async function FounderPartnershipsTrackerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: summaryRows }, { data: partnerships }, { data: activities }] = await Promise.all([
    supabase.rpc("founder_partnerships_summary"),
    supabase.rpc("founder_partnerships_recent", { p_status: null, p_limit: 50 }),
    supabase.rpc("founder_partnership_activities_recent", { p_partnership_id: null, p_limit: 50 }),
  ]);

  const s: Summary = (summaryRows?.[0] as Summary) ?? ({
    total_partnerships: 0, identified_count: 0, intro_count: 0, nda_count: 0,
    negotiation_count: 0, active_count: 0, dormant_count: 0, dissolved_count: 0,
    conversion_pct_to_active: 0, total_revenue_attributed_rupees: 0,
    top_partner_by_revenue: null, top_kind: null, top_kind_count: 0,
    recent_activities_30d_count: 0,
  });
  const rows: Partnership[] = (partnerships as Partnership[]) ?? [];
  const acts: Activity[] = (activities as Activity[]) ?? [];

  return (
    <main style={{ maxWidth: 1280, margin: "0 auto", padding: "32px 24px", fontFamily: "system-ui,-apple-system,Segoe UI,Roboto,sans-serif" }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 800, margin: 0 }}>Founder Partnerships Tracker</h1>
        <p style={{ color: "#6b7280", marginTop: 6 }}>
          Strategic partnerships · joint ventures · technology integrations · channel & distribution. Pipeline from
          identified {"→"} active, with revenue attribution and an activity ledger per partner.
        </p>
      </header>

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 12, marginBottom: 28 }}>
        <Card label="Total partnerships" value={formatNumber(s.total_partnerships)} />
        <Card label="Identified" value={formatNumber(s.identified_count)} />
        <Card label="Intro call" value={formatNumber(s.intro_count)} />
        <Card label="NDA signed" value={formatNumber(s.nda_count)} />
        <Card label="Term negotiation" value={formatNumber(s.negotiation_count)} />
        <Card label="Active" value={formatNumber(s.active_count)} sub="signed + live" />
        <Card label="Dormant" value={formatNumber(s.dormant_count)} />
        <Card label="Dissolved" value={formatNumber(s.dissolved_count)} />
        <Card label="Conv % to active" value={`${formatNumber(s.conversion_pct_to_active)}%`} />
        <Card label="Total revenue attributed" value={`₹${formatNumber(s.total_revenue_attributed_rupees)}`} />
        <Card label="Top partner by revenue" value={s.top_partner_by_revenue ?? "—"} />
        <Card label="Top kind" value={s.top_kind ?? "—"} sub={`${formatNumber(s.top_kind_count)} partners`} />
        <Card label="Top kind count" value={formatNumber(s.top_kind_count)} />
        <Card label="Activities · 30d" value={formatNumber(s.recent_activities_30d_count)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Partnership pipeline · 50 most recent</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 12, background: "#fff" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead>
              <tr style={{ background: "#f9fafb", textAlign: "left" }}>
                <th style={{ padding: 10 }}>Partner</th>
                <th style={{ padding: 10 }}>Kind</th>
                <th style={{ padding: 10 }}>Status</th>
                <th style={{ padding: 10 }}>Integration</th>
                <th style={{ padding: 10 }}>Contact</th>
                <th style={{ padding: 10 }}>Rev share</th>
                <th style={{ padding: 10 }}>Attributed ₹</th>
                <th style={{ padding: 10 }}>Signed</th>
                <th style={{ padding: 10 }}>Updated</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 && (
                <tr><td colSpan={9} style={{ padding: 24, textAlign: "center", color: "#9ca3af" }}>No partnerships registered yet.</td></tr>
              )}
              {rows.map((r) => (
                <tr key={r.id} style={{ borderTop: "1px solid #f3f4f6" }}>
                  <td style={{ padding: 10, fontWeight: 600 }}>{r.partner_name}</td>
                  <td style={{ padding: 10 }}>{kindTag(r.partner_kind)}</td>
                  <td style={{ padding: 10 }}>{statusBadge(r.partnership_status)}</td>
                  <td style={{ padding: 10 }}>{kindTag(r.integration_kind)}</td>
                  <td style={{ padding: 10, color: "#6b7280" }}>
                    {r.primary_contact_name ?? "—"}{r.primary_contact_email ? ` · ${r.primary_contact_email}` : ""}
                  </td>
                  <td style={{ padding: 10 }}>{r.revenue_share_pct != null ? `${formatNumber(r.revenue_share_pct)}%` : "—"}</td>
                  <td style={{ padding: 10 }}>{r.total_revenue_attributed_rupees ? `₹${formatNumber(r.total_revenue_attributed_rupees)}` : "—"}</td>
                  <td style={{ padding: 10, color: "#6b7280" }}>{r.signed_at ?? "—"}</td>
                  <td style={{ padding: 10, color: "#9ca3af", fontSize: 12 }}>{new Date(r.updated_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Recent activity feed · 50 events</h2>
        <div style={{ border: "1px solid #e5e7eb", borderRadius: 12, background: "#fff" }}>
          {acts.length === 0 && <div style={{ padding: 24, textAlign: "center", color: "#9ca3af" }}>No activity logged yet.</div>}
          {acts.map((a) => (
            <div key={a.id} style={{ padding: 12, borderTop: "1px solid #f3f4f6", display: "flex", gap: 12, alignItems: "flex-start" }}>
              <div style={{ minWidth: 110, fontSize: 11, color: "#9ca3af" }}>{new Date(a.happened_at).toLocaleString()}</div>
              <div style={{ minWidth: 120 }}>{kindTag(a.activity_kind)}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 600, fontSize: 13 }}>{a.partner_name}</div>
                <div style={{ fontSize: 13, color: "#374151" }}>{a.description}</div>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section style={{ background: "#fffbeb", border: "1px solid #fde68a", borderRadius: 12, padding: 16, fontSize: 13, color: "#78350f" }}>
        <b>Partnership discipline.</b> Every conversation gets logged; status only advances when a real artifact exists
        (intro_call {"→"} call notes; nda_signed {"→"} signed PDF; term_negotiation {"→"} term sheet; active {"→"} executed agreement +
        first integration commit or first attributed rupee). Dormant {">"} 90 days with no activity auto-flags for cleanup.
        Revenue attribution is the only North Star — pipeline volume is vanity unless rupees flow.
      </section>
    </main>
  );
}
