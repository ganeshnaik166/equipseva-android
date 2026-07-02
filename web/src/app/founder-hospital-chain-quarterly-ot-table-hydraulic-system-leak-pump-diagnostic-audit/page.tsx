import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type ChainRollup = { chain_name: string; audits_count: number; fail_or_shutdown_count: number; avg_leak_rate: number; total_repair_cost: number };
type GradeDist = { grade: string; audits_count: number; pct_of_total: number };
type CriticalFinding = { chain_name: string; hospital_site: string; ot_room_code: string; table_model: string; finding_category: string; severity: string; component_affected: string; deviation_pct: number; parts_cost_rupees: number; finding_status: string };
type Manufacturer = { manufacturer: string; tables_audited: number; avg_leak_rate: number; fail_count: number; avg_repair_cost: number };
type Fluid = { chain_name: string; hospital_site: string; ot_room_code: string; fluid_color_grade: string; particle_iso: string; fluid_level_pct: number; reservoir_temp_celsius: number };
type Remediation = { remediation_status: string; items_count: number; total_cost: number };
type Downtime = { chain_name: string; hospital_site: string; ot_room_code: string; table_asset_tag: string; ot_downtime_risk: string; overall_audit_grade: string; next_audit_due: string; estimated_repair_cost_rupees: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [rollup, grades, critical, mfr, fluid, remed, downtime] = await Promise.all([
    supabase.rpc('rpc_r2999_chain_rollup'),
    supabase.rpc('rpc_r2999_grade_distribution'),
    supabase.rpc('rpc_r2999_critical_findings'),
    supabase.rpc('rpc_r2999_manufacturer_reliability'),
    supabase.rpc('rpc_r2999_fluid_contamination_watch'),
    supabase.rpc('rpc_r2999_remediation_pipeline'),
    supabase.rpc('rpc_r2999_downtime_risk_register'),
  ]);

  const rollupRows: ChainRollup[] = (rollup.data ?? []) as ChainRollup[];
  const gradeRows: GradeDist[] = (grades.data ?? []) as GradeDist[];
  const criticalRows: CriticalFinding[] = (critical.data ?? []) as CriticalFinding[];
  const mfrRows: Manufacturer[] = (mfr.data ?? []) as Manufacturer[];
  const fluidRows: Fluid[] = (fluid.data ?? []) as Fluid[];
  const remedRows: Remediation[] = (remed.data ?? []) as Remediation[];
  const downtimeRows: Downtime[] = (downtime.data ?? []) as Downtime[];

  const rollupCols: Column<ChainRollup>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Audits', accessor: (r) => r.audits_count },
    { header: 'Fail/Shutdown', accessor: (r) => r.fail_or_shutdown_count },
    { header: 'Avg Leak (ml/min)', accessor: (r) => r.avg_leak_rate },
    { header: 'Repair Cost (Rs)', accessor: (r) => Number(r.total_repair_cost).toLocaleString('en-IN') },
  ];
  const gradeCols: Column<GradeDist>[] = [
    { header: 'Grade', accessor: (r) => r.grade },
    { header: 'Audits', accessor: (r) => r.audits_count },
    { header: 'Pct of Total', accessor: (r) => `${r.pct_of_total}%` },
  ];
  const criticalCols: Column<CriticalFinding>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'OT', accessor: (r) => r.ot_room_code },
    { header: 'Model', accessor: (r) => r.table_model },
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Component', accessor: (r) => r.component_affected },
    { header: 'Deviation %', accessor: (r) => r.deviation_pct },
    { header: 'Parts Cost (Rs)', accessor: (r) => Number(r.parts_cost_rupees).toLocaleString('en-IN') },
    { header: 'Status', accessor: (r) => r.finding_status },
  ];
  const mfrCols: Column<Manufacturer>[] = [
    { header: 'Manufacturer', accessor: (r) => r.manufacturer },
    { header: 'Tables', accessor: (r) => r.tables_audited },
    { header: 'Avg Leak', accessor: (r) => r.avg_leak_rate },
    { header: 'Fail Count', accessor: (r) => r.fail_count },
    { header: 'Avg Repair (Rs)', accessor: (r) => Number(r.avg_repair_cost).toLocaleString('en-IN') },
  ];
  const fluidCols: Column<Fluid>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'OT', accessor: (r) => r.ot_room_code },
    { header: 'Color', accessor: (r) => r.fluid_color_grade },
    { header: 'Particle ISO', accessor: (r) => r.particle_iso },
    { header: 'Level %', accessor: (r) => r.fluid_level_pct },
    { header: 'Reservoir Temp (C)', accessor: (r) => r.reservoir_temp_celsius },
  ];
  const remedCols: Column<Remediation>[] = [
    { header: 'Status', accessor: (r) => r.remediation_status },
    { header: 'Items', accessor: (r) => r.items_count },
    { header: 'Total Cost (Rs)', accessor: (r) => Number(r.total_cost).toLocaleString('en-IN') },
  ];
  const downtimeCols: Column<Downtime>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'OT', accessor: (r) => r.ot_room_code },
    { header: 'Asset Tag', accessor: (r) => r.table_asset_tag },
    { header: 'Risk', accessor: (r) => r.ot_downtime_risk },
    { header: 'Grade', accessor: (r) => r.overall_audit_grade },
    { header: 'Next Audit', accessor: (r) => r.next_audit_due },
    { header: 'Repair (Rs)', accessor: (r) => Number(r.estimated_repair_cost_rupees).toLocaleString('en-IN') },
  ];

  return (
    <div style={{ padding: '1.5rem', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.25rem' }}>
        Hospital Chain Quarterly OT-Table Hydraulic-System Leak & Pump Diagnostic Audit
      </h1>
      <p style={{ color: '#666', marginBottom: '1.5rem', fontSize: '0.9rem' }}>
        Round r2999 — chain-wide quarterly review of operating-room table hydraulic integrity, pump pressure, fluid contamination, leak rate & remediation pipeline.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Chain Rollup</h2>
        <DataTable rows={rollupRows} columns={rollupCols} emptyMessage="No chain rollup yet" rowKey={(r, i) => String((r as { chain_name?: string }).chain_name ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Grade Distribution</h2>
        <DataTable rows={gradeRows} columns={gradeCols} emptyMessage="No grade data" rowKey={(r, i) => String((r as { grade?: string }).grade ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Critical & High Severity Findings</h2>
        <DataTable rows={criticalRows} columns={criticalCols} emptyMessage="No critical findings" rowKey={(_r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Manufacturer Reliability</h2>
        <DataTable rows={mfrRows} columns={mfrCols} emptyMessage="No manufacturer rollup" rowKey={(r, i) => String((r as { manufacturer?: string }).manufacturer ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Fluid Contamination Watch</h2>
        <DataTable rows={fluidRows} columns={fluidCols} emptyMessage="All fluids clean" rowKey={(_r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Remediation Pipeline</h2>
        <DataTable rows={remedRows} columns={remedCols} emptyMessage="No remediation items" rowKey={(r, i) => String((r as { remediation_status?: string }).remediation_status ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Downtime Risk Register</h2>
        <DataTable rows={downtimeRows} columns={downtimeCols} emptyMessage="No downtime risk" rowKey={(r, i) => String((r as { table_asset_tag?: string }).table_asset_tag ?? i)} />
      </section>
    </div>
  );
}
