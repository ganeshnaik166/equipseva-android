import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? '';

  const [summaryRes, integrationsRes, chainsRes, vendorsRes] = await Promise.all([
    supabase.rpc('r2367_summary'),
    supabase.rpc('r2367_list_integrations'),
    supabase.rpc('r2367_chain_rollup'),
    supabase.rpc('r2367_top_risk_vendors'),
  ]);

  const summary = (summaryRes.data ?? [])[0] ?? null;
  const integrations = integrationsRes.data ?? [];
  const chains = chainsRes.data ?? [];
  const vendors = vendorsRes.data ?? [];

  const intCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'integration_name', header: 'Integration', render: (r) => r.integration_name },
    { key: 'integration_type', header: 'Type', render: (r) => r.integration_type },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'criticality', header: 'Criticality', render: (r) => r.criticality },
    { key: 'dep_count', header: 'Deps', render: (r) => String(r.dep_count) },
    { key: 'blocking_count', header: 'Blocking', render: (r) => String(r.blocking_count) },
    { key: 'avg_health', header: 'Avg health', render: (r) => Number(r.avg_health).toFixed(1) },
    { key: 'monthly_volume_cents', header: 'Monthly vol', render: (r) => `₹${(Number(r.monthly_volume_cents)/100).toLocaleString('en-IN')}` },
    { key: 'go_live_date', header: 'Go-live', render: (r) => r.go_live_date },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'integration_count', header: 'Integrations', render: (r) => String(r.integration_count) },
    { key: 'live_count', header: 'Live', render: (r) => String(r.live_count) },
    { key: 'degraded_count', header: 'Degraded', render: (r) => String(r.degraded_count) },
    { key: 'down_count', header: 'Down', render: (r) => String(r.down_count) },
    { key: 'total_monthly_volume_cents', header: 'Monthly vol', render: (r) => `₹${(Number(r.total_monthly_volume_cents)/100).toLocaleString('en-IN')}` },
    { key: 'avg_health', header: 'Avg health', render: (r) => Number(r.avg_health).toFixed(1) },
  ];

  const vendorCols: Column<any>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r) => r.vendor_name },
    { key: 'integration_count', header: 'Integrations', render: (r) => String(r.integration_count) },
    { key: 'avg_health', header: 'Avg health', render: (r) => Number(r.avg_health).toFixed(1) },
    { key: 'blocking_count', header: 'Blocking', render: (r) => String(r.blocking_count) },
    { key: 'last_incident_at', header: 'Last incident', render: (r) => r.last_incident_at ? new Date(r.last_incident_at).toLocaleString() : '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700 }}>Hospital chain integration & dependency tracker</h1>
      <p style={{ color: '#555', marginTop: 4 }}>
        Per-integration 3rd-party dependency map, health rollups & fallback plans. Founder: {email || 'unknown'}.
      </p>

      {summary && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginTop: 16 }}>
          <Card label="Integrations" value={String(summary.total_integrations)} />
          <Card label="Live" value={String(summary.live_integrations)} />
          <Card label="Degraded" value={String(summary.degraded_integrations)} />
          <Card label="Down" value={String(summary.down_integrations)} />
          <Card label="Total deps" value={String(summary.total_deps)} />
          <Card label="Blocking deps" value={String(summary.blocking_deps)} />
          <Card label="Avg health" value={Number(summary.avg_health).toFixed(1)} />
          <Card label="Monthly volume" value={`₹${(Number(summary.total_monthly_volume_cents)/100).toLocaleString('en-IN')}`} />
        </section>
      )}

      <h2 style={{ fontSize: 16, fontWeight: 600, marginTop: 24 }}>Integrations</h2>
      <DataTable rows={integrations} emptyMessage="No integrations tracked" rowKey={(r: any) => r.id} columns={intCols} />

      <h2 style={{ fontSize: 16, fontWeight: 600, marginTop: 24 }}>Chain rollup</h2>
      <DataTable rows={chains} emptyMessage="No chains" rowKey={(r: any) => r.chain_name} columns={chainCols} />

      <h2 style={{ fontSize: 16, fontWeight: 600, marginTop: 24 }}>Top risk vendors</h2>
      <DataTable rows={vendors} emptyMessage="No vendor data" rowKey={(r: any) => r.vendor_name} columns={vendorCols} />
    </main>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
