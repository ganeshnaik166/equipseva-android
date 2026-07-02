import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Summary = { total_findings: number; p0_count: number; p1_count: number; total_headcount_affected: number; total_correction_cost_lpa: number; avg_attrition_risk: number; open_count: number };
type CityRow = { city: string; band_count: number; total_headcount: number; avg_compa: number; avg_market_gap: number };
type Hotspot = { lower_band: string; upper_band: string; job_family: string; city: string; overlap_pct: number; affected_headcount: number; severity: string };
type Lag = { band_level: string; job_family: string; city: string; current_median_lpa: number; market_p50_lpa: number; market_gap_pct: number; headcount: number };
type Budget = { job_family: string; findings: number; headcount_affected: number; total_cost_lpa: number; avg_attrition_risk: number };
type Due = { finding_type: string; severity: string; lower_band: string; upper_band: string; city: string; owner: string; due_date: string; status: string };
type Dist = { bucket: string; band_count: number; total_headcount: number };
type Status = { status: string; findings: number; total_cost_lpa: number; headcount_affected: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [summaryR, cityR, hotR, lagR, budR, dueR, distR, statR] = await Promise.all([
    supabase.rpc('r2977_summary'),
    supabase.rpc('r2977_bands_by_city'),
    supabase.rpc('r2977_compression_hotspots'),
    supabase.rpc('r2977_market_lag'),
    supabase.rpc('r2977_budget_by_family'),
    supabase.rpc('r2977_due_soon'),
    supabase.rpc('r2977_penetration_dist'),
    supabase.rpc('r2977_status_board'),
  ]);
  const summary: Summary | null = (summaryR.data as Summary[] | null)?.[0] ?? null;
  const city = (cityR.data as CityRow[] | null) ?? [];
  const hot = (hotR.data as Hotspot[] | null) ?? [];
  const lag = (lagR.data as Lag[] | null) ?? [];
  const bud = (budR.data as Budget[] | null) ?? [];
  const due = (dueR.data as Due[] | null) ?? [];
  const dist = (distR.data as Dist[] | null) ?? [];
  const stat = (statR.data as Status[] | null) ?? [];

  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Bands', accessor: (r) => r.band_count },
    { header: 'Headcount', accessor: (r) => r.total_headcount },
    { header: 'Avg Compa', accessor: (r) => Number(r.avg_compa).toFixed(3) },
    { header: 'Avg Market Gap %', accessor: (r) => Number(r.avg_market_gap).toFixed(2) },
  ];
  const hotCols: Column<Hotspot>[] = [
    { header: 'Lower', accessor: (r) => r.lower_band },
    { header: 'Upper', accessor: (r) => r.upper_band },
    { header: 'Family', accessor: (r) => r.job_family },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Overlap %', accessor: (r) => Number(r.overlap_pct).toFixed(2) },
    { header: 'Headcount', accessor: (r) => r.affected_headcount },
    { header: 'Severity', accessor: (r) => r.severity },
  ];
  const lagCols: Column<Lag>[] = [
    { header: 'Band', accessor: (r) => r.band_level },
    { header: 'Family', accessor: (r) => r.job_family },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Median LPA', accessor: (r) => Number(r.current_median_lpa).toFixed(2) },
    { header: 'Market p50', accessor: (r) => Number(r.market_p50_lpa).toFixed(2) },
    { header: 'Gap %', accessor: (r) => Number(r.market_gap_pct).toFixed(2) },
    { header: 'Headcount', accessor: (r) => r.headcount },
  ];
  const budCols: Column<Budget>[] = [
    { header: 'Family', accessor: (r) => r.job_family },
    { header: 'Findings', accessor: (r) => r.findings },
    { header: 'Headcount', accessor: (r) => r.headcount_affected },
    { header: 'Cost LPA', accessor: (r) => Number(r.total_cost_lpa).toFixed(2) },
    { header: 'Avg Attrition %', accessor: (r) => Number(r.avg_attrition_risk).toFixed(2) },
  ];
  const dueCols: Column<Due>[] = [
    { header: 'Type', accessor: (r) => r.finding_type },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Lower', accessor: (r) => r.lower_band },
    { header: 'Upper', accessor: (r) => r.upper_band },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Owner', accessor: (r) => r.owner },
    { header: 'Due', accessor: (r) => r.due_date },
    { header: 'Status', accessor: (r) => r.status },
  ];
  const distCols: Column<Dist>[] = [
    { header: 'Bucket', accessor: (r) => r.bucket },
    { header: 'Bands', accessor: (r) => r.band_count },
    { header: 'Headcount', accessor: (r) => r.total_headcount },
  ];
  const statCols: Column<Status>[] = [
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Findings', accessor: (r) => r.findings },
    { header: 'Cost LPA', accessor: (r) => Number(r.total_cost_lpa).toFixed(2) },
    { header: 'Headcount', accessor: (r) => r.headcount_affected },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Engineering Salary-Band Compression Risk Audit</h1>
        <p className="text-sm text-gray-600">Round r2977 — band compression, inversion & market-lag findings</p>
      </header>

      {summary && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Total Findings</div><div className="text-xl font-semibold">{summary.total_findings}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">P0</div><div className="text-xl font-semibold">{summary.p0_count}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">P1</div><div className="text-xl font-semibold">{summary.p1_count}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Open</div><div className="text-xl font-semibold">{summary.open_count}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Headcount Affected</div><div className="text-xl font-semibold">{summary.total_headcount_affected}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Correction Cost LPA</div><div className="text-xl font-semibold">{Number(summary.total_correction_cost_lpa).toFixed(2)}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Avg Attrition Risk %</div><div className="text-xl font-semibold">{Number(summary.avg_attrition_risk).toFixed(2)}</div></div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Bands by City</h2>
        <DataTable rows={city} columns={cityCols} emptyMessage="No city snapshots" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Compression Hotspots (overlap &gt;= 0%)</h2>
        <DataTable rows={hot} columns={hotCols} emptyMessage="No hotspots" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Market Lag (gap &lt; -10%)</h2>
        <DataTable rows={lag} columns={lagCols} emptyMessage="No lag" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Correction Budget by Family</h2>
        <DataTable rows={bud} columns={budCols} emptyMessage="No budget rows" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Due Soon (&lt;= 2026-08-15)</h2>
        <DataTable rows={due} columns={dueCols} emptyMessage="Nothing due" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Range Penetration Distribution</h2>
        <DataTable rows={dist} columns={distCols} emptyMessage="No dist" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Board</h2>
        <DataTable rows={stat} columns={statCols} emptyMessage="No status" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
