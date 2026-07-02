import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type BrandSummary = { brand: string; total_units: number; avg_uptime: number; avg_mttr: number; red_units: number; retired_units: number };
type ChainHealth = { chain_name: string; total_units: number; green_units: number; amber_units: number; red_units: number; avg_uptime: number };
type WorstUnit = { chain_name: string; hospital_site: string; brand: string; unit_serial: string; uptime_pct: number; mttr_hours: number; incidents_q: number; fleet_status: string };
type WardPerf = { ward_type: string; units: number; avg_uptime: number; avg_mtbf: number; total_incidents: number };
type Finding = { chain_name: string; brand: string; finding_quarter: string; finding_category: string; severity: string; units_affected: number; cost_impact_rupees: number; remediation_status: string };
type BrandCost = { brand: string; findings: number; p0_count: number; total_cost: number; units_affected_total: number };
type QuarterTrend = { finding_quarter: string; findings: number; p0_count: number; total_cost: number; resolved_count: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [brandRes, chainRes, worstRes, wardRes, findRes, costRes, trendRes] = await Promise.all([
    supabase.rpc('rpc_r2963_brand_fleet_summary'),
    supabase.rpc('rpc_r2963_chain_fleet_health'),
    supabase.rpc('rpc_r2963_worst_units'),
    supabase.rpc('rpc_r2963_ward_type_perf'),
    supabase.rpc('rpc_r2963_open_critical_findings'),
    supabase.rpc('rpc_r2963_brand_cost_rollup'),
    supabase.rpc('rpc_r2963_quarterly_trend'),
  ]);

  const brands = (brandRes.data ?? []) as BrandSummary[];
  const chains = (chainRes.data ?? []) as ChainHealth[];
  const worst = (worstRes.data ?? []) as WorstUnit[];
  const wards = (wardRes.data ?? []) as WardPerf[];
  const findings = (findRes.data ?? []) as Finding[];
  const costs = (costRes.data ?? []) as BrandCost[];
  const trend = (trendRes.data ?? []) as QuarterTrend[];

  const brandCols: Column<BrandSummary>[] = [
    { header: 'Brand', accessor: (r) => r.brand },
    { header: 'Units', accessor: (r) => r.total_units },
    { header: 'Avg Uptime %', accessor: (r) => r.avg_uptime },
    { header: 'Avg MTTR (h)', accessor: (r) => r.avg_mttr },
    { header: 'Red Units', accessor: (r) => r.red_units },
    { header: 'Retired', accessor: (r) => r.retired_units },
  ];

  const chainCols: Column<ChainHealth>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Units', accessor: (r) => r.total_units },
    { header: 'Green', accessor: (r) => r.green_units },
    { header: 'Amber', accessor: (r) => r.amber_units },
    { header: 'Red', accessor: (r) => r.red_units },
    { header: 'Avg Uptime %', accessor: (r) => r.avg_uptime },
  ];

  const worstCols: Column<WorstUnit>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'Brand', accessor: (r) => r.brand },
    { header: 'Serial', accessor: (r) => r.unit_serial },
    { header: 'Uptime %', accessor: (r) => r.uptime_pct },
    { header: 'MTTR (h)', accessor: (r) => r.mttr_hours },
    { header: 'Incidents', accessor: (r) => r.incidents_q },
    { header: 'Status', accessor: (r) => r.fleet_status },
  ];

  const wardCols: Column<WardPerf>[] = [
    { header: 'Ward Type', accessor: (r) => r.ward_type },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Avg Uptime %', accessor: (r) => r.avg_uptime },
    { header: 'Avg MTBF (days)', accessor: (r) => r.avg_mtbf },
    { header: 'Incidents Q', accessor: (r) => r.total_incidents },
  ];

  const findCols: Column<Finding>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Brand', accessor: (r) => r.brand },
    { header: 'Quarter', accessor: (r) => r.finding_quarter },
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Units', accessor: (r) => r.units_affected },
    { header: 'Cost (Rs)', accessor: (r) => r.cost_impact_rupees },
    { header: 'Status', accessor: (r) => r.remediation_status },
  ];

  const costCols: Column<BrandCost>[] = [
    { header: 'Brand', accessor: (r) => r.brand },
    { header: 'Findings', accessor: (r) => r.findings },
    { header: 'P0', accessor: (r) => r.p0_count },
    { header: 'Total Cost (Rs)', accessor: (r) => r.total_cost },
    { header: 'Units Affected', accessor: (r) => r.units_affected_total },
  ];

  const trendCols: Column<QuarterTrend>[] = [
    { header: 'Quarter', accessor: (r) => r.finding_quarter },
    { header: 'Findings', accessor: (r) => r.findings },
    { header: 'P0', accessor: (r) => r.p0_count },
    { header: 'Total Cost (Rs)', accessor: (r) => r.total_cost },
    { header: 'Resolved', accessor: (r) => r.resolved_count },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly NICU/PICU Incubator-Brand Fleet-Performance Audit</h1>
        <p className="text-sm text-gray-600">Round r2963 · founder console</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Brand fleet summary</h2>
        <DataTable rows={brands} columns={brandCols} emptyMessage="No brand data" rowKey={(r, i) => String((r as BrandSummary).brand ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain fleet health</h2>
        <DataTable rows={chains} columns={chainCols} emptyMessage="No chain data" rowKey={(r, i) => String((r as ChainHealth).chain_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Worst-performing units (uptime &lt; 97% or red/retired)</h2>
        <DataTable rows={worst} columns={worstCols} emptyMessage="No problem units" rowKey={(r, i) => String((r as WorstUnit).unit_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Ward-type performance</h2>
        <DataTable rows={wards} columns={wardCols} emptyMessage="No ward data" rowKey={(r, i) => String((r as WardPerf).ward_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open critical findings (p0/p1)</h2>
        <DataTable rows={findings} columns={findCols} emptyMessage="No open critical findings" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Brand audit cost rollup</h2>
        <DataTable rows={costs} columns={costCols} emptyMessage="No cost data" rowKey={(r, i) => String((r as BrandCost).brand ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly trend</h2>
        <DataTable rows={trend} columns={trendCols} emptyMessage="No trend data" rowKey={(r, i) => String((r as QuarterTrend).finding_quarter ?? i)} />
      </section>
    </main>
  );
}
