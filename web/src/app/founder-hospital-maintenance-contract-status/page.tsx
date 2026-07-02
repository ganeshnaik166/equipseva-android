import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [contractsRes, expiringRes, recentRes] = await Promise.all([
    sb.rpc('list_contracts_r2051', { p_limit: 200 }),
    sb.rpc('expiring_soon_r2051', { p_within_days: 60, p_limit: 100 }),
    sb.rpc('recent_actions_r2051', { p_limit: 50 }),
  ]);

  const contracts: any[] = Array.isArray(contractsRes.data) ? contractsRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalMonthly = contracts.reduce(
    (acc, r) => acc + Number(r?.monthly_value_rupees || 0),
    0,
  );
  const activeCount = contracts.filter((r) => r?.status === 'active').length;
  const expiringCount = contracts.filter((r) => r?.status === 'expiring_soon').length;
  const lostCount = contracts.filter((r) => r?.status === 'lost').length;

  const contractCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r?.hospital_name ?? r?.hospital_id ?? '') },
    { key: 'contract_label', header: 'Contract', render: (r: any) => String(r?.contract_label ?? '') },
    { key: 'monthly_value_rupees', header: 'Monthly value', render: (r: any) => `Rs ${Number(r?.monthly_value_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'contract_end_date', header: 'Ends', render: (r: any) => String(r?.contract_end_date ?? '') },
    { key: 'days_until_expiry', header: 'Days left', render: (r: any) => String(r?.days_until_expiry ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r?.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r?.captured_at ? new Date(r.captured_at).toLocaleString('en-IN') : '' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r?.hospital_name ?? r?.hospital_id ?? '') },
    { key: 'contract_label', header: 'Contract', render: (r: any) => String(r?.contract_label ?? '') },
    { key: 'monthly_value_rupees', header: 'Monthly value', render: (r: any) => `Rs ${Number(r?.monthly_value_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'contract_end_date', header: 'Ends', render: (r: any) => String(r?.contract_end_date ?? '') },
    { key: 'days_until_expiry', header: 'Days left', render: (r: any) => String(r?.days_until_expiry ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r?.status ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r?.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '' },
    { key: 'contract_label', header: 'Contract', render: (r: any) => String(r?.contract_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r?.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r?.by_email ?? '') },
    { key: 'value_change_rupees', header: 'Value change', render: (r: any) => `Rs ${Number(r?.value_change_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r?.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>Hospital Maintenance Contract Status</h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Round 2051. Track every AMC and maintenance contract, the days remaining, and the renewal action log.
        </p>
      </header>

      <section style={{ marginBottom: 24, display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
        <Stat label="Total contracts" value={String(contracts.length)} />
        <Stat label="Active" value={String(activeCount)} />
        <Stat label="Expiring soon" value={String(expiringCount)} />
        <Stat label="Lost" value={String(lostCount)} />
        <Stat label="Monthly book" value={`Rs ${Number(totalMonthly).toLocaleString('en-IN')}`} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All contracts</h2>
        <DataTable rows={contracts} columns={contractCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Expiring within 60 days</h2>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent action log</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
