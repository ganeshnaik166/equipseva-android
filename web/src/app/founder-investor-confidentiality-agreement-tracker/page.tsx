import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [agreementsRes, expiringRes, recentRes] = await Promise.all([
    sb.rpc('list_agreements_r2069'),
    sb.rpc('expiring_soon_r2069', { p_days: 30 }),
    sb.rpc('recent_actions_r2069', { p_limit: 50 }),
  ]);

  const agreements: any[] = Array.isArray(agreementsRes.data) ? agreementsRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const agreementCols: Column<any>[] = [
    { key: 'agreement_label', header: 'Label', render: (r: any) => String(r.agreement_label ?? '') },
    { key: 'agreement_type', header: 'Type', render: (r: any) => String(r.agreement_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'signed_at', header: 'Signed', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'agreement_label', header: 'Label', render: (r: any) => String(r.agreement_label ?? '') },
    { key: 'agreement_type', header: 'Type', render: (r: any) => String(r.agreement_type ?? '') },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'agreement_id', header: 'Agreement', render: (r: any) => String(r.agreement_id ?? '').slice(0, 8) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Confidentiality Agreement Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track NDAs and confidentiality agreements across investor relationships. Founder only.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Agreements</h2>
        <DataTable rows={agreements} columns={agreementCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Expiring Soon (next 30 days)</h2>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
