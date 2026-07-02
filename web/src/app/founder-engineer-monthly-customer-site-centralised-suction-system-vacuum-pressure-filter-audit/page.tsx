import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { total_audits: number; completed_audits: number; failed_audits: number; remediation_audits: number; scheduled_audits: number; avg_pressure: number; avg_noise: number };
type FailedSite = { site_code: string; hospital_name: string; city: string; vacuum_pressure_kpa: number; target_pressure_kpa: number; noise_db: number; filter_status: string; next_audit_due: string | null };
type FilterBreakdown = { filter_status: string; site_count: number; avg_pressure: number };
type EngineerWork = { engineer_name: string; audit_count: number; fail_count: number; avg_pressure: number };
type FilterCost = { filter_type: string; replacement_count: number; total_cost_rupees: number; avg_hours_used: number };
type BelowTarget = { site_code: string; hospital_name: string; vacuum_pressure_kpa: number; target_pressure_kpa: number; deficit: number; status: string };
type Upcoming = { site_code: string; hospital_name: string; next_audit_due: string; status: string; filter_status: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ov, fs, fb, ew, fc, bt, up] = await Promise.all([
    supabase.rpc('rpc_r3014_audit_overview'),
    supabase.rpc('rpc_r3014_failed_sites'),
    supabase.rpc('rpc_r3014_filter_status_breakdown'),
    supabase.rpc('rpc_r3014_engineer_workload'),
    supabase.rpc('rpc_r3014_filter_replacement_cost'),
    supabase.rpc('rpc_r3014_pressure_below_target'),
    supabase.rpc('rpc_r3014_upcoming_audits'),
  ]);

  const overview: Overview | null = (ov.data?.[0] as Overview) ?? null;
  const failed: FailedSite[] = (fs.data as FailedSite[]) ?? [];
  const breakdown: FilterBreakdown[] = (fb.data as FilterBreakdown[]) ?? [];
  const engineers: EngineerWork[] = (ew.data as EngineerWork[]) ?? [];
  const costs: FilterCost[] = (fc.data as FilterCost[]) ?? [];
  const below: BelowTarget[] = (bt.data as BelowTarget[]) ?? [];
  const upcoming: Upcoming[] = (up.data as Upcoming[]) ?? [];

  const failedCols: Column<FailedSite>[] = [
    { header: 'Site', accessor: (r) => r.site_code },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Vacuum kPa', accessor: (r) => r.vacuum_pressure_kpa },
    { header: 'Target kPa', accessor: (r) => r.target_pressure_kpa },
    { header: 'Noise dB', accessor: (r) => r.noise_db },
    { header: 'Filter', accessor: (r) => r.filter_status },
    { header: 'Next Audit', accessor: (r) => r.next_audit_due ?? '-' },
  ];

  const breakdownCols: Column<FilterBreakdown>[] = [
    { header: 'Filter Status', accessor: (r) => r.filter_status },
    { header: 'Sites', accessor: (r) => r.site_count },
    { header: 'Avg Pressure', accessor: (r) => r.avg_pressure },
  ];

  const engineerCols: Column<EngineerWork>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audit_count },
    { header: 'Fails', accessor: (r) => r.fail_count },
    { header: 'Avg Pressure', accessor: (r) => r.avg_pressure },
  ];

  const costCols: Column<FilterCost>[] = [
    { header: 'Filter Type', accessor: (r) => r.filter_type },
    { header: 'Replacements', accessor: (r) => r.replacement_count },
    { header: 'Total Cost (Rs)', accessor: (r) => r.total_cost_rupees },
    { header: 'Avg Hours Used', accessor: (r) => r.avg_hours_used },
  ];

  const belowCols: Column<BelowTarget>[] = [
    { header: 'Site', accessor: (r) => r.site_code },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Vacuum kPa', accessor: (r) => r.vacuum_pressure_kpa },
    { header: 'Target kPa', accessor: (r) => r.target_pressure_kpa },
    { header: 'Deficit', accessor: (r) => r.deficit },
    { header: 'Status', accessor: (r) => r.status },
  ];

  const upcomingCols: Column<Upcoming>[] = [
    { header: 'Site', accessor: (r) => r.site_code },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Next Audit', accessor: (r) => r.next_audit_due },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Filter', accessor: (r) => r.filter_status },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Suction System Audit (r3014)</h1>
        <p className="text-sm text-gray-600">Centralised suction system vacuum pressure & filter audit across customer sites.</p>
      </header>

      {overview && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="p-4 bg-white rounded shadow">
            <div className="text-xs text-gray-500">Total Audits</div>
            <div className="text-2xl font-semibold">{overview.total_audits}</div>
          </div>
          <div className="p-4 bg-white rounded shadow">
            <div className="text-xs text-gray-500">Completed</div>
            <div className="text-2xl font-semibold text-green-700">{overview.completed_audits}</div>
          </div>
          <div className="p-4 bg-white rounded shadow">
            <div className="text-xs text-gray-500">Failed</div>
            <div className="text-2xl font-semibold text-red-700">{overview.failed_audits}</div>
          </div>
          <div className="p-4 bg-white rounded shadow">
            <div className="text-xs text-gray-500">Remediation</div>
            <div className="text-2xl font-semibold text-amber-700">{overview.remediation_audits}</div>
          </div>
          <div className="p-4 bg-white rounded shadow">
            <div className="text-xs text-gray-500">Scheduled</div>
            <div className="text-2xl font-semibold">{overview.scheduled_audits}</div>
          </div>
          <div className="p-4 bg-white rounded shadow">
            <div className="text-xs text-gray-500">Avg Vacuum (kPa)</div>
            <div className="text-2xl font-semibold">{overview.avg_pressure}</div>
          </div>
          <div className="p-4 bg-white rounded shadow">
            <div className="text-xs text-gray-500">Avg Noise (dB)</div>
            <div className="text-2xl font-semibold">{overview.avg_noise}</div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Failed & Remediation Sites</h2>
        <DataTable
          rows={failed}
          columns={failedCols}
          emptyMessage="No failing sites"
          rowKey={(r, i) => String((r as { site_code?: string }).site_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Filter Status Breakdown</h2>
        <DataTable
          rows={breakdown}
          columns={breakdownCols}
          emptyMessage="No filter data"
          rowKey={(r, i) => String((r as { filter_status?: string }).filter_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Workload</h2>
        <DataTable
          rows={engineers}
          columns={engineerCols}
          emptyMessage="No engineers"
          rowKey={(r, i) => String((r as { engineer_name?: string }).engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Filter Replacement Cost</h2>
        <DataTable
          rows={costs}
          columns={costCols}
          emptyMessage="No cost data"
          rowKey={(r, i) => String((r as { filter_type?: string }).filter_type ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pressure Below Target</h2>
        <DataTable
          rows={below}
          columns={belowCols}
          emptyMessage="All sites at target"
          rowKey={(r, i) => String((r as { site_code?: string }).site_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming Audits</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          emptyMessage="No upcoming"
          rowKey={(r, i) => String((r as { site_code?: string }).site_code ?? i)}
        />
      </section>
    </div>
  );
}
