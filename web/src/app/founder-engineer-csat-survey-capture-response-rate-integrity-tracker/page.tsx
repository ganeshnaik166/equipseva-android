import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { response_verdict: string; records: number; pct: number };
type ScoreRow = {
  engineer_name: string;
  jobs: number;
  surveys_sent: number;
  completed: number;
  response_rate_pct: number;
  avg_csat: number;
  detractors: number;
  gaming_flags: number;
  clean_pct: number;
};
type MatrixRow = { survey_channel: string; service_type: string; records: number; completed: number; response_rate_pct: number };
type TrendRow = { survey_date: string; records: number; completed: number; detractors: number; gaming_flags: number };
type CapaRow = { capa_status: string; findings: number; avg_cost_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_cost_rupees: number; pct: number };
type ImpactRow = { cx_impact: string; findings: number; open_findings: number; total_cost_rupees: number };
type RiskRow = {
  hospital_name: string;
  engineer_name: string;
  job_code: string;
  service_type: string;
  survey_channel: string;
  survey_date: string;
  csat_score: number | null;
  nps_category: string;
  response_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, impactRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3396_response_verdict_rollup'),
    supabase.rpc('founder_r3396_engineer_scorecard'),
    supabase.rpc('founder_r3396_channel_service_matrix'),
    supabase.rpc('founder_r3396_daily_response_trend'),
    supabase.rpc('founder_r3396_capa_status_board'),
    supabase.rpc('founder_r3396_root_cause_pareto'),
    supabase.rpc('founder_r3396_cx_impact_digest'),
    supabase.rpc('founder_r3396_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'response_verdict', header: 'Response Verdict' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];
  const scoreCols: Column<ScoreRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'surveys_sent', header: 'Sent' },
    { key: 'completed', header: 'Completed' },
    { key: 'response_rate_pct', header: 'Response %' },
    { key: 'avg_csat', header: 'Avg CSAT' },
    { key: 'detractors', header: 'Detractors' },
    { key: 'gaming_flags', header: 'Gaming Flags' },
    { key: 'clean_pct', header: 'Clean %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'survey_channel', header: 'Channel' },
    { key: 'service_type', header: 'Service Type' },
    { key: 'records', header: 'Records' },
    { key: 'completed', header: 'Completed' },
    { key: 'response_rate_pct', header: 'Response %' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'survey_date', header: 'Date' },
    { key: 'records', header: 'Records' },
    { key: 'completed', header: 'Completed' },
    { key: 'detractors', header: 'Detractors' },
    { key: 'gaming_flags', header: 'Gaming Flags' },
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
    { key: 'cx_impact', header: 'CX Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];
  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'job_code', header: 'Job' },
    { key: 'service_type', header: 'Service Type' },
    { key: 'survey_channel', header: 'Channel' },
    { key: 'survey_date', header: 'Date' },
    { key: 'csat_score', header: 'CSAT' },
    { key: 'nps_category', header: 'NPS' },
    { key: 'response_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        CSAT Survey-Capture &amp; Response-Rate Integrity Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Post-service survey ops &mdash; service type &times; channel &times; sent/completed &times; response rate
        &times; CSAT &times; NPS category &times; verbatim &times; gaming/bias integrity flags &amp; CAPA.
        Founder-gated view: response-verdict rollup, engineer scorecard, channel &times; service matrix, and
        integrity/detractor queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Response verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No surveys yet." rowKey={(r, i) => String(r.response_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer survey scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No engineer rollups." rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Channel &times; service-type matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.survey_channel}-${r.service_type}-${i}`} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily response trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.survey_date ?? i)} />
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. CX-impact digest</h2>
        <DataTable rows={impactRows} columns={impactCols} emptyMessage="No CX-impact rollups." rowKey={(r, i) => String(r.cx_impact ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Integrity / detractor queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No at-risk survey records." rowKey={(r, i) => `${r.job_code}-${i}`} />
      </section>
    </main>
  );
}
