import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [holdingsRes, totalsRes, recentRes] = await Promise.all([
    sb.rpc('list_crypto_holdings_r1957'),
    sb.rpc('total_crypto_value_r1957'),
    sb.rpc('recent_crypto_actions_r1957'),
  ]);

  const holdings: any[] = Array.isArray(holdingsRes.data) ? holdingsRes.data : [];
  const totals: any[] = Array.isArray(totalsRes.data) ? totalsRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const holdingsCols: Column<any>[] = [
    { key: 'asset_symbol', header: 'Asset', render: (r: any) => String(r.asset_symbol ?? '') },
    { key: 'holding_quantity', header: 'Quantity', render: (r: any) => String(r.holding_quantity ?? 0) },
    { key: 'avg_cost_basis_rupees', header: 'Avg Cost (rupees)', render: (r: any) => String(r.avg_cost_basis_rupees ?? 0) },
    { key: 'current_value_rupees', header: 'Current Value (rupees)', render: (r: any) => String(r.current_value_rupees ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'custodian', header: 'Custodian', render: (r: any) => String(r.custodian ?? '') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
  ];

  const totalsCols: Column<any>[] = [
    { key: 'asset_symbol', header: 'Asset', render: (r: any) => String(r.asset_symbol ?? '') },
    { key: 'holdings_count', header: 'Active Holdings', render: (r: any) => String(r.holdings_count ?? 0) },
    { key: 'total_value_rupees', header: 'Total Value (rupees)', render: (r: any) => String(r.total_value_rupees ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'treasury_id', header: 'Treasury', render: (r: any) => String(r.treasury_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'quantity_change', header: 'Qty Change', render: (r: any) => String(r.quantity_change ?? 0) },
    { key: 'value_change_rupees', header: 'Value Change (rupees)', render: (r: any) => String(r.value_change_rupees ?? 0) },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Crypto Treasury Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track corporate crypto holdings across custodians. Covers BTC, ETH, USDC, USDT and other digital assets with at least one logged action per state change.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Totals by Asset (active only)</h2>
        <DataTable rows={totals} columns={totalsCols} rowKey={(r: any, i: number) => String(r.asset_symbol ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Holdings</h2>
        <DataTable rows={holdings} columns={holdingsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Treasury Actions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
