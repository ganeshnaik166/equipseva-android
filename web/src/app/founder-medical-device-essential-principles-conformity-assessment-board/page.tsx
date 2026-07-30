import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { conformity_status: string; assessments: number; pct: number };
type ClassRow = {
  device_class: string;
  total_assessments: number;
  conformant: number;
  minor_gap: number;
  major_or_non: number;
  total_gaps: number;
  avg_conformity_pct: number;
  avg_evidence_pct: number;
  conformant_pct: number;
};
type MatrixRow = {
  principle_area: string;
  conformity_status: string;
  assessments: number;
  total_gaps: number;
  avg_conformity_pct: number;
};
type TrendRow = {
  period_month: string;
  assessments: number;
  conformant: number;
  major_or_non: number;
  avg_conformity_pct: number;
  avg_evidence_pct: number;
};
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type RegRow = { regulatory_impact: string; findings: number; open_findings: number; total_cost_rupees: number };
type RiskRow = {
  device_code: string;
  device_name: string;
  device_class: string;
  principle_area: string;
  period_month: string;
  conformity_status: string;
  principles_gap: number;
  conformity_pct: number;
  evidence_attached_pct: number;
  reassessment_due: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    classRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3643_conformity_status_rollup'),
    supabase.rpc('founder_r3643_device_class_scorecard'),
    supabase.rpc('founder_r3643_principle_area_status_matrix'),
    supabase.rpc('founder_r3643_monthly_conformity_trend'),
    supabase.rpc('founder_r3643_capa_status_board'),
    supabase.rpc('founder_r3643_root_cause_pareto'),
    supabase.rpc('founder_r3643_gap_impact_digest'),
    supabase.rpc('founder_r3643_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const classRows: ClassRow[] = (classRes.data as ClassRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'conformity_status', header: 'Conformity Status' },
    { key: 'assessments', header: 'Assessments' },
    { key: 'pct', header: 'Share %' },
  ];

  const classCols: Column<ClassRow>[] = [
    { key: 'device_class', header: 'Device Class' },
    { key: 'total_assessments', header: 'Assessments' },
    { key: 'conformant', header: 'Conformant' },
    { key: 'minor_gap', header: 'Minor Gap' },
    { key: 'major_or_non', header: 'Major / Non' },
    { key: 'total_gaps', header: 'Total Gaps' },
    { key: 'avg_conformity_pct', header: 'Avg Conformity %' },
    { key: 'avg_evidence_pct', header: 'Avg Evidence %' },
    { key: 'conformant_pct', header: 'Conformant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'principle_area', header: 'Principle Area' },
    { key: 'conformity_status', header: 'Conformity Status' },
    { key: 'assessments', header: 'Assessments' },
    { key: 'total_gaps', header: 'Total Gaps' },
    { key: 'avg_conformity_pct', header: 'Avg Conformity %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'assessments', header: 'Assessments' },
    { key: 'conformant', header: 'Conformant' },
    { key: 'major_or_non', header: 'Major / Non' },
    { key: 'avg_conformity_pct', header: 'Avg Conformity %' },
    { key: 'avg_evidence_pct', header: 'Avg Evidence %' },
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
    { key: 'device_code', header: 'Device Code' },
    { key: 'device_name', header: 'Device' },
    { key: 'device_class', header: 'Class' },
    { key: 'principle_area', header: 'Principle Area' },
    { key: 'period_month', header: 'Month' },
    { key: 'conformity_status', header: 'Status' },
    { key: 'principles_gap', header: 'Gaps' },
    { key: 'conformity_pct', header: 'Conformity %' },
    { key: 'evidence_attached_pct', header: 'Evidence %' },
    { key: 'reassessment_due', header: 'Reassess Due' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Essential-Principles Conformity-Assessment Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        MDR-2017 essential-principles conformity assessment &mdash; principle area (safety &amp; performance, design
        &amp; manufacture, chemical/biological, sterility, labeling &amp; IFU) &times; device class &times; principles
        met vs gaps &times; conformity % &times; evidence attached &times; reassessment due &amp; CAPA closure.
        Founder-gated view: conformity distribution, device-class scorecards, gap-impact digest, and high-risk
        non-conformity queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Conformity-status distribution</h2>
        <DataTable rows={statusRows} columns={statusCols} emptyMessage="No assessments logged yet." rowKey={(r, i) => String(r.conformity_status ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-class scorecard</h2>
        <DataTable rows={classRows} columns={classCols} emptyMessage="No device-class rollups." rowKey={(r, i) => String(r.device_class ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Principle-area &times; conformity-status matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.principle_area}-${r.conformity_status}-${i}`} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly conformity trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.period_month ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No CAPA findings." rowKey={(r, i) => String(r.capa_status ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable rows={causeRows} columns={causeCols} emptyMessage="No root-cause data." rowKey={(r, i) => String(r.root_cause ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Gap-impact digest</h2>
        <DataTable rows={regRows} columns={regCols} emptyMessage="No regulatory-impact rollups." rowKey={(r, i) => String(r.regulatory_impact ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk non-conformity queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No high-risk assessments." rowKey={(r, i) => `${r.device_code}-${r.principle_area}-${i}`} />
      </section>
    </main>
  );
}
