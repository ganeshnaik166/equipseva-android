import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [benefRes, docsRes, summaryRes, expiringRes] = await Promise.all([
    sb.rpc('list_beneficiaries_r1753', { p_investor_id: null }),
    sb.rpc('list_documents_r1753', { p_beneficiary_id: null }),
    sb.rpc('beneficiary_summary_per_investor_r1753'),
    sb.rpc('expiring_documents_r1753', { p_days: 90 }),
  ]);

  const beneficiaries: any[] = benefRes.data ?? [];
  const documents: any[] = docsRes.data ?? [];
  const summary: any[] = summaryRes.data ?? [];
  const expiring: any[] = expiringRes.data ?? [];

  const benefColumns: Column<any>[] = [
    { key: 'beneficiary_name', header: 'Name', render: (r: any) => r.beneficiary_name },
    { key: 'beneficiary_relationship', header: 'Relationship', render: (r: any) => r.beneficiary_relationship },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'allocation_pct', header: 'Allocation %', render: (r: any) => `${Number(r.allocation_pct ?? 0).toFixed(2)}%` },
    { key: 'is_primary', header: 'Primary', render: (r: any) => (r.is_primary ? 'yes' : 'no') },
    { key: 'is_contingent', header: 'Contingent', render: (r: any) => (r.is_contingent ? 'yes' : 'no') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'beneficiary_email', header: 'Email', render: (r: any) => r.beneficiary_email ?? '—' },
    { key: 'beneficiary_phone', header: 'Phone', render: (r: any) => r.beneficiary_phone ?? '—' },
    { key: 'set_at', header: 'Set At', render: (r: any) => (r.set_at ? new Date(r.set_at).toLocaleDateString() : '—') },
  ];

  const docColumns: Column<any>[] = [
    { key: 'document_name', header: 'Document', render: (r: any) => r.document_name },
    { key: 'document_type', header: 'Type', render: (r: any) => r.document_type },
    { key: 'beneficiary_name', header: 'Beneficiary', render: (r: any) => r.beneficiary_name ?? '—' },
    { key: 'uploaded_at', header: 'Uploaded', render: (r: any) => (r.uploaded_at ? new Date(r.uploaded_at).toLocaleDateString() : '—') },
    { key: 'expires_at', header: 'Expires', render: (r: any) => (r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—') },
  ];

  const summaryColumns: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'total_beneficiaries', header: 'Total', render: (r: any) => r.total_beneficiaries },
    { key: 'primary_count', header: 'Primary', render: (r: any) => r.primary_count },
    { key: 'contingent_count', header: 'Contingent', render: (r: any) => r.contingent_count },
    { key: 'active_count', header: 'Active', render: (r: any) => r.active_count },
    { key: 'total_allocation_pct', header: 'Total Alloc %', render: (r: any) => `${Number(r.total_allocation_pct ?? 0).toFixed(2)}%` },
    { key: 'document_count', header: 'Docs', render: (r: any) => r.document_count },
  ];

  const expiringColumns: Column<any>[] = [
    { key: 'document_name', header: 'Document', render: (r: any) => r.document_name },
    { key: 'document_type', header: 'Type', render: (r: any) => r.document_type },
    { key: 'beneficiary_name', header: 'Beneficiary', render: (r: any) => r.beneficiary_name ?? '—' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => (r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—') },
    { key: 'days_until_expiry', header: 'Days Left', render: (r: any) => r.days_until_expiry },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor Beneficiary Roster</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track per-investor designated beneficiaries for death & incapacity events. Allocation totals
        across active beneficiaries should be &lt;= 100%. Documents expiring within 90 days surface in the
        section below.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Beneficiaries ({beneficiaries.length})</h2>
        <DataTable rows={beneficiaries} columns={benefColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Summary per Investor ({summary.length})</h2>
        <DataTable rows={summary} columns={summaryColumns} rowKey={(r: any, i: number) => String(r.investor_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Documents ({documents.length})</h2>
        <DataTable rows={documents} columns={docColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Expiring Documents (next 90 days, {expiring.length})
        </h2>
        <DataTable rows={expiring} columns={expiringColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
