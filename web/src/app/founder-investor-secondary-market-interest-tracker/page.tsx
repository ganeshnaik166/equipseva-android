import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [iRes, sRes, mRes, aRes] = await Promise.all([
    sb.rpc('list_interests_r2202'),
    sb.rpc('top_side_r2202'),
    sb.rpc('list_matches_r2202'),
    sb.rpc('recent_actions_r2202'),
  ]);

  const interests: any[] = Array.isArray(iRes.data) ? iRes.data : [];
  const sides: any[] = Array.isArray(sRes.data) ? sRes.data : [];
  const matches: any[] = Array.isArray(mRes.data) ? mRes.data : [];
  const actions: any[] = Array.isArray(aRes.data) ? aRes.data : [];

  const totalOpen = interests.filter((r) => r.status === 'open').length;
  const totalBuy = interests.filter((r) => r.side === 'buy').length;
  const totalSell = interests.filter((r) => r.side === 'sell').length;
  const totalShares = interests.reduce((s, r) => s + Number(r.shares_qty || 0), 0);

  const interestCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => String(r.investor_name ?? '') },
    { key: 'investor_org', header: 'Org', render: (r: any) => String(r.investor_org ?? '') },
    { key: 'side', header: 'Side', render: (r: any) => String(r.side ?? '').toUpperCase() },
    { key: 'share_class', header: 'Class', render: (r: any) => String(r.share_class ?? '') },
    { key: 'shares_qty', header: 'Shares', render: (r: any) => Number(r.shares_qty ?? 0).toLocaleString('en-IN') },
    { key: 'price_min_rupees', header: 'Price Min', render: (r: any) => '₹' + Number(r.price_min_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'price_max_rupees', header: 'Price Max', render: (r: any) => '₹' + Number(r.price_max_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'implied_valuation_cr', header: 'Implied Val (Cr)', render: (r: any) => r.implied_valuation_cr != null ? Number(r.implied_valuation_cr).toFixed(2) : '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString('en-IN') : '' },
  ];

  const sideCols: Column<any>[] = [
    { key: 'side', header: 'Side', render: (r: any) => String(r.side ?? '').toUpperCase() },
    { key: 'open_count', header: 'Open', render: (r: any) => Number(r.open_count ?? 0).toLocaleString('en-IN') },
    { key: 'matched_count', header: 'Matched', render: (r: any) => Number(r.matched_count ?? 0).toLocaleString('en-IN') },
    { key: 'total_shares', header: 'Total Shares', render: (r: any) => Number(r.total_shares ?? 0).toLocaleString('en-IN') },
    { key: 'avg_price_min', header: 'Avg Min', render: (r: any) => '₹' + Number(r.avg_price_min ?? 0).toLocaleString('en-IN') },
    { key: 'avg_price_max', header: 'Avg Max', render: (r: any) => '₹' + Number(r.avg_price_max ?? 0).toLocaleString('en-IN') },
  ];

  const matchCols: Column<any>[] = [
    { key: 'buy_investor', header: 'Buyer', render: (r: any) => String(r.buy_investor ?? '') },
    { key: 'sell_investor', header: 'Seller', render: (r: any) => String(r.sell_investor ?? '') },
    { key: 'matched_shares_qty', header: 'Shares', render: (r: any) => Number(r.matched_shares_qty ?? 0).toLocaleString('en-IN') },
    { key: 'matched_price_rupees', header: 'Price', render: (r: any) => '₹' + Number(r.matched_price_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'match_status', header: 'Status', render: (r: any) => String(r.match_status ?? '') },
    { key: 'match_notes', header: 'Notes', render: (r: any) => String(r.match_notes ?? '') },
    { key: 'created_at', header: 'Logged', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'op_name', header: 'Op', render: (r: any) => String(r.op_name ?? '') },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    { key: 'after_value', header: 'Payload', render: (r: any) => r.after_value ? JSON.stringify(r.after_value) : '' },
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Investor Secondary Market Interest Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Track buy & sell expressions of interest at specific price ranges & match log.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Open Interests</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalOpen}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Buy-side</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalBuy}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Sell-side</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalSell}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Shares Interest</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalShares.toLocaleString('en-IN')}</div>
        </div>
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '16px 0 8px' }}>Side Aggregates</h2>
      <DataTable columns={sideCols} rows={sides} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Recent Interests</h2>
      <DataTable columns={interestCols} rows={interests} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Match Log</h2>
      <DataTable columns={matchCols} rows={matches} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Action Log</h2>
      <DataTable columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />
    </main>
  );
}
