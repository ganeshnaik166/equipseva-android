import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [ndasRes, expiringRes, sharesRes] = await Promise.all([
    sb.rpc('list_ndas_r1801'),
    sb.rpc('expiring_ndas_r1801'),
    sb.rpc('recent_shares_r1801'),
  ]);

  const ndas: any[] = Array.isArray(ndasRes.data) ? ndasRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];
  const shares: any[] = Array.isArray(sharesRes.data) ? sharesRes.data : [];

  const active = ndas.filter((n) => n.status === 'active').length;
  const expired = ndas.filter((n) => n.status === 'expired').length;
  const terminated = ndas.filter((n) => n.status === 'terminated').length;

  const ndaCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'nda_purpose', header: 'Purpose', render: (r: any) => <span>{r.nda_purpose}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'nda_signed_at', header: 'Signed', render: (r: any) => <span>{r.nda_signed_at ? new Date(r.nda_signed_at).toLocaleDateString() : '—'}</span> },
    { key: 'nda_expires_at', header: 'Expires', render: (r: any) => <span>{r.nda_expires_at ? new Date(r.nda_expires_at).toLocaleDateString() : '—'}</span> },
    { key: 'days_to_expiry', header: 'Days Left', render: (r: any) => <span>{r.days_to_expiry ?? 0}</span> },
    { key: 'nda_url', header: 'URL', render: (r: any) => <a href={r.nda_url} target="_blank" rel="noreferrer" style={{ color: '#2563eb' }}>open</a> },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'nda_purpose', header: 'Purpose', render: (r: any) => <span>{r.nda_purpose}</span> },
    { key: 'nda_expires_at', header: 'Expires', render: (r: any) => <span>{r.nda_expires_at ? new Date(r.nda_expires_at).toLocaleDateString() : '—'}</span> },
    { key: 'days_to_expiry', header: 'Days Left', render: (r: any) => <strong style={{ color: r.days_to_expiry < 14 ? '#dc2626' : '#ca8a04' }}>{r.days_to_expiry}</strong> },
  ];

  const sharesCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'document_shared', header: 'Document', render: (r: any) => <span>{r.document_shared}</span> },
    { key: 'shared_at', header: 'Shared', render: (r: any) => <span>{r.shared_at ? new Date(r.shared_at).toLocaleString() : '—'}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{r.by_email}</span> },
    { key: 'has_response', header: 'Response?', render: (r: any) => <span>{r.has_response ? 'yes' : 'pending'}</span> },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Investor Confidential NDA Vault</h1>
        <p style={{ color: '#64748b', marginTop: 4 }}>Executed NDAs with investors & expiry tracking.</p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Total NDAs</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{ndas.length}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Active</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#16a34a' }}>{active}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Expired</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#dc2626' }}>{expired}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#64748b' }}>Terminated</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#64748b' }}>{terminated}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Expiring within 60 days</h2>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All NDAs</h2>
        <DataTable rows={ndas} columns={ndaCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent document shares</h2>
        <DataTable rows={shares} columns={sharesCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
