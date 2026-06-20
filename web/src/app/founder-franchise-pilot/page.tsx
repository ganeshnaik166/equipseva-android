import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type SummaryRow = {
  total_partners: number;
  identified_count: number;
  contacted_count: number;
  dd_count: number;
  signed_count: number;
  active_count: number;
  dormant_count: number;
  dissolved_count: number;
  conversion_pct_to_active: number;
  total_franchise_fee_rupees: number;
  total_milestones: number;
  milestones_30d: number;
  top_state: string;
  top_state_partner_count: number;
};

type PartnerRow = {
  id: string;
  partner_name: string;
  partner_kind: string | null;
  state: string;
  primary_district: string | null;
  partnership_status: string;
  franchise_fee_rupees: number;
  royalty_pct: number;
  expected_hospitals_target: number;
  expected_engineers_target: number;
  signed_at: string | null;
  activated_at: string | null;
  created_at: string;
};

type MilestoneRow = {
  id: string;
  partner_id: string;
  partner_name: string | null;
  state: string | null;
  milestone_kind: string;
  description: string;
  value_rupees: number;
  achieved_at: string;
};

const STATUS_BADGE: Record<string, string> = {
  identified: 'bg-slate-100 text-slate-700',
  contacted: 'bg-blue-100 text-blue-700',
  due_diligence: 'bg-indigo-100 text-indigo-700',
  term_negotiation: 'bg-amber-100 text-amber-700',
  signed: 'bg-teal-100 text-teal-700',
  active: 'bg-emerald-100 text-emerald-700',
  dormant: 'bg-yellow-100 text-yellow-700',
  dissolved: 'bg-rose-100 text-rose-700',
};

const KIND_LABEL: Record<string, string> = {
  individual_entrepreneur: 'Individual',
  existing_biomedical_company: 'Biomed Co.',
  hospital_chain_partnership: 'Hospital Chain',
  engineering_college: 'Engg. College',
  distributor: 'Distributor',
};

const MILESTONE_LABEL: Record<string, string> = {
  hospital_onboarded: 'Hospital Onboarded',
  engineer_recruited: 'Engineer Recruited',
  training_completed: 'Training Completed',
  first_revenue_event: 'First Revenue',
  quarterly_review: 'Quarterly Review',
  contract_renewal: 'Contract Renewal',
  termination: 'Termination',
};

export default async function FounderFranchisePilotPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, partnersRes, milestonesRes] = await Promise.all([
    supabase.rpc('founder_franchise_pilot_summary'),
    supabase.rpc('founder_franchise_partners_recent', { p_status: null, p_limit: 50 }),
    supabase.rpc('founder_franchise_milestones_recent', { p_partner_id: null, p_limit: 50 }),
  ]);

  const summary: SummaryRow = (summaryRes.data?.[0] ?? {
    total_partners: 0, identified_count: 0, contacted_count: 0, dd_count: 0,
    signed_count: 0, active_count: 0, dormant_count: 0, dissolved_count: 0,
    conversion_pct_to_active: 0, total_franchise_fee_rupees: 0,
    total_milestones: 0, milestones_30d: 0, top_state: '—', top_state_partner_count: 0,
  }) as SummaryRow;

  const partners: PartnerRow[] = (partnersRes.data ?? []) as PartnerRow[];
  const milestones: MilestoneRow[] = (milestonesRes.data ?? []) as MilestoneRow[];

  const cards: Array<{ label: string; value: string; hint?: string }> = [
    { label: 'Total Partners', value: formatNumber(summary.total_partners), hint: 'all pipeline rows' },
    { label: 'Identified', value: formatNumber(summary.identified_count), hint: 'cold leads' },
    { label: 'Contacted', value: formatNumber(summary.contacted_count) },
    { label: 'Due Diligence', value: formatNumber(summary.dd_count) },
    { label: 'Signed', value: formatNumber(summary.signed_count), hint: 'contract inked' },
    { label: 'Active', value: formatNumber(summary.active_count), hint: 'currently operating' },
    { label: 'Dormant', value: formatNumber(summary.dormant_count) },
    { label: 'Dissolved', value: formatNumber(summary.dissolved_count) },
    { label: 'Conv. to Active', value: `${formatNumber(summary.conversion_pct_to_active)}%`, hint: 'identified to active' },
    { label: 'Total Fee Pool', value: `₹${formatNumber(summary.total_franchise_fee_rupees)}`, hint: 'cumulative franchise fees' },
    { label: 'Total Milestones', value: formatNumber(summary.total_milestones) },
    { label: 'Milestones (30d)', value: formatNumber(summary.milestones_30d), hint: 'last 30 days' },
    { label: 'Top State', value: summary.top_state || '—', hint: 'most partners' },
    { label: 'Top State Count', value: formatNumber(summary.top_state_partner_count) },
  ];

  return (
    <div className="mx-auto max-w-7xl px-6 py-8">
      <div className="mb-6">
        <h1 className="text-2xl font-semibold text-slate-900">Founder · Franchise Pilot</h1>
        <p className="mt-1 text-sm text-slate-600">
          State-level franchise model — partner pipeline, signed deals, milestone velocity, and conversion funnel.
        </p>
      </div>

      <div className="mb-6 rounded-lg border border-emerald-200 bg-emerald-50 p-4">
        <div className="text-xs font-semibold uppercase tracking-wide text-emerald-700">3-State Pilot Focus</div>
        <div className="mt-2 flex flex-wrap gap-2">
          <span className="rounded-md bg-white px-3 py-1 text-sm font-medium text-emerald-800 ring-1 ring-emerald-200">Telangana</span>
          <span className="rounded-md bg-white px-3 py-1 text-sm font-medium text-emerald-800 ring-1 ring-emerald-200">Karnataka</span>
          <span className="rounded-md bg-white px-3 py-1 text-sm font-medium text-emerald-800 ring-1 ring-emerald-200">Tamil Nadu</span>
        </div>
        <p className="mt-2 text-xs text-emerald-700">Pilot horizon: 12 months · target 5 partners per state · 50 hospitals per partner · 5% royalty default</p>
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-7">
        {cards.map((c) => (
          <div key={c.label} className="rounded-lg border border-slate-200 bg-white p-4">
            <div className="text-xs font-medium uppercase tracking-wide text-slate-500">{c.label}</div>
            <div className="mt-1 text-xl font-semibold text-slate-900">{c.value}</div>
            {c.hint ? <div className="mt-1 text-xs text-slate-500">{c.hint}</div> : null}
          </div>
        ))}
      </div>

      <div className="mt-8 overflow-hidden rounded-lg border border-slate-200 bg-white">
        <div className="border-b border-slate-200 px-4 py-3">
          <h2 className="text-sm font-semibold text-slate-900">Partner Ledger</h2>
          <p className="text-xs text-slate-500">Latest 50 franchise partners by recruitment timestamp.</p>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50">
              <tr className="text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                <th className="px-4 py-2">Partner</th>
                <th className="px-4 py-2">Kind</th>
                <th className="px-4 py-2">State</th>
                <th className="px-4 py-2">District</th>
                <th className="px-4 py-2">Status</th>
                <th className="px-4 py-2 text-right">Fee (₹)</th>
                <th className="px-4 py-2 text-right">Royalty</th>
                <th className="px-4 py-2 text-right">Hosp Target</th>
                <th className="px-4 py-2 text-right">Engg Target</th>
                <th className="px-4 py-2">Signed</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {partners.length === 0 ? (
                <tr>
                  <td colSpan={10} className="px-4 py-6 text-center text-sm text-slate-500">No franchise partners yet.</td>
                </tr>
              ) : partners.map((p) => (
                <tr key={p.id} className="hover:bg-slate-50">
                  <td className="px-4 py-2 font-medium text-slate-900">{p.partner_name}</td>
                  <td className="px-4 py-2 text-slate-700">{p.partner_kind ? (KIND_LABEL[p.partner_kind] ?? p.partner_kind) : '—'}</td>
                  <td className="px-4 py-2 text-slate-700">{p.state}</td>
                  <td className="px-4 py-2 text-slate-600">{p.primary_district ?? '—'}</td>
                  <td className="px-4 py-2">
                    <span className={`inline-flex rounded-md px-2 py-0.5 text-xs font-medium ${STATUS_BADGE[p.partnership_status] ?? 'bg-slate-100 text-slate-700'}`}>
                      {p.partnership_status}
                    </span>
                  </td>
                  <td className="px-4 py-2 text-right text-slate-700">{formatNumber(p.franchise_fee_rupees)}</td>
                  <td className="px-4 py-2 text-right text-slate-700">{formatNumber(p.royalty_pct)}%</td>
                  <td className="px-4 py-2 text-right text-slate-700">{formatNumber(p.expected_hospitals_target)}</td>
                  <td className="px-4 py-2 text-right text-slate-700">{formatNumber(p.expected_engineers_target)}</td>
                  <td className="px-4 py-2 text-xs text-slate-500">{p.signed_at ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="mt-8 overflow-hidden rounded-lg border border-slate-200 bg-white">
        <div className="border-b border-slate-200 px-4 py-3">
          <h2 className="text-sm font-semibold text-slate-900">Milestones Feed</h2>
          <p className="text-xs text-slate-500">Latest 50 franchise milestones across all partners.</p>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50">
              <tr className="text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                <th className="px-4 py-2">Partner</th>
                <th className="px-4 py-2">State</th>
                <th className="px-4 py-2">Kind</th>
                <th className="px-4 py-2">Description</th>
                <th className="px-4 py-2 text-right">Value (₹)</th>
                <th className="px-4 py-2">Achieved</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {milestones.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-6 text-center text-sm text-slate-500">No milestones logged yet.</td>
                </tr>
              ) : milestones.map((m) => (
                <tr key={m.id} className="hover:bg-slate-50">
                  <td className="px-4 py-2 font-medium text-slate-900">{m.partner_name ?? '—'}</td>
                  <td className="px-4 py-2 text-slate-700">{m.state ?? '—'}</td>
                  <td className="px-4 py-2 text-slate-700">{MILESTONE_LABEL[m.milestone_kind] ?? m.milestone_kind}</td>
                  <td className="px-4 py-2 text-slate-600">{m.description}</td>
                  <td className="px-4 py-2 text-right text-slate-700">{formatNumber(m.value_rupees)}</td>
                  <td className="px-4 py-2 text-xs text-slate-500">{new Date(m.achieved_at).toLocaleString('en-IN')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="mt-6 rounded-lg border border-slate-200 bg-slate-50 p-4 text-xs text-slate-600">
        <strong className="text-slate-700">Pilot model:</strong> identify state-level partners (entrepreneurs, biomed cos, hospital chains, engineering colleges, distributors) who replicate the EquipSeva playbook in their territory. Partner pays one-time franchise fee + 5% royalty on monthly platform revenue. Pilot proof-points: 50+ hospitals onboarded, ₹10L+ monthly platform GMV per state within 12 months.
      </div>
    </div>
  );
}
