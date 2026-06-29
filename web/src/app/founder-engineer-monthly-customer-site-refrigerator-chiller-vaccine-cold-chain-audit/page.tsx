import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CityRow = { city: string; visits: number; avg_score: number; fails: number; value_at_risk_rupees: number };
type EngRow = { engineer_name: string; visits: number; avg_score: number; passes: number; fails: number };
type AssetRow = { asset_kind: string; visits: number; excursion_minutes_total: number; value_at_risk_rupees: number };
type SevRow = { severity: string; findings: number; open_count: number; parts_rupees: number };
type SiteRow = { customer_site: string; city: string; audit_score: number; excursion_minutes_last_30d: number; value_at_risk_rupees: number; outcome: string };
type CatRow = { finding_category: string; findings: number; escalated: number; parts_rupees: number };
type KpiRow = { metric: string; value: string };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [city, eng, asset, sev, sites, cat, kpi] = await Promise.all([
    sb.rpc('r2994_city_rollup'),
    sb.rpc('r2994_engineer_scoreboard'),
    sb.rpc('r2994_asset_risk_mix'),
    sb.rpc('r2994_severity_ladder'),
    sb.rpc('r2994_top_sites_at_risk'),
    sb.rpc('r2994_finding_category_mix'),
    sb.rpc('r2994_monthly_kpi'),
  ]);

  const cityRows: CityRow[] = (city.data as CityRow[]) ?? [];
  const engRows: EngRow[] = (eng.data as EngRow[]) ?? [];
  const assetRows: AssetRow[] = (asset.data as AssetRow[]) ?? [];
  const sevRows: SevRow[] = (sev.data as SevRow[]) ?? [];
  const siteRows: SiteRow[] = (sites.data as SiteRow[]) ?? [];
  const catRows: CatRow[] = (cat.data as CatRow[]) ?? [];
  const kpiRows: KpiRow[] = (kpi.data as KpiRow[]) ?? [];

  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Avg score', accessor: (r) => r.avg_score },
    { header: 'Fails', accessor: (r) => r.fails },
    { header: 'Value at risk (Rs)', accessor: (r) => r.value_at_risk_rupees.toLocaleString('en-IN') },
  ];
  const engCols: Column<EngRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Avg score', accessor: (r) => r.avg_score },
    { header: 'Pass', accessor: (r) => r.passes },
    { header: 'Fail', accessor: (r) => r.fails },
  ];
  const assetCols: Column<AssetRow>[] = [
    { header: 'Asset kind', accessor: (r) => r.asset_kind },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Excursion minutes (30d total)', accessor: (r) => r.excursion_minutes_total },
    { header: 'Value at risk (Rs)', accessor: (r) => r.value_at_risk_rupees.toLocaleString('en-IN') },
  ];
  const sevCols: Column<SevRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Findings', accessor: (r) => r.findings },
    { header: 'Open / in-progress / escalated', accessor: (r) => r.open_count },
    { header: 'Parts (Rs)', accessor: (r) => r.parts_rupees.toLocaleString('en-IN') },
  ];
  const siteCols: Column<SiteRow>[] = [
    { header: 'Customer site', accessor: (r) => r.customer_site },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Score', accessor: (r) => r.audit_score },
    { header: 'Excursion mins', accessor: (r) => r.excursion_minutes_last_30d },
    { header: 'Value at risk (Rs)', accessor: (r) => r.value_at_risk_rupees.toLocaleString('en-IN') },
    { header: 'Outcome', accessor: (r) => r.outcome },
  ];
  const catCols: Column<CatRow>[] = [
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Findings', accessor: (r) => r.findings },
    { header: 'Escalated', accessor: (r) => r.escalated },
    { header: 'Parts (Rs)', accessor: (r) => r.parts_rupees.toLocaleString('en-IN') },
  ];
  const kpiCols: Column<KpiRow>[] = [
    { header: 'Metric', accessor: (r) => r.metric },
    { header: 'Value', accessor: (r) => r.value },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Monthly Cold-Chain Audit — r2994</h1>
        <p className="text-sm text-gray-600">
          Refrigerator, chiller, plasma freezer and walk-in cold-room audits across customer sites. Pass rate target &gt;= 85%, P0/P1 findings must close within 7 days.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Monthly KPI</h2>
        <DataTable rows={kpiRows} columns={kpiCols} emptyMessage="No KPI yet" rowKey={(r, i) => String(r.metric ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">City rollup</h2>
        <DataTable rows={cityRows} columns={cityCols} emptyMessage="No cities" rowKey={(r, i) => String(r.city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Engineer scoreboard</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Asset risk mix</h2>
        <DataTable rows={assetRows} columns={assetCols} emptyMessage="No assets" rowKey={(r, i) => String(r.asset_kind ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Severity ladder</h2>
        <DataTable rows={sevRows} columns={sevCols} emptyMessage="No findings" rowKey={(r, i) => String(r.severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top sites at risk</h2>
        <DataTable rows={siteRows} columns={siteCols} emptyMessage="No sites" rowKey={(r, i) => String(r.customer_site ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Finding category mix</h2>
        <DataTable rows={catRows} columns={catCols} emptyMessage="No categories" rowKey={(r, i) => String(r.finding_category ?? i)} />
      </section>
    </main>
  );
}
