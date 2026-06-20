import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';
import Link from 'next/link';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type Summary = {
  total_listings: number;
  active_listings: number;
  reserved_listings: number;
  sold_listings: number;
  withdrawn_listings: number;
  flagged_listings: number;
  total_bids: number;
  accepted_bids: number;
  rejected_bids: number;
  pending_bids: number;
  total_transactions: number;
  pending_payment_txn: number;
  escrow_held_txn: number;
  complete_txn: number;
  total_transaction_volume_rupees: number;
  avg_listing_price_rupees: number;
  total_platform_fees_rupees: number;
  top_part_category: string;
};

type ListingRow = {
  id: string;
  seller_engineer_user_id: string;
  part_category: string;
  part_label: string;
  manufacturer: string | null;
  condition_band: string;
  ask_price_rupees: number;
  quantity_available: number;
  listing_status: string;
  listed_at: string;
  expires_at: string;
};

type TxnRow = {
  id: string;
  listing_id: string | null;
  bid_id: string | null;
  seller_engineer_user_id: string;
  buyer_engineer_user_id: string;
  transaction_amount_rupees: number;
  platform_fee_rupees: number;
  transaction_status: string;
  shipped_at: string | null;
  delivered_at: string | null;
  completed_at: string | null;
  created_at: string;
};

export default async function FounderEngineerP2PPartsMarketplacePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: sumData }, { data: listingsData }, { data: txnsData }] = await Promise.all([
    supabase.rpc('founder_engineer_p2p_marketplace_summary'),
    supabase.rpc('founder_engineer_p2p_listings_recent', { p_status: null, p_limit: 50 }),
    supabase.rpc('founder_engineer_p2p_transactions_recent', { p_limit: 50 }),
  ]);

  const s: Summary = (sumData?.[0] as Summary) ?? {
    total_listings: 0,
    active_listings: 0,
    reserved_listings: 0,
    sold_listings: 0,
    withdrawn_listings: 0,
    flagged_listings: 0,
    total_bids: 0,
    accepted_bids: 0,
    rejected_bids: 0,
    pending_bids: 0,
    total_transactions: 0,
    pending_payment_txn: 0,
    escrow_held_txn: 0,
    complete_txn: 0,
    total_transaction_volume_rupees: 0,
    avg_listing_price_rupees: 0,
    total_platform_fees_rupees: 0,
    top_part_category: 'n/a',
  };

  const listings: ListingRow[] = (listingsData as ListingRow[]) ?? [];
  const txns: TxnRow[] = (txnsData as TxnRow[]) ?? [];

  const cards = [
    { label: 'Total listings', value: formatNumber(s.total_listings) },
    { label: 'Active', value: formatNumber(s.active_listings) },
    { label: 'Reserved', value: formatNumber(s.reserved_listings) },
    { label: 'Sold', value: formatNumber(s.sold_listings) },
    { label: 'Withdrawn', value: formatNumber(s.withdrawn_listings) },
    { label: 'Flagged', value: formatNumber(s.flagged_listings) },
    { label: 'Total bids', value: formatNumber(s.total_bids) },
    { label: 'Accepted bids', value: formatNumber(s.accepted_bids) },
    { label: 'Rejected bids', value: formatNumber(s.rejected_bids) },
    { label: 'Pending bids', value: formatNumber(s.pending_bids) },
    { label: 'Total transactions', value: formatNumber(s.total_transactions) },
    { label: 'Pending payment', value: formatNumber(s.pending_payment_txn) },
    { label: 'Escrow held', value: formatNumber(s.escrow_held_txn) },
    { label: 'Complete', value: formatNumber(s.complete_txn) },
    { label: 'Txn volume (Rs)', value: formatNumber(Math.round(Number(s.total_transaction_volume_rupees) || 0)) },
    { label: 'Avg ask (Rs)', value: formatNumber(Math.round(Number(s.avg_listing_price_rupees) || 0)) },
  ];

  return (
    <main style={{ padding: '24px', fontFamily: 'system-ui, -apple-system, sans-serif', maxWidth: '1280px', margin: '0 auto' }}>
      <div style={{ marginBottom: '8px' }}>
        <Link href="/ops" style={{ color: '#6366f1', textDecoration: 'none', fontSize: '14px' }}>{'<-'} ops index</Link>
      </div>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '4px' }}>Engineer P2P Parts Marketplace</h1>
      <p style={{ color: '#6b7280', fontSize: '14px', marginBottom: '24px' }}>
        Engineer-to-engineer parts marketplace. Listings, bids, transactions. Top category: <strong>{s.top_part_category}</strong>. Platform fee 5% default. Platform fee accrued so far: Rs {formatNumber(Math.round(Number(s.total_platform_fees_rupees) || 0))}.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        {cards.map((c) => (
          <div key={c.label} style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: '8px', padding: '16px' }}>
            <div style={{ fontSize: '12px', color: '#6b7280', marginBottom: '6px', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{c.label}</div>
            <div style={{ fontSize: '24px', fontWeight: 700, color: '#111827' }}>{c.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recent listings (50)</h2>
        <div style={{ overflowX: 'auto', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px', minWidth: '900px' }}>
            <thead style={{ background: '#f9fafb', textAlign: 'left' }}>
              <tr>
                <th style={{ padding: '10px 12px' }}>Listed</th>
                <th style={{ padding: '10px 12px' }}>Part</th>
                <th style={{ padding: '10px 12px' }}>Category</th>
                <th style={{ padding: '10px 12px' }}>Manufacturer</th>
                <th style={{ padding: '10px 12px' }}>Condition</th>
                <th style={{ padding: '10px 12px' }}>Ask (Rs)</th>
                <th style={{ padding: '10px 12px' }}>Qty</th>
                <th style={{ padding: '10px 12px' }}>Status</th>
                <th style={{ padding: '10px 12px' }}>Expires</th>
              </tr>
            </thead>
            <tbody>
              {listings.length === 0 ? (
                <tr><td colSpan={9} style={{ padding: '20px', textAlign: 'center', color: '#9ca3af' }}>No listings yet.</td></tr>
              ) : (
                listings.map((l) => (
                  <tr key={l.id} style={{ borderTop: '1px solid #f3f4f6' }}>
                    <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>{new Date(l.listed_at).toLocaleDateString('en-IN')}</td>
                    <td style={{ padding: '10px 12px', fontWeight: 500 }}>{l.part_label}</td>
                    <td style={{ padding: '10px 12px', color: '#6b7280' }}>{l.part_category}</td>
                    <td style={{ padding: '10px 12px', color: '#6b7280' }}>{l.manufacturer ?? '-'}</td>
                    <td style={{ padding: '10px 12px', color: '#6b7280' }}>{l.condition_band}</td>
                    <td style={{ padding: '10px 12px', textAlign: 'right', fontFamily: 'ui-monospace, monospace' }}>{formatNumber(Math.round(Number(l.ask_price_rupees) || 0))}</td>
                    <td style={{ padding: '10px 12px', textAlign: 'right' }}>{l.quantity_available}</td>
                    <td style={{ padding: '10px 12px' }}>
                      <span style={{
                        background: l.listing_status === 'active' ? '#dcfce7' : l.listing_status === 'flagged' ? '#fee2e2' : l.listing_status === 'sold' ? '#dbeafe' : '#f3f4f6',
                        color: l.listing_status === 'active' ? '#166534' : l.listing_status === 'flagged' ? '#991b1b' : l.listing_status === 'sold' ? '#1e40af' : '#374151',
                        padding: '2px 8px', borderRadius: '12px', fontSize: '11px', fontWeight: 500,
                      }}>{l.listing_status}</span>
                    </td>
                    <td style={{ padding: '10px 12px', color: '#6b7280', whiteSpace: 'nowrap' }}>{new Date(l.expires_at).toLocaleDateString('en-IN')}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recent transactions (50)</h2>
        <div style={{ overflowX: 'auto', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px', minWidth: '900px' }}>
            <thead style={{ background: '#f9fafb', textAlign: 'left' }}>
              <tr>
                <th style={{ padding: '10px 12px' }}>Created</th>
                <th style={{ padding: '10px 12px' }}>Txn ID</th>
                <th style={{ padding: '10px 12px' }}>Amount (Rs)</th>
                <th style={{ padding: '10px 12px' }}>Platform fee (Rs)</th>
                <th style={{ padding: '10px 12px' }}>Status</th>
                <th style={{ padding: '10px 12px' }}>Shipped</th>
                <th style={{ padding: '10px 12px' }}>Delivered</th>
                <th style={{ padding: '10px 12px' }}>Completed</th>
              </tr>
            </thead>
            <tbody>
              {txns.length === 0 ? (
                <tr><td colSpan={8} style={{ padding: '20px', textAlign: 'center', color: '#9ca3af' }}>No transactions yet.</td></tr>
              ) : (
                txns.map((t) => (
                  <tr key={t.id} style={{ borderTop: '1px solid #f3f4f6' }}>
                    <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>{new Date(t.created_at).toLocaleDateString('en-IN')}</td>
                    <td style={{ padding: '10px 12px', fontFamily: 'ui-monospace, monospace', fontSize: '11px', color: '#6b7280' }}>{t.id.slice(0, 8)}</td>
                    <td style={{ padding: '10px 12px', textAlign: 'right', fontFamily: 'ui-monospace, monospace' }}>{formatNumber(Math.round(Number(t.transaction_amount_rupees) || 0))}</td>
                    <td style={{ padding: '10px 12px', textAlign: 'right', fontFamily: 'ui-monospace, monospace', color: '#059669' }}>{formatNumber(Math.round(Number(t.platform_fee_rupees) || 0))}</td>
                    <td style={{ padding: '10px 12px' }}>
                      <span style={{
                        background: t.transaction_status === 'complete' ? '#dcfce7' : t.transaction_status === 'disputed' ? '#fee2e2' : t.transaction_status === 'escrow_held' ? '#fef3c7' : '#f3f4f6',
                        color: t.transaction_status === 'complete' ? '#166534' : t.transaction_status === 'disputed' ? '#991b1b' : t.transaction_status === 'escrow_held' ? '#92400e' : '#374151',
                        padding: '2px 8px', borderRadius: '12px', fontSize: '11px', fontWeight: 500,
                      }}>{t.transaction_status}</span>
                    </td>
                    <td style={{ padding: '10px 12px', color: '#6b7280', whiteSpace: 'nowrap' }}>{t.shipped_at ? new Date(t.shipped_at).toLocaleDateString('en-IN') : '-'}</td>
                    <td style={{ padding: '10px 12px', color: '#6b7280', whiteSpace: 'nowrap' }}>{t.delivered_at ? new Date(t.delivered_at).toLocaleDateString('en-IN') : '-'}</td>
                    <td style={{ padding: '10px 12px', color: '#6b7280', whiteSpace: 'nowrap' }}>{t.completed_at ? new Date(t.completed_at).toLocaleDateString('en-IN') : '-'}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ background: '#f9fafb', border: '1px solid #e5e7eb', borderRadius: '8px', padding: '16px', fontSize: '13px', color: '#374151' }}>
        <h3 style={{ fontSize: '14px', fontWeight: 600, marginBottom: '8px' }}>Notes</h3>
        <ul style={{ paddingLeft: '20px', lineHeight: '1.7' }}>
          <li>Platform fee defaults to 5% of transaction amount, captured at bid acceptance.</li>
          <li>Listings auto-expire 60 days after listing; cron flips them to withdrawn + bids to expired.</li>
          <li>Engineers cannot bid on their own listings (RPC guard).</li>
          <li>Bid acceptance is atomic: bid -{'>'} accepted, listing -{'>'} reserved, transaction created with status pending_payment.</li>
          <li>Use log_founder_p2p_flag_listing(uuid) to flag a listing manually for moderation review.</li>
        </ul>
      </section>
    </main>
  );
}
