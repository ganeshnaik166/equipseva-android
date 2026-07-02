import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_clinics_invited: number;
  total_clinics_onboarded: number;
  total_clinics_live: number;
  total_clinics_paused: number;
  total_clinics_churned: number;
  total_amcs_signed: number;
  total_suppliers_signed: number;
  total_suppliers_pending: number;
  total_bond_value_rupees: number;
  days_since_pilot_start: number;
  conversion_pct_invited_to_live: number;
  days_to_first_amc_median: number;
};

type ClinicRow = {
  id: string;
  clinic_name: string;
  city: string | null;
  cohort: string;
  enrollment_status: string;
  invited_at: string;
  onboarded_at: string | null;
  first_amc_signed_at: string | null;
  categories_count: number;
  days_in_pipeline: number;
};

type SupplierRow = {
  id: string;
  supplier_name: string;
  bonded_status: string;
  supported_count: number;
  bond_amount_rupees: number;
  bond_signed_at: string | null;
  bond_expires_at: string | null;
  days_until_expiry: number | null;
};

const EQUIPMENT_CATEGORIES = [
  { key: 'blood_analyzer', label: 'Blood Analyzer' },
  { key: 'centrifuge', label: 'Centrifuge' },
  { key: 'autoclave_lab', label: 'Autoclave (Lab)' },
  { key: 'microscope', label: 'Microscope' },
  { key: 'elisa_reader', label: 'ELISA Reader' },
  { key: 'urine_analyzer', label: 'Urine Analyzer' },
  { key: 'spectrophotometer', label: 'Spectrophotometer' },
  { key: 'pcr_machine', label: 'PCR Machine' },
  { key: 'immunoassay_analyzer', label: 'Immunoassay Analyzer' },
];

function statusBadge(status: string): string {
  const map: Record<string, string> = {
    invited: 'bg-slate-100 text-slate-700',
    onboarding: 'bg-amber-100 text-amber-800',
    live: 'bg-emerald-100 text-emerald-800',
    paused: 'bg-orange-100 text-orange-800',
    churned: 'bg-rose-100 text-rose-800',
    pending: 'bg-slate-100 text-slate-700',
    signed: 'bg-sky-100 text-sky-800',
    active: 'bg-emerald-100 text-emerald-800',
    revoked: 'bg-rose-100 text-rose-800',
  };
  return map[status] ?? 'bg-slate-100 text-slate-700';
}

function fmtDate(d: string | null): string {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: '2-digit' });
}

export default async function LabDiagnosticsVerticalPilotPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: summaryData }, { data: clinicData }, { data: supplierData }] = await Promise.all([
    supabase.rpc('founder_lab_diagnostics_pilot_summary'),
    supabase.rpc('founder_lab_diagnostics_pilot_clinics', { p_limit: 50 }),
    supabase.rpc('founder_lab_diagnostics_pilot_suppliers', { p_limit: 30 }),
  ]);

  const s: SummaryRow = (summaryData?.[0] as SummaryRow) ?? {
    total_clinics_invited: 0, total_clinics_onboarded: 0, total_clinics_live: 0,
    total_clinics_paused: 0, total_clinics_churned: 0, total_amcs_signed: 0,
    total_suppliers_signed: 0, total_suppliers_pending: 0, total_bond_value_rupees: 0,
    days_since_pilot_start: 0, conversion_pct_invited_to_live: 0, days_to_first_amc_median: 0,
  };
  const clinics: ClinicRow[] = (clinicData as ClinicRow[]) ?? [];
  const suppliers: SupplierRow[] = (supplierData as SupplierRow[]) ?? [];

  const cards = [
    { label: 'Clinics Invited', value: formatNumber(s.total_clinics_invited), tone: 'slate' },
    { label: 'Onboarding', value: formatNumber(s.total_clinics_onboarded), tone: 'amber' },
    { label: 'Live', value: formatNumber(s.total_clinics_live), tone: 'emerald' },
    { label: 'Paused', value: formatNumber(s.total_clinics_paused), tone: 'orange' },
    { label: 'Churned', value: formatNumber(s.total_clinics_churned), tone: 'rose' },
    { label: 'AMCs Signed', value: formatNumber(s.total_amcs_signed), tone: 'sky' },
    { label: 'Suppliers Signed', value: formatNumber(s.total_suppliers_signed), tone: 'emerald' },
    { label: 'Suppliers Pending', value: formatNumber(s.total_suppliers_pending), tone: 'amber' },
    { label: 'Total Bond Value', value: `₹${formatNumber(s.total_bond_value_rupees)}`, tone: 'sky' },
    { label: 'Days Since Pilot Start', value: formatNumber(s.days_since_pilot_start), tone: 'slate' },
    { label: 'Invited → Live Conversion', value: `${s.conversion_pct_invited_to_live}%`, tone: 'emerald' },
    { label: 'Median Days to First AMC', value: `${s.days_to_first_amc_median} d`, tone: 'sky' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 px-4 py-8">
      <header className="space-y-2">
        <p className="text-xs font-medium uppercase tracking-wider text-sky-600">Vertical Pilot · v0.6 Phase 1</p>
        <h1 className="text-3xl font-bold text-slate-900">Lab Diagnostics Vertical Pilot</h1>
        <p className="text-sm text-slate-600">
          Hyderabad 2026Q4 cohort · clinic enrollment funnel, bonded-parts supplier coverage, and 9-category equipment scope.
        </p>
      </header>

      <section aria-labelledby="kpis" className="space-y-3">
        <h2 id="kpis" className="text-lg font-semibold text-slate-900">Pilot KPIs (12)</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {cards.map((c) => (
            <div key={c.label} className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
              <div className="text-xs font-medium uppercase tracking-wide text-slate-500">{c.label}</div>
              <div className="mt-1 text-2xl font-bold text-slate-900">{c.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section aria-labelledby="cats" className="space-y-3">
        <h2 id="cats" className="text-lg font-semibold text-slate-900">Equipment Categories in Scope (9)</h2>
        <div className="rounded-lg border border-sky-200 bg-sky-50 p-4">
          <div className="grid grid-cols-3 gap-2 text-sm sm:grid-cols-3 lg:grid-cols-9">
            {EQUIPMENT_CATEGORIES.map((cat) => (
              <div key={cat.key} className="rounded border border-sky-200 bg-white px-2 py-1.5 text-center text-xs font-medium text-sky-900">
                {cat.label}
              </div>
            ))}
          </div>
        </div>
      </section>

      <section aria-labelledby="clinics" className="space-y-3">
        <h2 id="clinics" className="text-lg font-semibold text-slate-900">Clinic Enrollment Ledger (top 50)</h2>
        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white shadow-sm">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Clinic</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">City</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Cohort</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Status</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Invited</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Onboarded</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">First AMC</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Cats</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Days</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {clinics.length === 0 ? (
                <tr><td colSpan={9} className="px-3 py-6 text-center text-slate-500">No clinics enrolled yet.</td></tr>
              ) : clinics.map((c) => (
                <tr key={c.id} className="hover:bg-slate-50">
                  <td className="px-3 py-2 font-medium text-slate-900">{c.clinic_name}</td>
                  <td className="px-3 py-2 text-slate-700">{c.city ?? '—'}</td>
                  <td className="px-3 py-2 text-xs text-slate-600">{c.cohort}</td>
                  <td className="px-3 py-2">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${statusBadge(c.enrollment_status)}`}>
                      {c.enrollment_status}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-right text-slate-700">{fmtDate(c.invited_at)}</td>
                  <td className="px-3 py-2 text-right text-slate-700">{fmtDate(c.onboarded_at)}</td>
                  <td className="px-3 py-2 text-right text-slate-700">{fmtDate(c.first_amc_signed_at)}</td>
                  <td className="px-3 py-2 text-right text-slate-700">{c.categories_count}</td>
                  <td className="px-3 py-2 text-right text-slate-700">{c.days_in_pipeline}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section aria-labelledby="suppliers" className="space-y-3">
        <h2 id="suppliers" className="text-lg font-semibold text-slate-900">Bonded-Parts Suppliers (top 30)</h2>
        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white shadow-sm">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Supplier</th>
                <th className="px-3 py-2 text-left font-medium text-slate-600">Status</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Categories</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Bond ₹</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Signed</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Expires</th>
                <th className="px-3 py-2 text-right font-medium text-slate-600">Days Left</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {suppliers.length === 0 ? (
                <tr><td colSpan={7} className="px-3 py-6 text-center text-slate-500">No suppliers registered yet.</td></tr>
              ) : suppliers.map((sp) => (
                <tr key={sp.id} className="hover:bg-slate-50">
                  <td className="px-3 py-2 font-medium text-slate-900">{sp.supplier_name}</td>
                  <td className="px-3 py-2">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${statusBadge(sp.bonded_status)}`}>
                      {sp.bonded_status}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-right text-slate-700">{sp.supported_count}</td>
                  <td className="px-3 py-2 text-right text-slate-700">{formatNumber(sp.bond_amount_rupees)}</td>
                  <td className="px-3 py-2 text-right text-slate-700">{fmtDate(sp.bond_signed_at)}</td>
                  <td className="px-3 py-2 text-right text-slate-700">{fmtDate(sp.bond_expires_at)}</td>
                  <td className="px-3 py-2 text-right text-slate-700">{sp.days_until_expiry ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="border-t border-slate-200 pt-4 text-xs text-slate-500">
        Round 1392 · v0.6 Phase 1 · mirrors dental r1323 · founder-gated.
      </footer>
    </main>
  );
}
