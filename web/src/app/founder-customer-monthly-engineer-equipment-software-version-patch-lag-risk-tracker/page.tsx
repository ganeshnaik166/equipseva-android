import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Rollup = { snapshot_month: string; snapshots: number; green_count: number; amber_count: number; red_count: number; black_count: number; avg_risk: number };
type Offender = { hospital_name: string; equipment_label: string; engineer_name: string; patch_lag_days: number; risk_score: number; risk_band: string; status: string };
type HospProfile = { hospital_name: string; devices: number; avg_lag_days: number; max_lag_days: number; critical_count: number; avg_risk: number };
type EngScore = { engineer_name: string; devices: number; overdue_count: number; breach_count: number; avg_risk: number; total_cves: number };
type CatLag = { equipment_category: string; devices: number; avg_lag: number; max_patches_behind: number; avg_risk: number };
type SlaBreach = { action_month: string; action_type: string; owner_name: string; sla_hours: number; hours_elapsed: number; action_status: string };
type ActionMix = { action_type: string; queued_count: number; in_progress_count: number; blocked_count: number; completed_count: number; cancelled_count: number };
type CveRow = { hospital_name: string; total_cves: number; critical_devices: number; black_band: number; red_band: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [r1, r2, r3, r4, r5, r6, r7, r8] = await Promise.all([
    supabase.rpc('rpc_r2972_monthly_risk_rollup'),
    supabase.rpc('rpc_r2972_top_lag_offenders'),
    supabase.rpc('rpc_r2972_per_hospital_profile'),
    supabase.rpc('rpc_r2972_per_engineer_scorecard'),
    supabase.rpc('rpc_r2972_category_lag'),
    supabase.rpc('rpc_r2972_action_sla_breach'),
    supabase.rpc('rpc_r2972_action_mix'),
    supabase.rpc('rpc_r2972_cve_exposure'),
  ]);

  const rollup = (r1.data ?? []) as Rollup[];
  const offenders = (r2.data ?? []) as Offender[];
  const hosp = (r3.data ?? []) as HospProfile[];
  const eng = (r4.data ?? []) as EngScore[];
  const cat = (r5.data ?? []) as CatLag[];
  const sla = (r6.data ?? []) as SlaBreach[];
  const mix = (r7.data ?? []) as ActionMix[];
  const cve = (r8.data ?? []) as CveRow[];

  const rollupCols: Column<Rollup>[] = [
    { header: 'Month', accessor: (r) => r.snapshot_month },
    { header: 'Snapshots', accessor: (r) => r.snapshots },
    { header: 'Green', accessor: (r) => r.green_count },
    { header: 'Amber', accessor: (r) => r.amber_count },
    { header: 'Red', accessor: (r) => r.red_count },
    { header: 'Black', accessor: (r) => r.black_count },
    { header: 'Avg Risk', accessor: (r) => r.avg_risk },
  ];

  const offCols: Column<Offender>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Equipment', accessor: (r) => r.equipment_label },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Lag (days)', accessor: (r) => r.patch_lag_days },
    { header: 'Risk', accessor: (r) => r.risk_score },
    { header: 'Band', accessor: (r) => r.risk_band },
    { header: 'Status', accessor: (r) => r.status },
  ];

  const hospCols: Column<HospProfile>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Devices', accessor: (r) => r.devices },
    { header: 'Avg Lag', accessor: (r) => r.avg_lag_days },
    { header: 'Max Lag', accessor: (r) => r.max_lag_days },
    { header: 'Critical', accessor: (r) => r.critical_count },
    { header: 'Avg Risk', accessor: (r) => r.avg_risk },
  ];

  const engCols: Column<EngScore>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Devices', accessor: (r) => r.devices },
    { header: 'Overdue', accessor: (r) => r.overdue_count },
    { header: 'Breach', accessor: (r) => r.breach_count },
    { header: 'Avg Risk', accessor: (r) => r.avg_risk },
    { header: 'CVEs', accessor: (r) => r.total_cves },
  ];

  const catCols: Column<CatLag>[] = [
    { header: 'Category', accessor: (r) => r.equipment_category },
    { header: 'Devices', accessor: (r) => r.devices },
    { header: 'Avg Lag', accessor: (r) => r.avg_lag },
    { header: 'Max Behind', accessor: (r) => r.max_patches_behind },
    { header: 'Avg Risk', accessor: (r) => r.avg_risk },
  ];

  const slaCols: Column<SlaBreach>[] = [
    { header: 'Month', accessor: (r) => r.action_month },
    { header: 'Action', accessor: (r) => r.action_type },
    { header: 'Owner', accessor: (r) => r.owner_name },
    { header: 'SLA hr', accessor: (r) => r.sla_hours },
    { header: 'Elapsed', accessor: (r) => r.hours_elapsed },
    { header: 'Status', accessor: (r) => r.action_status },
  ];

  const mixCols: Column<ActionMix>[] = [
    { header: 'Action', accessor: (r) => r.action_type },
    { header: 'Queued', accessor: (r) => r.queued_count },
    { header: 'In Progress', accessor: (r) => r.in_progress_count },
    { header: 'Blocked', accessor: (r) => r.blocked_count },
    { header: 'Completed', accessor: (r) => r.completed_count },
    { header: 'Cancelled', accessor: (r) => r.cancelled_count },
  ];

  const cveCols: Column<CveRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Total CVEs', accessor: (r) => r.total_cves },
    { header: 'Critical', accessor: (r) => r.critical_devices },
    { header: 'Black', accessor: (r) => r.black_band },
    { header: 'Red', accessor: (r) => r.red_band },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Engineer Equipment-Software Version Patch-Lag Risk Tracker</h1>
        <p className="text-sm text-gray-600">Round r2972 · founder console</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Risk Band Rollup</h2>
        <DataTable rows={rollup} columns={rollupCols} emptyMessage="No rollup data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Lag Offenders (current month)</h2>
        <DataTable rows={offenders} columns={offCols} emptyMessage="No offenders" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per-Hospital Risk Profile</h2>
        <DataTable rows={hosp} columns={hospCols} emptyMessage="No hospital data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per-Engineer Scorecard</h2>
        <DataTable rows={eng} columns={engCols} emptyMessage="No engineer data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Category-Level Lag</h2>
        <DataTable rows={cat} columns={catCols} emptyMessage="No category data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action SLA Breaches</h2>
        <DataTable rows={sla} columns={slaCols} emptyMessage="No SLA breaches" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action Mix by Status</h2>
        <DataTable rows={mix} columns={mixCols} emptyMessage="No action mix" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">CVE Exposure Rollup</h2>
        <DataTable rows={cve} columns={cveCols} emptyMessage="No CVE rows" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>
    </div>
  );
}
