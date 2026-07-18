import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; machines: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  fit_for_use: number;
  restricted: number;
  out_of_service: number;
  cal_fail: number;
  severe_noise: number;
  avg_speed_error_pct: number;
  fit_pct: number;
};
type MatrixRow = {
  signal_noise_level: string;
  ac_filter_setting: string;
  machines: number;
  fit_for_use: number;
  avg_noise_microvolts: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  fit_for_use: number;
  cal_fail: number;
  severe_noise: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
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
  department_code: string;
  ecg_asset_tag: string;
  machine_model: string;
  audit_date: string;
  audit_verdict: string;
  calibration_pulse_result: string | null;
  signal_noise_level: string | null;
  cable_condition: string | null;
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
    supabase.rpc('founder_r3218_verdict_rollup'),
    supabase.rpc('founder_r3218_hospital_scorecard'),
    supabase.rpc('founder_r3218_noise_filter_matrix'),
    supabase.rpc('founder_r3218_daily_audit_trend'),
    supabase.rpc('founder_r3218_capa_status_board'),
    supabase.rpc('founder_r3218_root_cause_pareto'),
    supabase.rpc('founder_r3218_regulatory_impact_digest'),
    supabase.rpc('founder_r3218_high_risk_machines'),
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
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'machines', header: 'Machines' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'restricted', header: 'Restricted' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'cal_fail', header: 'Cal Fail' },
    { key: 'severe_noise', header: 'Severe Noise' },
    { key: 'avg_speed_error_pct', header: 'Avg Speed Err %' },
    { key: 'fit_pct', header: 'Fit %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'signal_noise_level', header: 'Noise Level' },
    { key: 'ac_filter_setting', header: 'AC Filter' },
    { key: 'machines', header: 'Machines' },
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'avg_noise_microvolts', header: 'Avg Noise (µV)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'cal_fail', header: 'Cal Fail' },
    { key: 'severe_noise', header: 'Severe Noise' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
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
    { key: 'department_code', header: 'Dept' },
    { key: 'ecg_asset_tag', header: 'Asset' },
    { key: 'machine_model', header: 'Model' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'calibration_pulse_result', header: 'Cal Pulse' },
    { key: 'signal_noise_level', header: 'Noise' },
    { key: 'cable_condition', header: 'Cable' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital ECG-Machine 12-Lead Signal-Quality &amp; Filter Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        ECG QA log — machine model &times; lead-off detection &times; 1mV calibration pulse &times;
        paper speed 25/50mm &times; filter settings (AC/muscle/drift) &times; signal noise &times;
        interpretation module &times; cable condition &amp; CAPA closure. Founder-gated view: audit verdicts,
        hospital scorecards, root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No ECG audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital QA scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Signal noise &times; AC filter matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No noise-filter data."
          rowKey={(r, i) => `${r.signal_noise_level}-${r.ac_filter_setting}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily audit trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk machines queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk machines."
          rowKey={(r, i) => `${r.ecg_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
