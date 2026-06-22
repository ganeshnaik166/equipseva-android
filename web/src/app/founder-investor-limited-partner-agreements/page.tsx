import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorLimitedPartnerAgreementsPage() {
  const sb = await getSupabaseServerClient();

  const [agreementsRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_lpa_agreements_r2053'),
    sb.rpc('active_lpa_agreements_r2053'),
    sb.rpc('recent_lpa_actions_r2053'),
  ]);

  const agreements: any[] = Array.isArray(agreementsRes.data) ? agreementsRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const agreementCols: Column<any>[] = [
    { key: 'agreement_label', header: 'Label', render: (r: any) => String(r.agreement_label ?? '') },
    { key: 'agreement_version', header: 'Version', render: (r: any) => String(r.agreement_version ?? '') },
    { key: 'investor_email', header: 'Investor', render: (r: any) => String(r.investor_email ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'signed_at', header: 'Signed', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'agreement_label', header: 'Label', render: (r: any) => String(r.agreement_label ?? '') },
    { key: 'agreement_version', header: 'Version', render: (r: any) => String(r.agreement_version ?? '') },
    { key: 'investor_email', header: 'Investor', render: (r: any) => String(r.investor_email ?? '') },
    { key: 'signed_at', header: 'Signed', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'agreement_label', header: 'Agreement', render: (r: any) => String(r.agreement_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Limited Partner Agreements</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track LP agreements, versions, signature events, and lifecycle actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active Agreements</h2>
        <DataTable
          rows={active}
          columns={activeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Agreements</h2>
        <DataTable
          rows={agreements}
          columns={agreementCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
