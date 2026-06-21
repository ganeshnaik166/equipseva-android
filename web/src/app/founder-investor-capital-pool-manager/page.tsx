import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorCapitalPoolManagerPage() {
  const sb = await getSupabaseServerClient();

  const [entriesRes, eventsRes, summaryRes, outlookRes] = await Promise.all([
    sb.rpc('list_pool_entries_r1821'),
    sb.rpc('list_pool_events_r1821', { p_entry_id: null }),
    sb.rpc('total_pool_summary_r1821'),
    sb.rpc('conversion_outlook_r1821'),
  ]);

  const entries = (entriesRes.data as any[]) ?? [];
  const events = (eventsRes.data as any[]) ?? [];
  const summary = (summaryRes.data as any[]) ?? [];
  const outlook = (outlookRes.data as any[]) ?? [];

  const fmtMoney = (n: any) => {
    const v = Number(n ?? 0);
    return '₹' + v.toLocaleString('en-IN');
  };
  const fmtDate = (d: any) => (d ? String(d).slice(0, 10) : '—');

  const entryCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) ?? '—' },
    { key: 'instrument_type', header: 'Instrument', render: (r: any) => r.instrument_type },
    { key: 'principal_amount_rupees', header: 'Principal', render: (r: any) => fmtMoney(r.principal_amount_rupees) },
    { key: 'interest_rate_pct', header: 'Rate %', render: (r: any) => `${r.interest_rate_pct ?? 0}` },
    { key: 'signed_at', header: 'Signed', render: (r: any) => fmtDate(r.signed_at) },
    { key: 'maturity_date', header: 'Maturity', render: (r: any) => fmtDate(r.maturity_date) },
    { key: 'conversion_trigger', header: 'Trigger', render: (r: any) => r.conversion_trigger },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'accrued_interest_rupees', header: 'Accrued', render: (r: any) => fmtMoney(r.accrued_interest_rupees) },
  ];

  const eventCols: Column<any>[] = [
    { key: 'event_date', header: 'Date', render: (r: any) => fmtDate(r.event_date) },
    { key: 'entry_id', header: 'Entry', render: (r: any) => String(r.entry_id ?? '').slice(0, 8) },
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type },
    { key: 'amount_delta_rupees', header: 'Delta', render: (r: any) => fmtMoney(r.amount_delta_rupees) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'instrument_type', header: 'Instrument', render: (r: any) => r.instrument_type },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'entry_count', header: 'Count', render: (r: any) => r.entry_count },
    { key: 'total_principal_rupees', header: 'Total Principal', render: (r: any) => fmtMoney(r.total_principal_rupees) },
    { key: 'total_accrued_rupees', header: 'Total Accrued', render: (r: any) => fmtMoney(r.total_accrued_rupees) },
  ];

  const outlookCols: Column<any>[] = [
    { key: 'conversion_trigger', header: 'Trigger', render: (r: any) => r.conversion_trigger },
    { key: 'active_entries', header: 'Active', render: (r: any) => r.active_entries },
    { key: 'pending_principal_rupees', header: 'Pending Principal', render: (r: any) => fmtMoney(r.pending_principal_rupees) },
    { key: 'pending_accrued_rupees', header: 'Pending Accrued', render: (r: any) => fmtMoney(r.pending_accrued_rupees) },
    { key: 'next_maturity', header: 'Next Maturity', render: (r: any) => fmtDate(r.next_maturity) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Capital Pool Manager</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track SAFEs, convertible notes, warrants & loans. Accrue interest, log conversions & monitor maturity outlook.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pool Summary</h2>
        <DataTable rows={summary} columns={summaryCols} rowKey={(r: any, i: number) => String(r.instrument_type + '-' + r.status + '-' + i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Conversion Outlook</h2>
        <DataTable rows={outlook} columns={outlookCols} rowKey={(r: any, i: number) => String(r.conversion_trigger + '-' + i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active & Historical Entries</h2>
        <DataTable rows={entries} columns={entryCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Event Log</h2>
        <DataTable rows={events} columns={eventCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
