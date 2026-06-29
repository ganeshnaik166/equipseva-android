import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { hospital_chain: string; audits: number; pass_count: number; fail_count: number; critical_count: number; avg_atp: number; avg_visual: number };
type BranchFailRow = { hospital_chain: string; hospital_branch: string; city: string; pass_status: string; swab_atp_rlu: number; gasket_integrity_pct: number; audit_date: string };
type ZoneRow = { window_zone: string; audits: number; avg_atp: number; avg_gasket: number; fail_rate_pct: number };
type CatRow = { finding_category: string; total: number; critical_count: number; open_count: number; closed_count: number };
type EscRow = { hospital_chain: string; hospital_branch: string; finding_category: string; severity: string; location_detail: string; recommended_action: string };
type QtrRow = { quarter: string; audits: number; avg_atp: number; pass_rate_pct: number; critical_count: number };
type CityRow = { city: string; audits: number; avg_visual: number; avg_sanitizer: number; fail_count: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [chain, branchFail, zone, cat, esc, qtr, city] = await Promise.all([
    supabase.rpc('r3043_chain_rollup'),
    supabase.rpc('r3043_branch_failures'),
    supabase.rpc('r3043_zone_hygiene'),
    supabase.rpc('r3043_findings_by_category'),
    supabase.rpc('r3043_open_escalations'),
    supabase.rpc('r3043_quarter_trend'),
    supabase.rpc('r3043_city_leaderboard'),
  ]);

  const chainRows: ChainRow[] = (chain.data as ChainRow[]) ?? [];
  const branchFailRows: BranchFailRow[] = (branchFail.data as BranchFailRow[]) ?? [];
  const zoneRows: ZoneRow[] = (zone.data as ZoneRow[]) ?? [];
  const catRows: CatRow[] = (cat.data as CatRow[]) ?? [];
  const escRows: EscRow[] = (esc.data as EscRow[]) ?? [];
  const qtrRows: QtrRow[] = (qtr.data as QtrRow[]) ?? [];
  const cityRows: CityRow[] = (city.data as CityRow[]) ?? [];

  const chainCols: Column<ChainRow>[] = [
    { header: 'Chain', accessor: (r) => r.hospital_chain },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Pass', accessor: (r) => r.pass_count },
    { header: 'Fail', accessor: (r) => r.fail_count },
    { header: 'Critical', accessor: (r) => r.critical_count },
    { header: 'Avg ATP RLU', accessor: (r) => r.avg_atp },
    { header: 'Avg Visual', accessor: (r) => r.avg_visual },
  ];

  const branchFailCols: Column<BranchFailRow>[] = [
    { header: 'Chain', accessor: (r) => r.hospital_chain },
    { header: 'Branch', accessor: (r) => r.hospital_branch },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Status', accessor: (r) => r.pass_status },
    { header: 'ATP RLU', accessor: (r) => r.swab_atp_rlu },
    { header: 'Gasket %', accessor: (r) => r.gasket_integrity_pct },
    { header: 'Audit Date', accessor: (r) => r.audit_date },
  ];

  const zoneCols: Column<ZoneRow>[] = [
    { header: 'Window Zone', accessor: (r) => r.window_zone },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg ATP', accessor: (r) => r.avg_atp },
    { header: 'Avg Gasket %', accessor: (r) => r.avg_gasket },
    { header: 'Fail Rate %', accessor: (r) => r.fail_rate_pct },
  ];

  const catCols: Column<CatRow>[] = [
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Critical', accessor: (r) => r.critical_count },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Closed', accessor: (r) => r.closed_count },
  ];

  const escCols: Column<EscRow>[] = [
    { header: 'Chain', accessor: (r) => r.hospital_chain },
    { header: 'Branch', accessor: (r) => r.hospital_branch },
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Location', accessor: (r) => r.location_detail },
    { header: 'Action', accessor: (r) => r.recommended_action },
  ];

  const qtrCols: Column<QtrRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg ATP', accessor: (r) => r.avg_atp },
    { header: 'Pass Rate %', accessor: (r) => r.pass_rate_pct },
    { header: 'Critical', accessor: (r) => r.critical_count },
  ];

  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg Visual', accessor: (r) => r.avg_visual },
    { header: 'Avg Sanitizer ppm', accessor: (r) => r.avg_sanitizer },
    { header: 'Fails', accessor: (r) => r.fail_count },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Patient-Diet Tray Pass-Through Window Hygiene Audit</h1>
        <p className="text-sm text-gray-600">ATP swab, gasket integrity & sanitizer residue across chain branches (r3043).</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Rollup</h2>
        <DataTable<ChainRow> rows={chainRows} columns={chainCols} emptyMessage="No chain data" rowKey={(r, i) => String(r.hospital_chain ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Branch Failures (ATP &gt;= 480 or status fail/critical)</h2>
        <DataTable<BranchFailRow> rows={branchFailRows} columns={branchFailCols} emptyMessage="No failing branches" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Zone Hygiene</h2>
        <DataTable<ZoneRow> rows={zoneRows} columns={zoneCols} emptyMessage="No zone data" rowKey={(r, i) => String(r.window_zone ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Findings by Category</h2>
        <DataTable<CatRow> rows={catRows} columns={catCols} emptyMessage="No findings" rowKey={(r, i) => String(r.finding_category ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Escalations</h2>
        <DataTable<EscRow> rows={escRows} columns={escCols} emptyMessage="No open escalations" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter Trend</h2>
        <DataTable<QtrRow> rows={qtrRows} columns={qtrCols} emptyMessage="No quarter data" rowKey={(r, i) => String(r.quarter ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Leaderboard</h2>
        <DataTable<CityRow> rows={cityRows} columns={cityCols} emptyMessage="No city data" rowKey={(r, i) => String(r.city ?? i)} />
      </section>
    </main>
  );
}
