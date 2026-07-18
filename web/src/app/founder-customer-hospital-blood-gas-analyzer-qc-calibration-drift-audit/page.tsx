import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { qc_verdict: string; runs: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_runs: number;
  accepted: number;
  rejected: number;
  recalibrated: number;
  sensor_replaced: number;
  westgard_rejects: number;
  avg_bias_pct: number;
  acceptance_pct: number;
};
type MatrixRow = {
  analyte: string;
  qc_level: string;
  runs: number;
  rejected: number;
  avg_bias_pct: number;
  avg_drift_pct: number;
};
type TrendRow = {
  qc_date: string;
  runs: number;
  accepted: number;
  warnings: number;
  rejected: number;
  avg_bias_pct: number;
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
  lab_section_code: string;
  analyzer_asset_tag: string;
  qc_date: string;
  analyte: string;
  qc_level: string;
  bias_pct: number | null;
  cal_drift_pct: number | null;
  westgard_rule: string;
  qc_verdict: string;
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
    supabase.rpc('founder_r3170_qc_verdict_rollup'),
    supabase.rpc('founder_r3170_hospital_scorecard'),
    supabase.rpc('founder_r3170_analyte_level_matrix'),
    supabase.rpc('founder_r3170_qc_daily_trend'),
    supabase.rpc('founder_r3170_capa_status_board'),
    supabase.rpc('founder_r3170_root_cause_pareto'),
    supabase.rpc('founder_r3170_regulatory_impact_digest'),
    supabase.rpc('founder_r3170_high_risk_runs'),
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
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'runs', header: 'Runs' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_runs', header: 'Runs' },
    { key: 'accepted', header: 'Accepted' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'recalibrated', header: 'Recalibrated' },
    { key: 'sensor_replaced', header: 'Sensor Swap' },
    { key: 'westgard_rejects', header: 'Westgard Rejects' },
    { key: 'avg_bias_pct', header: 'Avg Bias %' },
    { key: 'acceptance_pct', header: 'Acceptance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'analyte', header: 'Analyte' },
    { key: 'qc_level', header: 'QC Level' },
    { key: 'runs', header: 'Runs' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'avg_bias_pct', header: 'Avg Bias %' },
    { key: 'avg_drift_pct', header: 'Avg Drift %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'qc_date', header: 'Date' },
    { key: 'runs', header: 'Runs' },
    { key: 'accepted', header: 'Accepted' },
    { key: 'warnings', header: 'Warnings' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'avg_bias_pct', header: 'Avg Bias %' },
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
    { key: 'lab_section_code', header: 'Section' },
    { key: 'analyzer_asset_tag', header: 'Asset' },
    { key: 'qc_date', header: 'Date' },
    { key: 'analyte', header: 'Analyte' },
    { key: 'qc_level', header: 'Level' },
    { key: 'bias_pct', header: 'Bias %' },
    { key: 'cal_drift_pct', header: 'Drift %' },
    { key: 'westgard_rule', header: 'Westgard' },
    { key: 'qc_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Blood-Gas Analyzer QC &amp; Calibration-Drift Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        ABG analyzer quality-control log — analyte &times; QC level &times; target/measured/bias &times;
        Westgard rule &times; calibration-drift &times; sensor age &amp; CAPA closure. Founder-gated view:
        verdict rollups, hospital scorecards, root-cause pareto, and regulatory-impact digest across NABL,
        NABH &amp; ISO 15189 surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Analyte &times; QC level matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No runs by analyte."
          rowKey={(r, i) => `${r.analyte}-${r.qc_level}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk QC runs queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk runs."
          rowKey={(r, i) => `${r.analyzer_asset_tag}-${r.qc_date}-${i}`}
        />
      </section>
    </main>
  );
}
