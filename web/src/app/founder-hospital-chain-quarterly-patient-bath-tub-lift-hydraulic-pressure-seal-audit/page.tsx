import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/data-table';

export const dynamic = 'force-dynamic';

type ChainRollup = {
  chain_code: string;
  audits_total: number;
  passes: number;
  watches: number;
  remediates: number;
  condemns: number;
  avg_pressure_drop_pct: number;
  remediation_cost_total_rupees: number;
};

type Condemn = {
  hospital_site: string;
  chain_code: string;
  lift_asset_tag: string;
  ward_zone: string;
  audit_date: string;
  pressure_drop_pct: number;
  cylinder_creep_mm: number;
  remediation_cost_rupees: number;
};

type WardRisk = {
  ward_zone: string;
  audits: number;
  avg_pressure_drop_pct: number;
  avg_creep_mm: number;
  high_risk_count: number;
};

type WoBoard = {
  status: string;
  workorders: number;
  total_parts_cost_rupees: number;
  total_labour_cost_rupees: number;
  total_downtime_hours: number;
};

type FluidPerf = {
  fluid_grade: string;
  audits: number;
  avg_pressure_drop_pct: number;
  avg_ph: number;
  pass_rate_pct: number;
};

type QuarterTrend = {
  quarter_label: string;
  audits: number;
  condemns: number;
  remediates: number;
  avg_pressure_drop_pct: number;
  total_remediation_cost_rupees: number;
};

type Escalation = {
  workorder_ref: string;
  chain_code: string;
  audit_asset_tag: string;
  remediation_type: string;
  status: string;
  raised_on: string;
  parts_cost_rupees: number;
  downtime_hours: number;
};

type ClosureEff = {
  technician_grade: string;
  closed_workorders: number;
  avg_days_to_close: number;
  avg_downtime_hours: number;
  total_labour_cost_rupees: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [rollup, condemns, ward, wo, fluid, qtr, esc, closure] = await Promise.all([
    supabase.rpc('r3039_chain_rollup'),
    supabase.rpc('r3039_condemnation_list'),
    supabase.rpc('r3039_ward_zone_risk'),
    supabase.rpc('r3039_workorder_status_board'),
    supabase.rpc('r3039_fluid_grade_performance'),
    supabase.rpc('r3039_quarter_trend'),
    supabase.rpc('r3039_open_escalations'),
    supabase.rpc('r3039_closure_efficiency'),
  ]);

  const rollupRows = (rollup.data ?? []) as ChainRollup[];
  const condemnRows = (condemns.data ?? []) as Condemn[];
  const wardRows = (ward.data ?? []) as WardRisk[];
  const woRows = (wo.data ?? []) as WoBoard[];
  const fluidRows = (fluid.data ?? []) as FluidPerf[];
  const qtrRows = (qtr.data ?? []) as QuarterTrend[];
  const escRows = (esc.data ?? []) as Escalation[];
  const closureRows = (closure.data ?? []) as ClosureEff[];

  const rollupCols: Column<ChainRollup>[] = [
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Audits', accessor: (r) => r.audits_total },
    { header: 'Pass', accessor: (r) => r.passes },
    { header: 'Watch', accessor: (r) => r.watches },
    { header: 'Remediate', accessor: (r) => r.remediates },
    { header: 'Condemn', accessor: (r) => r.condemns },
    { header: 'Avg drop %', accessor: (r) => r.avg_pressure_drop_pct },
    { header: 'Remediation cost', accessor: (r) => `Rs ${r.remediation_cost_total_rupees.toLocaleString('en-IN')}` },
  ];

  const condemnCols: Column<Condemn>[] = [
    { header: 'Site', accessor: (r) => r.hospital_site },
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Asset', accessor: (r) => r.lift_asset_tag },
    { header: 'Ward', accessor: (r) => r.ward_zone },
    { header: 'Date', accessor: (r) => r.audit_date },
    { header: 'Drop %', accessor: (r) => r.pressure_drop_pct },
    { header: 'Creep mm', accessor: (r) => r.cylinder_creep_mm },
    { header: 'Cost', accessor: (r) => `Rs ${r.remediation_cost_rupees.toLocaleString('en-IN')}` },
  ];

  const wardCols: Column<WardRisk>[] = [
    { header: 'Ward zone', accessor: (r) => r.ward_zone },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg drop %', accessor: (r) => r.avg_pressure_drop_pct },
    { header: 'Avg creep mm', accessor: (r) => r.avg_creep_mm },
    { header: 'High-risk count', accessor: (r) => r.high_risk_count },
  ];

  const woCols: Column<WoBoard>[] = [
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Workorders', accessor: (r) => r.workorders },
    { header: 'Parts cost', accessor: (r) => `Rs ${r.total_parts_cost_rupees.toLocaleString('en-IN')}` },
    { header: 'Labour cost', accessor: (r) => `Rs ${r.total_labour_cost_rupees.toLocaleString('en-IN')}` },
    { header: 'Downtime hrs', accessor: (r) => r.total_downtime_hours },
  ];

  const fluidCols: Column<FluidPerf>[] = [
    { header: 'Fluid grade', accessor: (r) => r.fluid_grade },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Avg drop %', accessor: (r) => r.avg_pressure_drop_pct },
    { header: 'Avg pH', accessor: (r) => r.avg_ph },
    { header: 'Pass rate %', accessor: (r) => r.pass_rate_pct },
  ];

  const qtrCols: Column<QuarterTrend>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Condemns', accessor: (r) => r.condemns },
    { header: 'Remediates', accessor: (r) => r.remediates },
    { header: 'Avg drop %', accessor: (r) => r.avg_pressure_drop_pct },
    { header: 'Total cost', accessor: (r) => `Rs ${r.total_remediation_cost_rupees.toLocaleString('en-IN')}` },
  ];

  const escCols: Column<Escalation>[] = [
    { header: 'WO ref', accessor: (r) => r.workorder_ref },
    { header: 'Chain', accessor: (r) => r.chain_code },
    { header: 'Asset', accessor: (r) => r.audit_asset_tag },
    { header: 'Type', accessor: (r) => r.remediation_type },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Raised', accessor: (r) => r.raised_on },
    { header: 'Parts cost', accessor: (r) => `Rs ${r.parts_cost_rupees.toLocaleString('en-IN')}` },
    { header: 'Downtime hrs', accessor: (r) => r.downtime_hours },
  ];

  const closureCols: Column<ClosureEff>[] = [
    { header: 'Technician grade', accessor: (r) => r.technician_grade },
    { header: 'Closed WOs', accessor: (r) => r.closed_workorders },
    { header: 'Avg days to close', accessor: (r) => r.avg_days_to_close },
    { header: 'Avg downtime hrs', accessor: (r) => r.avg_downtime_hours },
    { header: 'Total labour cost', accessor: (r) => `Rs ${r.total_labour_cost_rupees.toLocaleString('en-IN')}` },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>
          Hospital Chain Quarterly Patient-Bath Tub Lift Hydraulic Pressure & Seal Audit
        </h1>
        <p style={{ opacity: 0.75, marginTop: 6 }}>
          Round r3039 — fleet-wide hydraulic integrity, ward-zone risk, and remediation throughput across hospital chains.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Chain rollup</h2>
        <DataTable
          rows={rollupRows}
          columns={rollupCols}
          emptyMessage="No chain rollup data."
          rowKey={(r, i) => String((r as ChainRollup).chain_code ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Condemnation list (lifts out of service)</h2>
        <DataTable
          rows={condemnRows}
          columns={condemnCols}
          emptyMessage="No condemned lifts."
          rowKey={(r, i) => String((r as Condemn).lift_asset_tag ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Ward-zone risk</h2>
        <DataTable
          rows={wardRows}
          columns={wardCols}
          emptyMessage="No ward zone data."
          rowKey={(r, i) => String((r as WardRisk).ward_zone ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Workorder status board</h2>
        <DataTable
          rows={woRows}
          columns={woCols}
          emptyMessage="No workorders."
          rowKey={(r, i) => String((r as WoBoard).status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Fluid grade performance</h2>
        <DataTable
          rows={fluidRows}
          columns={fluidCols}
          emptyMessage="No fluid data."
          rowKey={(r, i) => String((r as FluidPerf).fluid_grade ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Quarter trend</h2>
        <DataTable
          rows={qtrRows}
          columns={qtrCols}
          emptyMessage="No quarter trend data."
          rowKey={(r, i) => String((r as QuarterTrend).quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Open escalations</h2>
        <DataTable
          rows={escRows}
          columns={escCols}
          emptyMessage="No open escalations."
          rowKey={(r, i) => String((r as Escalation).workorder_ref ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Closure efficiency by technician grade</h2>
        <DataTable
          rows={closureRows}
          columns={closureCols}
          emptyMessage="No closure data."
          rowKey={(r, i) => String((r as ClosureEff).technician_grade ?? i)}
        />
      </section>
    </main>
  );
}
