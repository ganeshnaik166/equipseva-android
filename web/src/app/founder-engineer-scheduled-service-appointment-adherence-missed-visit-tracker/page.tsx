import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { adherence_verdict: string; visits: number; pct: number };
type EngineerRow = {
  engineer_name: string;
  region: string;
  total_visits: number;
  on_time: number;
  completed_late: number;
  rescheduled: number;
  missed: number;
  cancelled: number;
  breaches: number;
  on_time_pct: number;
};
type MatrixRow = {
  visit_type: string;
  actual_status: string;
  visits: number;
  avg_delay_minutes: number;
  breaches: number;
};
type TrendRow = {
  scheduled_date: string;
  visits: number;
  on_time: number;
  missed: number;
  rescheduled: number;
  breaches: number;
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
type RiskDigestRow = {
  risk_severity: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type QueueRow = {
  engineer_name: string;
  region: string;
  hospital_name: string;
  job_code: string;
  scheduled_date: string;
  visit_type: string;
  actual_status: string;
  sla_impact: string | null;
  adherence_verdict: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engineerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    riskRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3312_adherence_verdict_rollup'),
    supabase.rpc('founder_r3312_engineer_scorecard'),
    supabase.rpc('founder_r3312_visit_type_status_matrix'),
    supabase.rpc('founder_r3312_daily_adherence_trend'),
    supabase.rpc('founder_r3312_capa_status_board'),
    supabase.rpc('founder_r3312_root_cause_pareto'),
    supabase.rpc('founder_r3312_risk_severity_digest'),
    supabase.rpc('founder_r3312_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engineerRows: EngineerRow[] = (engineerRes.data as EngineerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const riskRows: RiskDigestRow[] = (riskRes.data as RiskDigestRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'adherence_verdict', header: 'Verdict' },
    { key: 'visits', header: 'Visits' },
    { key: 'pct', header: 'Share %' },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'total_visits', header: 'Visits' },
    { key: 'on_time', header: 'On Time' },
    { key: 'completed_late', header: 'Late' },
    { key: 'rescheduled', header: 'Rescheduled' },
    { key: 'missed', header: 'Missed' },
    { key: 'cancelled', header: 'Cancelled' },
    { key: 'breaches', header: 'SLA Breaches' },
    { key: 'on_time_pct', header: 'On-Time %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'visit_type', header: 'Visit Type' },
    { key: 'actual_status', header: 'Actual Status' },
    { key: 'visits', header: 'Visits' },
    { key: 'avg_delay_minutes', header: 'Avg Delay (min)' },
    { key: 'breaches', header: 'SLA Breaches' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'scheduled_date', header: 'Date' },
    { key: 'visits', header: 'Visits' },
    { key: 'on_time', header: 'On Time' },
    { key: 'missed', header: 'Missed' },
    { key: 'rescheduled', header: 'Rescheduled' },
    { key: 'breaches', header: 'SLA Breaches' },
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

  const riskCols: Column<RiskDigestRow>[] = [
    { key: 'risk_severity', header: 'Risk Severity' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'job_code', header: 'Job' },
    { key: 'scheduled_date', header: 'Date' },
    { key: 'visit_type', header: 'Visit Type' },
    { key: 'actual_status', header: 'Status' },
    { key: 'sla_impact', header: 'SLA Impact' },
    { key: 'adherence_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Scheduled-Service Appointment Adherence &amp; Missed-Visit Recovery Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer appointment log — visit type &times; scheduled window &times; actual status
        &times; delay minutes &times; reschedule count &times; advance-notice &amp; customer-informed
        flags &times; SLA impact &times; adherence verdict &amp; recovery/coaching CAPA closure.
        Founder-gated view: adherence verdicts, engineer scorecards, root-cause pareto, and
        risk-severity cost digest across missed and chronically-slipping visits.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Adherence verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No scheduled visits logged yet."
          rowKey={(r, i) => String(r.adherence_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer adherence scorecard</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => `${r.engineer_name}-${r.region}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Visit type &times; actual status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No visits by type."
          rowKey={(r, i) => `${r.visit_type}-${r.actual_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily adherence trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.scheduled_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Risk-severity cost digest</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No risk-severity rollups."
          rowKey={(r, i) => String(r.risk_severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk visit queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk visits."
          rowKey={(r, i) => `${r.job_code}-${r.scheduled_date}-${i}`}
        />
      </section>
    </main>
  );
}
