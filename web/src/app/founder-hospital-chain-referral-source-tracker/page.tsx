import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainReferralSourceTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, roiRes, recentRes, catRes, monthlyRes, chainsRes, lowConfRes] = await Promise.all([
    supabase.rpc('r2395_kpis'),
    supabase.rpc('r2395_source_roi_summary'),
    supabase.rpc('r2395_recent_attributions', { p_limit: 50 }),
    supabase.rpc('r2395_category_rollup'),
    supabase.rpc('r2395_monthly_signups', { p_months: 12 }),
    supabase.rpc('r2395_top_chains'),
    supabase.rpc('r2395_low_confidence_attributions'),
  ]);

  const kpis = (kpisRes.data ?? [])[0] ?? null;
  const roi = roiRes.data ?? [];
  const recent = recentRes.data ?? [];
  const categories = catRes.data ?? [];
  const monthly = monthlyRes.data ?? [];
  const chains = chainsRes.data ?? [];
  const lowConf = lowConfRes.data ?? [];

  const fmtRupees = (v: number | null | undefined) =>
    v == null ? '—' : '₹' + Number(v).toLocaleString('en-IN');
  const fmtNum = (v: number | null | undefined) => (v == null ? '—' : Number(v).toLocaleString('en-IN'));
  const fmtMult = (v: number | null | undefined) => (v == null ? '—' : Number(v).toFixed(2) + 'x');

  const roiCols: Column<any>[] = [
    { key: 'source_name', header: 'Source', render: (r) => r.source_name },
    { key: 'source_category', header: 'Category', render: (r) => r.source_category },
    { key: 'hospitals_signed', header: 'Hospitals', render: (r) => fmtNum(r.hospitals_signed) },
    { key: 'total_cost_rupees', header: 'Cost', render: (r) => fmtRupees(r.total_cost_rupees) },
    { key: 'total_ltv_rupees', header: 'LTV', render: (r) => fmtRupees(r.total_ltv_rupees) },
    { key: 'roi_multiple', header: 'ROI', render: (r) => fmtMult(r.roi_multiple) },
    { key: 'cost_per_hospital_rupees', header: 'CAC', render: (r) => fmtRupees(r.cost_per_hospital_rupees) },
    { key: 'avg_ltv_per_hospital_rupees', header: 'Avg LTV', render: (r) => fmtRupees(r.avg_ltv_per_hospital_rupees) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name ?? '—' },
    { key: 'source_name', header: 'Source', render: (r) => r.source_name },
    { key: 'source_category', header: 'Category', render: (r) => r.source_category },
    { key: 'signup_date', header: 'Signed', render: (r) => r.signup_date },
    { key: 'beds_count', header: 'Beds', render: (r) => fmtNum(r.beds_count) },
    { key: 'city', header: 'City', render: (r) => r.city ?? '—' },
    { key: 'amc_contracts_signed', header: 'AMCs', render: (r) => fmtNum(r.amc_contracts_signed) },
    { key: 'ltv_to_date_rupees', header: 'LTV', render: (r) => fmtRupees(r.ltv_to_date_rupees) },
    { key: 'attribution_confidence', header: 'Conf.', render: (r) => r.attribution_confidence },
  ];

  const catCols: Column<any>[] = [
    { key: 'source_category', header: 'Category', render: (r) => r.source_category },
    { key: 'source_count', header: 'Sources', render: (r) => fmtNum(r.source_count) },
    { key: 'hospitals_signed', header: 'Hospitals', render: (r) => fmtNum(r.hospitals_signed) },
    { key: 'total_cost_rupees', header: 'Spend', render: (r) => fmtRupees(r.total_cost_rupees) },
    { key: 'total_ltv_rupees', header: 'LTV', render: (r) => fmtRupees(r.total_ltv_rupees) },
    { key: 'blended_roi', header: 'Blended ROI', render: (r) => fmtMult(r.blended_roi) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r) => r.month_start },
    { key: 'signups', header: 'Signups', render: (r) => fmtNum(r.signups) },
    { key: 'total_ltv_rupees', header: 'LTV Added', render: (r) => fmtRupees(r.total_ltv_rupees) },
    { key: 'avg_beds', header: 'Avg Beds', render: (r) => fmtNum(r.avg_beds) },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospitals_in_chain', header: 'Hospitals', render: (r) => fmtNum(r.hospitals_in_chain) },
    { key: 'total_beds', header: 'Beds', render: (r) => fmtNum(r.total_beds) },
    { key: 'total_ltv_rupees', header: 'LTV', render: (r) => fmtRupees(r.total_ltv_rupees) },
    { key: 'dominant_source', header: 'Dominant Source', render: (r) => r.dominant_source ?? '—' },
  ];

  const lowCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'source_name', header: 'Source', render: (r) => r.source_name },
    { key: 'signup_date', header: 'Signed', render: (r) => r.signup_date },
    { key: 'attribution_confidence', header: 'Conf.', render: (r) => r.attribution_confidence },
    { key: 'ltv_to_date_rupees', header: 'LTV', render: (r) => fmtRupees(r.ltv_to_date_rupees) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Referral Source Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track which referral sources are bringing in new hospitals & the ROI of each acquisition channel.
        </p>
      </header>

      {kpis && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Active Sources</div>
            <div className="text-xl font-semibold">{fmtNum(kpis.active_sources)} / {fmtNum(kpis.total_sources)}</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Hospitals Attributed</div>
            <div className="text-xl font-semibold">{fmtNum(kpis.total_hospitals)}</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Total Marketing Spend</div>
            <div className="text-xl font-semibold">{fmtRupees(kpis.total_marketing_spend_rupees)}</div>
          </div>
          <div className="p-4 border rounded">
            <div className="text-xs text-gray-500">Total LTV / Blended ROI</div>
            <div className="text-xl font-semibold">{fmtRupees(kpis.total_ltv_rupees)} · {fmtMult(kpis.blended_roi)}</div>
            <div className="text-xs text-gray-500 mt-1">CAC {fmtRupees(kpis.blended_cac_rupees)}</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Source ROI Summary</h2>
        <DataTable
          rows={roi}
          columns={roiCols}
          emptyMessage="No referral sources tracked yet."
          rowKey={(r) => r.source_id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Category Rollup</h2>
        <DataTable
          rows={categories}
          columns={catCols}
          emptyMessage="No category data."
          rowKey={(r) => r.source_category}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Signups (last 12 months)</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          emptyMessage="No signups recorded."
          rowKey={(r) => String(r.month_start)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Chains by LTV</h2>
        <DataTable
          rows={chains}
          columns={chainCols}
          emptyMessage="No chain-level attributions yet."
          rowKey={(r) => r.chain_name}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Attributions</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          emptyMessage="No attributions logged."
          rowKey={(r) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Low-Confidence Attributions (review)</h2>
        <DataTable
          rows={lowConf}
          columns={lowCols}
          emptyMessage="All attributions are high/medium confidence."
          rowKey={(r) => r.id}
        />
      </section>
    </div>
  );
}
