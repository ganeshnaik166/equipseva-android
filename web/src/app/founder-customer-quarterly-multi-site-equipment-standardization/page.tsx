import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiSummary = {
  total_customers: number;
  total_sites: number;
  total_units: number;
  total_annual_service_cost_rupees: number;
  total_non_standard_sites: number;
  total_estimated_saving_rupees: number;
};

type InventoryRow = {
  id: string;
  customer_org_name: string;
  site_code: string;
  site_city: string;
  equipment_kind: string;
  brand_model: string;
  units_count: number;
  avg_age_months: number;
  annual_service_cost_rupees: number;
  is_standard_brand: boolean;
  variance_severity: string;
  quarter_label: string;
};

type RecommendationRow = {
  id: string;
  customer_org_name: string;
  equipment_kind: string;
  recommended_brand_model: string;
  non_standard_sites_count: number;
  estimated_annual_saving_rupees: number;
  rollout_horizon_months: number;
  capex_required_rupees: number;
  payback_months: number;
  recommendation_status: string;
  founder_notes: string | null;
};

type VarianceByCustomer = {
  customer_org_name: string;
  total_sites: number;
  non_standard_sites: number;
  variance_pct: number;
  worst_severity: string;
};

type SavingByKind = {
  equipment_kind: string;
  recommendation_count: number;
  total_saving_rupees: number;
  total_capex_rupees: number;
  avg_payback_months: number;
};

type StatusPipeline = {
  recommendation_status: string;
  count_recommendations: number;
  saving_in_status_rupees: number;
};

type QuickWin = {
  customer_org_name: string;
  equipment_kind: string;
  recommended_brand_model: string;
  estimated_annual_saving_rupees: number;
  payback_months: number;
  recommendation_status: string;
};

type SiteOutlier = {
  customer_org_name: string;
  site_code: string;
  site_city: string;
  equipment_kind: string;
  brand_model: string;
  annual_service_cost_rupees: number;
  cost_per_unit_rupees: number;
  variance_severity: string;
};

function formatRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpiRes,
    inventoryRes,
    recommendationsRes,
    varianceRes,
    savingByKindRes,
    statusRes,
    quickWinsRes,
    outliersRes,
  ] = await Promise.all([
    supabase.rpc('rpc_r2764_kpi_summary'),
    supabase.rpc('rpc_r2764_inventory_rows'),
    supabase.rpc('rpc_r2764_recommendation_rows'),
    supabase.rpc('rpc_r2764_variance_by_customer'),
    supabase.rpc('rpc_r2764_saving_by_kind'),
    supabase.rpc('rpc_r2764_status_pipeline'),
    supabase.rpc('rpc_r2764_top_quick_wins'),
    supabase.rpc('rpc_r2764_site_cost_outliers'),
  ]);

  const kpi: KpiSummary | null = Array.isArray(kpiRes.data) ? kpiRes.data[0] ?? null : kpiRes.data ?? null;
  const inventory: InventoryRow[] = (inventoryRes.data ?? []) as InventoryRow[];
  const recommendations: RecommendationRow[] = (recommendationsRes.data ?? []) as RecommendationRow[];
  const variance: VarianceByCustomer[] = (varianceRes.data ?? []) as VarianceByCustomer[];
  const savingByKind: SavingByKind[] = (savingByKindRes.data ?? []) as SavingByKind[];
  const statusPipeline: StatusPipeline[] = (statusRes.data ?? []) as StatusPipeline[];
  const quickWins: QuickWin[] = (quickWinsRes.data ?? []) as QuickWin[];
  const outliers: SiteOutlier[] = (outliersRes.data ?? []) as SiteOutlier[];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Customer Quarterly Multi-Site Equipment Standardization</h1>
        <p className="text-sm text-gray-600">
          Quarterly review across enterprise customers: site-by-site fleet variance, standardization candidates,
          and cost savings when non-standard kit consolidates onto the customer's preferred brand.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Customers</div>
          <div className="text-2xl font-semibold">{kpi?.total_customers ?? 0}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Sites</div>
          <div className="text-2xl font-semibold">{kpi?.total_sites ?? 0}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Units</div>
          <div className="text-2xl font-semibold">{kpi?.total_units ?? 0}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Annual Service Spend</div>
          <div className="text-xl font-semibold">{formatRupees(kpi?.total_annual_service_cost_rupees ?? 0)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Non-Standard Sites</div>
          <div className="text-2xl font-semibold">{kpi?.total_non_standard_sites ?? 0}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Est. Annual Saving</div>
          <div className="text-xl font-semibold text-green-700">{formatRupees(kpi?.total_estimated_saving_rupees ?? 0)}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Variance by Customer</h2>
        <p className="text-xs text-gray-500">Customers ranked by % of sites running non-standard brand fleets.</p>
        <DataTable
          rows={variance}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: VarianceByCustomer) => r.customer_org_name },
            { key: 'total_sites', header: 'Sites', render: (r: VarianceByCustomer) => r.total_sites },
            { key: 'non_standard_sites', header: 'Non-Standard', render: (r: VarianceByCustomer) => r.non_standard_sites },
            { key: 'variance_pct', header: 'Variance %', render: (r: VarianceByCustomer) => (r.variance_pct ?? 0) + '%' },
            { key: 'worst_severity', header: 'Worst Severity', render: (r: VarianceByCustomer) => r.worst_severity },
          ]}
          emptyMessage="No data"
          rowKey={(r: VarianceByCustomer, i: number) => String(r.customer_org_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Saving by Equipment Kind</h2>
        <DataTable
          rows={savingByKind}
          columns={[
            { key: 'equipment_kind', header: 'Equipment Kind', render: (r: SavingByKind) => r.equipment_kind },
            { key: 'recommendation_count', header: 'Recs', render: (r: SavingByKind) => r.recommendation_count },
            { key: 'total_saving_rupees', header: 'Annual Saving', render: (r: SavingByKind) => formatRupees(r.total_saving_rupees) },
            { key: 'total_capex_rupees', header: 'Capex', render: (r: SavingByKind) => formatRupees(r.total_capex_rupees) },
            { key: 'avg_payback_months', header: 'Avg Payback (mo)', render: (r: SavingByKind) => r.avg_payback_months },
          ]}
          emptyMessage="No data"
          rowKey={(r: SavingByKind, i: number) => String(r.equipment_kind ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Status Pipeline</h2>
        <DataTable
          rows={statusPipeline}
          columns={[
            { key: 'recommendation_status', header: 'Status', render: (r: StatusPipeline) => r.recommendation_status },
            { key: 'count_recommendations', header: 'Count', render: (r: StatusPipeline) => r.count_recommendations },
            { key: 'saving_in_status_rupees', header: 'Saving in Status', render: (r: StatusPipeline) => formatRupees(r.saving_in_status_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: StatusPipeline, i: number) => String(r.recommendation_status ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Top Quick Wins</h2>
        <p className="text-xs text-gray-500">Recommendations with payback &lt;= 24 months, ranked by annual saving.</p>
        <DataTable
          rows={quickWins}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: QuickWin) => r.customer_org_name },
            { key: 'equipment_kind', header: 'Kind', render: (r: QuickWin) => r.equipment_kind },
            { key: 'recommended_brand_model', header: 'Standard Brand', render: (r: QuickWin) => r.recommended_brand_model },
            { key: 'estimated_annual_saving_rupees', header: 'Annual Saving', render: (r: QuickWin) => formatRupees(r.estimated_annual_saving_rupees) },
            { key: 'payback_months', header: 'Payback (mo)', render: (r: QuickWin) => r.payback_months },
            { key: 'recommendation_status', header: 'Status', render: (r: QuickWin) => r.recommendation_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: QuickWin, i: number) => String(r.customer_org_name + ':' + r.equipment_kind + ':' + i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Site Cost Outliers (high & critical variance)</h2>
        <DataTable
          rows={outliers}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: SiteOutlier) => r.customer_org_name },
            { key: 'site_code', header: 'Site', render: (r: SiteOutlier) => r.site_code + ' (' + r.site_city + ')' },
            { key: 'equipment_kind', header: 'Kind', render: (r: SiteOutlier) => r.equipment_kind },
            { key: 'brand_model', header: 'Brand / Model', render: (r: SiteOutlier) => r.brand_model },
            { key: 'annual_service_cost_rupees', header: 'Annual Cost', render: (r: SiteOutlier) => formatRupees(r.annual_service_cost_rupees) },
            { key: 'cost_per_unit_rupees', header: 'Cost / Unit', render: (r: SiteOutlier) => formatRupees(r.cost_per_unit_rupees) },
            { key: 'variance_severity', header: 'Severity', render: (r: SiteOutlier) => r.variance_severity },
          ]}
          emptyMessage="No data"
          rowKey={(r: SiteOutlier, i: number) => String(r.site_code + ':' + i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Full Site Inventory</h2>
        <DataTable
          rows={inventory}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: InventoryRow) => r.customer_org_name },
            { key: 'site_code', header: 'Site', render: (r: InventoryRow) => r.site_code + ' (' + r.site_city + ')' },
            { key: 'equipment_kind', header: 'Kind', render: (r: InventoryRow) => r.equipment_kind },
            { key: 'brand_model', header: 'Brand / Model', render: (r: InventoryRow) => r.brand_model },
            { key: 'units_count', header: 'Units', render: (r: InventoryRow) => r.units_count },
            { key: 'avg_age_months', header: 'Avg Age (mo)', render: (r: InventoryRow) => r.avg_age_months },
            { key: 'annual_service_cost_rupees', header: 'Annual Cost', render: (r: InventoryRow) => formatRupees(r.annual_service_cost_rupees) },
            { key: 'is_standard_brand', header: 'Standard?', render: (r: InventoryRow) => (r.is_standard_brand ? 'yes' : 'no') },
            { key: 'variance_severity', header: 'Variance', render: (r: InventoryRow) => r.variance_severity },
            { key: 'quarter_label', header: 'Quarter', render: (r: InventoryRow) => r.quarter_label },
          ]}
          emptyMessage="No data"
          rowKey={(r: InventoryRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All Standardization Recommendations</h2>
        <DataTable
          rows={recommendations}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: RecommendationRow) => r.customer_org_name },
            { key: 'equipment_kind', header: 'Kind', render: (r: RecommendationRow) => r.equipment_kind },
            { key: 'recommended_brand_model', header: 'Standard Brand', render: (r: RecommendationRow) => r.recommended_brand_model },
            { key: 'non_standard_sites_count', header: 'Sites to Swap', render: (r: RecommendationRow) => r.non_standard_sites_count },
            { key: 'estimated_annual_saving_rupees', header: 'Annual Saving', render: (r: RecommendationRow) => formatRupees(r.estimated_annual_saving_rupees) },
            { key: 'capex_required_rupees', header: 'Capex', render: (r: RecommendationRow) => formatRupees(r.capex_required_rupees) },
            { key: 'rollout_horizon_months', header: 'Rollout (mo)', render: (r: RecommendationRow) => r.rollout_horizon_months },
            { key: 'payback_months', header: 'Payback (mo)', render: (r: RecommendationRow) => r.payback_months },
            { key: 'recommendation_status', header: 'Status', render: (r: RecommendationRow) => r.recommendation_status },
            { key: 'founder_notes', header: 'Notes', render: (r: RecommendationRow) => r.founder_notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r: RecommendationRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
