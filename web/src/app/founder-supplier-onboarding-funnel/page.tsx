import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder Supplier Onboarding Funnel · EquipSeva Ops" };
export const dynamic = "force-dynamic";

type Summary = {
  total_candidates: number;
  identified_count: number;
  first_call_count: number;
  sample_request_count: number;
  quote_review_count: number;
  bond_negotiation_count: number;
  onboarded_count: number;
  rejected_count: number;
  churned_count: number;
  conversion_pct: number;
  total_bond_value_rupees: number;
  top_category: string | null;
  top_category_count: number;
  median_days_identified_to_onboarded: number;
  churn_rate_pct: number;
};

type Candidate = {
  id: string;
  supplier_company_name: string;
  supplier_contact_name: string | null;
  supplier_contact_phone: string | null;
  supplier_contact_email: string | null;
  supplier_category: string | null;
  funnel_stage: string;
  expected_bond_amount_rupees: number | null;
  expected_categories: string[] | null;
  identified_at: string;
  first_call_at: string | null;
  sample_received_at: string | null;
  bond_signed_at: string | null;
  onboarded_at: string | null;
  churned_at: string | null;
  rejection_reason: string | null;
  notes: string | null;
  updated_at: string;
};

function stageBadge(s: string) {
  const palette: Record<string, string> = {
    identified: "#e5e7eb",
    first_call: "#bfdbfe",
    sample_request: "#c7d2fe",
    quote_review: "#fde68a",
    bond_negotiation: "#fdba74",
    onboarded_active: "#86efac",
    rejected: "#fca5a5",
    churned: "#d1d5db",
  };
  return (
    <span style={{ background: palette[s] ?? "#e5e7eb", padding: "2px 8px", borderRadius: 12, fontSize: 12, fontWeight: 600 }}>
      {s}
    </span>
  );
}

function categoryTag(k: string | null) {
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

export default async function FounderSupplierOnboardingFunnelPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: summaryRows }, { data: candidates }] = await Promise.all([
    supabase.rpc("founder_supplier_onboarding_funnel_summary"),
    supabase.rpc("founder_supplier_onboarding_candidates_recent", { p_status: null, p_limit: 80 }),
  ]);

  const s: Summary = (summaryRows?.[0] as Summary) ?? ({
    total_candidates: 0, identified_count: 0, first_call_count: 0, sample_request_count: 0,
    quote_review_count: 0, bond_negotiation_count: 0, onboarded_count: 0, rejected_count: 0,
    churned_count: 0, conversion_pct: 0, total_bond_value_rupees: 0,
    top_category: null, top_category_count: 0,
    median_days_identified_to_onboarded: 0, churn_rate_pct: 0,
  });
  const rows: Candidate[] = (candidates as Candidate[]) ?? [];

  return (
    <main style={{ maxWidth: 1280, margin: "0 auto", padding: "32px 24px", fontFamily: "system-ui,-apple-system,Segoe UI,Roboto,sans-serif" }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 800, margin: 0 }}>Founder Supplier Onboarding Funnel</h1>
        <p style={{ color: "#6b7280", marginTop: 6 }}>
          Supplier-side recruit funnel · OEM parts · third-party parts · consumables · tools · calibration · training ·
          logistics. Pipeline from identified {"→"} onboarded_active, with bond value capture and stage timestamps.
        </p>
      </header>

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 12, marginBottom: 28 }}>
        <Card label="Total candidates" value={formatNumber(s.total_candidates)} />
        <Card label="Identified" value={formatNumber(s.identified_count)} sub="top of funnel" />
        <Card label="First call" value={formatNumber(s.first_call_count)} />
        <Card label="Sample request" value={formatNumber(s.sample_request_count)} />
        <Card label="Quote review" value={formatNumber(s.quote_review_count)} />
        <Card label="Bond negotiation" value={formatNumber(s.bond_negotiation_count)} />
        <Card label="Onboarded · active" value={formatNumber(s.onboarded_count)} sub="signed + live" />
        <Card label="Rejected" value={formatNumber(s.rejected_count)} />
        <Card label="Churned" value={formatNumber(s.churned_count)} sub="post-onboard drop-off" />
        <Card label="Conversion %" value={`${formatNumber(s.conversion_pct)}%`} sub="onboarded ÷ total" />
        <Card label="Total bond value" value={`₹${formatNumber(s.total_bond_value_rupees)}`} sub="active suppliers" />
        <Card label="Top category" value={s.top_category ?? "—"} sub={`${formatNumber(s.top_category_count)} suppliers`} />
        <Card label="Top category count" value={formatNumber(s.top_category_count)} />
        <Card label="Median days · onboard" value={formatNumber(s.median_days_identified_to_onboarded)} sub="identified → active" />
        <Card label="Churn rate %" value={`${formatNumber(s.churn_rate_pct)}%`} sub="churned ÷ (onboarded+churned)" />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Supplier candidate ledger · 80 most recent</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 12, background: "#fff" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead>
              <tr style={{ background: "#f9fafb", textAlign: "left" }}>
                <th style={{ padding: 10 }}>Company</th>
                <th style={{ padding: 10 }}>Category</th>
                <th style={{ padding: 10 }}>Stage</th>
                <th style={{ padding: 10 }}>Contact</th>
                <th style={{ padding: 10 }}>Expected bond ₹</th>
                <th style={{ padding: 10 }}>Identified</th>
                <th style={{ padding: 10 }}>Onboarded</th>
                <th style={{ padding: 10 }}>Rejection</th>
                <th style={{ padding: 10 }}>Updated</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 && (
                <tr><td colSpan={9} style={{ padding: 24, textAlign: "center", color: "#9ca3af" }}>No supplier candidates registered yet.</td></tr>
              )}
              {rows.map((r) => (
                <tr key={r.id} style={{ borderTop: "1px solid #f3f4f6" }}>
                  <td style={{ padding: 10, fontWeight: 600 }}>{r.supplier_company_name}</td>
                  <td style={{ padding: 10 }}>{categoryTag(r.supplier_category)}</td>
                  <td style={{ padding: 10 }}>{stageBadge(r.funnel_stage)}</td>
                  <td style={{ padding: 10, color: "#6b7280" }}>
                    {r.supplier_contact_name ?? "—"}
                    {r.supplier_contact_phone ? ` · ${r.supplier_contact_phone}` : ""}
                    {r.supplier_contact_email ? ` · ${r.supplier_contact_email}` : ""}
                  </td>
                  <td style={{ padding: 10 }}>
                    {r.expected_bond_amount_rupees != null ? `₹${formatNumber(r.expected_bond_amount_rupees)}` : "—"}
                  </td>
                  <td style={{ padding: 10, color: "#6b7280" }}>
                    {new Date(r.identified_at).toLocaleDateString()}
                  </td>
                  <td style={{ padding: 10, color: "#6b7280" }}>
                    {r.onboarded_at ? new Date(r.onboarded_at).toLocaleDateString() : "—"}
                  </td>
                  <td style={{ padding: 10, color: "#b91c1c", fontSize: 12 }}>{r.rejection_reason ?? "—"}</td>
                  <td style={{ padding: 10, color: "#9ca3af", fontSize: 12 }}>{new Date(r.updated_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ background: "#fffbeb", border: "1px solid #fde68a", borderRadius: 12, padding: 16, fontSize: 13, color: "#78350f" }}>
        <b>Supplier acquisition discipline.</b> Every candidate logged at identified · stage only advances when artifact
        exists (first_call {"→"} call notes; sample_request {"→"} sample tracking #; quote_review {"→"} quote PDF;
        bond_negotiation {"→"} term sheet; onboarded_active {"→"} executed bond + first PO routed). Bond value is the
        unlock signal — no bond means no real commitment. Churn rate {">"} 15% on the cohort means our terms are off or
        our volume promise didn{"'"}t land — escalate to founder review. Median onboarding {">"} 60 days flags a broken
        legal/finance pipeline, not a sourcing problem.
      </section>
    </main>
  );
}
