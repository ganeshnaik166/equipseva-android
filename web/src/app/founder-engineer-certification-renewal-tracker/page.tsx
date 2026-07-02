import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [renewalsRes, expiringRes, recentRes] = await Promise.all([
    sb.rpc('list_renewals_r2024'),
    sb.rpc('expiring_certs_r2024'),
    sb.rpc('recent_actions_r2024', { p_limit: 50 }),
  ]);

  const renewals: any[] = renewalsRes.data ?? [];
  const expiring: any[] = expiringRes.data ?? [];
  const recent: any[] = recentRes.data ?? [];

  const renewalCols: Column<any>[] = [
    { key: 'cert_label', header: 'Cert', render: (r: any) => String(r.cert_label ?? '') },
    { key: 'cert_authority', header: 'Authority', render: (r: any) => String(r.cert_authority ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'expiry_date', header: 'Expiry', render: (r: any) => String(r.expiry_date ?? '') },
    { key: 'renewal_required_by', header: 'Renew By', render: (r: any) => String(r.renewal_required_by ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'cert_label', header: 'Cert', render: (r: any) => String(r.cert_label ?? '') },
    { key: 'cert_authority', header: 'Authority', render: (r: any) => String(r.cert_authority ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'expiry_date', header: 'Expiry', render: (r: any) => String(r.expiry_date ?? '') },
    { key: 'days_to_expiry', header: 'Days Left', render: (r: any) => String(r.days_to_expiry ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'renewal_id', header: 'Renewal', render: (r: any) => String(r.renewal_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'cost_rupees', header: 'Cost (rupees)', render: (r: any) => r.cost_rupees == null ? '' : String(r.cost_rupees) },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Certification Renewal Tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track engineer credential expiries, renewal deadlines, and remediation actions. Catch lapses before they
        block field deployment.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Renewals</h2>
        <DataTable
          rows={renewals}
          columns={renewalCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Expiring Within Sixty Days</h2>
        <DataTable
          rows={expiring}
          columns={expiringCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable
          rows={recent}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
