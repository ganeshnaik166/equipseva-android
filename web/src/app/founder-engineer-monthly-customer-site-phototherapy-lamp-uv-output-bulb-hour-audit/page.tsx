import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type FleetRow = { total_lamps: number; passed: number; marginal: number; failed: number; pass_rate_pct: number | null; avg_irradiance: number | null; bulbs_replaced: number; lamps_swapped: number };
type FailRow = { hospital_name: string; ward: string; lamp_serial: string; measured_irradiance_uw_cm2: number; bulb_hours_used: number; action_taken: string; audit_notes: string | null };
type HospRow = { hospital_name: string; city: string; lamps_audited: number; failures: number; avg_irradiance: number | null; oldest_bulb_hours: number };
type EngRow = { engineer_name: string; lamps_audited: number; failures_found: number; bulbs_replaced: number; avg_irradiance: number | null };
type EolRow = { hospital_name: string; ward: string; lamp_serial: string; bulb_hours_used: number; bulb_hours_rated: number; pct_consumed: number | null; replacement_due_within_days: number | null };
type ModelRow = { lamp_model: string; units: number; failures: number; fail_pct: number | null; avg_irradiance: number | null };
type CostRow = { event_type: string; events: number; total_parts_rupees: number; total_labor_rupees: number; total_rupees: number };
type LedgerRow = { event_date: string; event_type: string; performed_by: string; cumulative_hours: number; part_cost_rupees: number; labor_cost_rupees: number; notes: string | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [fleet, fails, hosp, eng, eol, model, cost, ledger] = await Promise.all([
    supabase.rpc('rpc_r3022_fleet_summary'),
    supabase.rpc('rpc_r3022_failures'),
    supabase.rpc('rpc_r3022_hospital_rollup'),
    supabase.rpc('rpc_r3022_engineer_scorecard'),
    supabase.rpc('rpc_r3022_bulbs_nearing_eol'),
    supabase.rpc('rpc_r3022_lamp_model_perf'),
    supabase.rpc('rpc_r3022_cost_summary'),
    supabase.rpc('rpc_r3022_recent_ledger'),
  ]);

  const fleetRows: FleetRow[] = (fleet.data as FleetRow[]) ?? [];
  const failRows: FailRow[] = (fails.data as FailRow[]) ?? [];
  const hospRows: HospRow[] = (hosp.data as HospRow[]) ?? [];
  const engRows: EngRow[] = (eng.data as EngRow[]) ?? [];
  const eolRows: EolRow[] = (eol.data as EolRow[]) ?? [];
  const modelRows: ModelRow[] = (model.data as ModelRow[]) ?? [];
  const costRows: CostRow[] = (cost.data as CostRow[]) ?? [];
  const ledgerRows: LedgerRow[] = (ledger.data as LedgerRow[]) ?? [];

  const fleetCols: Column<FleetRow>[] = [
    { header: 'Total lamps', accessor: (r) => r.total_lamps },
    { header: 'Passed', accessor: (r) => r.passed },
    { header: 'Marginal', accessor: (r) => r.marginal },
    { header: 'Failed', accessor: (r) => r.failed },
    { header: 'Pass rate %', accessor: (r) => r.pass_rate_pct ?? '-' },
    { header: 'Avg irradiance (uW/cm2)', accessor: (r) => r.avg_irradiance ?? '-' },
    { header: 'Bulbs replaced', accessor: (r) => r.bulbs_replaced },
    { header: 'Lamps swapped', accessor: (r) => r.lamps_swapped },
  ];
  const failCols: Column<FailRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Ward', accessor: (r) => r.ward },
    { header: 'Lamp serial', accessor: (r) => r.lamp_serial },
    { header: 'Irradiance', accessor: (r) => r.measured_irradiance_uw_cm2 },
    { header: 'Bulb hours', accessor: (r) => r.bulb_hours_used },
    { header: 'Action', accessor: (r) => r.action_taken },
    { header: 'Notes', accessor: (r) => r.audit_notes ?? '-' },
  ];
  const hospCols: Column<HospRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Lamps audited', accessor: (r) => r.lamps_audited },
    { header: 'Failures', accessor: (r) => r.failures },
    { header: 'Avg irradiance', accessor: (r) => r.avg_irradiance ?? '-' },
    { header: 'Oldest bulb hours', accessor: (r) => r.oldest_bulb_hours },
  ];
  const engCols: Column<EngRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Lamps audited', accessor: (r) => r.lamps_audited },
    { header: 'Failures found', accessor: (r) => r.failures_found },
    { header: 'Bulbs replaced', accessor: (r) => r.bulbs_replaced },
    { header: 'Avg irradiance', accessor: (r) => r.avg_irradiance ?? '-' },
  ];
  const eolCols: Column<EolRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Ward', accessor: (r) => r.ward },
    { header: 'Lamp serial', accessor: (r) => r.lamp_serial },
    { header: 'Bulb hours used', accessor: (r) => r.bulb_hours_used },
    { header: 'Rated hours', accessor: (r) => r.bulb_hours_rated },
    { header: '% consumed', accessor: (r) => r.pct_consumed ?? '-' },
    { header: 'Replace within (days)', accessor: (r) => r.replacement_due_within_days ?? '-' },
  ];
  const modelCols: Column<ModelRow>[] = [
    { header: 'Lamp model', accessor: (r) => r.lamp_model },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Failures', accessor: (r) => r.failures },
    { header: 'Fail %', accessor: (r) => r.fail_pct ?? '-' },
    { header: 'Avg irradiance', accessor: (r) => r.avg_irradiance ?? '-' },
  ];
  const costCols: Column<CostRow>[] = [
    { header: 'Event type', accessor: (r) => r.event_type },
    { header: 'Events', accessor: (r) => r.events },
    { header: 'Parts (Rs)', accessor: (r) => r.total_parts_rupees },
    { header: 'Labor (Rs)', accessor: (r) => r.total_labor_rupees },
    { header: 'Total (Rs)', accessor: (r) => r.total_rupees },
  ];
  const ledgerCols: Column<LedgerRow>[] = [
    { header: 'Date', accessor: (r) => r.event_date },
    { header: 'Event', accessor: (r) => r.event_type },
    { header: 'By', accessor: (r) => r.performed_by },
    { header: 'Cum. hours', accessor: (r) => r.cumulative_hours },
    { header: 'Parts (Rs)', accessor: (r) => r.part_cost_rupees },
    { header: 'Labor (Rs)', accessor: (r) => r.labor_cost_rupees },
    { header: 'Notes', accessor: (r) => r.notes ?? '-' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700 }}>r3022 — Phototherapy Lamp UV Output &amp; Bulb Hour Audit</h1>
      <p style={{ color: '#666', marginBottom: '1.5rem' }}>
        Monthly NICU phototherapy lamp irradiance readings + bulb-hour ledger. Threshold pass &gt;= 30 uW/cm2.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Fleet summary</h2>
        <DataTable rows={fleetRows} columns={fleetCols} emptyMessage="No fleet data" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Failures this month</h2>
        <DataTable rows={failRows} columns={failCols} emptyMessage="No failures" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Hospital rollup</h2>
        <DataTable rows={hospRows} columns={hospCols} emptyMessage="No hospital data" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Engineer scorecard</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineer data" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Bulbs nearing end-of-life (&gt;= 75% consumed)</h2>
        <DataTable rows={eolRows} columns={eolCols} emptyMessage="No EOL bulbs" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Lamp model performance</h2>
        <DataTable rows={modelRows} columns={modelCols} emptyMessage="No model data" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Cost summary (parts + labor)</h2>
        <DataTable rows={costRows} columns={costCols} emptyMessage="No cost data" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Recent ledger feed</h2>
        <DataTable rows={ledgerRows} columns={ledgerCols} emptyMessage="No ledger entries" rowKey={(r, i) => String(i)} />
      </section>
    </main>
  );
}
