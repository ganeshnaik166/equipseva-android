import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type HospitalSummary = { hospital_name: string; inspections: number; pass_count: number; fail_count: number; marginal_count: number; fail_rate_pct: number | null };
type ZoneHealth = { refrigerator_zone: string; total: number; avg_decay: number; avg_crack: number; severe_mold_count: number };
type EngineerScorecard = { engineer_name: string; visits: number; completed: number; no_shows: number; rescheduled: number; completion_rate_pct: number | null };
type ActionCost = { action_type: string; action_count: number; total_part_cost: number; total_labor_cost: number; total_downtime_hours: number };
type OpenPriority = { hospital_name: string; refrigerator_asset_tag: string; action_type: string; priority: string; scheduled_at: string | null };
type FailedInspection = { hospital_name: string; refrigerator_asset_tag: string; refrigerator_zone: string; inspected_at: string; vacuum_decay_pa_per_min: number; mold_growth_level: string; seal_age_months: number };
type WarrantySplit = { billing_path: string; action_count: number; total_cost: number };
type AgingBucket = { age_bucket: string; inspections: number; fail_count: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [hospitalRes, zoneRes, engineerRes, actionCostRes, queueRes, failedRes, warrantyRes, agingRes] = await Promise.all([
    supabase.rpc('gasket_r3012_hospital_summary'),
    supabase.rpc('gasket_r3012_zone_health'),
    supabase.rpc('gasket_r3012_engineer_scorecard'),
    supabase.rpc('gasket_r3012_action_cost_rollup'),
    supabase.rpc('gasket_r3012_open_priority_queue'),
    supabase.rpc('gasket_r3012_failed_inspections'),
    supabase.rpc('gasket_r3012_warranty_split'),
    supabase.rpc('gasket_r3012_seal_aging_buckets'),
  ]);

  const hospitals: HospitalSummary[] = (hospitalRes.data as HospitalSummary[]) ?? [];
  const zones: ZoneHealth[] = (zoneRes.data as ZoneHealth[]) ?? [];
  const engineers: EngineerScorecard[] = (engineerRes.data as EngineerScorecard[]) ?? [];
  const actionCosts: ActionCost[] = (actionCostRes.data as ActionCost[]) ?? [];
  const queue: OpenPriority[] = (queueRes.data as OpenPriority[]) ?? [];
  const failed: FailedInspection[] = (failedRes.data as FailedInspection[]) ?? [];
  const warranty: WarrantySplit[] = (warrantyRes.data as WarrantySplit[]) ?? [];
  const aging: AgingBucket[] = (agingRes.data as AgingBucket[]) ?? [];

  const hospitalCols: Column<HospitalSummary>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Inspections', accessor: (r) => r.inspections },
    { header: 'Pass', accessor: (r) => r.pass_count },
    { header: 'Fail', accessor: (r) => r.fail_count },
    { header: 'Marginal', accessor: (r) => r.marginal_count },
    { header: 'Fail rate %', accessor: (r) => r.fail_rate_pct ?? '-' },
  ];

  const zoneCols: Column<ZoneHealth>[] = [
    { header: 'Zone', accessor: (r) => r.refrigerator_zone },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Avg decay (Pa/min)', accessor: (r) => r.avg_decay },
    { header: 'Avg crack score', accessor: (r) => r.avg_crack },
    { header: 'Severe mold', accessor: (r) => r.severe_mold_count },
  ];

  const engineerCols: Column<EngineerScorecard>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Completed', accessor: (r) => r.completed },
    { header: 'No-shows', accessor: (r) => r.no_shows },
    { header: 'Rescheduled', accessor: (r) => r.rescheduled },
    { header: 'Completion %', accessor: (r) => r.completion_rate_pct ?? '-' },
  ];

  const actionCols: Column<ActionCost>[] = [
    { header: 'Action', accessor: (r) => r.action_type },
    { header: 'Count', accessor: (r) => r.action_count },
    { header: 'Parts cost (₹)', accessor: (r) => r.total_part_cost },
    { header: 'Labor cost (₹)', accessor: (r) => r.total_labor_cost },
    { header: 'Downtime (h)', accessor: (r) => r.total_downtime_hours },
  ];

  const queueCols: Column<OpenPriority>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Asset', accessor: (r) => r.refrigerator_asset_tag },
    { header: 'Action', accessor: (r) => r.action_type },
    { header: 'Priority', accessor: (r) => r.priority },
    { header: 'Scheduled', accessor: (r) => r.scheduled_at ? new Date(r.scheduled_at).toLocaleString('en-IN') : '-' },
  ];

  const failedCols: Column<FailedInspection>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Asset', accessor: (r) => r.refrigerator_asset_tag },
    { header: 'Zone', accessor: (r) => r.refrigerator_zone },
    { header: 'Inspected', accessor: (r) => new Date(r.inspected_at).toLocaleDateString('en-IN') },
    { header: 'Decay Pa/min', accessor: (r) => r.vacuum_decay_pa_per_min },
    { header: 'Mold', accessor: (r) => r.mold_growth_level },
    { header: 'Age (m)', accessor: (r) => r.seal_age_months },
  ];

  const warrantyCols: Column<WarrantySplit>[] = [
    { header: 'Billing path', accessor: (r) => r.billing_path },
    { header: 'Actions', accessor: (r) => r.action_count },
    { header: 'Total cost (₹)', accessor: (r) => r.total_cost },
  ];

  const agingCols: Column<AgingBucket>[] = [
    { header: 'Age bucket', accessor: (r) => r.age_bucket },
    { header: 'Inspections', accessor: (r) => r.inspections },
    { header: 'Fail count', accessor: (r) => r.fail_count },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Refrigerator Door Gasket Seal Integrity Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Monthly engineer inspections of hospital refrigerator door gasket seals — pass/fail, mold, decay & corrective actions.</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Hospital pass/fail summary</h2>
        <DataTable rows={hospitals} columns={hospitalCols} emptyMessage="No hospitals" rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Zone seal health</h2>
        <DataTable rows={zones} columns={zoneCols} emptyMessage="No zones" rowKey={(r, i) => String(r.refrigerator_zone ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Engineer scorecard</h2>
        <DataTable rows={engineers} columns={engineerCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Corrective action cost rollup</h2>
        <DataTable rows={actionCosts} columns={actionCols} emptyMessage="No actions" rowKey={(r, i) => String(r.action_type ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Open / in-progress priority queue</h2>
        <DataTable rows={queue} columns={queueCols} emptyMessage="Queue empty" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Failed inspections detail</h2>
        <DataTable rows={failed} columns={failedCols} emptyMessage="No failures" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Warranty vs customer-billed split</h2>
        <DataTable rows={warranty} columns={warrantyCols} emptyMessage="No data" rowKey={(r, i) => String(r.billing_path ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Seal aging buckets</h2>
        <DataTable rows={aging} columns={agingCols} emptyMessage="No data" rowKey={(r, i) => String(r.age_bucket ?? i)} />
      </section>
    </main>
  );
}
