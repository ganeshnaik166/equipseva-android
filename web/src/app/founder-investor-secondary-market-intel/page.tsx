import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Math.round(Number(n)).toLocaleString('en-IN');
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return 'Rs 0';
  const v = Number(n);
  if (v >= 10000000) return 'Rs ' + (v / 10000000).toFixed(2) + ' Cr';
  if (v >= 100000) return 'Rs ' + (v / 100000).toFixed(2) + ' L';
  return 'Rs ' + Math.round(v).toLocaleString('en-IN');
}

function fmtPrice(n: number | null | undefined): string {
  if (n === null || n === undefined) return 'Rs 0';
  return 'Rs ' + Number(n).toFixed(2);
}

export default async function FounderSecondaryMarketIntelPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let recent: any[] = [];
  let pending: any[] = [];
  let trajectory: any[] = [];
  let watchlist: any[] = [];

  try {
    const r = await sb.rpc('founder_smt_kpis');
    kpis = r.data ?? {};
  } catch (_e) { kpis = {}; }

  try {
    const r = await sb.rpc('founder_smt_recent_transactions', { p_limit: 50 });
    recent = (r.data as any[]) ?? [];
  } catch (_e) { recent = []; }

  try {
    const r = await sb.rpc('founder_smt_pending_rofr');
    pending = (r.data as any[]) ?? [];
  } catch (_e) { pending = []; }

  try {
    const r = await sb.rpc('founder_smt_price_trajectory');
    trajectory = (r.data as any[]) ?? [];
  } catch (_e) { trajectory = []; }

  try {
    const r = await sb.rpc('founder_smt_watchlist');
    watchlist = (r.data as any[]) ?? [];
  } catch (_e) { watchlist = []; }

  const cards: Kpi[] = [
    { label: 'Total Txns', value: fmtInt(kpis.total_txns) },
    { label: 'YTD Txns', value: fmtInt(kpis.ytd_txns) },
    { label: 'Recent 90d Txns', value: fmtInt(kpis.recent_txns_90d) },
    { label: 'Total Value', value: fmtRupees(kpis.total_value_rupees) },
    { label: 'YTD Value', value: fmtRupees(kpis.ytd_value_rupees) },
    { label: 'Recent 90d Value', value: fmtRupees(kpis.recent_value_rupees) },
    { label: 'Avg Price/Share (90d)', value: fmtPrice(kpis.avg_price_per_share) },
    { label: 'Max Price/Share (90d)', value: fmtPrice(kpis.max_price_per_share) },
    { label: 'Min Price/Share (90d)', value: fmtPrice(kpis.min_price_per_share) },
    { label: 'Latest Implied Val', value: fmtRupees(kpis.implied_valuation_latest) },
    { label: 'Pending RoFR', value: fmtInt(kpis.pending_rofr_count) },
    { label: 'Exercised RoFR', value: fmtInt(kpis.exercised_rofr_count) },
    { label: 'Waived RoFR', value: fmtInt(kpis.waived_rofr_count) },
    { label: 'Watchlist Parties', value: fmtInt(kpis.watchlist_count) },
    { label: 'Hard Sell Intent', value: fmtInt(kpis.hard_intent_count) },
    { label: 'Tracked Counterparties', value: fmtInt(kpis.tracked_counterparties) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'txn_date', header: 'Date', render: (r: any) => r.txn_date ?? '—' },
    { key: 'seller_name', header: 'Seller', render: (r: any) => r.seller_name ?? '—' },
    { key: 'seller_type', header: 'Seller Type', render: (r: any) => r.seller_type ?? '—' },
    { key: 'buyer_name', header: 'Buyer', render: (r: any) => r.buyer_name ?? '—' },
    { key: 'share_count', header: 'Shares', render: (r: any) => fmtInt(r.share_count) },
    { key: 'price_per_share_rupees', header: 'Price/Share', render: (r: any) => fmtPrice(r.price_per_share_rupees) },
    { key: 'total_value_rupees', header: 'Total', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'rofr_status', header: 'RoFR', render: (r: any) => r.rofr_status ?? '—' },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'txn_date', header: 'Date', render: (r: any) => r.txn_date ?? '—' },
    { key: 'seller_name', header: 'Seller', render: (r: any) => r.seller_name ?? '—' },
    { key: 'share_count', header: 'Shares', render: (r: any) => fmtInt(r.share_count) },
    { key: 'price_per_share_rupees', header: 'Price/Share', render: (r: any) => fmtPrice(r.price_per_share_rupees) },
    { key: 'total_value_rupees', header: 'Total', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'rofr_deadline', header: 'Deadline', render: (r: any) => r.rofr_deadline ?? '—' },
    { key: 'days_to_deadline', header: 'Days Left', render: (r: any) => fmtInt(r.days_to_deadline) },
  ];

  const trajCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ?? '—' },
    { key: 'txn_count', header: 'Txns', render: (r: any) => fmtInt(r.txn_count) },
    { key: 'avg_price', header: 'Avg Price', render: (r: any) => fmtPrice(r.avg_price) },
    { key: 'max_price', header: 'Max Price', render: (r: any) => fmtPrice(r.max_price) },
    { key: 'total_volume', header: 'Volume', render: (r: any) => fmtRupees(r.total_volume) },
  ];

  const watchCols: Column<any>[] = [
    { key: 'party_name', header: 'Party', render: (r: any) => r.party_name ?? '—' },
    { key: 'party_type', header: 'Type', render: (r: any) => r.party_type ?? '—' },
    { key: 'current_holding_shares', header: 'Holding', render: (r: any) => fmtInt(r.current_holding_shares) },
    { key: 'intent_to_sell', header: 'Intent', render: (r: any) => r.intent_to_sell ?? '—' },
    { key: 'last_signal_at', header: 'Last Signal', render: (r: any) => r.last_signal_at ? new Date(r.last_signal_at).toLocaleDateString('en-IN') : '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Investor Secondary Market Intel</h1>
        <p className="text-sm text-gray-600">Per-transaction price, counterparty intel, and founder right-of-first-refusal tracking on our cap-table secondary sales.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map((k) => (
          <div key={k.label} className="rounded-lg border bg-white p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Transactions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pending RoFR Decisions</h2>
        <DataTable rows={pending} columns={pendingCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Price Trajectory (12 mo)</h2>
        <DataTable rows={trajectory} columns={trajCols} rowKey={(r: any) => String(r.month_start)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Counterparty Watchlist</h2>
        <DataTable rows={watchlist} columns={watchCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
