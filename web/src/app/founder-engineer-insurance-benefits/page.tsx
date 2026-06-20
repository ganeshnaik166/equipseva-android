import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type SummaryRow = {
  total_policies: number;
  active_policies: number;
  expired_policies: number;
  cancelled_policies: number;
  lapsed_policies: number;
  renewed_policies: number;
  expiring_in_30d: number;
  unique_engineers_covered: number;
  total_sum_assured_rupees: number;
  total_premium_paid_rupees: number;
  company_paid_premium_rupees: number;
  total_claims: number;
  claims_paid: number;
  claims_pending: number;
  total_approved_payout_rupees: number;
  policies_created_30d: number;
};

type PolicyRow = {
  id: string;
  engineer_user_id: string;
  policy_kind: string;
  policy_number: string;
  insurer_company: string;
  sum_assured_rupees: number;
  premium_paid_rupees: number;
  premium_payer: string;
  policy_start_date: string;
  policy_end_date: string;
  status: string;
  created_at: string;
};

type ClaimRow = {
  id: string;
  policy_id: string;
  policy_number: string;
  engineer_user_id: string;
  claim_kind: string;
  claimed_amount_rupees: number;
  approved_amount_rupees: number;
  claim_status: string;
  submitted_at: string;
  approved_at: string | null;
  paid_at: string | null;
  notes: string | null;
};

type ExpiringRow = {
  id: string;
  engineer_user_id: string;
  policy_kind: string;
  policy_number: string;
  insurer_company: string;
  sum_assured_rupees: number;
  policy_end_date: string;
  days_until_expiry: number;
};

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, policiesRes, claimsRes, expiringRes] = await Promise.all([
    supabase.rpc("founder_engineer_insurance_summary"),
    supabase.rpc("founder_engineer_insurance_policies_recent", { p_limit: 50 }),
    supabase.rpc("founder_engineer_insurance_claims_recent", { p_limit: 30 }),
    supabase.rpc("founder_engineer_insurance_expiring_soon"),
  ]);

  const s: SummaryRow = (summaryRes.data?.[0] as SummaryRow) ?? {
    total_policies: 0, active_policies: 0, expired_policies: 0,
    cancelled_policies: 0, lapsed_policies: 0, renewed_policies: 0,
    expiring_in_30d: 0, unique_engineers_covered: 0,
    total_sum_assured_rupees: 0, total_premium_paid_rupees: 0,
    company_paid_premium_rupees: 0, total_claims: 0,
    claims_paid: 0, claims_pending: 0,
    total_approved_payout_rupees: 0, policies_created_30d: 0,
  };
  const policies: PolicyRow[] = (policiesRes.data as PolicyRow[]) ?? [];
  const claims: ClaimRow[] = (claimsRes.data as ClaimRow[]) ?? [];
  const expiring: ExpiringRow[] = (expiringRes.data as ExpiringRow[]) ?? [];

  const cards = [
    { label: "Total policies", value: formatNumber(s.total_policies) },
    { label: "Active", value: formatNumber(s.active_policies) },
    { label: "Expired", value: formatNumber(s.expired_policies) },
    { label: "Cancelled", value: formatNumber(s.cancelled_policies) },
    { label: "Lapsed", value: formatNumber(s.lapsed_policies) },
    { label: "Renewed", value: formatNumber(s.renewed_policies) },
    { label: "Expiring in 30d", value: formatNumber(s.expiring_in_30d) },
    { label: "Engineers covered", value: formatNumber(s.unique_engineers_covered) },
    { label: "Sum assured (active) Rs", value: formatNumber(s.total_sum_assured_rupees) },
    { label: "Premium paid total Rs", value: formatNumber(s.total_premium_paid_rupees) },
    { label: "Company-paid premium Rs", value: formatNumber(s.company_paid_premium_rupees) },
    { label: "Total claims", value: formatNumber(s.total_claims) },
    { label: "Claims paid", value: formatNumber(s.claims_paid) },
    { label: "Claims pending", value: formatNumber(s.claims_pending) },
    { label: "Approved payout Rs", value: formatNumber(s.total_approved_payout_rupees) },
    { label: "Policies (30d)", value: formatNumber(s.policies_created_30d) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Insurance & Benefits</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track engineer health, accident, life, indemnity and equipment-damage cover; monitor claims pipeline and renewal exposure.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">KPI summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {cards.map((c) => (
            <div key={c.label} className="rounded-lg border border-gray-200 bg-white p-4">
              <div className="text-xs uppercase tracking-wide text-gray-500">{c.label}</div>
              <div className="mt-1 text-xl font-semibold tabular-nums">{c.value}</div>
            </div>
          ))}
        </div>
      </section>

      {expiring.length > 0 && (
        <section className="rounded-lg border border-amber-300 bg-amber-50 p-4">
          <h2 className="text-base font-semibold text-amber-900 mb-2">Expiring within 30 days ({expiring.length})</h2>
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="text-amber-900">
                <tr>
                  <th className="px-2 py-1 text-left">Policy #</th>
                  <th className="px-2 py-1 text-left">Kind</th>
                  <th className="px-2 py-1 text-left">Insurer</th>
                  <th className="px-2 py-1 text-right">Sum assured</th>
                  <th className="px-2 py-1 text-left">End date</th>
                  <th className="px-2 py-1 text-right">Days left</th>
                </tr>
              </thead>
              <tbody>
                {expiring.map((e) => (
                  <tr key={e.id} className="border-t border-amber-200">
                    <td className="px-2 py-1 font-mono text-xs">{e.policy_number}</td>
                    <td className="px-2 py-1">{e.policy_kind}</td>
                    <td className="px-2 py-1">{e.insurer_company}</td>
                    <td className="px-2 py-1 text-right tabular-nums">{formatNumber(e.sum_assured_rupees)}</td>
                    <td className="px-2 py-1">{e.policy_end_date}</td>
                    <td className="px-2 py-1 text-right tabular-nums font-semibold">{e.days_until_expiry}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-3">Policy ledger (latest 50)</h2>
        <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-gray-600">
              <tr>
                <th className="px-3 py-2 text-left">Policy #</th>
                <th className="px-3 py-2 text-left">Kind</th>
                <th className="px-3 py-2 text-left">Insurer</th>
                <th className="px-3 py-2 text-right">Sum assured</th>
                <th className="px-3 py-2 text-right">Premium</th>
                <th className="px-3 py-2 text-left">Payer</th>
                <th className="px-3 py-2 text-left">Start</th>
                <th className="px-3 py-2 text-left">End</th>
                <th className="px-3 py-2 text-left">Status</th>
              </tr>
            </thead>
            <tbody>
              {policies.length === 0 ? (
                <tr><td colSpan={9} className="px-3 py-4 text-gray-500 text-center">No policies registered yet.</td></tr>
              ) : policies.map((p) => (
                <tr key={p.id} className="border-t border-gray-100">
                  <td className="px-3 py-2 font-mono text-xs">{p.policy_number}</td>
                  <td className="px-3 py-2">{p.policy_kind}</td>
                  <td className="px-3 py-2">{p.insurer_company}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(p.sum_assured_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(p.premium_paid_rupees)}</td>
                  <td className="px-3 py-2">{p.premium_payer}</td>
                  <td className="px-3 py-2 text-gray-600">{p.policy_start_date}</td>
                  <td className="px-3 py-2 text-gray-600">{p.policy_end_date}</td>
                  <td className="px-3 py-2">{p.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Claims feed (latest 30)</h2>
        <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-gray-600">
              <tr>
                <th className="px-3 py-2 text-left">Policy #</th>
                <th className="px-3 py-2 text-left">Kind</th>
                <th className="px-3 py-2 text-right">Claimed</th>
                <th className="px-3 py-2 text-right">Approved</th>
                <th className="px-3 py-2 text-left">Status</th>
                <th className="px-3 py-2 text-left">Submitted</th>
                <th className="px-3 py-2 text-left">Approved at</th>
                <th className="px-3 py-2 text-left">Paid at</th>
              </tr>
            </thead>
            <tbody>
              {claims.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-4 text-gray-500 text-center">No claims filed yet.</td></tr>
              ) : claims.map((c) => (
                <tr key={c.id} className="border-t border-gray-100">
                  <td className="px-3 py-2 font-mono text-xs">{c.policy_number}</td>
                  <td className="px-3 py-2">{c.claim_kind}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(c.claimed_amount_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(c.approved_amount_rupees)}</td>
                  <td className="px-3 py-2">{c.claim_status}</td>
                  <td className="px-3 py-2 text-gray-500">{new Date(c.submitted_at).toLocaleString()}</td>
                  <td className="px-3 py-2 text-gray-500">{c.approved_at ? new Date(c.approved_at).toLocaleString() : "—"}</td>
                  <td className="px-3 py-2 text-gray-500">{c.paid_at ? new Date(c.paid_at).toLocaleString() : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
