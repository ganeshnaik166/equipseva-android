import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { overall_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  fit_for_use: number;
  out_of_service: number;
  condemn_recommended: number;
  cutoff_fails: number;
  avg_output_error_pct: number | null;
  fit_pct: number;
};
type DeviceRow = {
  device_type: string;
  audits: number;
  fit_for_use: number;
  avg_abs_output_error_pct: number | null;
  timer_fails: number;
};
type TrendRow = {
  test_date: string;
  audits: number;
  fit_for_use: number;
  out_of_service: number;
  cutoff_fails: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number | null;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  physio_unit_code: string;
  device_asset_tag: string;
  device_type: string;
  test_date: string;
  overall_verdict: string;
  output_error_pct: number | null;
  patient_safety_cutoff_test: string;
  electrode_applicator_condition: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    deviceRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3186_verdict_rollup'),
    supabase.rpc('founder_r3186_hospital_scorecard'),
    supabase.rpc('founder_r3186_device_type_matrix'),
    supabase.rpc('founder_r3186_daily_trend'),
    supabase.rpc('founder_r3186_capa_status_board'),
    supabase.rpc('founder_r3186_root_cause_pareto'),
    supabase.rpc('founder_r3186_regulatory_impact_digest'),
    supabase.rpc('founder_r3186_high_risk_devices'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const deviceRows: DeviceRow[] = (deviceRes.data as DeviceRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'overall_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'condemn_recommended', header: 'Condemn' },
    { key: 'cutoff_fails', header: 'Cutoff Fails' },
    { key: 'avg_output_error_pct', header: 'Avg Output Error %' },
    { key: 'fit_pct', header: 'Fit %' },
  ];

  const deviceCols: Column<DeviceRow>[] = [
    { key: 'device_type', header: 'Device Type' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'avg_abs_output_error_pct', header: 'Avg |Output Error| %' },
    { key: 'timer_fails', header: 'Timer Issues' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit for Use' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'cutoff_fails', header: 'Cutoff Fails' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'physio_unit_code', header: 'Unit' },
    { key: 'device_asset_tag', header: 'Asset' },
    { key: 'device_type', header: 'Device' },
    { key: 'test_date', header: 'Date' },
    { key: 'overall_verdict', header: 'Verdict' },
    { key: 'output_error_pct', header: 'Output Error %' },
    { key: 'patient_safety_cutoff_test', header: 'Cutoff' },
    { key: 'electrode_applicator_condition', header: 'Electrode / Applicator' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Physiotherapy &amp; Rehab Equipment (SWD/US/TENS/CPM) Output Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Physio equipment QA — SWD &times; ultrasound therapy &times; TENS &times; CPM &times; traction.
        Set intensity vs measured output, output error %, timer accuracy, electrode/applicator
        condition, patient-safety cutoff &amp; CAPA closure. Founder-gated view: verdicts, hospital
        scorecards, device-type matrix, root-cause pareto, and regulatory-impact digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Overall verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No audits logged yet."
          rowKey={(r, i) => String(r.overall_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device-type matrix</h2>
        <DataTable
          rows={deviceRows}
          columns={deviceCols}
          emptyMessage="No audits by device type."
          rowKey={(r, i) => String(r.device_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily audit trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.test_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk devices queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk devices."
          rowKey={(r, i) => `${r.device_asset_tag}-${r.test_date}-${i}`}
        />
      </section>
    </main>
  );
}
