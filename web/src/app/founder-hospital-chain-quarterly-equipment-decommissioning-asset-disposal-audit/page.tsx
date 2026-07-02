import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = {
  id: string;
  chain_name: string;
  branches: number;
  total_units: number;
  total_book_value_lakhs: number;
  total_salvage_lakhs: number;
  pending_pickup_units: number;
};

type CategoryRow = {
  id: string;
  equipment_category: string;
  units: number;
  avg_acquisition_lakhs: number;
  avg_book_lakhs: number;
  recovery_pct: number;
};

type VendorRow = {
  id: string;
  vendor_name: string;
  vendor_category: string;
  vendor_city: string;
  total_units_handled: number;
  total_payout_lakhs: number;
  rating: number;
  compliance_flag: string;
  days_to_cpcb_expiry: number;
};

type RiskRow = {
  id: string;
  asset_tag: string;
  chain_name: string;
  hospital_branch: string;
  equipment_category: string;
  risk_reason: string;
  severity: string;
  audit_findings: string | null;
};

type CityRow = {
  id: string;
  city: string;
  units: number;
  disposed: number;
  pending: number;
  quarantined: number;
  total_book_lakhs: number;
};

type VintageRow = {
  id: string;
  vintage_band: string;
  units: number;
  avg_age_years: number;
  total_book_lakhs: number;
};

type MethodRow = {
  id: string;
  disposal_method: string;
  units: number;
  pct_of_total: number;
  total_salvage_lakhs: number;
};

type ToplineRow = {
  id: string;
  metric: string;
  value_text: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    chainRes,
    catRes,
    vendorRes,
    riskRes,
    cityRes,
    vintageRes,
    methodRes,
    toplineRes,
  ] = await Promise.all([
    supabase.rpc('chain_summary_r2927'),
    supabase.rpc('category_breakdown_r2927'),
    supabase.rpc('vendor_scorecard_r2927'),
    supabase.rpc('compliance_risk_queue_r2927'),
    supabase.rpc('city_heatmap_r2927'),
    supabase.rpc('vintage_distribution_r2927'),
    supabase.rpc('disposal_method_mix_r2927'),
    supabase.rpc('q1_topline_r2927'),
  ]);

  const chain: ChainRow[] = (chainRes.data as ChainRow[]) ?? [];
  const categories: CategoryRow[] = (catRes.data as CategoryRow[]) ?? [];
  const vendors: VendorRow[] = (vendorRes.data as VendorRow[]) ?? [];
  const risks: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];
  const cities: CityRow[] = (cityRes.data as CityRow[]) ?? [];
  const vintages: VintageRow[] = (vintageRes.data as VintageRow[]) ?? [];
  const methods: MethodRow[] = (methodRes.data as MethodRow[]) ?? [];
  const topline: ToplineRow[] = (toplineRes.data as ToplineRow[]) ?? [];

  const toplineCols: Column<ToplineRow>[] = [
    { key: 'metric', header: 'Metric', render: (r) => r.metric },
    { key: 'value_text', header: 'Value', render: (r) => r.value_text },
  ];

  const chainCols: Column<ChainRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'branches', header: 'Branches', render: (r) => r.branches },
    { key: 'total_units', header: 'Units', render: (r) => r.total_units },
    { key: 'total_book_value_lakhs', header: 'Book (L)', render: (r) => r.total_book_value_lakhs },
    { key: 'total_salvage_lakhs', header: 'Salvage (L)', render: (r) => r.total_salvage_lakhs },
    { key: 'pending_pickup_units', header: 'Pending pickup', render: (r) => r.pending_pickup_units },
  ];

  const catCols: Column<CategoryRow>[] = [
    { key: 'equipment_category', header: 'Category', render: (r) => r.equipment_category },
    { key: 'units', header: 'Units', render: (r) => r.units },
    { key: 'avg_acquisition_lakhs', header: 'Avg acq (L)', render: (r) => r.avg_acquisition_lakhs },
    { key: 'avg_book_lakhs', header: 'Avg book (L)', render: (r) => r.avg_book_lakhs },
    { key: 'recovery_pct', header: 'Recovery %', render: (r) => r.recovery_pct },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { key: 'vendor_name', header: 'Vendor', render: (r) => r.vendor_name },
    { key: 'vendor_category', header: 'Category', render: (r) => r.vendor_category },
    { key: 'vendor_city', header: 'City', render: (r) => r.vendor_city },
    { key: 'total_units_handled', header: 'Units', render: (r) => r.total_units_handled },
    { key: 'total_payout_lakhs', header: 'Payout (L)', render: (r) => r.total_payout_lakhs },
    { key: 'rating', header: 'Rating', render: (r) => r.rating },
    { key: 'compliance_flag', header: 'Flag', render: (r) => r.compliance_flag },
    { key: 'days_to_cpcb_expiry', header: 'CPCB days', render: (r) => r.days_to_cpcb_expiry },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'asset_tag', header: 'Asset', render: (r) => r.asset_tag },
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_branch', header: 'Branch', render: (r) => r.hospital_branch },
    { key: 'equipment_category', header: 'Equipment', render: (r) => r.equipment_category },
    { key: 'risk_reason', header: 'Risk reason', render: (r) => r.risk_reason },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'audit_findings', header: 'Notes', render: (r) => r.audit_findings ?? '' },
  ];

  const cityCols: Column<CityRow>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'units', header: 'Units', render: (r) => r.units },
    { key: 'disposed', header: 'Disposed', render: (r) => r.disposed },
    { key: 'pending', header: 'Pending', render: (r) => r.pending },
    { key: 'quarantined', header: 'Quarantined', render: (r) => r.quarantined },
    { key: 'total_book_lakhs', header: 'Book (L)', render: (r) => r.total_book_lakhs },
  ];

  const vintageCols: Column<VintageRow>[] = [
    { key: 'vintage_band', header: 'Vintage', render: (r) => r.vintage_band },
    { key: 'units', header: 'Units', render: (r) => r.units },
    { key: 'avg_age_years', header: 'Avg age (yr)', render: (r) => r.avg_age_years },
    { key: 'total_book_lakhs', header: 'Book (L)', render: (r) => r.total_book_lakhs },
  ];

  const methodCols: Column<MethodRow>[] = [
    { key: 'disposal_method', header: 'Method', render: (r) => r.disposal_method },
    { key: 'units', header: 'Units', render: (r) => r.units },
    { key: 'pct_of_total', header: '% of total', render: (r) => r.pct_of_total },
    { key: 'total_salvage_lakhs', header: 'Salvage (L)', render: (r) => r.total_salvage_lakhs },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>
          Hospital Chain Quarterly Equipment Decommissioning & Asset Disposal Audit
        </h1>
        <p style={{ color: '#666', marginTop: 6 }}>
          Round r2927 · Q1-2026 quarterly close: book-value at risk, CPCB compliance,
          vendor scorecards, biohazard & radiation quarantine queue. Recovery % = salvage / book value.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Q1 topline</h2>
        <DataTable
          rows={topline}
          columns={toplineCols}
          emptyMessage="No topline data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Chain summary</h2>
        <DataTable
          rows={chain}
          columns={chainCols}
          emptyMessage="No chains"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Category breakdown</h2>
        <DataTable
          rows={categories}
          columns={catCols}
          emptyMessage="No categories"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Vendor scorecard</h2>
        <DataTable
          rows={vendors}
          columns={vendorCols}
          emptyMessage="No vendors"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Compliance risk queue</h2>
        <DataTable
          rows={risks}
          columns={riskCols}
          emptyMessage="No outstanding risks"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>City heatmap</h2>
        <DataTable
          rows={cities}
          columns={cityCols}
          emptyMessage="No cities"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Vintage distribution</h2>
        <DataTable
          rows={vintages}
          columns={vintageCols}
          emptyMessage="No vintage rows"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Disposal method mix</h2>
        <DataTable
          rows={methods}
          columns={methodCols}
          emptyMessage="No methods"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
