import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type DriftRollup = { drift_severity: string; pumps: number; avg_drift_pct: number; max_drift_pct: number; critical_or_major: number };
type BatteryRisk = { pump_asset_tag: string; manufacturer: string; battery_cycle_count: number; drift_percent: number; action_taken: string };
type MemoryFail = { pump_asset_tag: string; model: string; memory_drift_seconds: number; ward_location: string | null; action_taken: string };
type GradeSummary = { safety_grade: string; pumps: number; patient_risk_flags: number; avg_free_flow: number };
type RiskPump = { pump_asset_tag: string; set_brand: string; safety_grade: string; failure_mode: string | null; corrective_action: string; free_flow_ml_per_min: number };
type FailMode = { failure_mode: string; occurrences: number; removed_from_service: number; replace_set: number };
type CombinedHealth = { pump_asset_tag: string; drift_severity: string; drift_action: string; safety_grade: string | null; corrective_action: string | null; combined_risk: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [r1, r2, r3, r4, r5, r6, r7] = await Promise.all([
    supabase.rpc('r3090_drift_severity_rollup'),
    supabase.rpc('r3090_battery_aging_risk'),
    supabase.rpc('r3090_memory_retention_failures'),
    supabase.rpc('r3090_free_flow_grade_summary'),
    supabase.rpc('r3090_patient_risk_pumps'),
    supabase.rpc('r3090_failure_mode_breakdown'),
    supabase.rpc('r3090_combined_audit_health'),
  ]);

  const drift = (r1.data ?? []) as DriftRollup[];
  const battery = (r2.data ?? []) as BatteryRisk[];
  const memory = (r3.data ?? []) as MemoryFail[];
  const grade = (r4.data ?? []) as GradeSummary[];
  const risk = (r5.data ?? []) as RiskPump[];
  const failmode = (r6.data ?? []) as FailMode[];
  const combined = (r7.data ?? []) as CombinedHealth[];

  const driftCols: Column<DriftRollup>[] = [
    { header: 'Severity', accessor: (r) => r.drift_severity },
    { header: 'Pumps', accessor: (r) => r.pumps },
    { header: 'Avg Drift %', accessor: (r) => r.avg_drift_pct },
    { header: 'Max Drift %', accessor: (r) => r.max_drift_pct },
    { header: 'Major/Critical', accessor: (r) => r.critical_or_major },
  ];

  const batteryCols: Column<BatteryRisk>[] = [
    { header: 'Asset', accessor: (r) => r.pump_asset_tag },
    { header: 'Manufacturer', accessor: (r) => r.manufacturer },
    { header: 'Cycles', accessor: (r) => r.battery_cycle_count },
    { header: 'Drift %', accessor: (r) => r.drift_percent },
    { header: 'Action', accessor: (r) => r.action_taken },
  ];

  const memoryCols: Column<MemoryFail>[] = [
    { header: 'Asset', accessor: (r) => r.pump_asset_tag },
    { header: 'Model', accessor: (r) => r.model },
    { header: 'Drift (s)', accessor: (r) => r.memory_drift_seconds },
    { header: 'Ward', accessor: (r) => r.ward_location ?? '—' },
    { header: 'Action', accessor: (r) => r.action_taken },
  ];

  const gradeCols: Column<GradeSummary>[] = [
    { header: 'Grade', accessor: (r) => r.safety_grade },
    { header: 'Pumps', accessor: (r) => r.pumps },
    { header: 'Risk Flags', accessor: (r) => r.patient_risk_flags },
    { header: 'Avg Free-Flow ml/min', accessor: (r) => r.avg_free_flow },
  ];

  const riskCols: Column<RiskPump>[] = [
    { header: 'Asset', accessor: (r) => r.pump_asset_tag },
    { header: 'Set', accessor: (r) => r.set_brand },
    { header: 'Grade', accessor: (r) => r.safety_grade },
    { header: 'Failure Mode', accessor: (r) => r.failure_mode ?? '—' },
    { header: 'Action', accessor: (r) => r.corrective_action },
    { header: 'Free-Flow', accessor: (r) => r.free_flow_ml_per_min },
  ];

  const failCols: Column<FailMode>[] = [
    { header: 'Failure Mode', accessor: (r) => r.failure_mode },
    { header: 'Occurrences', accessor: (r) => r.occurrences },
    { header: 'Removed', accessor: (r) => r.removed_from_service },
    { header: 'Set Replaced', accessor: (r) => r.replace_set },
  ];

  const combinedCols: Column<CombinedHealth>[] = [
    { header: 'Asset', accessor: (r) => r.pump_asset_tag },
    { header: 'Drift Sev.', accessor: (r) => r.drift_severity },
    { header: 'Drift Action', accessor: (r) => r.drift_action },
    { header: 'Safety Grade', accessor: (r) => r.safety_grade ?? '—' },
    { header: 'Corr. Action', accessor: (r) => r.corrective_action ?? '—' },
    { header: 'Combined Risk', accessor: (r) => r.combined_risk },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Site IV-Pump Audit</h1>
        <p className="text-sm text-gray-600">Battery-memory drift & free-flow safety — round r3090</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">1. Drift Severity Rollup</h2>
        <DataTable rows={drift} columns={driftCols} emptyMessage="No drift data" rowKey={(r, i) => String((r as DriftRollup).drift_severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">2. Battery Aging Risk (cycles &gt; 500 or drift &gt; 10%)</h2>
        <DataTable rows={battery} columns={batteryCols} emptyMessage="No aging batteries" rowKey={(r, i) => String((r as BatteryRisk).pump_asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">3. Memory Retention Failures</h2>
        <DataTable rows={memory} columns={memoryCols} emptyMessage="No retention failures" rowKey={(r, i) => String((r as MemoryFail).pump_asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">4. Free-Flow Safety Grade Summary</h2>
        <DataTable rows={grade} columns={gradeCols} emptyMessage="No grade data" rowKey={(r, i) => String((r as GradeSummary).safety_grade ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">5. Patient-Risk Pumps</h2>
        <DataTable rows={risk} columns={riskCols} emptyMessage="No risk-flagged pumps" rowKey={(r, i) => String((r as RiskPump).pump_asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">6. Failure-Mode Breakdown</h2>
        <DataTable rows={failmode} columns={failCols} emptyMessage="No failure modes" rowKey={(r, i) => String((r as FailMode).failure_mode ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">7. Combined Audit Health</h2>
        <DataTable rows={combined} columns={combinedCols} emptyMessage="No combined data" rowKey={(r, i) => String((r as CombinedHealth).pump_asset_tag ?? i)} />
      </section>
    </div>
  );
}
