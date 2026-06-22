import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [contractsRes, expiringRes, recentRes] = await Promise.all([
    sb.rpc('list_contracts_r1959'),
    sb.rpc('expiring_soon_r1959'),
    sb.rpc('recent_renewals_r1959'),
  ]);

  const contracts: any[] = Array.isArray(contractsRes.data) ? contractsRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalValue = contracts.reduce((s, r) => s + Number(r.total_value_rupees || 0), 0);
  const activeCount = contracts.filter((r) => r.status === 'active').length;
  const renewedCount = contracts.filter((r) => r.status === 'renewed').length;
  const lostCount = contracts.filter((r) => r.status === 'lost').length;

  const contractCols: Column<any>[] = [
    { key: 'contract_label', header: 'Contract', render: (r: any) => String(r.contract_label ?? '') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '') },
    { key: 'contract_years', header: 'Years', render: (r: any) => String(r.contract_years ?? '') },
    { key: 'total_value_rupees', header: 'Value (Rs)', render: (r: any) => Number(r.total_value_rupees || 0).toLocaleString('en-IN') },
    { key: 'signed_date', header: 'Signed', render: (r: any) => r.signed_date ? String(r.signed_date) : '-' },
    { key: 'expiry_date', header: 'Expiry', render: (r: any) => r.expiry_date ? String(r.expiry_date) : '-' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '-' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'contract_label', header: 'Contract', render: (r: any) => String(r.contract_label ?? '') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '') },
    { key: 'expiry_date', header: 'Expiry', render: (r: any) => String(r.expiry_date ?? '') },
    { key: 'days_to_expiry', header: 'Days Left', render: (r: any) => String(r.days_to_expiry ?? '') },
    { key: 'total_value_rupees', header: 'Value (Rs)', render: (r: any) => Number(r.total_value_rupees || 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const renewalCols: Column<any>[] = [
    { key: 'contract_label', header: 'Contract', render: (r: any) => String(r.contract_label ?? '') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'value_change_rupees', header: 'Value Change (Rs)', render: (r: any) => Number(r.value_change_rupees || 0).toLocaleString('en-IN') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '-' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Multi-Year Contract Pipeline</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Track multi-year hospital contracts: pipeline, expiring contracts &lt;= 90 days, and renewal log.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Contracts</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{contracts.length}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{activeCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Renewed / Lost</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{renewedCount} / {lostCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Pipeline Value (Rs)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{totalValue.toLocaleString('en-IN')}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Contracts</h2>
        <DataTable rows={contracts} columns={contractCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Expiring Soon (next 90 days)</h2>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Renewal Activity</h2>
        <DataTable rows={recent} columns={renewalCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
