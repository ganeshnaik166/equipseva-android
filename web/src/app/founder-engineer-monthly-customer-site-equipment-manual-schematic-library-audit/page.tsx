import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { total_audits: number; clean_audits: number; minor_gap: number; major_gap: number; critical_gap: number; avg_coverage: number; total_equipment: number; total_manuals_missing: number; total_schematics_missing: number };
type ByCategory = { equipment_category: string; audit_count: number; avg_coverage: number; total_missing: number };
type Leader = { engineer_name: string; sites_audited: number; avg_coverage: number; total_minutes: number; critical_count: number };
type CriticalSite = { customer_site: string; city: string; engineer_name: string; equipment_category: string; coverage_pct: number; manuals_missing: number; schematics_missing: number };
type GapType = { gap_type: string; severity: string; gap_count: number; avg_age: number };
type OemRow = { oem_name: string; total_gaps: number; received_count: number; escalated_count: number; pending_count: number; response_rate: number };
type CityRow = { city: string; sites: number; avg_coverage: number; total_equipment: number; critical_gaps: number };
type StaleRow = { equipment_model: string; oem_name: string; gap_type: string; severity: string; age_days: number; request_status: string; resolution_eta: string | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ov, cat, lb, crit, gt, oem, city, stale] = await Promise.all([
    supabase.rpc('r2998_audit_overview'),
    supabase.rpc('r2998_audits_by_category'),
    supabase.rpc('r2998_engineer_leaderboard'),
    supabase.rpc('r2998_critical_sites'),
    supabase.rpc('r2998_gaps_by_type'),
    supabase.rpc('r2998_oem_response'),
    supabase.rpc('r2998_city_summary'),
    supabase.rpc('r2998_stale_gaps'),
  ]);

  const overview = ((ov.data ?? []) as Overview[])[0];
  const categories = (cat.data ?? []) as ByCategory[];
  const leaders = (lb.data ?? []) as Leader[];
  const criticals = (crit.data ?? []) as CriticalSite[];
  const gapTypes = (gt.data ?? []) as GapType[];
  const oems = (oem.data ?? []) as OemRow[];
  const cities = (city.data ?? []) as CityRow[];
  const staleGaps = (stale.data ?? []) as StaleRow[];

  const catCols: Column<ByCategory>[] = [
    { header: 'Category', accessor: (r) => r.equipment_category },
    { header: 'Audits', accessor: (r) => r.audit_count },
    { header: 'Avg Coverage %', accessor: (r) => r.avg_coverage },
    { header: 'Total Missing', accessor: (r) => r.total_missing },
  ];
  const lbCols: Column<Leader>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Sites', accessor: (r) => r.sites_audited },
    { header: 'Avg Coverage %', accessor: (r) => r.avg_coverage },
    { header: 'Minutes', accessor: (r) => r.total_minutes },
    { header: 'Critical', accessor: (r) => r.critical_count },
  ];
  const critCols: Column<CriticalSite>[] = [
    { header: 'Site', accessor: (r) => r.customer_site },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Category', accessor: (r) => r.equipment_category },
    { header: 'Coverage %', accessor: (r) => r.coverage_pct },
    { header: 'Manuals Missing', accessor: (r) => r.manuals_missing },
    { header: 'Schematics Missing', accessor: (r) => r.schematics_missing },
  ];
  const gtCols: Column<GapType>[] = [
    { header: 'Gap Type', accessor: (r) => r.gap_type },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Count', accessor: (r) => r.gap_count },
    { header: 'Avg Age (d)', accessor: (r) => r.avg_age },
  ];
  const oemCols: Column<OemRow>[] = [
    { header: 'OEM', accessor: (r) => r.oem_name },
    { header: 'Total Gaps', accessor: (r) => r.total_gaps },
    { header: 'Received', accessor: (r) => r.received_count },
    { header: 'Escalated', accessor: (r) => r.escalated_count },
    { header: 'Pending', accessor: (r) => r.pending_count },
    { header: 'Response %', accessor: (r) => r.response_rate },
  ];
  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Sites', accessor: (r) => r.sites },
    { header: 'Avg Coverage %', accessor: (r) => r.avg_coverage },
    { header: 'Equipment', accessor: (r) => r.total_equipment },
    { header: 'Critical Gaps', accessor: (r) => r.critical_gaps },
  ];
  const staleCols: Column<StaleRow>[] = [
    { header: 'Model', accessor: (r) => r.equipment_model },
    { header: 'OEM', accessor: (r) => r.oem_name },
    { header: 'Gap', accessor: (r) => r.gap_type },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Age (d)', accessor: (r) => r.age_days },
    { header: 'Status', accessor: (r) => r.request_status },
    { header: 'ETA', accessor: (r) => r.resolution_eta ?? '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Manual & Schematic Library Audit</h1>
        <p className="text-sm text-gray-600">Round 2998 — Coverage of equipment documentation across customer sites</p>
      </header>

      {overview && (
        <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div className="p-3 border rounded"><div className="text-xs text-gray-500">Audits</div><div className="text-xl font-semibold">{overview.total_audits}</div></div>
          <div className="p-3 border rounded"><div className="text-xs text-gray-500">Clean</div><div className="text-xl font-semibold">{overview.clean_audits}</div></div>
          <div className="p-3 border rounded"><div className="text-xs text-gray-500">Critical Gaps</div><div className="text-xl font-semibold">{overview.critical_gap}</div></div>
          <div className="p-3 border rounded"><div className="text-xs text-gray-500">Avg Coverage</div><div className="text-xl font-semibold">{overview.avg_coverage}%</div></div>
          <div className="p-3 border rounded"><div className="text-xs text-gray-500">Equipment</div><div className="text-xl font-semibold">{overview.total_equipment}</div></div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">By Equipment Category</h2>
        <DataTable rows={categories} columns={catCols} emptyMessage="No categories" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable rows={leaders} columns={lbCols} emptyMessage="No engineers" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical & Major Gap Sites</h2>
        <DataTable rows={criticals} columns={critCols} emptyMessage="No critical sites" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Gaps By Type</h2>
        <DataTable rows={gapTypes} columns={gtCols} emptyMessage="No gaps" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">OEM Response</h2>
        <DataTable rows={oems} columns={oemCols} emptyMessage="No OEM rows" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Summary</h2>
        <DataTable rows={cities} columns={cityCols} emptyMessage="No cities" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stale Gaps (&gt; 14 days)</h2>
        <DataTable rows={staleGaps} columns={staleCols} emptyMessage="No stale gaps" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}