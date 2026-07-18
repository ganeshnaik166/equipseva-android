import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; qc_runs: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_qc_runs: number;
  cleared: number;
  suspended: number;
  uniformity_flags: number;
  collimator_damaged: number;
  wipe_contaminated: number;
  aerb_lapsed: number;
  clearance_pct: number;
};
type MatrixRow = {
  camera_model: string;
  collimator_type: string;
  qc_runs: number;
  cleared: number;
  avg_intrinsic_uniformity_pct: number;
};
type TrendRow = {
  qc_date: string;
  qc_runs: number;
  uniformity_pass: number;
  uniformity_flags: number;
  cor_flags: number;
  energy_flags: number;
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
  camera_asset_tag: string;
  camera_model: string;
  qc_date: string;
  qc_verdict: string;
  uniformity_verdict: string | null;
  collimator_integrity: string | null;
  wipe_test_result: string | null;
  aerb_record_current: boolean | null;
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
    supabase.rpc('founder_r3226_qc_verdict_rollup'),
    supabase.rpc('founder_r3226_hospital_scorecard'),
    supabase.rpc('founder_r3226_camera_collimator_matrix'),
    supabase.rpc('founder_r3226_qc_daily_trend'),
    supabase.rpc('founder_r3226_capa_status_board'),
    supabase.rpc('founder_r3226_root_cause_pareto'),
    supabase.rpc('founder_r3226_regulatory_impact_digest'),
    supabase.rpc('founder_r3226_high_risk_cameras'),
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
    { key: 'qc_verdict', header: 'QC Verdict' },
    { key: 'qc_runs', header: 'QC Runs' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_qc_runs', header: 'QC Runs' },
    { key: 'cleared', header: 'Cleared' },
    { key: 'suspended', header: 'Suspended' },
    { key: 'uniformity_flags', header: 'Uniformity Flags' },
    { key: 'collimator_damaged', header: 'Collimator Damage' },
    { key: 'wipe_contaminated', header: 'Wipe Contam.' },
    { key: 'aerb_lapsed', header: 'AERB Lapsed' },
    { key: 'clearance_pct', header: 'Clearance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'camera_model', header: 'Camera Model' },
    { key: 'collimator_type', header: 'Collimator' },
    { key: 'qc_runs', header: 'QC Runs' },
    { key: 'cleared', header: 'Cleared' },
    { key: 'avg_intrinsic_uniformity_pct', header: 'Avg Intrinsic Unif. %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'qc_date', header: 'Date' },
    { key: 'qc_runs', header: 'QC Runs' },
    { key: 'uniformity_pass', header: 'Unif. Pass' },
    { key: 'uniformity_flags', header: 'Unif. Flags' },
    { key: 'cor_flags', header: 'COR Flags' },
    { key: 'energy_flags', header: 'Energy Flags' },
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
    { key: 'camera_asset_tag', header: 'Asset' },
    { key: 'camera_model', header: 'Model' },
    { key: 'qc_date', header: 'Date' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'uniformity_verdict', header: 'Uniformity' },
    { key: 'collimator_integrity', header: 'Collimator' },
    { key: 'wipe_test_result', header: 'Wipe Test' },
    { key: 'aerb_record_current', header: 'AERB Current' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Gamma-Camera / SPECT Uniformity &amp; Collimator QC Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Nuclear-medicine QA log — intrinsic/extrinsic uniformity × collimator integrity ×
        energy-peak offset × COR error × dose-calibrator constancy × wipe test &amp; AERB
        record currency with CAPA closure. Founder-gated view: QC verdicts, hospital scorecards,
        root-cause pareto, and regulatory-impact digest across AERB &amp; NABH surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. QC verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No QC runs logged yet."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Camera model × collimator matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No camera/collimator rollups."
          rowKey={(r, i) => `${r.camera_model}-${r.collimator_type}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk cameras queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cameras."
          rowKey={(r, i) => `${r.camera_asset_tag}-${r.qc_date}-${i}`}
        />
      </section>
    </main>
  );
}
