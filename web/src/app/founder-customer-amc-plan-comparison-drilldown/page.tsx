import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [catalog, distribution, candidates, revenue, roi, migration, kpi] = await Promise.all([
    sb.rpc('founder_amc_plan_catalog_r2236'),
    sb.rpc('founder_amc_customer_distribution_r2236'),
    sb.rpc('founder_amc_upsell_candidates_r2236'),
    sb.rpc('founder_amc_plan_revenue_compare_r2236'),
    sb.rpc('founder_amc_upsell_roi_summary_r2236'),
    sb.rpc('founder_amc_tier_migration_r2236'),
    sb.rpc('founder_amc_plan_kpi_r2236'),
  ]);

  const catalogRows: any[] = catalog.data ?? [];
  const distRows: any[] = distribution.data ?? [];
  const candRows: any[] = candidates.data ?? [];
  const revRows: any[] = revenue.data ?? [];
  const roiRows: any[] = roi.data ?? [];
  const migRows: any[] = migration.data ?? [];
  const k: any = (kpi.data && kpi.data[0]) || {};

  const catalogCols: Column<any>[] = [
    { key: 'plan_tier', header: 'Plan Tier', render: (r: any) => String(r.plan_tier ?? '') },
    { key: 'monthly_fee_rupees', header: 'Monthly Fee', render: (r: any) => String(r.monthly_fee_rupees ?? '') },
    { key: 'visits_included_per_quarter', header: 'Visits / Qtr', render: (r: any) => String(r.visits_included_per_quarter ?? '') },
    { key: 'response_sla_hours', header: 'SLA Hours', render: (r: any) => String(r.response_sla_hours ?? '') },
    { key: 'spare_discount_pct', header: 'Spare Disc %', render: (r: any) => String(r.spare_discount_pct ?? '') },
    { key: 'priority_dispatch', header: 'Priority', render: (r: any) => String(r.priority_dispatch ?? '') },
    { key: 'free_calibration', header: 'Free Calib', render: (r: any) => String(r.free_calibration ?? '') },
    { key: 'twenty_four_seven_support', header: '24x7', render: (r: any) => String(r.twenty_four_seven_support ?? '') },
    { key: 'upsell_blurb', header: 'Blurb', render: (r: any) => String(r.upsell_blurb ?? '') },
  ];

  const distCols: Column<any>[] = [
    { key: 'tier_label', header: 'Tier', render: (r: any) => String(r.tier_label ?? '') },
    { key: 'customer_count', header: 'Customers', render: (r: any) => String(r.customer_count ?? '') },
    { key: 'total_mrr_rupees', header: 'MRR (rupees)', render: (r: any) => String(r.total_mrr_rupees ?? '') },
  ];

  const candCols: Column<any>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: any) => String(r.customer_email ?? '') },
    { key: 'current_tier', header: 'Current', render: (r: any) => String(r.current_tier ?? '') },
    { key: 'target_tier', header: 'Target', render: (r: any) => String(r.target_tier ?? '') },
    { key: 'monthly_uplift_rupees', header: 'MRR Uplift', render: (r: any) => String(r.monthly_uplift_rupees ?? '') },
    { key: 'annual_uplift_rupees', header: 'ARR Uplift', render: (r: any) => String(r.annual_uplift_rupees ?? '') },
    { key: 'roi_payback_months', header: 'Payback Mo.', render: (r: any) => String(r.roi_payback_months ?? '') },
    { key: 'signal_strength', header: 'Signal', render: (r: any) => String(r.signal_strength ?? '') },
  ];

  const revCols: Column<any>[] = [
    { key: 'plan_tier', header: 'Plan Tier', render: (r: any) => String(r.plan_tier ?? '') },
    { key: 'active_customers', header: 'Active', render: (r: any) => String(r.active_customers ?? '') },
    { key: 'monthly_revenue_rupees', header: 'MRR', render: (r: any) => String(r.monthly_revenue_rupees ?? '') },
    { key: 'annual_revenue_rupees', header: 'ARR', render: (r: any) => String(r.annual_revenue_rupees ?? '') },
    { key: 'avg_fee_rupees', header: 'Avg Fee', render: (r: any) => String(r.avg_fee_rupees ?? '') },
  ];

  const roiCols: Column<any>[] = [
    { key: 'signal_strength', header: 'Signal', render: (r: any) => String(r.signal_strength ?? '') },
    { key: 'candidate_count', header: 'Candidates', render: (r: any) => String(r.candidate_count ?? '') },
    { key: 'total_monthly_uplift', header: 'Monthly Uplift', render: (r: any) => String(r.total_monthly_uplift ?? '') },
    { key: 'total_annual_uplift', header: 'Annual Uplift', render: (r: any) => String(r.total_annual_uplift ?? '') },
    { key: 'avg_payback_months', header: 'Avg Payback', render: (r: any) => String(r.avg_payback_months ?? '') },
  ];

  const migCols: Column<any>[] = [
    { key: 'from_tier', header: 'From', render: (r: any) => String(r.from_tier ?? '') },
    { key: 'to_tier', header: 'To', render: (r: any) => String(r.to_tier ?? '') },
    { key: 'migration_count', header: 'Count', render: (r: any) => String(r.migration_count ?? '') },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Customer AMC Plan Comparison Drilldown</h1>
        <p className="text-sm text-gray-600">Side-by-side basic vs standard vs premium AMC tiers & upsell ROI</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Active AMCs</div>
          <div className="text-xl font-semibold">{String(k.total_active_amcs ?? 0)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Total MRR</div>
          <div className="text-xl font-semibold">{String(k.total_mrr_rupees ?? 0)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Total ARR</div>
          <div className="text-xl font-semibold">{String(k.total_arr_rupees ?? 0)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Hot Upsell Leads</div>
          <div className="text-xl font-semibold">{String(k.hot_upsell_candidates ?? 0)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Potential ARR Uplift</div>
          <div className="text-xl font-semibold">{String(k.potential_annual_uplift ?? 0)}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Plan Catalog (Basic &lt; Standard &lt; Premium)</h2>
        <DataTable columns={catalogCols} rows={catalogRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Customer Distribution by Tier</h2>
        <DataTable columns={distCols} rows={distRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Revenue Compare by Plan</h2>
        <DataTable columns={revCols} rows={revRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upsell ROI Summary</h2>
        <DataTable columns={roiCols} rows={roiRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier Migration Targets</h2>
        <DataTable columns={migCols} rows={migRows} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Upsell Candidates</h2>
        <DataTable columns={candCols} rows={candRows} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
