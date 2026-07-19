import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { loop_verdict: string; cases: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_cases: number;
  promoters: number;
  passives: number;
  detractors: number;
  recovered: number;
  churn_risk: number;
  followup_48h: number;
  recovery_pct: number;
};
type MatrixRow = {
  feedback_channel: string;
  sentiment: string;
  cases: number;
  avg_score: number;
  avg_rerated_score: number | null;
  recovered: number;
};
type TrendRow = {
  feedback_date: string;
  cases: number;
  detractors: number;
  recovered: number;
  churn_risk: number;
  followup_48h: number;
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
type ChurnRow = {
  churn_risk_tier: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  engineer_name: string;
  region: string;
  job_code: string;
  feedback_date: string;
  score_type: string;
  score: number;
  primary_gripe: string;
  recovered_status: string;
  loop_verdict: string;
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
    churnRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3324_loop_verdict_rollup'),
    supabase.rpc('founder_r3324_engineer_scorecard'),
    supabase.rpc('founder_r3324_channel_sentiment_matrix'),
    supabase.rpc('founder_r3324_daily_feedback_trend'),
    supabase.rpc('founder_r3324_capa_status_board'),
    supabase.rpc('founder_r3324_root_cause_pareto'),
    supabase.rpc('founder_r3324_churn_risk_digest'),
    supabase.rpc('founder_r3324_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const churnRows: ChurnRow[] = (churnRes.data as ChurnRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'loop_verdict', header: 'Loop Verdict' },
    { key: 'cases', header: 'Cases' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_cases', header: 'Cases' },
    { key: 'promoters', header: 'Promoters' },
    { key: 'passives', header: 'Passives' },
    { key: 'detractors', header: 'Detractors' },
    { key: 'recovered', header: 'Recovered' },
    { key: 'churn_risk', header: 'Churn Risk' },
    { key: 'followup_48h', header: '48h Follow-up' },
    { key: 'recovery_pct', header: 'Recovery %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'feedback_channel', header: 'Channel' },
    { key: 'sentiment', header: 'Sentiment' },
    { key: 'cases', header: 'Cases' },
    { key: 'avg_score', header: 'Avg Score' },
    { key: 'avg_rerated_score', header: 'Avg Re-rated' },
    { key: 'recovered', header: 'Recovered' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'feedback_date', header: 'Date' },
    { key: 'cases', header: 'Cases' },
    { key: 'detractors', header: 'Detractors' },
    { key: 'recovered', header: 'Recovered' },
    { key: 'churn_risk', header: 'Churn Risk' },
    { key: 'followup_48h', header: '48h Follow-up' },
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

  const churnCols: Column<ChurnRow>[] = [
    { key: 'churn_risk_tier', header: 'Churn-Risk Tier' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'job_code', header: 'Job' },
    { key: 'feedback_date', header: 'Date' },
    { key: 'score_type', header: 'Score Type' },
    { key: 'score', header: 'Score' },
    { key: 'primary_gripe', header: 'Primary Gripe' },
    { key: 'recovered_status', header: 'Recovery' },
    { key: 'loop_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer NPS/CSAT Closed-Loop Detractor-Recovery Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        CX closed-loop log — feedback channel &times; score type (NPS / CSAT) &times; sentiment
        &times; primary gripe &times; 48h follow-up &times; root-cause &times; recovery action
        &times; re-rated score &times; loop verdict &amp; systemic CAPA. Founder-gated view:
        loop-verdict rollup, engineer recovery scorecards, root-cause pareto, and churn-risk
        digest across detractor cases &amp; recurring-gripe fixes.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Loop verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No feedback cases logged yet."
          rowKey={(r, i) => String(r.loop_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer recovery scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Channel &times; sentiment matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cases by channel."
          rowKey={(r, i) => `${r.feedback_channel}-${r.sentiment}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily feedback trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.feedback_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Churn-risk digest</h2>
        <DataTable
          rows={churnRows}
          columns={churnCols}
          emptyMessage="No churn-risk rollups."
          rowKey={(r, i) => String(r.churn_risk_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk recovery queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cases."
          rowKey={(r, i) => `${r.job_code}-${r.feedback_date}-${i}`}
        />
      </section>
    </main>
  );
}
