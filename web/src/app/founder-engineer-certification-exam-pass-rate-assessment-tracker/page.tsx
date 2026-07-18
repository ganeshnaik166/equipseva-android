import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { proctor_verdict: string; exams: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_exams: number;
  passed_exams: number;
  failed_exams: number;
  malpractice_flags: number;
  no_shows: number;
  avg_score_pct: number;
  pass_pct: number;
};
type MatrixRow = {
  exam_type: string;
  skill_domain: string;
  exams: number;
  passed_exams: number;
  avg_score_pct: number;
};
type TrendRow = {
  exam_date: string;
  exams: number;
  passed_exams: number;
  failed_exams: number;
  avg_score_pct: number;
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
  engineer_name: string;
  exam_ref: string;
  exam_date: string;
  exam_type: string;
  attempt_number: number;
  score_pct: number;
  proctor_verdict: string;
  retake_due_date: string | null;
  weak_areas: string | null;
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
    supabase.rpc('founder_r3208_verdict_rollup'),
    supabase.rpc('founder_r3208_hospital_scorecard'),
    supabase.rpc('founder_r3208_exam_type_matrix'),
    supabase.rpc('founder_r3208_daily_trend'),
    supabase.rpc('founder_r3208_capa_status_board'),
    supabase.rpc('founder_r3208_root_cause_pareto'),
    supabase.rpc('founder_r3208_regulatory_impact_digest'),
    supabase.rpc('founder_r3208_high_risk_queue'),
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
    { key: 'proctor_verdict', header: 'Proctor Verdict' },
    { key: 'exams', header: 'Exams' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_exams', header: 'Exams' },
    { key: 'passed_exams', header: 'Passed' },
    { key: 'failed_exams', header: 'Failed' },
    { key: 'malpractice_flags', header: 'Malpractice' },
    { key: 'no_shows', header: 'No-Shows' },
    { key: 'avg_score_pct', header: 'Avg Score %' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'exam_type', header: 'Exam Type' },
    { key: 'skill_domain', header: 'Skill Domain' },
    { key: 'exams', header: 'Exams' },
    { key: 'passed_exams', header: 'Passed' },
    { key: 'avg_score_pct', header: 'Avg Score %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'exam_date', header: 'Date' },
    { key: 'exams', header: 'Exams' },
    { key: 'passed_exams', header: 'Passed' },
    { key: 'failed_exams', header: 'Failed' },
    { key: 'avg_score_pct', header: 'Avg Score %' },
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
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'exam_ref', header: 'Exam Ref' },
    { key: 'exam_date', header: 'Date' },
    { key: 'exam_type', header: 'Type' },
    { key: 'attempt_number', header: 'Attempt' },
    { key: 'score_pct', header: 'Score %' },
    { key: 'proctor_verdict', header: 'Verdict' },
    { key: 'retake_due_date', header: 'Retake Due' },
    { key: 'weak_areas', header: 'Weak Areas' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Certification-Exam Pass-Rate &amp; Skill-Assessment Outcome Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Certification-exam log &mdash; exam type &times; skill domain &times; attempt &times; score &times;
        proctor verdict &times; retake pipeline &amp; CAPA closure. Founder-gated view: verdict rollups,
        hospital pass-rate scorecards, root-cause pareto, and regulatory-impact digest across
        AERB &amp; OEM-authorization surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Proctor verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No exams logged yet."
          rowKey={(r, i) => String(r.proctor_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital pass-rate scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Exam type &times; skill domain matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No exams by type."
          rowKey={(r, i) => `${r.exam_type}-${r.skill_domain}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily exam-outcome trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.exam_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk engineers queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk exam attempts."
          rowKey={(r, i) => `${r.exam_ref}-${r.exam_date}-${i}`}
        />
      </section>
    </main>
  );
}
