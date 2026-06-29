import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { inspection_month: string; sites: number; total_straps: number; passed: number; failed: number; avg_pass_pct: number };
type RiskBand = { risk_band: string; sites: number; avg_pass_pct: number; total_failed: number };
type EngPerf = { engineer_name: string; inspections: number; avg_pass_pct: number; escalations: number };
type RedBlack = { customer_site_name: string; city: string; risk_band: string; pass_rate_pct: number; straps_failed: number; notes: string | null };
type DefectMix = { defect_type: string; occurrences: number; critical_count: number; avg_cost: number };
type Unresolved = { finding_date: string; strap_serial: string; defect_type: string; severity: string; action_taken: string; replacement_cost_rupees: number };
type CityRoll = { city: string; sites: number; avg_pass_pct: number; total_failed: number; escalations: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [ov, rb, ep, redb, dm, ur, cr] = await Promise.all([
    sb.rpc('rpc_r2990_inspection_overview'),
    sb.rpc('rpc_r2990_risk_band_breakdown'),
    sb.rpc('rpc_r2990_engineer_performance'),
    sb.rpc('rpc_r2990_red_black_sites'),
    sb.rpc('rpc_r2990_defect_mix'),
    sb.rpc('rpc_r2990_unresolved_findings'),
    sb.rpc('rpc_r2990_city_rollup'),
  ]);

  const overview = (ov.data ?? []) as Overview[];
  const risk = (rb.data ?? []) as RiskBand[];
  const eng = (ep.data ?? []) as EngPerf[];
  const redBlack = (redb.data ?? []) as RedBlack[];
  const defect = (dm.data ?? []) as DefectMix[];
  const unresolved = (ur.data ?? []) as Unresolved[];
  const city = (cr.data ?? []) as CityRoll[];

  const ovCols: Column<Overview>[] = [
    { header: 'Month', cell: (r) => r.inspection_month },
    { header: 'Sites', cell: (r) => r.sites },
    { header: 'Straps', cell: (r) => r.total_straps },
    { header: 'Passed', cell: (r) => r.passed },
    { header: 'Failed', cell: (r) => r.failed },
    { header: 'Avg Pass %', cell: (r) => r.avg_pass_pct },
  ];
  const rbCols: Column<RiskBand>[] = [
    { header: 'Risk Band', cell: (r) => r.risk_band },
    { header: 'Sites', cell: (r) => r.sites },
    { header: 'Avg Pass %', cell: (r) => r.avg_pass_pct },
    { header: 'Total Failed', cell: (r) => r.total_failed },
  ];
  const epCols: Column<EngPerf>[] = [
    { header: 'Engineer', cell: (r) => r.engineer_name },
    { header: 'Inspections', cell: (r) => r.inspections },
    { header: 'Avg Pass %', cell: (r) => r.avg_pass_pct },
    { header: 'Escalations', cell: (r) => r.escalations },
  ];
  const redCols: Column<RedBlack>[] = [
    { header: 'Site', cell: (r) => r.customer_site_name },
    { header: 'City', cell: (r) => r.city },
    { header: 'Band', cell: (r) => r.risk_band },
    { header: 'Pass %', cell: (r) => r.pass_rate_pct },
    { header: 'Failed', cell: (r) => r.straps_failed },
    { header: 'Notes', cell: (r) => r.notes ?? '' },
  ];
  const dmCols: Column<DefectMix>[] = [
    { header: 'Defect', cell: (r) => r.defect_type },
    { header: 'Occurrences', cell: (r) => r.occurrences },
    { header: 'Critical', cell: (r) => r.critical_count },
    { header: 'Avg Cost', cell: (r) => r.avg_cost },
  ];
  const urCols: Column<Unresolved>[] = [
    { header: 'Date', cell: (r) => r.finding_date },
    { header: 'Serial', cell: (r) => r.strap_serial },
    { header: 'Defect', cell: (r) => r.defect_type },
    { header: 'Severity', cell: (r) => r.severity },
    { header: 'Action', cell: (r) => r.action_taken },
    { header: 'Cost', cell: (r) => r.replacement_cost_rupees },
  ];
  const crCols: Column<CityRoll>[] = [
    { header: 'City', cell: (r) => r.city },
    { header: 'Sites', cell: (r) => r.sites },
    { header: 'Avg Pass %', cell: (r) => r.avg_pass_pct },
    { header: 'Total Failed', cell: (r) => r.total_failed },
    { header: 'Escalations', cell: (r) => r.escalations },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Hoist Strap Inspection Audit</h1>
        <p className="text-sm text-gray-600">Patient lift hoist safety-strap inspection rollups across customer sites & engineers.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Overview</h2>
        <DataTable rows={overview} columns={ovCols} emptyMessage="No inspections" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Risk Band Breakdown</h2>
        <DataTable rows={risk} columns={rbCols} emptyMessage="No data" rowKey={(r, i) => String(r.risk_band ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Performance</h2>
        <DataTable rows={eng} columns={epCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Red &amp; Black Sites (pass % &lt;= 60)</h2>
        <DataTable rows={redBlack} columns={redCols} emptyMessage="None" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Defect Mix</h2>
        <DataTable rows={defect} columns={dmCols} emptyMessage="No findings" rowKey={(r, i) => String(r.defect_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Unresolved Findings</h2>
        <DataTable rows={unresolved} columns={urCols} emptyMessage="All resolved" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Rollup</h2>
        <DataTable rows={city} columns={crCols} emptyMessage="No cities" rowKey={(r, i) => String(r.city ?? i)} />
      </section>
    </div>
  );
}
