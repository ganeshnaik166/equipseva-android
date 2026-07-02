import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_assets: number;
  critical_grade: number;
  poor_grade: number;
  total_book_value_rupees: number;
  total_estimated_capex_rupees: number;
  total_amc_renewal_rupees: number;
  total_service_revenue_impact_rupees: number;
};

type AssetRow = {
  id: string;
  chain_name: string;
  hospital_branch: string;
  asset_serial: string;
  asset_category: string;
  asset_make: string;
  asset_model: string;
  install_date: string;
  expected_eol_date: string;
  current_age_months: number;
  remaining_life_months: number;
  condition_grade: string;
  current_book_value_rupees: number;
  replacement_quarter: string;
  replacement_year: number;
  replacement_status: string;
};

type ProcurementRow = {
  id: string;
  chain_name: string;
  replacement_quarter: string;
  replacement_year: number;
  asset_category: string;
  units_to_replace: number;
  budget_allocated_rupees: number;
  estimated_capex_rupees: number;
  vendor_shortlisted: string;
  po_status: string;
  service_revenue_impact_rupees: number;
  amc_renewal_value_rupees: number;
  decision_owner: string;
  decision_due_date: string;
  notes: string | null;
};

type ChainRow = {
  chain_name: string;
  asset_count: number;
  critical_count: number;
  total_book_value_rupees: number;
  total_capex_planned_rupees: number;
  total_amc_renewal_rupees: number;
};

type QuarterRow = {
  replacement_year: number;
  replacement_quarter: string;
  asset_count: number;
  units_to_replace: number;
  total_capex_rupees: number;
  total_amc_renewal_rupees: number;
  total_service_revenue_impact_rupees: number;
};

type CriticalRow = {
  chain_name: string;
  hospital_branch: string;
  asset_serial: string;
  asset_category: string;
  remaining_life_months: number;
  condition_grade: string;
  replacement_status: string;
  expected_eol_date: string;
};

type PoStatusRow = {
  po_status: string;
  pipeline_count: number;
  total_capex_rupees: number;
  total_amc_renewal_rupees: number;
};

type CategoryRow = {
  asset_category: string;
  asset_count: number;
  total_book_value_rupees: number;
  total_capex_rupees: number;
};

function inr(v: number | null | undefined): string {
  const n = Number(v ?? 0);
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(n);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, assetsRes, procurementRes, chainRes, quarterRes, criticalRes, poStatusRes, categoryRes] = await Promise.all([
    supabase.rpc('founder_r2855_eol_overview'),
    supabase.rpc('founder_r2855_eol_assets_list'),
    supabase.rpc('founder_r2855_procurement_pipeline'),
    supabase.rpc('founder_r2855_chain_rollup'),
    supabase.rpc('founder_r2855_quarter_rollup'),
    supabase.rpc('founder_r2855_critical_assets'),
    supabase.rpc('founder_r2855_po_status_breakdown'),
    supabase.rpc('founder_r2855_category_rollup'),
  ]);

  const overview: Overview = (overviewRes.data?.[0] as Overview) ?? {
    total_assets: 0,
    critical_grade: 0,
    poor_grade: 0,
    total_book_value_rupees: 0,
    total_estimated_capex_rupees: 0,
    total_amc_renewal_rupees: 0,
    total_service_revenue_impact_rupees: 0,
  };
  const assets: AssetRow[] = (assetsRes.data as AssetRow[]) ?? [];
  const procurement: ProcurementRow[] = (procurementRes.data as ProcurementRow[]) ?? [];
  const chains: ChainRow[] = (chainRes.data as ChainRow[]) ?? [];
  const quarters: QuarterRow[] = (quarterRes.data as QuarterRow[]) ?? [];
  const critical: CriticalRow[] = (criticalRes.data as CriticalRow[]) ?? [];
  const poStatus: PoStatusRow[] = (poStatusRes.data as PoStatusRow[]) ?? [];
  const categories: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Chain Quarterly Equipment EOL Replacement</h1>
        <p className="text-sm text-gray-600">
          Track end-of-life medical equipment across hospital chains. Plan quarterly replacement waves, capex, AMC renewal value, and service-revenue impact.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total EOL Assets</div>
          <div className="text-xl font-semibold">{overview.total_assets}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Critical Grade</div>
          <div className="text-xl font-semibold text-red-600">{overview.critical_grade}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Poor Grade</div>
          <div className="text-xl font-semibold text-amber-600">{overview.poor_grade}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Current Book Value</div>
          <div className="text-xl font-semibold">{inr(overview.total_book_value_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Planned Capex</div>
          <div className="text-xl font-semibold">{inr(overview.total_estimated_capex_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">AMC Renewal Value</div>
          <div className="text-xl font-semibold">{inr(overview.total_amc_renewal_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Service Revenue Impact</div>
          <div className="text-xl font-semibold">{inr(overview.total_service_revenue_impact_rupees)}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Critical &amp; near-EOL assets (life &lt;= 6 months or poor/critical grade)</h2>
        <DataTable
          rows={critical}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: CriticalRow) => r.chain_name },
            { key: 'hospital_branch', header: 'Branch', render: (r: CriticalRow) => r.hospital_branch },
            { key: 'asset_serial', header: 'Serial', render: (r: CriticalRow) => r.asset_serial },
            { key: 'asset_category', header: 'Category', render: (r: CriticalRow) => r.asset_category },
            { key: 'remaining_life_months', header: 'Life left (mo)', render: (r: CriticalRow) => String(r.remaining_life_months) },
            { key: 'condition_grade', header: 'Grade', render: (r: CriticalRow) => r.condition_grade },
            { key: 'replacement_status', header: 'Status', render: (r: CriticalRow) => r.replacement_status },
            { key: 'expected_eol_date', header: 'EOL date', render: (r: CriticalRow) => r.expected_eol_date },
          ]}
          emptyMessage="No data"
          rowKey={(r: CriticalRow, i: number) => String(r.asset_serial ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Chain rollup</h2>
        <DataTable
          rows={chains}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'asset_count', header: 'EOL assets', render: (r: ChainRow) => String(r.asset_count) },
            { key: 'critical_count', header: 'Critical', render: (r: ChainRow) => String(r.critical_count) },
            { key: 'total_book_value_rupees', header: 'Book value', render: (r: ChainRow) => inr(r.total_book_value_rupees) },
            { key: 'total_capex_planned_rupees', header: 'Planned capex', render: (r: ChainRow) => inr(r.total_capex_planned_rupees) },
            { key: 'total_amc_renewal_rupees', header: 'AMC renewal', render: (r: ChainRow) => inr(r.total_amc_renewal_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Quarter rollup</h2>
        <DataTable
          rows={quarters}
          columns={[
            { key: 'replacement_year', header: 'Year', render: (r: QuarterRow) => String(r.replacement_year) },
            { key: 'replacement_quarter', header: 'Quarter', render: (r: QuarterRow) => r.replacement_quarter },
            { key: 'asset_count', header: 'Assets', render: (r: QuarterRow) => String(r.asset_count) },
            { key: 'units_to_replace', header: 'Units', render: (r: QuarterRow) => String(r.units_to_replace) },
            { key: 'total_capex_rupees', header: 'Capex', render: (r: QuarterRow) => inr(r.total_capex_rupees) },
            { key: 'total_amc_renewal_rupees', header: 'AMC renewal', render: (r: QuarterRow) => inr(r.total_amc_renewal_rupees) },
            { key: 'total_service_revenue_impact_rupees', header: 'Service rev impact', render: (r: QuarterRow) => inr(r.total_service_revenue_impact_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: QuarterRow, i: number) => String(`${r.replacement_year}-${r.replacement_quarter}-${i}`)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Procurement pipeline</h2>
        <DataTable
          rows={procurement}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ProcurementRow) => r.chain_name },
            { key: 'replacement_quarter', header: 'Quarter', render: (r: ProcurementRow) => `${r.replacement_quarter} ${r.replacement_year}` },
            { key: 'asset_category', header: 'Category', render: (r: ProcurementRow) => r.asset_category },
            { key: 'units_to_replace', header: 'Units', render: (r: ProcurementRow) => String(r.units_to_replace) },
            { key: 'estimated_capex_rupees', header: 'Capex', render: (r: ProcurementRow) => inr(r.estimated_capex_rupees) },
            { key: 'vendor_shortlisted', header: 'Vendor', render: (r: ProcurementRow) => r.vendor_shortlisted },
            { key: 'po_status', header: 'PO status', render: (r: ProcurementRow) => r.po_status },
            { key: 'amc_renewal_value_rupees', header: 'AMC renewal', render: (r: ProcurementRow) => inr(r.amc_renewal_value_rupees) },
            { key: 'decision_owner', header: 'Owner', render: (r: ProcurementRow) => r.decision_owner },
            { key: 'decision_due_date', header: 'Decision due', render: (r: ProcurementRow) => r.decision_due_date },
          ]}
          emptyMessage="No data"
          rowKey={(r: ProcurementRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">PO status breakdown</h2>
        <DataTable
          rows={poStatus}
          columns={[
            { key: 'po_status', header: 'PO status', render: (r: PoStatusRow) => r.po_status },
            { key: 'pipeline_count', header: 'Count', render: (r: PoStatusRow) => String(r.pipeline_count) },
            { key: 'total_capex_rupees', header: 'Capex', render: (r: PoStatusRow) => inr(r.total_capex_rupees) },
            { key: 'total_amc_renewal_rupees', header: 'AMC renewal', render: (r: PoStatusRow) => inr(r.total_amc_renewal_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: PoStatusRow, i: number) => String(r.po_status ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Category rollup</h2>
        <DataTable
          rows={categories}
          columns={[
            { key: 'asset_category', header: 'Category', render: (r: CategoryRow) => r.asset_category },
            { key: 'asset_count', header: 'Assets', render: (r: CategoryRow) => String(r.asset_count) },
            { key: 'total_book_value_rupees', header: 'Book value', render: (r: CategoryRow) => inr(r.total_book_value_rupees) },
            { key: 'total_capex_rupees', header: 'Capex', render: (r: CategoryRow) => inr(r.total_capex_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CategoryRow, i: number) => String(r.asset_category ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Full EOL asset register</h2>
        <DataTable
          rows={assets}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: AssetRow) => r.chain_name },
            { key: 'hospital_branch', header: 'Branch', render: (r: AssetRow) => r.hospital_branch },
            { key: 'asset_serial', header: 'Serial', render: (r: AssetRow) => r.asset_serial },
            { key: 'asset_category', header: 'Category', render: (r: AssetRow) => r.asset_category },
            { key: 'asset_make', header: 'Make', render: (r: AssetRow) => `${r.asset_make} ${r.asset_model}` },
            { key: 'install_date', header: 'Installed', render: (r: AssetRow) => r.install_date },
            { key: 'expected_eol_date', header: 'EOL date', render: (r: AssetRow) => r.expected_eol_date },
            { key: 'current_age_months', header: 'Age (mo)', render: (r: AssetRow) => String(r.current_age_months) },
            { key: 'remaining_life_months', header: 'Life left', render: (r: AssetRow) => String(r.remaining_life_months) },
            { key: 'condition_grade', header: 'Grade', render: (r: AssetRow) => r.condition_grade },
            { key: 'current_book_value_rupees', header: 'Book value', render: (r: AssetRow) => inr(r.current_book_value_rupees) },
            { key: 'replacement_quarter', header: 'Plan', render: (r: AssetRow) => `${r.replacement_quarter} ${r.replacement_year}` },
            { key: 'replacement_status', header: 'Status', render: (r: AssetRow) => r.replacement_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: AssetRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
