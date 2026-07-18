import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; scans: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_scans: number;
  passes: number;
  fails: number;
  recal_required: number;
  cert_lapsed: number;
  avg_cv_percent: number;
  avg_deviation_pct: number;
  pass_pct: number;
};
type ModelRow = {
  scanner_model: string;
  phantom_type: string;
  scans: number;
  passes: number;
  avg_cv_percent: number;
  avg_deviation_pct: number;
};
type TrendRow = {
  qc_date: string;
  scans: number;
  passes: number;
  fails: number;
  avg_cv_percent: number;
  avg_radiation_usv_hr: number;
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
  scanner_asset_tag: string;
  scanner_model: string;
  qc_date: string;
  qc_verdict: string;
  drift_trend_flag: string | null;
  laser_alignment_result: string | null;
  radiation_survey_verdict: string | null;
  operator_cert_current: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    modelRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3230_qc_verdict_rollup'),
    supabase.rpc('founder_r3230_hospital_scorecard'),
    supabase.rpc('founder_r3230_scanner_phantom_matrix'),
    supabase.rpc('founder_r3230_daily_qc_trend'),
    supabase.rpc('founder_r3230_capa_status_board'),
    supabase.rpc('founder_r3230_root_cause_pareto'),
    supabase.rpc('founder_r3230_regulatory_impact_digest'),
    supabase.rpc('founder_r3230_high_risk_scans'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const modelRows: ModelRow[] = (modelRes.data as ModelRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'scans', header: 'Scans' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_scans', header: 'Scans' },
    { key: 'passes', header: 'Pass' },
    { key: 'fails', header: 'Fail' },
    { key: 'recal_required', header: 'Recal Needed' },
    { key: 'cert_lapsed', header: 'Cert Lapsed' },
    { key: 'avg_cv_percent', header: 'Avg CV %' },
    { key: 'avg_deviation_pct', header: 'Avg BMD Dev %' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'scanner_model', header: 'Scanner Model' },
    { key: 'phantom_type', header: 'Phantom' },
    { key: 'scans', header: 'Scans' },
    { key: 'passes', header: 'Pass' },
    { key: 'avg_cv_percent', header: 'Avg CV %' },
    { key: 'avg_deviation_pct', header: 'Avg BMD Dev %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'qc_date', header: 'Date' },
    { key: 'scans', header: 'Scans' },
    { key: 'passes', header: 'Pass' },
    { key: 'fails', header: 'Fail / Recal' },
    { key: 'avg_cv_percent', header: 'Avg CV %' },
    { key: 'avg_radiation_usv_hr', header: 'Avg Survey uSv/hr' },
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
    { key: 'scanner_asset_tag', header: 'Asset' },
    { key: 'scanner_model', header: 'Model' },
    { key: 'qc_date', header: 'Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'drift_trend_flag', header: 'Drift' },
    { key: 'laser_alignment_result', header: 'Laser' },
    { key: 'radiation_survey_verdict', header: 'Survey' },
    { key: 'operator_cert_current', header: 'Cert OK' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Bone-Densitometer (DEXA) Calibration &amp; Phantom-Scan QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        DEXA QA log — scanner model &times; spine-phantom BMD vs reference &times; CV % &times;
        drift trend &times; laser alignment &times; table travel &times; radiation survey &amp; CAPA
        closure. Founder-gated view: QC verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across AERB &amp; NABH surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QC verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No QC scans logged yet."
          rowKey={(r, i) => String(r.qc_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital QC scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Scanner model &times; phantom matrix</h2>
        <DataTable
          rows={modelRows}
          columns={modelCols}
          emptyMessage="No scans by scanner model."
          rowKey={(r, i) => `${r.scanner_model}-${r.phantom_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily QC trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.qc_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk scan queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk scans."
          rowKey={(r, i) => `${r.scanner_asset_tag}-${r.qc_date}-${i}`}
        />
      </section>
    </main>
  );
}
