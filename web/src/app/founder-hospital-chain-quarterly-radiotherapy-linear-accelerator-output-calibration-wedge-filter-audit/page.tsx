import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_code: string; calibrations_total: number; out_of_tolerance: number; recalibration_required: number; aerb_noncompliant: number; avg_deviation_pct: number };
type OutcomeRow = { outcome: string; n: number; pct_of_total: number };
type VendorRow = { linac_vendor: string; units: number; avg_abs_deviation: number; out_of_tol_pct: number };
type EnergyRow = { energy_mode: string; units: number; avg_deviation: number; max_deviation: number };
type WedgeRow = { wedge_type: string; audits: number; pass_n: number; fail_n: number; equipment_fault_n: number; avg_abs_dev: number };
type CorrectiveRow = { hospital_name: string; wedge_type: string; factor_deviation_pct: number; audit_status: string; corrective_action: string | null };
type AerbRow = { hospital_name: string; linac_serial: string; energy_mode: string; deviation_pct: number; outcome: string; calibration_date: string };
type ScorecardRow = { hospital_name: string; calibrations: number; wedge_audits: number; failures: number; max_dev_pct: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [chain, outcome, vendor, energy, wedge, corrective, aerb, scorecard] = await Promise.all([
    supabase.rpc('rpc_r3091_chain_summary'),
    supabase.rpc('rpc_r3091_outcome_breakdown'),
    supabase.rpc('rpc_r3091_vendor_reliability'),
    supabase.rpc('rpc_r3091_energy_performance'),
    supabase.rpc('rpc_r3091_wedge_summary'),
    supabase.rpc('rpc_r3091_corrective_queue'),
    supabase.rpc('rpc_r3091_aerb_noncompliance'),
    supabase.rpc('rpc_r3091_hospital_scorecard'),
  ]);

  const chainCols: Column<ChainRow>[] = [
    { key: 'chain_code', header: 'Chain' },
    { key: 'calibrations_total', header: 'Calibrations' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'recalibration_required', header: 'Recalib Req' },
    { key: 'aerb_noncompliant', header: 'AERB Non-Compliant' },
    { key: 'avg_deviation_pct', header: 'Avg |Dev| %' },
  ];

  const outcomeCols: Column<OutcomeRow>[] = [
    { key: 'outcome', header: 'Outcome' },
    { key: 'n', header: 'Count' },
    { key: 'pct_of_total', header: '% Total' },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { key: 'linac_vendor', header: 'Vendor' },
    { key: 'units', header: 'Units' },
    { key: 'avg_abs_deviation', header: 'Avg |Dev| %' },
    { key: 'out_of_tol_pct', header: 'Out-of-Tol %' },
  ];

  const energyCols: Column<EnergyRow>[] = [
    { key: 'energy_mode', header: 'Energy' },
    { key: 'units', header: 'Units' },
    { key: 'avg_deviation', header: 'Avg |Dev| %' },
    { key: 'max_deviation', header: 'Max |Dev| %' },
  ];

  const wedgeCols: Column<WedgeRow>[] = [
    { key: 'wedge_type', header: 'Wedge Type' },
    { key: 'audits', header: 'Audits' },
    { key: 'pass_n', header: 'Pass' },
    { key: 'fail_n', header: 'Fail' },
    { key: 'equipment_fault_n', header: 'Eq Fault' },
    { key: 'avg_abs_dev', header: 'Avg |Dev| %' },
  ];

  const correctiveCols: Column<CorrectiveRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'wedge_type', header: 'Wedge' },
    { key: 'factor_deviation_pct', header: 'Dev %' },
    { key: 'audit_status', header: 'Status' },
    { key: 'corrective_action', header: 'Action' },
  ];

  const aerbCols: Column<AerbRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'linac_serial', header: 'LINAC Serial' },
    { key: 'energy_mode', header: 'Energy' },
    { key: 'deviation_pct', header: 'Dev %' },
    { key: 'outcome', header: 'Outcome' },
    { key: 'calibration_date', header: 'Cal Date' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'calibrations', header: 'Calibrations' },
    { key: 'wedge_audits', header: 'Wedge Audits' },
    { key: 'failures', header: 'Failures' },
    { key: 'max_dev_pct', header: 'Max |Dev| %' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Radiotherapy LINAC Output Calibration &amp; Wedge Filter Audit</h1>
        <p className="text-sm text-gray-600">Quarterly TG-51 LINAC output verification + wedge factor audit across hospital chains. AERB tolerance &lt;= 2%.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Summary</h2>
        <DataTable rows={(chain.data ?? []) as ChainRow[]} columns={chainCols} emptyMessage="No chain data" rowKey={(r, i) => String(r.chain_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Outcome Breakdown</h2>
        <DataTable rows={(outcome.data ?? []) as OutcomeRow[]} columns={outcomeCols} emptyMessage="No outcomes" rowKey={(r, i) => String(r.outcome ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Vendor Reliability</h2>
        <DataTable rows={(vendor.data ?? []) as VendorRow[]} columns={vendorCols} emptyMessage="No vendor data" rowKey={(r, i) => String(r.linac_vendor ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Energy Mode Performance</h2>
        <DataTable rows={(energy.data ?? []) as EnergyRow[]} columns={energyCols} emptyMessage="No energy data" rowKey={(r, i) => String(r.energy_mode ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Wedge Filter Summary</h2>
        <DataTable rows={(wedge.data ?? []) as WedgeRow[]} columns={wedgeCols} emptyMessage="No wedge data" rowKey={(r, i) => String(r.wedge_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Corrective Action Queue (deviation &gt;= 1.5%)</h2>
        <DataTable rows={(corrective.data ?? []) as CorrectiveRow[]} columns={correctiveCols} emptyMessage="Queue clear" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">AERB Non-Compliance</h2>
        <DataTable rows={(aerb.data ?? []) as AerbRow[]} columns={aerbCols} emptyMessage="All AERB-compliant" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospital Scorecard</h2>
        <DataTable rows={(scorecard.data ?? []) as ScorecardRow[]} columns={scorecardCols} emptyMessage="No hospitals" rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>
    </div>
  );
}
