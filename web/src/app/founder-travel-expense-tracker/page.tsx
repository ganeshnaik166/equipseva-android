import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_categories: number;
  active_categories: number;
  total_monthly_budget_rupees: number;
  total_claims_lifetime: number;
  total_claims_30d: number;
  total_claims_pending: number;
  total_claims_approved: number;
  total_claims_reimbursed: number;
  total_claims_rejected: number;
  total_claims_disputed: number;
  total_spent_lifetime_rupees: number;
  total_spent_30d_rupees: number;
  total_reimbursed_rupees: number;
  total_outstanding_rupees: number;
  distinct_claimants: number;
  top_category_label: string | null;
  generated_at: string;
};

type Category = {
  id: string;
  category_label: string;
  category_kind: string;
  monthly_budget_rupees: number;
  is_active: boolean;
  spent_30d_rupees: number;
  claims_30d: number;
  updated_at: string;
};

type Claim = {
  id: string;
  category_label: string | null;
  claimant_email: string | null;
  expense_date: string;
  amount_rupees: number;
  description: string | null;
  status: string;
  gst_invoiced: boolean;
  submitted_at: string;
  reimbursed_at: string | null;
  founder_response: string | null;
};

type Pending = {
  id: string;
  category_label: string | null;
  claimant_email: string | null;
  expense_date: string;
  amount_rupees: number;
  description: string | null;
  submitted_at: string;
  days_waiting: number;
};

const STATUS_COLOR: Record<string, string> = {
  submitted: "#a16207",
  approved: "#0369a1",
  reimbursed: "#065f46",
  rejected: "#991b1b",
  disputed: "#7c3aed",
};

const fmtRs = (n: number) => `Rs ${formatNumber(Math.round(n || 0))}`;

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [sumR, catR, claimsR, pendR] = await Promise.all([
    sb.rpc("founder_travel_expense_summary"),
    sb.rpc("founder_travel_expense_categories_recent"),
    sb.rpc("founder_travel_expense_claims_recent"),
    sb.rpc("founder_travel_expense_claims_pending"),
  ]);

  const s: Summary = (Array.isArray(sumR.data) ? sumR.data[0] : sumR.data) ?? {
    total_categories: 0, active_categories: 0, total_monthly_budget_rupees: 0,
    total_claims_lifetime: 0, total_claims_30d: 0, total_claims_pending: 0,
    total_claims_approved: 0, total_claims_reimbursed: 0, total_claims_rejected: 0,
    total_claims_disputed: 0, total_spent_lifetime_rupees: 0, total_spent_30d_rupees: 0,
    total_reimbursed_rupees: 0, total_outstanding_rupees: 0, distinct_claimants: 0,
    top_category_label: null, generated_at: new Date().toISOString(),
  };
  const cats: Category[] = (catR.data as Category[]) ?? [];
  const claims: Claim[] = (claimsR.data as Claim[]) ?? [];
  const pending: Pending[] = (pendR.data as Pending[]) ?? [];

  const kpis: Array<[string, string | number, string?]> = [
    ["Total categories", formatNumber(s.total_categories)],
    ["Active categories", formatNumber(s.active_categories)],
    ["Monthly budget", fmtRs(s.total_monthly_budget_rupees)],
    ["Claims lifetime", formatNumber(s.total_claims_lifetime)],
    ["Claims 30d", formatNumber(s.total_claims_30d)],
    ["Pending review", formatNumber(s.total_claims_pending), s.total_claims_pending > 0 ? "#a16207" : "#374151"],
    ["Approved", formatNumber(s.total_claims_approved), "#0369a1"],
    ["Reimbursed", formatNumber(s.total_claims_reimbursed), "#065f46"],
    ["Rejected", formatNumber(s.total_claims_rejected), s.total_claims_rejected > 0 ? "#991b1b" : "#374151"],
    ["Disputed", formatNumber(s.total_claims_disputed), s.total_claims_disputed > 0 ? "#7c3aed" : "#374151"],
    ["Spent lifetime", fmtRs(s.total_spent_lifetime_rupees)],
    ["Spent 30d", fmtRs(s.total_spent_30d_rupees)],
    ["Reimbursed amount", fmtRs(s.total_reimbursed_rupees), "#065f46"],
    ["Outstanding", fmtRs(s.total_outstanding_rupees), s.total_outstanding_rupees > 0 ? "#a16207" : "#374151"],
    ["Distinct claimants", formatNumber(s.distinct_claimants)],
    ["Top category", s.top_category_label ?? "-"],
  ];

  const pendingCount = pending.length;

  return (
    <main style={{ maxWidth: 1200, margin: "0 auto", padding: 24, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Travel + expense tracker</h1>
      <p style={{ color: "#666", marginBottom: 20 }}>
        Founder team travel + business expense claims. {s.active_categories} active categories,{" "}
        {s.distinct_claimants} claimants, outstanding {fmtRs(s.total_outstanding_rupees)} - generated{" "}
        {new Date(s.generated_at).toLocaleString()}
      </p>

      {pendingCount > 0 && (
        <div style={{ background: "#fef3c7", border: "1px solid #fcd34d", borderRadius: 10, padding: 14, marginBottom: 20 }}>
          <div style={{ fontWeight: 700, color: "#92400e", fontSize: 14 }}>
            {pendingCount} claim{pendingCount === 1 ? "" : "s"} awaiting review
          </div>
          <div style={{ color: "#92400e", fontSize: 12, marginTop: 4 }}>
            Approve, reimburse, or reject below to keep claimants unblocked.
          </div>
        </div>
      )}

      <section style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 12, marginBottom: 28 }}>
        {kpis.map(([label, value, color]) => (
          <div key={label as string} style={{ background: "#fff", border: "1px solid #e5e7eb", borderRadius: 10, padding: 14 }}>
            <div style={{ color: "#6b7280", fontSize: 12, fontWeight: 500 }}>{label}</div>
            <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4, color: (color as string) ?? "#111827" }}>{value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Pending claims ({pending.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Category", "Claimant", "Expense date", "Amount", "Description", "Submitted", "Days waiting"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {pending.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No pending claims - inbox clean.</td></tr>
              ) : pending.map((p) => (
                <tr key={p.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                  <td style={{ padding: "10px 12px", fontWeight: 500 }}>{p.category_label ?? "-"}</td>
                  <td style={{ padding: "10px 12px", color: "#374151" }}>{p.claimant_email ?? "-"}</td>
                  <td style={{ padding: "10px 12px" }}>{p.expense_date}</td>
                  <td style={{ padding: "10px 12px", fontWeight: 600 }}>{fmtRs(p.amount_rupees)}</td>
                  <td style={{ padding: "10px 12px", color: "#6b7280" }}>{p.description ?? "-"}</td>
                  <td style={{ padding: "10px 12px" }}>{new Date(p.submitted_at).toLocaleDateString()}</td>
                  <td style={{ padding: "10px 12px", color: p.days_waiting >= 7 ? "#991b1b" : p.days_waiting >= 3 ? "#a16207" : "#374151", fontWeight: 600 }}>{p.days_waiting}d</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Categories ({cats.length})</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e5e7eb", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead style={{ background: "#f9fafb" }}>
              <tr>
                {["Label", "Kind", "Monthly budget", "Active", "Spent 30d", "Claims 30d", "Updated"].map((h) => (
                  <th key={h} style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#374151", borderBottom: "1px solid #e5e7eb" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {cats.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No categories yet - seed via insert into founder_travel_expense_categories.</td></tr>
              ) : cats.map((c) => {
                const overBudget = c.monthly_budget_rupees > 0 && c.spent_30d_rupees > c.monthly_budget_rupees;
                return (
                  <tr key={c.id} style={{ borderTop: "1px solid #f1f5f9" }}>
                    <td style={{ padding: "10px 12px", fontWeight: 500 }}>{c.category_label}</td>
                    <td style={{ padding: "10px 12px", color: "#6b7280" }}>{c.category_kind}</td>
                    <td style={{ padding: "10px 12px" }}>{fmtRs(c.monthly_budget_rupees)}</td>
                    <td style={{ padding: "10px 12px", color: c.is_active ? "#065f46" : "#9ca3af", fontWeight: 600 }}>{c.is_active ? "yes" : "no"}</td>
                    <td style={{ padding: "10px 12px", color: overBudget ? "#991b1b" : "#374151", fontWeight: overBudget ? 700 : 500 }}>{fmtRs(c.spent_30d_rupees)}{overBudget ? " over" : ""}</td>
                    <td style={{ padding: "10px 12px" }}>{formatNumber(c.claims_30d)}</td>
                    <td style={{ padding: "10px 12px", color: "#6b7280" }}>{new Date(c.updated_at).toLocaleDateString()}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Claims feed ({claims.length})</h2>
        <div style={{ border: "1px solid #e5e7eb", borderRadius: 10, background: "#fff" }}>
          {claims.length === 0 ? (
            <div style={{ padding: 16, color: "#9ca3af", textAlign: "center" }}>No claims submitted yet.</div>
          ) : claims.map((c, i) => (
            <div key={c.id} style={{ display: "flex", justifyContent: "space-between", gap: 12, padding: "12px 14px", borderTop: i === 0 ? "none" : "1px solid #f1f5f9", flexWrap: "wrap" }}>
              <div style={{ display: "flex", gap: 10, alignItems: "center", flex: 1, minWidth: 0, flexWrap: "wrap" }}>
                <span style={{ background: STATUS_COLOR[c.status] ?? "#6b7280", color: "#fff", padding: "2px 8px", borderRadius: 12, fontSize: 11, fontWeight: 600, whiteSpace: "nowrap" }}>{c.status}</span>
                <span style={{ fontWeight: 600 }}>{fmtRs(c.amount_rupees)}</span>
                <span style={{ color: "#374151" }}>{c.category_label ?? "uncategorised"}</span>
                <span style={{ color: "#6b7280", fontSize: 12 }}>- {c.claimant_email ?? "?"}</span>
                {c.gst_invoiced && <span style={{ background: "#dbeafe", color: "#1e40af", padding: "1px 6px", borderRadius: 8, fontSize: 10, fontWeight: 600 }}>GST</span>}
                {c.description && <span style={{ color: "#6b7280", fontSize: 12 }}>- {c.description}</span>}
              </div>
              <div style={{ color: "#6b7280", fontSize: 12, textAlign: "right" }}>
                <div>exp {c.expense_date}</div>
                <div>sub {new Date(c.submitted_at).toLocaleDateString()}</div>
                {c.reimbursed_at && <div style={{ color: "#065f46" }}>paid {new Date(c.reimbursed_at).toLocaleDateString()}</div>}
              </div>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
