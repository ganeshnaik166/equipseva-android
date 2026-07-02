import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function rupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n == null) return '-';
  return Number(n).toFixed(2) + '%';
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  return new Date(s).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: '2-digit' });
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summary, listings, resales, byCategory, ladder, topEng, trend] = await Promise.all([
    supabase.rpc('founder_sle_summary'),
    supabase.rpc('founder_sle_list_listings', { p_limit: 50 }),
    supabase.rpc('founder_sle_list_resales', { p_limit: 50 }),
    supabase.rpc('founder_sle_by_category'),
    supabase.rpc('founder_sle_broker_ladder'),
    supabase.rpc('founder_sle_top_engineers', { p_limit: 20 }),
    supabase.rpc('founder_sle_monthly_trend'),
  ]);

  const s: any = (summary.data && (summary.data as any[])[0]) ?? {};
  const listingsRows: any[] = (listings.data as any[]) ?? [];
  const resalesRows: any[] = (resales.data as any[]) ?? [];
  const categoryRows: any[] = (byCategory.data as any[]) ?? [];
  const ladderRows: any[] = (ladder.data as any[]) ?? [];
  const engRows: any[] = (topEng.data as any[]) ?? [];
  const trendRows: any[] = (trend.data as any[]) ?? [];

  const soldCount = Number(s.sold_listings ?? 0);
  const activeCount = Number(s.active_listings ?? 0);
  const totalListings = Number(s.total_listings ?? 0);
  const totalResale = Number(s.total_resale_rupees ?? 0);
  const totalMargin = Number(s.total_net_margin_rupees ?? 0);
  const avgBroker = Number(s.avg_broker_fee_pct ?? 0);

  const sellThroughPct = totalListings > 0 ? (soldCount / totalListings) * 100 : 0;
  const marginPct = totalResale > 0 ? (totalMargin / totalResale) * 100 : 0;
  const avgSale = soldCount > 0 ? totalResale / soldCount : 0;
  const avgMargin = soldCount > 0 ? totalMargin / soldCount : 0;

  const totalBrokerPaid = resalesRows.reduce((a, r) => a + Number(r.broker_fee_rupees ?? 0), 0);
  const totalCommission = resalesRows.reduce((a, r) => a + Number(r.engineer_commission_rupees ?? 0), 0);
  const totalRefurb = resalesRows.reduce((a, r) => a + Number(r.refurb_cost_actual_rupees ?? 0), 0);
  const last30 = trendRows[0] ?? {};
  const last30Sold = Number(last30.sold_count ?? 0);
  const last30Resale = Number(last30.total_resale_rupees ?? 0);
  const engineerCount = engRows.length;
  const categoryCount = categoryRows.length;

  const kpis: Kpi[] = [
    { label: 'Total listings', value: String(totalListings) },
    { label: 'Active listings', value: String(activeCount) },
    { label: 'Sold listings', value: String(soldCount) },
    { label: 'Sell-through', value: sellThroughPct.toFixed(1) + '%' },
    { label: 'Total resale GMV', value: rupees(totalResale) },
    { label: 'Total net margin', value: rupees(totalMargin) },
    { label: 'Margin %', value: marginPct.toFixed(1) + '%' },
    { label: 'Avg sale price', value: rupees(Math.round(avgSale)) },
    { label: 'Avg margin/sale', value: rupees(Math.round(avgMargin)) },
    { label: 'Avg broker fee', value: pct(avgBroker) },
    { label: 'Total broker paid', value: rupees(totalBrokerPaid) },
    { label: 'Total engineer commission', value: rupees(totalCommission) },
    { label: 'Total refurb spend', value: rupees(totalRefurb) },
    { label: 'Latest month sold', value: String(last30Sold) },
    { label: 'Latest month GMV', value: rupees(last30Resale) },
    { label: 'Active engineers / categories', value: engineerCount + ' / ' + categoryCount },
  ];

  const listingCols: Column<any>[] = [
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model ?? '-' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '-' },
    { key: 'condition_grade', header: 'Grade', render: (r: any) => (r.condition_grade ?? '-').toString().toUpperCase() },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'est_resale_rupees', header: 'Est resale', render: (r: any) => rupees(r.est_resale_rupees) },
    { key: 'est_refurb_cost_rupees', header: 'Est refurb', render: (r: any) => rupees(r.est_refurb_cost_rupees) },
    { key: 'broker_fee_tier', header: 'Tier', render: (r: any) => (r.broker_fee_tier ?? '-').toString().toUpperCase() },
    { key: 'broker_fee_pct', header: 'Fee %', render: (r: any) => pct(r.broker_fee_pct) },
    { key: 'logged_at', header: 'Logged', render: (r: any) => fmtDate(r.logged_at) },
  ];

  const resaleCols: Column<any>[] = [
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model ?? '-' },
    { key: 'buyer_hospital_label', header: 'Buyer', render: (r: any) => r.buyer_hospital_label ?? '-' },
    { key: 'sale_price_rupees', header: 'Sale price', render: (r: any) => rupees(r.sale_price_rupees) },
    { key: 'refurb_cost_actual_rupees', header: 'Refurb', render: (r: any) => rupees(r.refurb_cost_actual_rupees) },
    { key: 'broker_fee_rupees', header: 'Broker fee', render: (r: any) => rupees(r.broker_fee_rupees) },
    { key: 'engineer_commission_rupees', header: 'Eng commission', render: (r: any) => rupees(r.engineer_commission_rupees) },
    { key: 'net_margin_rupees', header: 'Net margin', render: (r: any) => rupees(r.net_margin_rupees) },
    { key: 'sold_at', header: 'Sold', render: (r: any) => fmtDate(r.sold_at) },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '-' },
    { key: 'listings_count', header: 'Listings', render: (r: any) => String(r.listings_count ?? 0) },
    { key: 'sold_count', header: 'Sold', render: (r: any) => String(r.sold_count ?? 0) },
    { key: 'total_resale_rupees', header: 'GMV', render: (r: any) => rupees(r.total_resale_rupees) },
    { key: 'total_net_margin_rupees', header: 'Net margin', render: (r: any) => rupees(r.total_net_margin_rupees) },
  ];

  const ladderCols: Column<any>[] = [
    { key: 'broker_fee_tier', header: 'Tier', render: (r: any) => (r.broker_fee_tier ?? '-').toString().toUpperCase() },
    { key: 'listings_count', header: 'Listings', render: (r: any) => String(r.listings_count ?? 0) },
    { key: 'avg_broker_fee_pct', header: 'Avg fee %', render: (r: any) => pct(r.avg_broker_fee_pct) },
    { key: 'total_broker_fee_rupees', header: 'Fees collected', render: (r: any) => rupees(r.total_broker_fee_rupees) },
  ];

  const engCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '-' },
    { key: 'listings_count', header: 'Listings', render: (r: any) => String(r.listings_count ?? 0) },
    { key: 'sold_count', header: 'Sold', render: (r: any) => String(r.sold_count ?? 0) },
    { key: 'total_commission_rupees', header: 'Commission', render: (r: any) => rupees(r.total_commission_rupees) },
  ];

  return (
    <div className="min-h-screen bg-neutral-50 p-6">
      <div className="max-w-7xl mx-auto space-y-8">
        <header>
          <p className="text-xs uppercase tracking-wider text-neutral-500">r1484 Founder Console</p>
          <h1 className="text-3xl font-semibold text-neutral-900 mt-1">Engineer second-life equipment intel</h1>
          <p className="text-sm text-neutral-600 mt-2 max-w-3xl">
            Hospital end-of-life gear that field engineers flag as redeployable. Tracks refurb cost, broker-fee ladder,
            and resale margin to smaller hospitals.
          </p>
        </header>

        <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {kpis.map((k) => (
            <div key={k.label} className="bg-white rounded-lg border border-neutral-200 p-4">
              <div className="text-xs uppercase tracking-wide text-neutral-500">{k.label}</div>
              <div className="text-lg font-semibold text-neutral-900 mt-1 truncate">{k.value}</div>
            </div>
          ))}
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold text-neutral-900">Recent listings</h2>
          <DataTable columns={listingCols} rows={listingsRows} rowKey={(r: any) => r.id} />
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold text-neutral-900">Recent resales</h2>
          <DataTable columns={resaleCols} rows={resalesRows} rowKey={(r: any) => r.id} />
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold text-neutral-900">By equipment category</h2>
          <DataTable columns={categoryCols} rows={categoryRows} rowKey={(r: any) => r.equipment_category} />
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold text-neutral-900">Broker-fee ladder</h2>
          <DataTable columns={ladderCols} rows={ladderRows} rowKey={(r: any) => r.broker_fee_tier} />
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold text-neutral-900">Top engineers</h2>
          <DataTable columns={engCols} rows={engRows} rowKey={(r: any) => r.engineer_id} />
        </section>
      </div>
    </div>
  );
}
