import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [offersRes, totalsRes, recentRes] = await Promise.all([
    sb.rpc('list_pre_ipo_offers_r1841'),
    sb.rpc('total_pre_ipo_secondary_volume_r1841'),
    sb.rpc('recent_pre_ipo_secondaries_r1841'),
  ]);

  const offers: any[] = Array.isArray(offersRes.data) ? offersRes.data : [];
  const totals: any = Array.isArray(totalsRes.data) ? totalsRes.data[0] : totalsRes.data;
  const recents: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const offerCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => String(r.investor_email ?? r.investor_id ?? '—') },
    { key: 'instrument_type', header: 'Instrument', render: (r: any) => String(r.instrument_type ?? '—') },
    { key: 'shares_offered', header: 'Shares', render: (r: any) => Number(r.shares_offered ?? 0).toLocaleString('en-IN') },
    { key: 'price_per_share_rupees', header: 'Price/Share', render: (r: any) => '₹' + Number(r.price_per_share_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'valuation_implied_rupees', header: 'Implied Valuation', render: (r: any) => '₹' + Number(r.valuation_implied_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'offer_at', header: 'Offered', render: (r: any) => r.offer_at ? new Date(r.offer_at).toLocaleDateString('en-IN') : '—' },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString('en-IN') : '—' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'buyer_name', header: 'Buyer', render: (r: any) => String(r.buyer_name ?? '—') },
    { key: 'buyer_type', header: 'Type', render: (r: any) => String(r.buyer_type ?? '—') },
    { key: 'instrument_type', header: 'Instrument', render: (r: any) => String(r.instrument_type ?? '—') },
    { key: 'buyer_amount_rupees', header: 'Amount', render: (r: any) => '₹' + Number(r.buyer_amount_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'accepted_at', header: 'Accepted', render: (r: any) => r.accepted_at ? new Date(r.accepted_at).toLocaleDateString('en-IN') : '—' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Investor Pre-IPO Liquidity Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Secondary sale opportunities for employees & early investors (pre-IPO liquidity).
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">Volume Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Total Offers</div>
            <div className="text-2xl font-semibold">{Number(totals?.total_offers ?? 0).toLocaleString('en-IN')}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Accepted Offers</div>
            <div className="text-2xl font-semibold">{Number(totals?.accepted_offers ?? 0).toLocaleString('en-IN')}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Total Buyers</div>
            <div className="text-2xl font-semibold">{Number(totals?.total_buyers ?? 0).toLocaleString('en-IN')}</div>
          </div>
          <div className="border rounded p-4">
            <div className="text-xs text-gray-500">Secondary Volume</div>
            <div className="text-2xl font-semibold">
              {'₹'}{Number(totals?.total_volume_rupees ?? 0).toLocaleString('en-IN')}
            </div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Liquidity Offers</h2>
        <DataTable
          rows={offers}
          columns={offerCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Recent Secondary Buyers</h2>
        <DataTable
          rows={recents}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.buyer_id ?? i)}
        />
      </section>
    </main>
  );
}
