import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type QuarterlyRow = {
  audit_quarter: string;
  total_audits: number;
  passed: number;
  conditional_or_observation: number;
  failed_or_escalated: number;
  avg_helium_pct: number;
  avg_boil_off_lph: number;
  avg_field_stability_ppm: number;
};

type RiskBandRow = {
  risk_band: string;
  scanner_count: number;
  avg_quench_risk: number;
  avg_helium_pct: number;
  capa_open: number;
  capa_overdue: number;
};

type CriticalRow = {
  hospital_name: string;
  city: string;
  scanner_model: string;
  field_strength_tesla: number;
  helium_level_pct: number;
  helium_boil_off_lph: number;
  quench_risk_score: number;
  risk_band: string;
  audit_outcome: string;
  next_audit_due_date: string;
};

type MagnetRow = {
  magnet_type: string;
  scanner_count: number;
  avg_boil_off_lph: number;
  avg_helium_pct: number;
  avg_quench_risk: number;
  pass_rate_pct: number;
};

type ColdHeadRow = {
  hospital_name: string;
  scanner_model: string;
  field_strength_tesla: number;
  cold_head_runtime_hours: number;
  cold_head_replacement_due_hours: number;
  hours_over_spec: number;
  install_year: number;
  risk_band: string;
};

type SupplierRow = {
  supplier_name: string;
  contract_tier: string;
  fills_count: number;
  avg_response_hours: number;
  avg_delivery_days: number;
  total_litres_delivered: number;
  total_penalty_rupees: number;
  avg_supplier_rating: number;
  breaches: number;
};

type BreachRow = {
  hospital_name: string;
  supplier_name: string;
  cryogen_type: string;
  contract_tier: string;
  sla_response_hours: number;
  actual_response_hours: number;
  delivery_window_days: number;
  actual_delivery_days: number;
  purity_pct: number;
  purity_spec_pct: number;
  sla_breach: string;
  penalty_levied_rupees: number;
  remediation_status: string;
};

type CapaRow = {
  capa_status: string;
  scanner_count: number;
  avg_quench_risk: number;
  avg_days_to_next_audit: number;
  failed_scanners: number;
};

type DriftRow = {
  hospital_name: string;
  scanner_model: string;
  field_strength_tesla: number;
  field_stability_ppm: number;
  field_stability_spec_ppm: number;
  drift_over_spec_ppm: number;
  ramp_events_last_year: number;
  audit_outcome: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    quarterly,
    riskBand,
    critical,
    magnet,
    coldHead,
    supplier,
    breach,
    capa,
    drift,
  ] = await Promise.all([
    supabase.rpc('r3128_quarterly_audit_summary'),
    supabase.rpc('r3128_risk_band_breakdown'),
    supabase.rpc('r3128_critical_scanners_top'),
    supabase.rpc('r3128_magnet_type_performance'),
    supabase.rpc('r3128_cold_head_aging_alerts'),
    supabase.rpc('r3128_supplier_sla_scorecard'),
    supabase.rpc('r3128_sla_breach_detail'),
    supabase.rpc('r3128_capa_workflow_status'),
    supabase.rpc('r3128_field_stability_drift'),
  ]);

  const quarterlyRows: QuarterlyRow[] = (quarterly.data ?? []) as QuarterlyRow[];
  const riskBandRows: RiskBandRow[] = (riskBand.data ?? []) as RiskBandRow[];
  const criticalRows: CriticalRow[] = (critical.data ?? []) as CriticalRow[];
  const magnetRows: MagnetRow[] = (magnet.data ?? []) as MagnetRow[];
  const coldHeadRows: ColdHeadRow[] = (coldHead.data ?? []) as ColdHeadRow[];
  const supplierRows: SupplierRow[] = (supplier.data ?? []) as SupplierRow[];
  const breachRows: BreachRow[] = (breach.data ?? []) as BreachRow[];
  const capaRows: CapaRow[] = (capa.data ?? []) as CapaRow[];
  const driftRows: DriftRow[] = (drift.data ?? []) as DriftRow[];

  const quarterlyCols: Column<QuarterlyRow>[] = [
    { key: 'audit_quarter', header: 'Quarter' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'passed', header: 'Pass' },
    { key: 'conditional_or_observation', header: 'Conditional' },
    { key: 'failed_or_escalated', header: 'Fail / Escalate' },
    { key: 'avg_helium_pct', header: 'Avg He %' },
    { key: 'avg_boil_off_lph', header: 'Avg Boil-off (L/h)' },
    { key: 'avg_field_stability_ppm', header: 'Avg B0 drift (ppm)' },
  ];

  const riskBandCols: Column<RiskBandRow>[] = [
    { key: 'risk_band', header: 'Risk band' },
    { key: 'scanner_count', header: 'Scanners' },
    { key: 'avg_quench_risk', header: 'Avg quench risk' },
    { key: 'avg_helium_pct', header: 'Avg He %' },
    { key: 'capa_open', header: 'CAPA open' },
    { key: 'capa_overdue', header: 'CAPA overdue' },
  ];

  const criticalCols: Column<CriticalRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'city', header: 'City' },
    { key: 'scanner_model', header: 'Scanner' },
    { key: 'field_strength_tesla', header: 'B0 (T)' },
    { key: 'helium_level_pct', header: 'He %' },
    { key: 'helium_boil_off_lph', header: 'Boil-off (L/h)' },
    { key: 'quench_risk_score', header: 'Quench risk' },
    { key: 'risk_band', header: 'Band' },
    { key: 'audit_outcome', header: 'Outcome' },
    { key: 'next_audit_due_date', header: 'Next audit' },
  ];

  const magnetCols: Column<MagnetRow>[] = [
    { key: 'magnet_type', header: 'Magnet type' },
    { key: 'scanner_count', header: 'Count' },
    { key: 'avg_boil_off_lph', header: 'Avg boil-off (L/h)' },
    { key: 'avg_helium_pct', header: 'Avg He %' },
    { key: 'avg_quench_risk', header: 'Avg quench risk' },
    { key: 'pass_rate_pct', header: 'Pass rate %' },
  ];

  const coldHeadCols: Column<ColdHeadRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'scanner_model', header: 'Scanner' },
    { key: 'field_strength_tesla', header: 'B0 (T)' },
    { key: 'cold_head_runtime_hours', header: 'Runtime (h)' },
    { key: 'cold_head_replacement_due_hours', header: 'Replace at (h)' },
    { key: 'hours_over_spec', header: 'Hrs vs spec' },
    { key: 'install_year', header: 'Installed' },
    { key: 'risk_band', header: 'Band' },
  ];

  const supplierCols: Column<SupplierRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'contract_tier', header: 'Tier' },
    { key: 'fills_count', header: 'Fills' },
    { key: 'avg_response_hours', header: 'Avg response (h)' },
    { key: 'avg_delivery_days', header: 'Avg delivery (d)' },
    { key: 'total_litres_delivered', header: 'Total litres' },
    { key: 'total_penalty_rupees', header: 'Penalty (Rs)' },
    { key: 'avg_supplier_rating', header: 'Rating' },
    { key: 'breaches', header: 'Breaches' },
  ];

  const breachCols: Column<BreachRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'cryogen_type', header: 'Cryogen' },
    { key: 'contract_tier', header: 'Tier' },
    { key: 'sla_response_hours', header: 'SLA resp (h)' },
    { key: 'actual_response_hours', header: 'Actual resp (h)' },
    { key: 'delivery_window_days', header: 'SLA delv (d)' },
    { key: 'actual_delivery_days', header: 'Actual delv (d)' },
    { key: 'purity_pct', header: 'Purity %' },
    { key: 'purity_spec_pct', header: 'Purity spec %' },
    { key: 'sla_breach', header: 'Breach' },
    { key: 'penalty_levied_rupees', header: 'Penalty (Rs)' },
    { key: 'remediation_status', header: 'Remediation' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA status' },
    { key: 'scanner_count', header: 'Scanners' },
    { key: 'avg_quench_risk', header: 'Avg quench risk' },
    { key: 'avg_days_to_next_audit', header: 'Avg days to next audit' },
    { key: 'failed_scanners', header: 'Failed / OEM-escalated' },
  ];

  const driftCols: Column<DriftRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'scanner_model', header: 'Scanner' },
    { key: 'field_strength_tesla', header: 'B0 (T)' },
    { key: 'field_stability_ppm', header: 'Stability (ppm)' },
    { key: 'field_stability_spec_ppm', header: 'Spec (ppm)' },
    { key: 'drift_over_spec_ppm', header: 'Drift over spec' },
    { key: 'ramp_events_last_year', header: 'Ramps (12mo)' },
    { key: 'audit_outcome', header: 'Outcome' },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-10 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">MRI Cryogen & Field-Stability Audit</h1>
        <p className="text-sm text-neutral-600">
          Round r3128 · Quarterly review of helium level, boil-off, B0 drift, ramp / quench history,
          cold-head aging, cryogen-supplier SLA, and CAPA workflow across hospital MRI fleet.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Quarterly audit summary</h2>
        <DataTable
          rows={quarterlyRows}
          columns={quarterlyCols}
          emptyMessage="No quarterly data."
          rowKey={(r, i) => String(r.audit_quarter ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Risk-band breakdown</h2>
        <DataTable
          rows={riskBandRows}
          columns={riskBandCols}
          emptyMessage="No risk-band data."
          rowKey={(r, i) => String(r.risk_band ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Critical scanners (elevated / high / critical)</h2>
        <DataTable
          rows={criticalRows}
          columns={criticalCols}
          emptyMessage="No scanners currently flagged."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Magnet-type performance</h2>
        <DataTable
          rows={magnetRows}
          columns={magnetCols}
          emptyMessage="No magnet-type data."
          rowKey={(r, i) => String(r.magnet_type ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Cold-head aging alerts (&gt;=85% of replacement spec)</h2>
        <DataTable
          rows={coldHeadRows}
          columns={coldHeadCols}
          emptyMessage="No cold-head alerts."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Cryogen-supplier SLA scorecard</h2>
        <DataTable
          rows={supplierRows}
          columns={supplierCols}
          emptyMessage="No supplier data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">SLA breach detail</h2>
        <DataTable
          rows={breachRows}
          columns={breachCols}
          emptyMessage="No SLA breaches recorded."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">CAPA workflow status</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA workflow data."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Field-stability drift watchlist</h2>
        <DataTable
          rows={driftRows}
          columns={driftCols}
          emptyMessage="All scanners within B0 stability spec."
          rowKey={(r, i) => String(i)}
        />
      </section>
    </div>
  );
}
