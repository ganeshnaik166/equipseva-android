import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CycleStatusRow = { cycle_status: string; n: number; avg_minutes: number; avg_peak_heat_kHU: number };
type PassFailRow = { pass_fail: string; n: number; sites_affected: number };
type SitePerfRow = { customer_site: string; cycles: number; completed: number; failed: number; avg_arcs: number };
type EngineerRow = { engineer_name: string; cycles: number; pass_rate_pct: number; avg_cooling_min: number };
type ThermalRow = { thermal_alert_level: string; n: number; avg_anode_temp: number; avg_housing_temp: number };
type ModelRow = { scanner_model: string; cycles: number; avg_peak_heat: number; fail_count: number };
type CoolingRow = { cooling_curve_ok: boolean; n: number; avg_oil_temp: number; critical_count: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [statusRes, pfRes, siteRes, engRes, thermalRes, modelRes, coolRes] = await Promise.all([
    supabase.rpc('r3078_cycle_status_summary'),
    supabase.rpc('r3078_pass_fail_breakdown'),
    supabase.rpc('r3078_site_performance'),
    supabase.rpc('r3078_engineer_workload'),
    supabase.rpc('r3078_thermal_alerts'),
    supabase.rpc('r3078_scanner_model_health'),
    supabase.rpc('r3078_cooling_curve_health'),
  ]);

  const statusRows: CycleStatusRow[] = (statusRes.data ?? []) as CycleStatusRow[];
  const pfRows: PassFailRow[] = (pfRes.data ?? []) as PassFailRow[];
  const siteRows: SitePerfRow[] = (siteRes.data ?? []) as SitePerfRow[];
  const engRows: EngineerRow[] = (engRes.data ?? []) as EngineerRow[];
  const thermalRows: ThermalRow[] = (thermalRes.data ?? []) as ThermalRow[];
  const modelRows: ModelRow[] = (modelRes.data ?? []) as ModelRow[];
  const coolRows: CoolingRow[] = (coolRes.data ?? []) as CoolingRow[];

  const statusCols: Column<CycleStatusRow>[] = [
    { header: 'Status', cell: (r) => r.cycle_status },
    { header: 'N', cell: (r) => r.n },
    { header: 'Avg Min', cell: (r) => r.avg_minutes },
    { header: 'Avg Peak kHU', cell: (r) => r.avg_peak_heat_kHU },
  ];

  const pfCols: Column<PassFailRow>[] = [
    { header: 'Pass/Fail', cell: (r) => r.pass_fail },
    { header: 'N', cell: (r) => r.n },
    { header: 'Sites', cell: (r) => r.sites_affected },
  ];

  const siteCols: Column<SitePerfRow>[] = [
    { header: 'Site', cell: (r) => r.customer_site },
    { header: 'Cycles', cell: (r) => r.cycles },
    { header: 'Completed', cell: (r) => r.completed },
    { header: 'Failed', cell: (r) => r.failed },
    { header: 'Avg Arcs', cell: (r) => r.avg_arcs },
  ];

  const engCols: Column<EngineerRow>[] = [
    { header: 'Engineer', cell: (r) => r.engineer_name },
    { header: 'Cycles', cell: (r) => r.cycles },
    { header: 'Pass %', cell: (r) => r.pass_rate_pct },
    { header: 'Avg Cool Min', cell: (r) => r.avg_cooling_min },
  ];

  const thermalCols: Column<ThermalRow>[] = [
    { header: 'Alert Level', cell: (r) => r.thermal_alert_level },
    { header: 'N', cell: (r) => r.n },
    { header: 'Avg Anode °C', cell: (r) => r.avg_anode_temp },
    { header: 'Avg Housing °C', cell: (r) => r.avg_housing_temp },
  ];

  const modelCols: Column<ModelRow>[] = [
    { header: 'Scanner Model', cell: (r) => r.scanner_model },
    { header: 'Cycles', cell: (r) => r.cycles },
    { header: 'Avg Peak Heat', cell: (r) => r.avg_peak_heat },
    { header: 'Fails', cell: (r) => r.fail_count },
  ];

  const coolCols: Column<CoolingRow>[] = [
    { header: 'Cooling OK', cell: (r) => (r.cooling_curve_ok ? 'yes' : 'no') },
    { header: 'N', cell: (r) => r.n },
    { header: 'Avg Oil °C', cell: (r) => r.avg_oil_temp },
    { header: 'Critical', cell: (r) => r.critical_count },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1>CT Scanner X-Ray Tube Burn-In Cycle & Heat Audit</h1>
        <p>Monthly engineer site visits — tube burn-in, peak anode heat, cooling curves & thermal alerts.</p>
      </header>

      <section>
        <h2>Cycle Status Summary</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No status data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2>Pass / Fail Breakdown</h2>
        <DataTable
          rows={pfRows}
          columns={pfCols}
          emptyMessage="No pass/fail data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2>Site Performance</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2>Engineer Workload & Pass Rate</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2>Thermal Alerts</h2>
        <DataTable
          rows={thermalRows}
          columns={thermalCols}
          emptyMessage="No thermal alerts"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2>Scanner Model Health</h2>
        <DataTable
          rows={modelRows}
          columns={modelCols}
          emptyMessage="No model data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2>Cooling Curve Health</h2>
        <DataTable
          rows={coolRows}
          columns={coolCols}
          emptyMessage="No cooling data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </main>
  );
}
