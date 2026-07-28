import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type CoverageRow = { coverage_status: string; briefings: number; pct: number };
type TopicRow = {
  topic: string;
  briefings: number;
  full_coverage: number;
  partial_coverage: number;
  skipped: number;
  makeup_pending: number;
  avg_attendance_pct: number;
  ack_captured: number;
};
type MatrixRow = {
  topic: string;
  coverage_status: string;
  briefings: number;
  avg_attendance_pct: number;
  ack_captured: number;
};
type TrendRow = {
  month: string;
  briefings: number;
  total_attendees: number;
  total_team_size: number;
  avg_attendance_pct: number;
  skipped: number;
  makeup_pending: number;
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
type ImpactRow = {
  coverage_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  briefing_code: string;
  region: string;
  briefing_date: string;
  topic: string;
  coverage_status: string;
  attendees: number;
  team_size: number;
  attendance_pct: number | null;
  acknowledgment_captured: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    coverageRes,
    topicRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3560_coverage_status_rollup'),
    supabase.rpc('founder_r3560_topic_scorecard'),
    supabase.rpc('founder_r3560_topic_coverage_matrix'),
    supabase.rpc('founder_r3560_monthly_attendance_trend'),
    supabase.rpc('founder_r3560_capa_status_board'),
    supabase.rpc('founder_r3560_root_cause_pareto'),
    supabase.rpc('founder_r3560_coverage_gap_impact_digest'),
    supabase.rpc('founder_r3560_high_risk_queue'),
  ]);

  const coverageRows: CoverageRow[] = (coverageRes.data as CoverageRow[]) ?? [];
  const topicRows: TopicRow[] = (topicRes.data as TopicRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const coverageCols: Column<CoverageRow>[] = [
    { key: 'coverage_status', header: 'Coverage Status' },
    { key: 'briefings', header: 'Briefings' },
    { key: 'pct', header: 'Share %' },
  ];

  const topicCols: Column<TopicRow>[] = [
    { key: 'topic', header: 'Topic' },
    { key: 'briefings', header: 'Briefings' },
    { key: 'full_coverage', header: 'Full' },
    { key: 'partial_coverage', header: 'Partial' },
    { key: 'skipped', header: 'Skipped' },
    { key: 'makeup_pending', header: 'Makeup Pending' },
    { key: 'avg_attendance_pct', header: 'Avg Attendance %' },
    { key: 'ack_captured', header: 'Ack Captured' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'topic', header: 'Topic' },
    { key: 'coverage_status', header: 'Coverage Status' },
    { key: 'briefings', header: 'Briefings' },
    { key: 'avg_attendance_pct', header: 'Avg Attendance %' },
    { key: 'ack_captured', header: 'Ack Captured' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month', header: 'Month' },
    { key: 'briefings', header: 'Briefings' },
    { key: 'total_attendees', header: 'Attendees' },
    { key: 'total_team_size', header: 'Team Size' },
    { key: 'avg_attendance_pct', header: 'Avg Attendance %' },
    { key: 'skipped', header: 'Skipped' },
    { key: 'makeup_pending', header: 'Makeup Pending' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'coverage_impact', header: 'Coverage Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'briefing_code', header: 'Briefing' },
    { key: 'region', header: 'Region' },
    { key: 'briefing_date', header: 'Date' },
    { key: 'topic', header: 'Topic' },
    { key: 'coverage_status', header: 'Coverage' },
    { key: 'attendees', header: 'Attendees' },
    { key: 'team_size', header: 'Team Size' },
    { key: 'attendance_pct', header: 'Attendance %' },
    { key: 'acknowledgment_captured', header: 'Ack' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Toolbox-Talk / Safety-Briefing Attendance &amp; Coverage Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Daily pre-work toolbox-talk / safety-briefing attendance and topic-coverage log &mdash;
        engineer &times; region &times; safety topic (electrical safety, lifting &amp; handling, PPE,
        biohazard, working-at-height, tool safety, emergency response) &times; attendees vs team size
        &times; attendance % &times; coverage status &times; acknowledgment capture &amp; CAPA closure.
        Founder-gated view: coverage-status distribution, topic scorecards, root-cause pareto, and the
        high-risk queue of skipped, under-attended &amp; unacknowledged briefings.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Coverage-status distribution</h2>
        <DataTable
          rows={coverageRows}
          columns={coverageCols}
          emptyMessage="No briefings logged yet."
          rowKey={(r, i) => String(r.coverage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Topic scorecard</h2>
        <DataTable
          rows={topicRows}
          columns={topicCols}
          emptyMessage="No topic rollups."
          rowKey={(r, i) => String(r.topic ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Topic &times; coverage-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No briefings by topic."
          rowKey={(r, i) => `${r.topic}-${r.coverage_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly attendance trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Coverage-gap impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No coverage-gap rollups."
          rowKey={(r, i) => String(r.coverage_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk briefing queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk briefings."
          rowKey={(r, i) => `${r.briefing_code}-${r.briefing_date}-${i}`}
        />
      </section>
    </main>
  );
}
