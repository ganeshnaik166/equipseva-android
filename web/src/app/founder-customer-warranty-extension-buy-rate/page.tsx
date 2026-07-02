import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, funnelRes, catRes, chanRes, declineRes, recentRes, trendRes] = await Promise.all([
    sb.rpc('wext_buy_rate_summary_r2392'),
    sb.rpc('wext_funnel_stages_r2392'),
    sb.rpc('wext_buy_rate_by_category_r2392'),
    sb.rpc('wext_buy_rate_by_channel_r2392'),
    sb.rpc('wext_decline_reasons_r2392'),
    sb.rpc('wext_recent_purchases_r2392'),
    sb.rpc('wext_monthly_cohort_trend_r2392'),
  ]);

  const summary = (summaryRes.data?.[0] ?? {}) as any;
  const funnel = (funnelRes.data ?? []) as any[];
  const cats = (catRes.data ?? []) as any[];
  const chans = (chanRes.data ?? []) as any[];
  const declines = (declineRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];

  const funnelCols: Column<any>[] = [
    { key: 'funnel_stage', header: 'Stage', render: (r: any) => String(r.funnel_stage ?? '') },
    { key: 'offer_count', header: 'Offers', render: (r: any) => String(r.offer_count ?? 0) },
    { key: 'stage_value_rupees', header: 'Stage Value (Rs)', render: (r: any) => String(r.stage_value_rupees ?? 0) },
    { key: 'pct_of_total', header: '% of Total', render: (r: any) => String(r.pct_of_total ?? 0) },
  ];

  const catCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'offers_sent', header: 'Offers Sent', render: (r: any) => String(r.offers_sent ?? 0) },
    { key: 'offers_purchased', header: 'Purchased', render: (r: any) => String(r.offers_purchased ?? 0) },
    { key: 'buy_rate_pct', header: 'Buy Rate %', render: (r: any) => String(r.buy_rate_pct ?? 0) },
    { key: 'realized_value_rupees', header: 'Realized (Rs)', render: (r: any) => String(r.realized_value_rupees ?? 0) },
    { key: 'value_left_rupees', header: 'Left on Table (Rs)', render: (r: any) => String(r.value_left_rupees ?? 0) },
  ];

  const chanCols: Column<any>[] = [
    { key: 'offer_channel', header: 'Channel', render: (r: any) => String(r.offer_channel ?? '') },
    { key: 'offers_sent', header: 'Offers Sent', render: (r: any) => String(r.offers_sent ?? 0) },
    { key: 'offers_purchased', header: 'Purchased', render: (r: any) => String(r.offers_purchased ?? 0) },
    { key: 'buy_rate_pct', header: 'Buy Rate %', render: (r: any) => String(r.buy_rate_pct ?? 0) },
    { key: 'avg_days_to_purchase', header: 'Avg Days to Close', render: (r: any) => String(r.avg_days_to_purchase ?? 0) },
  ];

  const declineCols: Column<any>[] = [
    { key: 'decline_reason', header: 'Decline Reason', render: (r: any) => String(r.decline_reason ?? '') },
    { key: 'decline_count', header: 'Count', render: (r: any) => String(r.decline_count ?? 0) },
    { key: 'lost_value_rupees', header: 'Lost Value (Rs)', render: (r: any) => String(r.lost_value_rupees ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'purchased_at', header: 'Purchased', render: (r: any) => String(r.purchased_at ?? '').slice(0, 19) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '') },
    { key: 'extension_months', header: 'Months', render: (r: any) => String(r.extension_months ?? 0) },
    { key: 'final_price_rupees', header: 'Price (Rs)', render: (r: any) => String(r.final_price_rupees ?? 0) },
    { key: 'offer_channel', header: 'Channel', render: (r: any) => String(r.offer_channel ?? '') },
    { key: 'days_to_close', header: 'Days to Close', render: (r: any) => String(r.days_to_close ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'cohort_month', header: 'Month', render: (r: any) => String(r.cohort_month ?? '') },
    { key: 'offers_sent', header: 'Offers Sent', render: (r: any) => String(r.offers_sent ?? 0) },
    { key: 'offers_purchased', header: 'Purchased', render: (r: any) => String(r.offers_purchased ?? 0) },
    { key: 'buy_rate_pct', header: 'Buy Rate %', render: (r: any) => String(r.buy_rate_pct ?? 0) },
    { key: 'realized_value_rupees', header: 'Realized (Rs)', render: (r: any) => String(r.realized_value_rupees ?? 0) },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Customer Warranty Extension Buy Rate</h1>
        <p className="text-sm text-gray-600">% customers buying warranty extensions, conversion funnel & value left on table</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total Offers</div>
          <div className="text-2xl font-semibold">{String(summary.total_offers ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Purchased</div>
          <div className="text-2xl font-semibold">{String(summary.offers_purchased ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Buy Rate %</div>
          <div className="text-2xl font-semibold">{String(summary.buy_rate_pct ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">View Rate %</div>
          <div className="text-2xl font-semibold">{String(summary.view_rate_pct ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Click Rate %</div>
          <div className="text-2xl font-semibold">{String(summary.click_rate_pct ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Offered Value (Rs)</div>
          <div className="text-2xl font-semibold">{String(summary.total_offered_value_rupees ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Realized (Rs)</div>
          <div className="text-2xl font-semibold">{String(summary.total_realized_value_rupees ?? 0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Left on Table (Rs)</div>
          <div className="text-2xl font-semibold">{String(summary.value_left_on_table_rupees ?? 0)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Conversion Funnel</h2>
        <DataTable columns={funnelCols} rows={funnel} rowKey={(_, i) => String(i)} emptyMessage="No offers tracked yet" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Buy Rate by Equipment Category</h2>
        <DataTable columns={catCols} rows={cats} rowKey={(_, i) => String(i)} emptyMessage="No category data" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Buy Rate by Channel</h2>
        <DataTable columns={chanCols} rows={chans} rowKey={(_, i) => String(i)} emptyMessage="No channel data" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decline Reasons</h2>
        <DataTable columns={declineCols} rows={declines} rowKey={(_, i) => String(i)} emptyMessage="No declines logged" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Purchases</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(_, i) => String(i)} emptyMessage="No recent purchases" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Cohort Trend — Last 6 Months</h2>
        <DataTable columns={trendCols} rows={trend} rowKey={(_, i) => String(i)} emptyMessage="No trend data" />
      </section>
    </div>
  );
}
