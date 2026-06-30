import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainRollup = { chain_code: string; lamps: number; overdue: number; due_soon: number; avg_burn_hours: number; avg_irradiance: number };
type OverRated = { chain_code: string; hospital_unit: string; lamp_serial: string; lamp_model: string; cumulative_burn_hours: number; rated_life_hours: number; pct_of_rated: number };
type UnderIrr = { chain_code: string; hospital_unit: string; lamp_serial: string; irradiance_mw_cm2_nm: number; irradiance_threshold_mw: number; gap_mw: number; ward_acuity: string };
type CritFinding = { lamp_serial: string; chain_code: string; finding_category: string; babies_exposed: number; remediation_cost_rupees: number; remediation_status: string; auditor_note: string | null };
type CategoryMix = { finding_category: string; total: number; open_count: number; closed_count: number; total_remediation_rupees: number; babies_exposed: number };
type CalibOverdue = { chain_code: string; hospital_unit: string; lamp_serial: string; last_calibration_date: string; days_since_calibration: number; ward_acuity: string };
type BurnPace = { chain_code: string; lamps: number; total_quarter_burn_hours: number; projected_annualised: number; projected_replacement_risk: string };
type StatusSpread = { replacement_status: string; lamps: number; avg_cumulative_burn: number; total_babies_at_risk: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [rollupR, overR, underR, critR, mixR, calibR, paceR, spreadR] = await Promise.all([
    sb.rpc('founder_r3059_chain_rollup'),
    sb.rpc('founder_r3059_lamps_over_rated_life'),
    sb.rpc('founder_r3059_under_irradiance_lamps'),
    sb.rpc('founder_r3059_critical_open_findings'),
    sb.rpc('founder_r3059_finding_category_mix'),
    sb.rpc('founder_r3059_calibration_overdue'),
    sb.rpc('founder_r3059_quarter_burn_pace'),
    sb.rpc('founder_r3059_replacement_status_spread'),
  ]);

  const rollup = (rollupR.data ?? []) as ChainRollup[];
  const over = (overR.data ?? []) as OverRated[];
  const under = (underR.data ?? []) as UnderIrr[];
  const crit = (critR.data ?? []) as CritFinding[];
  const mix = (mixR.data ?? []) as CategoryMix[];
  const calib = (calibR.data ?? []) as CalibOverdue[];
  const pace = (paceR.data ?? []) as BurnPace[];
  const spread = (spreadR.data ?? []) as StatusSpread[];

  const rollupCols: Column<ChainRollup>[] = [
    { key: 'chain_code', header: 'Chain' },
    { key: 'lamps', header: 'Lamps' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'due_soon', header: 'Due Soon' },
    { key: 'avg_burn_hours', header: 'Avg Q Burn Hrs' },
    { key: 'avg_irradiance', header: 'Avg Irradiance (mW)' },
  ];
  const overCols: Column<OverRated>[] = [
    { key: 'chain_code', header: 'Chain' },
    { key: 'hospital_unit', header: 'Unit' },
    { key: 'lamp_serial', header: 'Serial' },
    { key: 'lamp_model', header: 'Model' },
    { key: 'cumulative_burn_hours', header: 'Cum Burn' },
    { key: 'rated_life_hours', header: 'Rated' },
    { key: 'pct_of_rated', header: '% of Rated' },
  ];
  const underCols: Column<UnderIrr>[] = [
    { key: 'chain_code', header: 'Chain' },
    { key: 'hospital_unit', header: 'Unit' },
    { key: 'lamp_serial', header: 'Serial' },
    { key: 'irradiance_mw_cm2_nm', header: 'Measured (mW)' },
    { key: 'irradiance_threshold_mw', header: 'Threshold (mW)' },
    { key: 'gap_mw', header: 'Gap (mW)' },
    { key: 'ward_acuity', header: 'Acuity' },
  ];
  const critCols: Column<CritFinding>[] = [
    { key: 'lamp_serial', header: 'Serial' },
    { key: 'chain_code', header: 'Chain' },
    { key: 'finding_category', header: 'Category' },
    { key: 'babies_exposed', header: 'Babies Exposed' },
    { key: 'remediation_cost_rupees', header: 'Cost (Rs)' },
    { key: 'remediation_status', header: 'Status' },
    { key: 'auditor_note', header: 'Note' },
  ];
  const mixCols: Column<CategoryMix>[] = [
    { key: 'finding_category', header: 'Category' },
    { key: 'total', header: 'Total' },
    { key: 'open_count', header: 'Open' },
    { key: 'closed_count', header: 'Closed' },
    { key: 'total_remediation_rupees', header: 'Remediation Rs' },
    { key: 'babies_exposed', header: 'Babies Exposed' },
  ];
  const calibCols: Column<CalibOverdue>[] = [
    { key: 'chain_code', header: 'Chain' },
    { key: 'hospital_unit', header: 'Unit' },
    { key: 'lamp_serial', header: 'Serial' },
    { key: 'last_calibration_date', header: 'Last Calib' },
    { key: 'days_since_calibration', header: 'Days Since' },
    { key: 'ward_acuity', header: 'Acuity' },
  ];
  const paceCols: Column<BurnPace>[] = [
    { key: 'chain_code', header: 'Chain' },
    { key: 'lamps', header: 'Lamps' },
    { key: 'total_quarter_burn_hours', header: 'Q Burn Hrs' },
    { key: 'projected_annualised', header: 'Annualised' },
    { key: 'projected_replacement_risk', header: 'Risk' },
  ];
  const spreadCols: Column<StatusSpread>[] = [
    { key: 'replacement_status', header: 'Status' },
    { key: 'lamps', header: 'Lamps' },
    { key: 'avg_cumulative_burn', header: 'Avg Cum Burn' },
    { key: 'total_babies_at_risk', header: 'Babies At Risk' },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly NICU Phototherapy Lamp Bulb-Hour Burn Audit</h1>
        <p className="text-sm text-gray-600">Round r3059 — founder console. Tracks bulb-hour burn, irradiance decay & remediation across NICU chains.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain rollup</h2>
        <DataTable rows={rollup} columns={rollupCols} emptyMessage="No chains" rowKey={(r, i) => String((r as ChainRollup).chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Lamps &gt;= 85% of rated life</h2>
        <DataTable rows={over} columns={overCols} emptyMessage="None over rated life" rowKey={(r, i) => String((r as OverRated).lamp_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Under-irradiance lamps (below threshold)</h2>
        <DataTable rows={under} columns={underCols} emptyMessage="All lamps above threshold" rowKey={(r, i) => String((r as UnderIrr).lamp_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical open findings</h2>
        <DataTable rows={crit} columns={critCols} emptyMessage="No critical open findings" rowKey={(r, i) => String((r as CritFinding).lamp_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Finding category mix</h2>
        <DataTable rows={mix} columns={mixCols} emptyMessage="No findings" rowKey={(r, i) => String((r as CategoryMix).finding_category ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Calibration overdue (&gt; 90 days)</h2>
        <DataTable rows={calib} columns={calibCols} emptyMessage="All calibrations current" rowKey={(r, i) => String((r as CalibOverdue).lamp_serial ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter burn pace & annualised projection</h2>
        <DataTable rows={pace} columns={paceCols} emptyMessage="No pace data" rowKey={(r, i) => String((r as BurnPace).chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Replacement status spread</h2>
        <DataTable rows={spread} columns={spreadCols} emptyMessage="No spread" rowKey={(r, i) => String((r as StatusSpread).replacement_status ?? i)} />
      </section>
    </main>
  );
}
