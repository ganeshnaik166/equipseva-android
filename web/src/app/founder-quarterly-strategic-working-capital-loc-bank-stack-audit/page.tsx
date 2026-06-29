import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type FacilityRow = {
  bank_name: string;
  facility_type: string;
  sanctioned_rupees: number;
  utilised_rupees: number;
  available_rupees: number;
  utilisation_pct: number;
  interest_rate_pct: number;
  facility_status: string;
  covenant_compliance: string;
};

type ConcRow = {
  facility_type: string;
  facility_count: number;
  total_sanctioned: number;
  total_utilised: number;
  weighted_avg_rate: number;
};

type RenewalRow = {
  bank_name: string;
  facility_type: string;
  review_due_date: string;
  days_to_review: number;
  sanctioned_rupees: number;
  facility_status: string;
  urgency: string;
};

type CovenantRow = {
  bank_name: string;
  facility_type: string;
  utilised_rupees: number;
  covenant_compliance: string;
  relationship_manager: string;
  rm_phone: string;
  notes: string;
};

type TxnRow = {
  txn_date: string;
  bank_name: string;
  txn_type: string;
  amount_rupees: number;
  currency: string;
  counterparty: string;
  status: string;
  reference_number: string;
};

type CostRow = {
  bank_name: string;
  total_interest_rupees: number;
  total_fees_rupees: number;
  txn_count: number;
};

type UnreconRow = {
  txn_date: string;
  bank_name: string;
  txn_type: string;
  amount_rupees: number;
  status: string;
  approver_email: string;
  notes: string;
};

type KpiRow = {
  kpi: string;
  value: string;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  if (n >= 10000000) return '₹' + (n / 10000000).toFixed(2) + ' Cr';
  if (n >= 100000) return '₹' + (n / 100000).toFixed(2) + ' L';
  return '₹' + n.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [facRes, concRes, renRes, covRes, txnRes, costRes, unreconRes, kpiRes] = await Promise.all([
    supabase.rpc('r2933_facility_summary'),
    supabase.rpc('r2933_utilisation_concentration'),
    supabase.rpc('r2933_renewal_calendar'),
    supabase.rpc('r2933_covenant_watchlist'),
    supabase.rpc('r2933_txn_recent_activity'),
    supabase.rpc('r2933_interest_cost_by_bank'),
    supabase.rpc('r2933_unreconciled_transactions'),
    supabase.rpc('r2933_stack_health_kpis'),
  ]);

  const facilities: FacilityRow[] = (facRes.data as FacilityRow[]) ?? [];
  const conc: ConcRow[] = (concRes.data as ConcRow[]) ?? [];
  const renewals: RenewalRow[] = (renRes.data as RenewalRow[]) ?? [];
  const covenants: CovenantRow[] = (covRes.data as CovenantRow[]) ?? [];
  const txns: TxnRow[] = (txnRes.data as TxnRow[]) ?? [];
  const costs: CostRow[] = (costRes.data as CostRow[]) ?? [];
  const unrecon: UnreconRow[] = (unreconRes.data as UnreconRow[]) ?? [];
  const kpis: KpiRow[] = (kpiRes.data as KpiRow[]) ?? [];

  const facCols: Column<FacilityRow>[] = [
    { key: 'bank_name', header: 'Bank', render: (r) => r.bank_name },
    { key: 'facility_type', header: 'Type', render: (r) => r.facility_type },
    { key: 'sanctioned_rupees', header: 'Sanctioned', render: (r) => fmtRupees(r.sanctioned_rupees) },
    { key: 'utilised_rupees', header: 'Utilised', render: (r) => fmtRupees(r.utilised_rupees) },
    { key: 'available_rupees', header: 'Available', render: (r) => fmtRupees(r.available_rupees) },
    { key: 'utilisation_pct', header: 'Util %', render: (r) => String(r.utilisation_pct) + '%' },
    { key: 'interest_rate_pct', header: 'Rate', render: (r) => String(r.interest_rate_pct) + '%' },
    { key: 'facility_status', header: 'Status', render: (r) => r.facility_status },
    { key: 'covenant_compliance', header: 'Covenant', render: (r) => r.covenant_compliance },
  ];

  const concCols: Column<ConcRow>[] = [
    { key: 'facility_type', header: 'Facility Type', render: (r) => r.facility_type },
    { key: 'facility_count', header: 'Count', render: (r) => String(r.facility_count) },
    { key: 'total_sanctioned', header: 'Sanctioned', render: (r) => fmtRupees(r.total_sanctioned) },
    { key: 'total_utilised', header: 'Utilised', render: (r) => fmtRupees(r.total_utilised) },
    { key: 'weighted_avg_rate', header: 'Wt Avg Rate', render: (r) => String(r.weighted_avg_rate ?? '-') + '%' },
  ];

  const renCols: Column<RenewalRow>[] = [
    { key: 'bank_name', header: 'Bank', render: (r) => r.bank_name },
    { key: 'facility_type', header: 'Type', render: (r) => r.facility_type },
    { key: 'review_due_date', header: 'Review Due', render: (r) => r.review_due_date },
    { key: 'days_to_review', header: 'Days Left', render: (r) => String(r.days_to_review) },
    { key: 'sanctioned_rupees', header: 'Sanctioned', render: (r) => fmtRupees(r.sanctioned_rupees) },
    { key: 'urgency', header: 'Urgency', render: (r) => r.urgency },
    { key: 'facility_status', header: 'Status', render: (r) => r.facility_status },
  ];

  const covCols: Column<CovenantRow>[] = [
    { key: 'bank_name', header: 'Bank', render: (r) => r.bank_name },
    { key: 'facility_type', header: 'Type', render: (r) => r.facility_type },
    { key: 'utilised_rupees', header: 'Utilised', render: (r) => fmtRupees(r.utilised_rupees) },
    { key: 'covenant_compliance', header: 'Status', render: (r) => r.covenant_compliance },
    { key: 'relationship_manager', header: 'RM', render: (r) => r.relationship_manager },
    { key: 'rm_phone', header: 'Phone', render: (r) => r.rm_phone },
    { key: 'notes', header: 'Notes', render: (r) => r.notes },
  ];

  const txnCols: Column<TxnRow>[] = [
    { key: 'txn_date', header: 'Date', render: (r) => r.txn_date },
    { key: 'bank_name', header: 'Bank', render: (r) => r.bank_name },
    { key: 'txn_type', header: 'Type', render: (r) => r.txn_type },
    { key: 'amount_rupees', header: 'Amount', render: (r) => fmtRupees(r.amount_rupees) },
    { key: 'currency', header: 'Ccy', render: (r) => r.currency },
    { key: 'counterparty', header: 'Counterparty', render: (r) => r.counterparty },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'reference_number', header: 'Ref', render: (r) => r.reference_number },
  ];

  const costCols: Column<CostRow>[] = [
    { key: 'bank_name', header: 'Bank', render: (r) => r.bank_name },
    { key: 'total_interest_rupees', header: 'Interest', render: (r) => fmtRupees(r.total_interest_rupees) },
    { key: 'total_fees_rupees', header: 'Fees', render: (r) => fmtRupees(r.total_fees_rupees) },
    { key: 'txn_count', header: 'Txns', render: (r) => String(r.txn_count) },
  ];

  const unreconCols: Column<UnreconRow>[] = [
    { key: 'txn_date', header: 'Date', render: (r) => r.txn_date },
    { key: 'bank_name', header: 'Bank', render: (r) => r.bank_name },
    { key: 'txn_type', header: 'Type', render: (r) => r.txn_type },
    { key: 'amount_rupees', header: 'Amount', render: (r) => fmtRupees(r.amount_rupees) },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'approver_email', header: 'Approver', render: (r) => r.approver_email },
    { key: 'notes', header: 'Notes', render: (r) => r.notes },
  ];

  const kpiCols: Column<KpiRow>[] = [
    { key: 'kpi', header: 'KPI', render: (r) => r.kpi },
    { key: 'value', header: 'Value', render: (r) => r.value },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '2rem', borderBottom: '2px solid #0f172a', paddingBottom: '1rem' }}>
        <div style={{ fontSize: '0.75rem', color: '#64748b', letterSpacing: '0.1em' }}>ROUND 2933 · HEAVY ★★★★ · 1500/50 MILESTONE</div>
        <h1 style={{ fontSize: '1.8rem', margin: '0.5rem 0', color: '#0f172a' }}>Quarterly Strategic Working-Capital, LoC & Bank Stack Audit</h1>
        <p style={{ color: '#475569', margin: 0 }}>Quarterly strategic review of all facility lines, utilisation concentration, covenant breaches, renewal calendar & transaction reconciliation across the bank stack.</p>
      </header>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', color: '#0f172a' }}>Stack Health KPIs</h2>
        <DataTable rows={kpis} columns={kpiCols} emptyMessage="No KPIs" rowKey={(r, i) => String((r as KpiRow).kpi ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', color: '#0f172a' }}>Facility Summary — all banks</h2>
        <DataTable rows={facilities} columns={facCols} emptyMessage="No facilities" rowKey={(r, i) => String((r as FacilityRow).bank_name ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', color: '#0f172a' }}>Utilisation Concentration by Type</h2>
        <DataTable rows={conc} columns={concCols} emptyMessage="No concentration data" rowKey={(r, i) => String((r as ConcRow).facility_type ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', color: '#0f172a' }}>Renewal Calendar — sorted by review date</h2>
        <DataTable rows={renewals} columns={renCols} emptyMessage="No upcoming renewals" rowKey={(r, i) => String((r as RenewalRow).bank_name ?? i) + '-' + i} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', color: '#0f172a' }}>Covenant Watchlist & Breaches</h2>
        <DataTable rows={covenants} columns={covCols} emptyMessage="No covenant issues" rowKey={(r, i) => String((r as CovenantRow).bank_name ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', color: '#0f172a' }}>Recent Transaction Activity (last 30)</h2>
        <DataTable rows={txns} columns={txnCols} emptyMessage="No transactions" rowKey={(r, i) => String((r as TxnRow).reference_number ?? i) + '-' + i} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', color: '#0f172a' }}>Interest & Fee Cost by Bank</h2>
        <DataTable rows={costs} columns={costCols} emptyMessage="No interest/fee data" rowKey={(r, i) => String((r as CostRow).bank_name ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', color: '#0f172a' }}>Unreconciled & Disputed Transactions</h2>
        <DataTable rows={unrecon} columns={unreconCols} emptyMessage="All reconciled — clean" rowKey={(r, i) => String((r as UnreconRow).txn_date ?? i) + '-' + i} />
      </section>

      <footer style={{ marginTop: '3rem', paddingTop: '1rem', borderTop: '1px solid #e2e8f0', fontSize: '0.75rem', color: '#64748b' }}>
        Founder-only view. All 8 RPCs gated by is_founder(). Round 2933 — 1500/50 milestone crossing batch.
      </footer>
    </main>
  );
}
