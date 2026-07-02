import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type CycleOutcomeRow = {
  cycle_outcome: string;
  total_cycles: number;
  total_organizations: number;
  pct_of_total: number;
};

type LeakTestRow = {
  scope_type: string;
  total_cycles: number;
  leak_pass: number;
  leak_fail: number;
  leak_not_performed: number;
  leak_fail_pct: number;
};

type ChemicalRow = {
  chemical_name: string;
  total_cycles: number;
  avg_concentration_ppm: number;
  min_concentration_ppm: number;
  below_threshold_count: number;
  threshold_breach_pct: number;
};

type AbortRow = {
  abort_reason: string;
  total_aborts: number;
  distinct_scopes: number;
  distinct_aer_units: number;
  last_seen: string | null;
};

type ScopeComplianceRow = {
  scope_serial: string;
  scope_model: string;
  scope_type: string;
  total_cycles: number;
  compliant_cycles: number;
  non_compliant_cycles: number;
  compliance_pct: number;
  current_status: string;
};

type AerUnitRow = {
  aer_unit_code: string;
  aer_manufacturer: string;
  total_cycles: number;
  passed: number;
  failed_or_aborted: number;
  avg_duration_min: number | null;
  pass_rate_pct: number;
};

type PatientTraceRow = {
  patient_procedure: string;
  total_cycles: number;
  cycles_with_uhid: number;
  cycles_missing_uhid: number;
  non_compliant_cycles: number;
  traceability_pct: number;
};

type RegistryStatusRow = {
  current_status: string;
  scope_count: number;
  total_lifetime_cycles: number;
  overdue_service_count: number;
  quarantined_count: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    outcomeRes,
    leakRes,
    chemicalRes,
    abortRes,
    scopeRes,
    aerUnitRes,
    patientRes,
    registryRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3102_cycle_outcome_rollup'),
    supabase.rpc('founder_r3102_leak_test_breakdown'),
    supabase.rpc('founder_r3102_chemical_concentration_audit'),
    supabase.rpc('founder_r3102_abort_reason_rollup'),
    supabase.rpc('founder_r3102_scope_compliance_rollup'),
    supabase.rpc('founder_r3102_aer_unit_performance'),
    supabase.rpc('founder_r3102_patient_traceability_rollup'),
    supabase.rpc('founder_r3102_scope_registry_status'),
  ]);

  const outcomeRows: CycleOutcomeRow[] = (outcomeRes.data as CycleOutcomeRow[] | null) ?? [];
  const leakRows: LeakTestRow[] = (leakRes.data as LeakTestRow[] | null) ?? [];
  const chemicalRows: ChemicalRow[] = (chemicalRes.data as ChemicalRow[] | null) ?? [];
  const abortRows: AbortRow[] = (abortRes.data as AbortRow[] | null) ?? [];
  const scopeRows: ScopeComplianceRow[] = (scopeRes.data as ScopeComplianceRow[] | null) ?? [];
  const aerUnitRows: AerUnitRow[] = (aerUnitRes.data as AerUnitRow[] | null) ?? [];
  const patientRows: PatientTraceRow[] = (patientRes.data as PatientTraceRow[] | null) ?? [];
  const registryRows: RegistryStatusRow[] = (registryRes.data as RegistryStatusRow[] | null) ?? [];

  const outcomeCols: Column<CycleOutcomeRow>[] = [
    { key: 'cycle_outcome', header: 'Outcome' },
    { key: 'total_cycles', header: 'Cycles' },
    { key: 'total_organizations', header: 'Orgs' },
    { key: 'pct_of_total', header: '% of Total', render: (r) => `${r.pct_of_total ?? 0}%` },
  ];

  const leakCols: Column<LeakTestRow>[] = [
    { key: 'scope_type', header: 'Scope Type' },
    { key: 'total_cycles', header: 'Cycles' },
    { key: 'leak_pass', header: 'Leak Pass' },
    { key: 'leak_fail', header: 'Leak Fail' },
    { key: 'leak_not_performed', header: 'Skipped' },
    { key: 'leak_fail_pct', header: 'Fail %', render: (r) => `${r.leak_fail_pct ?? 0}%` },
  ];

  const chemicalCols: Column<ChemicalRow>[] = [
    { key: 'chemical_name', header: 'Chemical' },
    { key: 'total_cycles', header: 'Cycles' },
    { key: 'avg_concentration_ppm', header: 'Avg ppm' },
    { key: 'min_concentration_ppm', header: 'Min ppm' },
    { key: 'below_threshold_count', header: 'Below Threshold' },
    { key: 'threshold_breach_pct', header: 'Breach %', render: (r) => `${r.threshold_breach_pct ?? 0}%` },
  ];

  const abortCols: Column<AbortRow>[] = [
    { key: 'abort_reason', header: 'Reason' },
    { key: 'total_aborts', header: 'Aborts' },
    { key: 'distinct_scopes', header: 'Scopes' },
    { key: 'distinct_aer_units', header: 'AER Units' },
    {
      key: 'last_seen',
      header: 'Last Seen',
      render: (r) => (r.last_seen ? new Date(r.last_seen).toLocaleString('en-IN') : '—'),
    },
  ];

  const scopeCols: Column<ScopeComplianceRow>[] = [
    { key: 'scope_serial', header: 'Serial' },
    { key: 'scope_model', header: 'Model' },
    { key: 'scope_type', header: 'Type' },
    { key: 'total_cycles', header: 'Cycles' },
    { key: 'compliant_cycles', header: 'Compliant' },
    { key: 'non_compliant_cycles', header: 'Non-Compliant' },
    { key: 'compliance_pct', header: 'Compliance %', render: (r) => `${r.compliance_pct ?? 0}%` },
    { key: 'current_status', header: 'Current Status' },
  ];

  const aerUnitCols: Column<AerUnitRow>[] = [
    { key: 'aer_unit_code', header: 'AER Unit' },
    { key: 'aer_manufacturer', header: 'Manufacturer' },
    { key: 'total_cycles', header: 'Cycles' },
    { key: 'passed', header: 'Passed' },
    { key: 'failed_or_aborted', header: 'Failed / Aborted' },
    { key: 'avg_duration_min', header: 'Avg Duration (min)' },
    { key: 'pass_rate_pct', header: 'Pass Rate %', render: (r) => `${r.pass_rate_pct ?? 0}%` },
  ];

  const patientCols: Column<PatientTraceRow>[] = [
    { key: 'patient_procedure', header: 'Procedure' },
    { key: 'total_cycles', header: 'Cycles' },
    { key: 'cycles_with_uhid', header: 'With UHID' },
    { key: 'cycles_missing_uhid', header: 'Missing UHID' },
    { key: 'non_compliant_cycles', header: 'Non-Compliant' },
    { key: 'traceability_pct', header: 'Traceability %', render: (r) => `${r.traceability_pct ?? 0}%` },
  ];

  const registryCols: Column<RegistryStatusRow>[] = [
    { key: 'current_status', header: 'Status' },
    { key: 'scope_count', header: 'Scopes' },
    { key: 'total_lifetime_cycles', header: 'Lifetime Cycles' },
    { key: 'overdue_service_count', header: 'Overdue Service' },
    { key: 'quarantined_count', header: 'Quarantined' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">
          Customer Hospital Endoscope Reprocessing AER Cycle Compliance Audit
        </h1>
        <p className="text-sm text-gray-600">
          Round 3102 · AER cycle logs, leak tests, chemical concentration, abort tracking, and
          patient-link traceability across hospital scopes.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">1. Cycle Outcome Rollup</h2>
        <DataTable
          rows={outcomeRows}
          columns={outcomeCols}
          emptyMessage="No cycle data."
          rowKey={(r, i) => String((r as CycleOutcomeRow).cycle_outcome ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">2. Leak Test Breakdown by Scope Type</h2>
        <DataTable
          rows={leakRows}
          columns={leakCols}
          emptyMessage="No leak test data."
          rowKey={(r, i) => String((r as LeakTestRow).scope_type ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">3. Chemical Concentration Audit</h2>
        <DataTable
          rows={chemicalRows}
          columns={chemicalCols}
          emptyMessage="No chemical data."
          rowKey={(r, i) => String((r as ChemicalRow).chemical_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">4. Abort Reason Rollup</h2>
        <DataTable
          rows={abortRows}
          columns={abortCols}
          emptyMessage="No aborts recorded."
          rowKey={(r, i) => String((r as AbortRow).abort_reason ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">5. Scope-Level Compliance Rollup</h2>
        <DataTable
          rows={scopeRows}
          columns={scopeCols}
          emptyMessage="No scopes."
          rowKey={(r, i) => String((r as ScopeComplianceRow).scope_serial ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">6. AER Unit Performance</h2>
        <DataTable
          rows={aerUnitRows}
          columns={aerUnitCols}
          emptyMessage="No AER unit data."
          rowKey={(r, i) => String((r as AerUnitRow).aer_unit_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">7. Patient Traceability Rollup</h2>
        <DataTable
          rows={patientRows}
          columns={patientCols}
          emptyMessage="No patient-link data."
          rowKey={(r, i) => String((r as PatientTraceRow).patient_procedure ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">8. Scope Registry Status</h2>
        <DataTable
          rows={registryRows}
          columns={registryCols}
          emptyMessage="No scopes registered."
          rowKey={(r, i) => String((r as RegistryStatusRow).current_status ?? i)}
        />
      </section>
    </div>
  );
}
