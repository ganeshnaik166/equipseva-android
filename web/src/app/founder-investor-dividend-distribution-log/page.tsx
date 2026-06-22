import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [distRes, totalRes, recentRes] = await Promise.all([
    sb.rpc('list_distributions_r2005'),
    sb.rpc('total_paid_r2005'),
    sb.rpc('recent_actions_r2005'),
  ]);

  const distributions: any[] = Array.isArray(distRes.data) ? distRes.data : [];
  const totals: any = Array.isArray(totalRes.data) && totalRes.data.length > 0 ? totalRes.data[0] : {};
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const distColumns: Column<any>[] = [
    { key: 'distribution_date', header: 'Date', render: (r: any) => String(r.distribution_date ?? '') },
    { key: 'dividend_label', header: 'Label', render: (r: any) => String(r.dividend_label ?? '') },
    { key: 'investor_email', header: 'Investor', render: (r: any) => String(r.investor_email ?? r.investor_id ?? '') },
    { key: 'dividend_type', header: 'Type', render: (r: any) => String(r.dividend_type ?? '') },
    { key: 'amount_rupees', header: 'Amount (rupees)', render: (r: any) => Number(r.amount_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'paid_at', header: 'Paid At', render: (r: any) => r.paid_at ? new Date(r.paid_at).toLocaleString() : 'pending' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'dividend_label', header: 'Distribution', render: (r: any) => String(r.dividend_label ?? r.distribution_id ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => r.amount_rupees != null ? Number(r.amount_rupees).toLocaleString('en-IN') : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Dividend Distribution Log</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track dividend distributions per investor. Ordinary, preferred, special, and liquidating dividends with full action audit trail.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Totals</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Paid</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>₹ {Number(totals?.total_paid_rupees ?? 0).toLocaleString('en-IN')}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Declared</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>₹ {Number(totals?.total_declared_rupees ?? 0).toLocaleString('en-IN')}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Withheld</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>₹ {Number(totals?.total_withheld_rupees ?? 0).toLocaleString('en-IN')}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Disputed</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>₹ {Number(totals?.total_disputed_rupees ?? 0).toLocaleString('en-IN')}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Distinct Investors</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{Number(totals?.distinct_investors ?? 0).toLocaleString('en-IN')}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Distributions</h2>
        <DataTable
          rows={distributions}
          columns={distColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable
          rows={recent}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
