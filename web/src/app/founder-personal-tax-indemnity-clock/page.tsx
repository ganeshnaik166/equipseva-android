import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_items: number;
  upcoming_count: number;
  in_progress_count: number;
  overdue_count: number;
  penalty_risk_count: number;
  total_amount_due_rupees: number;
  total_penalty_rupees: number;
  total_interest_rupees: number;
  critical_items: number;
};

type ClockRow = {
  id: string;
  clock_kind: string;
  fiscal_year: string;
  statutory_due_at: string;
  status: string;
  amount_due_rupees: number;
  ca_assigned: string | null;
  risk_band: string;
  days_to_due: number;
};

type OverdueRow = {
  id: string;
  clock_kind: string;
  fiscal_year: string;
  statutory_due_at: string;
  status: string;
  penalty_accrued_rupees: number;
  interest_accrued_rupees: number;
  ca_assigned: string | null;
  days_to_due: number;
  notes: string | null;
};

type AdvanceTaxRow = {
  id: string;
  clock_kind: string;
  fiscal_year: string;
  statutory_due_at: string;
  amount_due_rupees: number;
  amount_paid_rupees: number;
  status: string;
  filing_reference: string | null;
  days_to_due: number;
};

type IndemnityRow = {
  id: string;
  doc_kind: string;
  issuer: string;
  policy_or_ref_no: string;
  cover_amount_rupees: number | null;
  expires_on: string;
  status: string;
  custody_location: string;
  days_to_expiry: number;
};

type ClearanceRow = {
  id: string;
  doc_kind: string;
  issuer: string;
  policy_or_ref_no: string;
  issued_on: string;
  expires_on: string;
  status: string;
  custody_location: string;
  verification_status: string;
};

type CaRosterRow = {
  ca_assigned: string;
  ca_firm: string | null;
  items_assigned: number;
  pending_items: number;
  total_amount_rupees: number;
  total_penalty_rupees: number;
};

type RiskBandRow = {
  risk_band: string;
  items_count: number;
  amount_at_risk_rupees: number;
  penalty_rupees: number;
  earliest_due: string;
};

type ExpiringRow = {
  id: string;
  doc_kind: string;
  issuer: string;
  policy_or_ref_no: string;
  expires_on: string;
  status: string;
  days_to_expiry: number;
  renewal_window_days: number;
};

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + n.toLocaleString('en-IN');
}

function fmtDate(s: string | null): string {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: '2-digit' });
  } catch {
    return s;
  }
}

export default async function FounderPersonalTaxIndemnityClockPage() {
  const supabase = await getSupabaseServerClient();

  const [
    summaryRes,
    upcomingRes,
    overdueRes,
    advanceTaxRes,
    indemnityRes,
    clearanceRes,
    caRosterRes,
    riskBandRes,
    expiringRes,
  ] = await Promise.all([
    supabase.rpc('founder_statutory_clock_summary_r3117'),
    supabase.rpc('founder_upcoming_clock_items_r3117'),
    supabase.rpc('founder_overdue_clock_items_r3117'),
    supabase.rpc('founder_advance_tax_ladder_r3117'),
    supabase.rpc('founder_indemnity_roster_r3117'),
    supabase.rpc('founder_clearance_vault_r3117'),
    supabase.rpc('founder_ca_assignment_roster_r3117'),
    supabase.rpc('founder_risk_band_heatmap_r3117'),
    supabase.rpc('founder_expiring_docs_r3117'),
  ]);

  const summary: SummaryRow | null = (summaryRes.data as SummaryRow[] | null)?.[0] ?? null;
  const upcoming: ClockRow[] = (upcomingRes.data as ClockRow[] | null) ?? [];
  const overdue: OverdueRow[] = (overdueRes.data as OverdueRow[] | null) ?? [];
  const advanceTax: AdvanceTaxRow[] = (advanceTaxRes.data as AdvanceTaxRow[] | null) ?? [];
  const indemnity: IndemnityRow[] = (indemnityRes.data as IndemnityRow[] | null) ?? [];
  const clearance: ClearanceRow[] = (clearanceRes.data as ClearanceRow[] | null) ?? [];
  const caRoster: CaRosterRow[] = (caRosterRes.data as CaRosterRow[] | null) ?? [];
  const riskBand: RiskBandRow[] = (riskBandRes.data as RiskBandRow[] | null) ?? [];
  const expiring: ExpiringRow[] = (expiringRes.data as ExpiringRow[] | null) ?? [];

  const upcomingCols: Column<ClockRow>[] = [
    { key: 'clock_kind', header: 'Clock Kind' },
    { key: 'fiscal_year', header: 'FY' },
    { key: 'statutory_due_at', header: 'Statutory Due', render: (r) => fmtDate(r.statutory_due_at) },
    { key: 'status', header: 'Status' },
    { key: 'amount_due_rupees', header: 'Amount Due', render: (r) => rupees(r.amount_due_rupees) },
    { key: 'ca_assigned', header: 'CA', render: (r) => r.ca_assigned ?? '—' },
    { key: 'risk_band', header: 'Risk' },
    { key: 'days_to_due', header: 'Days to Due' },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { key: 'clock_kind', header: 'Clock Kind' },
    { key: 'fiscal_year', header: 'FY' },
    { key: 'statutory_due_at', header: 'Due', render: (r) => fmtDate(r.statutory_due_at) },
    { key: 'status', header: 'Status' },
    { key: 'penalty_accrued_rupees', header: 'Penalty', render: (r) => rupees(r.penalty_accrued_rupees) },
    { key: 'interest_accrued_rupees', header: 'Interest', render: (r) => rupees(r.interest_accrued_rupees) },
    { key: 'ca_assigned', header: 'CA', render: (r) => r.ca_assigned ?? '—' },
    { key: 'days_to_due', header: 'Days' },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const advanceTaxCols: Column<AdvanceTaxRow>[] = [
    { key: 'clock_kind', header: 'Installment' },
    { key: 'fiscal_year', header: 'FY' },
    { key: 'statutory_due_at', header: 'Due', render: (r) => fmtDate(r.statutory_due_at) },
    { key: 'amount_due_rupees', header: 'Due', render: (r) => rupees(r.amount_due_rupees) },
    { key: 'amount_paid_rupees', header: 'Paid', render: (r) => rupees(r.amount_paid_rupees) },
    { key: 'status', header: 'Status' },
    { key: 'filing_reference', header: 'Ref', render: (r) => r.filing_reference ?? '—' },
    { key: 'days_to_due', header: 'Days' },
  ];

  const indemnityCols: Column<IndemnityRow>[] = [
    { key: 'doc_kind', header: 'Doc Kind' },
    { key: 'issuer', header: 'Issuer' },
    { key: 'policy_or_ref_no', header: 'Policy No' },
    { key: 'cover_amount_rupees', header: 'Cover', render: (r) => rupees(r.cover_amount_rupees) },
    { key: 'expires_on', header: 'Expires', render: (r) => fmtDate(r.expires_on) },
    { key: 'status', header: 'Status' },
    { key: 'custody_location', header: 'Custody' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
  ];

  const clearanceCols: Column<ClearanceRow>[] = [
    { key: 'doc_kind', header: 'Doc Kind' },
    { key: 'issuer', header: 'Issuer' },
    { key: 'policy_or_ref_no', header: 'Cert No' },
    { key: 'issued_on', header: 'Issued', render: (r) => fmtDate(r.issued_on) },
    { key: 'expires_on', header: 'Expires', render: (r) => fmtDate(r.expires_on) },
    { key: 'status', header: 'Status' },
    { key: 'custody_location', header: 'Custody' },
    { key: 'verification_status', header: 'Verified' },
  ];

  const caRosterCols: Column<CaRosterRow>[] = [
    { key: 'ca_assigned', header: 'CA' },
    { key: 'ca_firm', header: 'Firm', render: (r) => r.ca_firm ?? '—' },
    { key: 'items_assigned', header: 'Items' },
    { key: 'pending_items', header: 'Pending' },
    { key: 'total_amount_rupees', header: 'Total Amt', render: (r) => rupees(r.total_amount_rupees) },
    { key: 'total_penalty_rupees', header: 'Penalty', render: (r) => rupees(r.total_penalty_rupees) },
  ];

  const riskBandCols: Column<RiskBandRow>[] = [
    { key: 'risk_band', header: 'Risk Band' },
    { key: 'items_count', header: 'Items' },
    { key: 'amount_at_risk_rupees', header: 'Amount at Risk', render: (r) => rupees(r.amount_at_risk_rupees) },
    { key: 'penalty_rupees', header: 'Penalty', render: (r) => rupees(r.penalty_rupees) },
    { key: 'earliest_due', header: 'Earliest Due', render: (r) => fmtDate(r.earliest_due) },
  ];

  const expiringCols: Column<ExpiringRow>[] = [
    { key: 'doc_kind', header: 'Doc Kind' },
    { key: 'issuer', header: 'Issuer' },
    { key: 'policy_or_ref_no', header: 'Ref No' },
    { key: 'expires_on', header: 'Expires', render: (r) => fmtDate(r.expires_on) },
    { key: 'status', header: 'Status' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'renewal_window_days', header: 'Window' },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Founder Personal Tax + Filing + Indemnity Clock</h1>
        <p className="text-sm text-gray-600">
          Founder statutory clock: advance tax, ITR, DSC, indemnity, CA assignments, clearances, penalty risk.
        </p>
      </header>

      {summary && (
        <section className="grid grid-cols-2 gap-4 md:grid-cols-4 lg:grid-cols-5">
          <div className="rounded-md border bg-white p-4">
            <div className="text-xs text-gray-500">Total Items</div>
            <div className="text-2xl font-semibold">{summary.total_items}</div>
          </div>
          <div className="rounded-md border bg-white p-4">
            <div className="text-xs text-gray-500">Upcoming</div>
            <div className="text-2xl font-semibold">{summary.upcoming_count}</div>
          </div>
          <div className="rounded-md border bg-white p-4">
            <div className="text-xs text-gray-500">Overdue</div>
            <div className="text-2xl font-semibold text-red-700">{summary.overdue_count}</div>
          </div>
          <div className="rounded-md border bg-white p-4">
            <div className="text-xs text-gray-500">Penalty Risk</div>
            <div className="text-2xl font-semibold text-orange-700">{summary.penalty_risk_count}</div>
          </div>
          <div className="rounded-md border bg-white p-4">
            <div className="text-xs text-gray-500">Critical</div>
            <div className="text-2xl font-semibold text-red-800">{summary.critical_items}</div>
          </div>
          <div className="rounded-md border bg-white p-4">
            <div className="text-xs text-gray-500">Amount Due</div>
            <div className="text-xl font-semibold">{rupees(summary.total_amount_due_rupees)}</div>
          </div>
          <div className="rounded-md border bg-white p-4">
            <div className="text-xs text-gray-500">Penalty Accrued</div>
            <div className="text-xl font-semibold text-red-700">{rupees(summary.total_penalty_rupees)}</div>
          </div>
          <div className="rounded-md border bg-white p-4">
            <div className="text-xs text-gray-500">Interest Accrued</div>
            <div className="text-xl font-semibold">{rupees(summary.total_interest_rupees)}</div>
          </div>
          <div className="rounded-md border bg-white p-4">
            <div className="text-xs text-gray-500">In Progress</div>
            <div className="text-2xl font-semibold">{summary.in_progress_count}</div>
          </div>
        </section>
      )}

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Upcoming Statutory Clock Items</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          emptyMessage="No upcoming clock items"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Overdue + Penalty Risk</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No overdue items"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Advance Tax Ladder (Q1-Q4)</h2>
        <DataTable
          rows={advanceTax}
          columns={advanceTaxCols}
          emptyMessage="No advance tax items"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Indemnity Policy Roster</h2>
        <DataTable
          rows={indemnity}
          columns={indemnityCols}
          emptyMessage="No indemnity policies"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Clearance Certificate Vault</h2>
        <DataTable
          rows={clearance}
          columns={clearanceCols}
          emptyMessage="No clearance certificates"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">CA Assignment Roster</h2>
        <DataTable
          rows={caRoster}
          columns={caRosterCols}
          emptyMessage="No CA assignments"
          rowKey={(r, i) => String(r.ca_assigned ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Risk-Band Heatmap</h2>
        <DataTable
          rows={riskBand}
          columns={riskBandCols}
          emptyMessage="No risk-band data"
          rowKey={(r, i) => String(r.risk_band ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Expiring Docs (next 60 days)</h2>
        <DataTable
          rows={expiring}
          columns={expiringCols}
          emptyMessage="No expiring docs"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
