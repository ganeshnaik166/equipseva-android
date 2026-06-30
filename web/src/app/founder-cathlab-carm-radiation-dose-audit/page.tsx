import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type FleetRow = {
  asset_tag: string;
  hospital_name: string;
  city: string;
  carm_make: string;
  carm_model: string;
  install_year: number;
  ii_type: string;
  ii_resolution_lp_mm: number;
  audit_quarter: string;
  audit_year: number;
  overall_audit_status: string;
  total_procedures: number;
  cumulative_dap_gy_cm2: number;
  peak_skin_dose_gy: number;
  exceeds_aerb_limit: boolean;
  capa_required: boolean;
  next_audit_due: string;
};

type ExceedRow = {
  asset_tag: string;
  hospital_name: string;
  city: string;
  finding_type: string;
  severity: string;
  measured_psd_gy: number | null;
  measured_dap_gy_cm2: number | null;
  deviation_percent: number | null;
  capa_action_code: string;
  capa_status: string;
  capa_target_date: string | null;
};

type CapaRow = {
  asset_tag: string;
  hospital_name: string;
  finding_type: string;
  capa_action_code: string;
  capa_status: string;
  capa_target_date: string | null;
  capa_closed_at: string | null;
  severity: string;
  estimated_repair_cost_rupees: number;
};

type SevRow = {
  severity: string;
  finding_count: number;
  total_capa_cost_rupees: number;
  avg_deviation_pct: number | null;
};

type IIRow = {
  asset_tag: string;
  hospital_name: string;
  carm_make: string;
  carm_model: string;
  install_year: number;
  ii_type: string;
  ii_resolution_lp_mm: number;
  age_years: number;
  resolution_status: string;
};

type LicRow = {
  asset_tag: string;
  hospital_name: string;
  aerb_licence_number: string;
  aerb_licence_expiry: string;
  days_to_expiry: number;
  rso_name: string;
  rso_certification_valid: boolean;
};

type MixRow = {
  procedure_category: string;
  finding_count: number;
  avg_psd_gy: number | null;
  avg_fluoro_minutes: number | null;
  critical_count: number;
};

type SummaryRow = {
  total_labs_audited: number;
  total_procedures: number;
  total_dap_gy_cm2: number;
  labs_over_aerb: number;
  critical_findings: number;
  capa_open: number;
  capa_overdue: number;
  capa_cost_outstanding_rupees: number;
  decommission_candidates: number;
};

const inr = (n: number) => '₹' + (n ?? 0).toLocaleString('en-IN');

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [fleet, exceed, capa, sev, ii, lic, mix, sum] = await Promise.all([
    sb.rpc('founder_r3114_fleet_overview'),
    sb.rpc('founder_r3114_dose_exceedances'),
    sb.rpc('founder_r3114_capa_pipeline'),
    sb.rpc('founder_r3114_severity_rollup'),
    sb.rpc('founder_r3114_ii_resolution_decay'),
    sb.rpc('founder_r3114_aerb_licence_watch'),
    sb.rpc('founder_r3114_procedure_mix'),
    sb.rpc('founder_r3114_executive_summary'),
  ]);

  const fleetRows  = (fleet.data ?? []) as FleetRow[];
  const exceedRows = (exceed.data ?? []) as ExceedRow[];
  const capaRows   = (capa.data ?? []) as CapaRow[];
  const sevRows    = (sev.data ?? []) as SevRow[];
  const iiRows     = (ii.data ?? []) as IIRow[];
  const licRows    = (lic.data ?? []) as LicRow[];
  const mixRows    = (mix.data ?? []) as MixRow[];
  const summary    = ((sum.data ?? []) as SummaryRow[])[0];

  const fleetCols: Column<FleetRow>[] = [
    { key: 'asset_tag', header: 'Asset' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'city', header: 'City' },
    { key: 'carm_make', header: 'Make' },
    { key: 'carm_model', header: 'Model' },
    { key: 'install_year', header: 'Yr' },
    { key: 'ii_type', header: 'II Type' },
    { key: 'ii_resolution_lp_mm', header: 'lp/mm' },
    { key: 'overall_audit_status', header: 'Status' },
    { key: 'total_procedures', header: 'Procs' },
    { key: 'cumulative_dap_gy_cm2', header: 'DAP Gy.cm2' },
    { key: 'peak_skin_dose_gy', header: 'PSD Gy' },
    { key: 'exceeds_aerb_limit', header: 'AERB?', render: (r) => r.exceeds_aerb_limit ? 'over limit' : 'ok' },
    { key: 'capa_required', header: 'CAPA?', render: (r) => r.capa_required ? 'yes' : 'no' },
    { key: 'next_audit_due', header: 'Next Due' },
  ];

  const exceedCols: Column<ExceedRow>[] = [
    { key: 'asset_tag', header: 'Asset' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'finding_type', header: 'Finding' },
    { key: 'severity', header: 'Severity' },
    { key: 'measured_psd_gy', header: 'PSD Gy', render: (r) => r.measured_psd_gy?.toFixed(3) ?? '-' },
    { key: 'measured_dap_gy_cm2', header: 'DAP Gy.cm2', render: (r) => r.measured_dap_gy_cm2?.toFixed(2) ?? '-' },
    { key: 'deviation_percent', header: 'Dev %', render: (r) => r.deviation_percent != null ? r.deviation_percent.toFixed(1) + '%' : '-' },
    { key: 'capa_action_code', header: 'Action' },
    { key: 'capa_status', header: 'CAPA' },
    { key: 'capa_target_date', header: 'Target' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'asset_tag', header: 'Asset' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'finding_type', header: 'Finding' },
    { key: 'capa_action_code', header: 'Action' },
    { key: 'capa_status', header: 'Status' },
    { key: 'capa_target_date', header: 'Target' },
    { key: 'capa_closed_at', header: 'Closed' },
    { key: 'severity', header: 'Severity' },
    { key: 'estimated_repair_cost_rupees', header: 'Cost', render: (r) => inr(r.estimated_repair_cost_rupees) },
  ];

  const sevCols: Column<SevRow>[] = [
    { key: 'severity', header: 'Severity' },
    { key: 'finding_count', header: 'Findings' },
    { key: 'total_capa_cost_rupees', header: 'CAPA Cost', render: (r) => inr(r.total_capa_cost_rupees) },
    { key: 'avg_deviation_pct', header: 'Avg Dev %', render: (r) => r.avg_deviation_pct != null ? r.avg_deviation_pct.toFixed(2) + '%' : '-' },
  ];

  const iiCols: Column<IIRow>[] = [
    { key: 'asset_tag', header: 'Asset' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'carm_make', header: 'Make' },
    { key: 'carm_model', header: 'Model' },
    { key: 'install_year', header: 'Install' },
    { key: 'age_years', header: 'Age yr' },
    { key: 'ii_type', header: 'II Type' },
    { key: 'ii_resolution_lp_mm', header: 'lp/mm' },
    { key: 'resolution_status', header: 'Status' },
  ];

  const licCols: Column<LicRow>[] = [
    { key: 'asset_tag', header: 'Asset' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'aerb_licence_number', header: 'AERB Lic' },
    { key: 'aerb_licence_expiry', header: 'Expiry' },
    { key: 'days_to_expiry', header: 'Days Left' },
    { key: 'rso_name', header: 'RSO' },
    { key: 'rso_certification_valid', header: 'Cert ok?', render: (r) => r.rso_certification_valid ? 'yes' : 'no' },
  ];

  const mixCols: Column<MixRow>[] = [
    { key: 'procedure_category', header: 'Procedure' },
    { key: 'finding_count', header: 'Findings' },
    { key: 'avg_psd_gy', header: 'Avg PSD Gy', render: (r) => r.avg_psd_gy != null ? r.avg_psd_gy.toFixed(3) : '-' },
    { key: 'avg_fluoro_minutes', header: 'Avg Fluoro min', render: (r) => r.avg_fluoro_minutes != null ? r.avg_fluoro_minutes.toFixed(2) : '-' },
    { key: 'critical_count', header: 'Critical' },
  ];

  return (
    <main className="p-6 space-y-8 max-w-screen-2xl">
      <header>
        <h1 className="text-2xl font-semibold">Cath-Lab C-Arm Radiation Dose Audit (r3114)</h1>
        <p className="text-sm text-gray-600">
          Quarterly DAP &times; PSD &times; fluoro time &times; kV/mA &times; II resolution audit with AERB-limit CAPA tracking.
        </p>
      </header>

      {summary && (
        <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-3">
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Labs Audited</div><div className="text-xl font-semibold">{summary.total_labs_audited}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Procedures</div><div className="text-xl font-semibold">{summary.total_procedures.toLocaleString('en-IN')}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Total DAP Gy.cm2</div><div className="text-xl font-semibold">{Number(summary.total_dap_gy_cm2).toLocaleString('en-IN')}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Labs Over AERB</div><div className="text-xl font-semibold">{summary.labs_over_aerb}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Critical Findings</div><div className="text-xl font-semibold">{summary.critical_findings}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">CAPA Open</div><div className="text-xl font-semibold">{summary.capa_open}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">CAPA Overdue</div><div className="text-xl font-semibold">{summary.capa_overdue}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">CAPA Cost Outstanding</div><div className="text-xl font-semibold">{inr(summary.capa_cost_outstanding_rupees)}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Decommission Candidates</div><div className="text-xl font-semibold">{summary.decommission_candidates}</div></div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-medium mb-2">Fleet Overview</h2>
        <DataTable rows={fleetRows} columns={fleetCols} emptyMessage="No audits yet" rowKey={(r, i) => String(r.asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Dose Exceedances (DAP / PSD / Fluoro)</h2>
        <DataTable rows={exceedRows} columns={exceedCols} emptyMessage="No dose exceedances" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">CAPA Pipeline (open / in-progress / overdue)</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No open CAPA" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Severity Rollup</h2>
        <DataTable rows={sevRows} columns={sevCols} emptyMessage="No findings" rowKey={(r, i) => String(r.severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Image-Intensifier Resolution Decay</h2>
        <DataTable rows={iiRows} columns={iiCols} emptyMessage="No data" rowKey={(r, i) => String(r.asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">AERB Licence & RSO Watch</h2>
        <DataTable rows={licRows} columns={licCols} emptyMessage="No licences tracked" rowKey={(r, i) => String(r.asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Procedure Mix & Avg Dose</h2>
        <DataTable rows={mixRows} columns={mixCols} emptyMessage="No procedures" rowKey={(r, i) => String(r.procedure_category ?? i)} />
      </section>
    </main>
  );
}
