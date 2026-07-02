import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [accountsRes, escalationsRes, tiersRes, healthRes] = await Promise.all([
    sb.rpc('list_vip_accounts_r2204'),
    sb.rpc('recent_actions_r2204'),
    sb.rpc('top_tier_r2204'),
    sb.rpc('aggregate_sla_health_r2204'),
  ]);

  const accounts: any[] = Array.isArray(accountsRes.data) ? accountsRes.data : [];
  const escalations: any[] = Array.isArray(escalationsRes.data) ? escalationsRes.data : [];
  const tiers: any[] = Array.isArray(tiersRes.data) ? tiersRes.data : [];
  const health: any = Array.isArray(healthRes.data) && healthRes.data.length > 0 ? healthRes.data[0] : null;

  const accountCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'tier', header: 'Tier', render: (r: any) => String(r.tier ?? '').toUpperCase() },
    { key: 'annual_revenue_rupees', header: 'Annual Rev', render: (r: any) => `₹${Number(r.annual_revenue_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'dedicated_csm_email', header: 'CSM', render: (r: any) => String(r.dedicated_csm_email ?? '—') },
    { key: 'response_sla_minutes', header: 'Resp SLA (min)', render: (r: any) => String(r.response_sla_minutes ?? 0) },
    { key: 'resolution_sla_hours', header: 'Resolve SLA (hr)', render: (r: any) => String(r.resolution_sla_hours ?? 0) },
    { key: 'fast_track_enabled', header: 'Fast-track', render: (r: any) => r.fast_track_enabled ? 'YES' : 'no' },
    { key: 'open_escalations', header: 'Open Esc.', render: (r: any) => String(r.open_escalations ?? 0) },
  ];

  const escCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'tier', header: 'Tier', render: (r: any) => String(r.tier ?? '').toUpperCase() },
    { key: 'subject', header: 'Subject', render: (r: any) => String(r.subject ?? '') },
    { key: 'severity', header: 'Sev', render: (r: any) => String(r.severity ?? '').toUpperCase() },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'routed_to_csm_email', header: 'Routed CSM', render: (r: any) => String(r.routed_to_csm_email ?? '—') },
    { key: 'breached_response', header: 'Resp Breach', render: (r: any) => r.breached_response ? 'YES' : 'no' },
    { key: 'breached_resolution', header: 'Resolve Breach', render: (r: any) => r.breached_resolution ? 'YES' : 'no' },
    { key: 'created_at', header: 'Opened', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '' },
  ];

  const tierCols: Column<any>[] = [
    { key: 'tier', header: 'Tier', render: (r: any) => String(r.tier ?? '').toUpperCase() },
    { key: 'account_count', header: 'Accounts', render: (r: any) => String(r.account_count ?? 0) },
    { key: 'open_escalations', header: 'Open Esc.', render: (r: any) => String(r.open_escalations ?? 0) },
    { key: 'breached_total', header: 'Breaches', render: (r: any) => String(r.breached_total ?? 0) },
    { key: 'total_revenue_rupees', header: 'Total Rev', render: (r: any) => `₹${Number(r.total_revenue_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital VIP Customer Escalation Router</h1>
        <p className="text-sm text-gray-600">Top revenue hospitals get fast-track escalation paths & tighter SLAs than standard accounts.</p>
      </header>

      {health && (
        <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
          <div className="border rounded p-3"><div className="text-xs text-gray-500">VIP Accounts</div><div className="text-xl font-semibold">{health.total_vip_accounts ?? 0}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Platinum</div><div className="text-xl font-semibold">{health.platinum_accounts ?? 0}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Open Esc.</div><div className="text-xl font-semibold">{health.open_escalations ?? 0}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Resp Breaches</div><div className="text-xl font-semibold">{health.response_breaches ?? 0}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Resolve Breaches</div><div className="text-xl font-semibold">{health.resolution_breaches ?? 0}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Total VIP Rev</div><div className="text-xl font-semibold">₹{Number(health.total_vip_revenue_rupees ?? 0).toLocaleString('en-IN')}</div></div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">VIP Accounts &amp; SLA tier</h2>
        <DataTable columns={accountCols} rows={accounts} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier rollup</h2>
        <DataTable columns={tierCols} rows={tiers} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent escalations</h2>
        <DataTable columns={escCols} rows={escalations} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
