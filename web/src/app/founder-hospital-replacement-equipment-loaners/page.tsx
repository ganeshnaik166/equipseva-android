import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [dispatchesRes, billingRes, summaryRes, overdueRes] = await Promise.all([
    sb.rpc('list_loaner_dispatches_r1711'),
    sb.rpc('list_loaner_billing_r1711'),
    sb.rpc('active_loaners_summary_r1711'),
    sb.rpc('overdue_loaners_r1711'),
  ]);

  const dispatches: any[] = Array.isArray(dispatchesRes.data) ? dispatchesRes.data : [];
  const billing: any[] = Array.isArray(billingRes.data) ? billingRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data;
  const overdue: any[] = Array.isArray(overdueRes.data) ? overdueRes.data : [];

  const dispatchCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name ?? '—' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'dispatched_at', header: 'Dispatched', render: (r: any) => r.dispatched_at ? new Date(r.dispatched_at).toLocaleDateString() : '—' },
    { key: 'days_out', header: 'Days Out', render: (r: any) => String(r.days_out ?? 0) },
    { key: 'returned_at', header: 'Returned', render: (r: any) => r.returned_at ? new Date(r.returned_at).toLocaleDateString() : '—' },
    { key: 'return_condition', header: 'Condition', render: (r: any) => r.return_condition ?? '—' },
    { key: 'billable_per_day_rupees', header: '₹/day', render: (r: any) => `₹${(r.billable_per_day_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_billed_rupees', header: 'Total ₹', render: (r: any) => `₹${(r.total_billed_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const billingCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '—' },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name ?? '—' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'dispatched_at', header: 'Dispatched', render: (r: any) => r.dispatched_at ? new Date(r.dispatched_at).toLocaleDateString() : '—' },
    { key: 'days_out', header: 'Days Out', render: (r: any) => String(r.days_out ?? 0) },
    { key: 'billable_per_day_rupees', header: '₹/day', render: (r: any) => `₹${(r.billable_per_day_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'accrued_rupees', header: 'Accrued ₹', render: (r: any) => `₹${(r.accrued_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '1.5rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.25rem' }}>
          Hospital Replacement Equipment Loaners
        </h1>
        <p style={{ color: '#666', fontSize: '0.95rem' }}>
          Track loaner equipment dispatched while repair pending. Overdue threshold: more than 14 days out.
        </p>
      </header>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '0.75rem' }}>
          <SummaryCard label="Active" value={String(summary?.total_active ?? 0)} />
          <SummaryCard label="Returned" value={String(summary?.total_returned ?? 0)} />
          <SummaryCard label="Billed" value={String(summary?.total_billed ?? 0)} />
          <SummaryCard label="Written Off" value={String(summary?.total_written_off ?? 0)} />
          <SummaryCard label="Billed ₹ Sum" value={`₹${Number(summary?.total_billed_rupees_sum ?? 0).toLocaleString('en-IN')}`} />
          <SummaryCard label="Active Accrued ₹" value={`₹${Number(summary?.active_potential_rupees ?? 0).toLocaleString('en-IN')}`} />
        </div>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Overdue Loaners (more than 14 days)
        </h2>
        {overdue.length === 0 ? (
          <p style={{ color: '#888', fontSize: '0.9rem' }}>No overdue loaners.</p>
        ) : (
          <DataTable rows={overdue} columns={overdueCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        )}
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>All Dispatches</h2>
        {dispatches.length === 0 ? (
          <p style={{ color: '#888', fontSize: '0.9rem' }}>No loaner dispatches yet.</p>
        ) : (
          <DataTable rows={dispatches} columns={dispatchCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        )}
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.75rem' }}>Billing Actions</h2>
        {billing.length === 0 ? (
          <p style={{ color: '#888', fontSize: '0.9rem' }}>No billing actions logged.</p>
        ) : (
          <DataTable rows={billing} columns={billingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        )}
      </section>

      <footer style={{ marginTop: '2rem', paddingTop: '1rem', borderTop: '1px solid #eee', color: '#888', fontSize: '0.85rem' }}>
        Round r1711 · founder-only console
      </footer>
    </main>
  );
}

function SummaryCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ padding: '0.85rem 1rem', border: '1px solid #e5e5e5', borderRadius: 8, background: '#fafafa' }}>
      <div style={{ fontSize: '0.75rem', color: '#777', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: '0.25rem' }}>
        {label}
      </div>
      <div style={{ fontSize: '1.25rem', fontWeight: 600 }}>{value}</div>
    </div>
  );
}
