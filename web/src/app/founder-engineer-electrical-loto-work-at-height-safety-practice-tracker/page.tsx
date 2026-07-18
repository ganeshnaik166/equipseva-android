import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { practice_verdict: string; jobs: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_jobs: number;
  compliant: number;
  minor_gaps: number;
  major_violations: number;
  stop_work: number;
  loto_gaps: number;
  permit_missing: number;
  total_violations: number;
  compliance_pct: number;
};
type MatrixRow = {
  hazard_type: string;
  loto_applied: string;
  jobs: number;
  verified_deenergized: number;
  avg_violations: number;
};
type TrendRow = {
  job_date: string;
  jobs: number;
  compliant: number;
  major_violations: number;
  stop_work: number;
  total_violations: number;
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
  engineer_name: string;
  hospital_name: string;
  job_code: string;
  job_date: string;
  hazard_type: string;
  loto_applied: string;
  ladder_or_scaffold_condition: string | null;
  harness_used: string | null;
  violation_count: number;
  practice_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3252_practice_verdict_rollup'),
    supabase.rpc('founder_r3252_engineer_scorecard'),
    supabase.rpc('founder_r3252_hazard_loto_matrix'),
    supabase.rpc('founder_r3252_daily_practice_trend'),
    supabase.rpc('founder_r3252_capa_status_board'),
    supabase.rpc('founder_r3252_root_cause_pareto'),
    supabase.rpc('founder_r3252_regulatory_impact_digest'),
    supabase.rpc('founder_r3252_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'practice_verdict', header: 'Verdict' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_jobs', header: 'Jobs' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'minor_gaps', header: 'Minor Gaps' },
    { key: 'major_violations', header: 'Major Violations' },
    { key: 'stop_work', header: 'Stop-Work' },
    { key: 'loto_gaps', header: 'LOTO Gaps' },
    { key: 'permit_missing', header: 'Permit Missing' },
    { key: 'total_violations', header: 'Total Violations' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'hazard_type', header: 'Hazard Type' },
    { key: 'loto_applied', header: 'LOTO Applied' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'verified_deenergized', header: 'Verified De-Energized' },
    { key: 'avg_violations', header: 'Avg Violations' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'job_date', header: 'Date' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'major_violations', header: 'Major Violations' },
    { key: 'stop_work', header: 'Stop-Work' },
    { key: 'total_violations', header: 'Total Violations' },
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
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'job_code', header: 'Job' },
    { key: 'job_date', header: 'Date' },
    { key: 'hazard_type', header: 'Hazard' },
    { key: 'loto_applied', header: 'LOTO' },
    { key: 'ladder_or_scaffold_condition', header: 'Access Equipment' },
    { key: 'harness_used', header: 'Harness' },
    { key: 'violation_count', header: 'Violations' },
    { key: 'practice_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Electrical LOTO &amp; Work-at-Height Safety-Practice Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-safety practice log — hazard type &times; lockout-tagout applied &times; de-energized
        verification test &times; work-at-height &times; ladder/scaffold condition &times; harness
        &times; permit-to-work &times; second person &amp; CAPA closure. Founder-gated view:
        practice verdicts, engineer scorecards, root-cause pareto, and regulatory-impact digest
        across Factories Act &amp; Electricity Rules surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Practice verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No safety-practice audits logged yet."
          rowKey={(r, i) => String(r.practice_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer safety scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Hazard type &times; LOTO applied matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No jobs by hazard."
          rowKey={(r, i) => `${r.hazard_type}-${r.loto_applied}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily practice trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.job_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk practice queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk jobs."
          rowKey={(r, i) => `${r.job_code}-${r.job_date}-${i}`}
        />
      </section>
    </main>
  );
}
