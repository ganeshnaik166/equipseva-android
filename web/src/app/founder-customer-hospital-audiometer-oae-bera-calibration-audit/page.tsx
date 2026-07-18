import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { calibration_verdict: string; devices: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_checks: number;
  fit_for_use: number;
  out_of_service: number;
  recal_required: number;
  booth_noncompliant: number;
  biologic_fail: number;
  cal_expired: number;
  compliance_pct: number;
};
type MatrixRow = {
  device_type: string;
  transducer_type: string;
  checks: number;
  fit_for_use: number;
  avg_deviation_db: number | null;
};
type TrendRow = {
  check_date: string;
  checks: number;
  fit_for_use: number;
  recal_required: number;
  out_of_service: number;
  booth_noncompliant: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
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
  audiology_room_code: string;
  device_asset_tag: string;
  device_type: string;
  check_date: string;
  calibration_verdict: string;
  frequency_accuracy_result: string;
  booth_noise_verdict: string | null;
  biologic_check_result: string;
  probe_tip_condition: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3214_calibration_verdict_rollup'),
    supabase.rpc('founder_r3214_hospital_scorecard'),
    supabase.rpc('founder_r3214_device_transducer_matrix'),
    supabase.rpc('founder_r3214_daily_check_trend'),
    supabase.rpc('founder_r3214_capa_status_board'),
    supabase.rpc('founder_r3214_root_cause_pareto'),
    supabase.rpc('founder_r3214_regulatory_impact_digest'),
    supabase.rpc('founder_r3214_high_risk_devices'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'calibration_verdict', header: 'Verdict' },
    { key: 'devices', header: 'Devices' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'fit_for_use', header: 'Fit For Use' },
    { key: 'out_of_service', header: 'Out Of Service' },
    { key: 'recal_required', header: 'Recal Required' },
    { key: 'booth_noncompliant', header: 'Booth NC' },
    { key: 'biologic_fail', header: 'Biologic Fail' },
    { key: 'cal_expired', header: 'Cal Expired' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_type', header: 'Device Type' },
    { key: 'transducer_type', header: 'Transducer' },
    { key: 'checks', header: 'Checks' },
    { key: 'fit_for_use', header: 'Fit For Use' },
    { key: 'avg_deviation_db', header: 'Avg Deviation dB' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'check_date', header: 'Date' },
    { key: 'checks', header: 'Checks' },
    { key: 'fit_for_use', header: 'Fit For Use' },
    { key: 'recal_required', header: 'Recal Required' },
    { key: 'out_of_service', header: 'Out Of Service' },
    { key: 'booth_noncompliant', header: 'Booth NC' },
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
    { key: 'audiology_room_code', header: 'Room' },
    { key: 'device_asset_tag', header: 'Asset' },
    { key: 'device_type', header: 'Device Type' },
    { key: 'check_date', header: 'Date' },
    { key: 'calibration_verdict', header: 'Verdict' },
    { key: 'frequency_accuracy_result', header: 'Freq Accuracy' },
    { key: 'booth_noise_verdict', header: 'Booth' },
    { key: 'biologic_check_result', header: 'Biologic' },
    { key: 'probe_tip_condition', header: 'Probe Tip' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Audiometer &amp; OAE/BERA Screening-Equipment Calibration Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Audiology QA log &mdash; device type &times; frequency dB accuracy &times; transducer &times;
        booth ambient noise &times; biologic check &times; probe-tip condition &amp; CAPA closure.
        Founder-gated view: calibration verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Calibration verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No calibration checks logged yet."
          rowKey={(r, i) => String(r.calibration_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device type &times; transducer matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by device type."
          rowKey={(r, i) => `${r.device_type}-${r.transducer_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily check trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.check_date ?? i)}
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
          rowKey={(r, i) => `${r.device_asset_tag}-${r.check_date}-${i}`}
        />
      </section>
    </main>
  );
}
