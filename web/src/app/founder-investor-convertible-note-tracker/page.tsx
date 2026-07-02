import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [notesRes, outstandingRes, recentRes] = await Promise.all([
    sb.rpc('icn_r1969_list_notes'),
    sb.rpc('icn_r1969_outstanding_principal'),
    sb.rpc('icn_r1969_recent_actions'),
  ]);

  const notes: any[] = Array.isArray(notesRes.data) ? notesRes.data : [];
  const outstanding: any[] = Array.isArray(outstandingRes.data) ? outstandingRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const noteCols: Column<any>[] = [
    { key: 'note_label', header: 'Label', render: (r: any) => String(r.note_label ?? '') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'principal_amount_rupees', header: 'Principal', render: (r: any) => `Rs ${Number(r.principal_amount_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'interest_rate_pct', header: 'Interest pct', render: (r: any) => `${Number(r.interest_rate_pct ?? 0)}` },
    { key: 'valuation_cap_rupees', header: 'Val Cap', render: (r: any) => `Rs ${Number(r.valuation_cap_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'discount_pct', header: 'Discount pct', render: (r: any) => `${Number(r.discount_pct ?? 0)}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'issued_at', header: 'Issued', render: (r: any) => r.issued_at ? new Date(r.issued_at).toLocaleDateString() : '' },
    { key: 'matures_on', header: 'Matures', render: (r: any) => r.matures_on ? String(r.matures_on) : '' },
  ];

  const outstandingCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'note_count', header: 'Notes', render: (r: any) => String(r.note_count ?? 0) },
    { key: 'total_principal_rupees', header: 'Total Principal', render: (r: any) => `Rs ${Number(r.total_principal_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const recentCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'note_label', header: 'Note', render: (r: any) => String(r.note_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => `Rs ${Number(r.amount_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Investor Convertible Note Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round 1969. Track convertible notes outstanding across active, converted, repaid and written-off states.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 4 }}>Outstanding principal by status</h2>
        <p style={{ color: '#888', marginBottom: 12, fontSize: 14 }}>
          Aggregated principal grouped by note status.
        </p>
        <DataTable
          rows={outstanding}
          columns={outstandingCols}
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 4 }}>All notes</h2>
        <p style={{ color: '#888', marginBottom: 12, fontSize: 14 }}>
          Up to 200 most recently issued notes.
        </p>
        <DataTable
          rows={notes}
          columns={noteCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 4 }}>Recent actions</h2>
        <p style={{ color: '#888', marginBottom: 12, fontSize: 14 }}>
          Up to 100 most recent log entries across all notes.
        </p>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
