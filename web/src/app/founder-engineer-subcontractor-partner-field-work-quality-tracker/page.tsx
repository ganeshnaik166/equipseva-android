import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { partner_verdict: string; jobs: number; pct: number };
type ScorecardRow = {
  partner_firm: string;
  total_jobs: number;
  sla_met_jobs: number;
  first_time_fix_jobs: number;
  rework_rejected: number;
  safety_violations: number;
  warranty_callbacks: number;
  invoice_disputes: number;
  avg_rating: number;
  quality_pct: number;
};
type MatrixRow = {
  partner_firm: string;
  equipment_type: string;
  jobs: number;
  sla_met_jobs: number;
  first_time_fix_jobs: number;
  avg_rating: number;
};
type TrendRow = {
  job_date: string;
  jobs: number;
  sla_met_jobs: number;
  first_time_fix_jobs: number;
  rework_rejected: number;
  safety_gaps: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  escalated_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RiskDigestRow = {
  risk_level: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type QueueRow = {
  partner_firm: string;
  partner_technician: string;
  region: string;
  job_code: string;
  job_date: string;
  partner_verdict: string;
  workmanship_grade: string;
  safety_compliance: string;
  customer_rating: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    scorecardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    riskRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3264_partner_verdict_rollup'),
    supabase.rpc('founder_r3264_partner_scorecard'),
    supabase.rpc('founder_r3264_firm_equipment_matrix'),
    supabase.rpc('founder_r3264_daily_quality_trend'),
    supabase.rpc('founder_r3264_capa_status_board'),
    supabase.rpc('founder_r3264_root_cause_pareto'),
    supabase.rpc('founder_r3264_risk_impact_digest'),
    supabase.rpc('founder_r3264_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const riskRows: RiskDigestRow[] = (riskRes.data as RiskDigestRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'partner_verdict', header: 'Partner Verdict' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'partner_firm', header: 'Partner Firm' },
    { key: 'total_jobs', header: 'Jobs' },
    { key: 'sla_met_jobs', header: 'SLA Met' },
    { key: 'first_time_fix_jobs', header: 'First-Time Fix' },
    { key: 'rework_rejected', header: 'Rework / Rejected' },
    { key: 'safety_violations', header: 'Safety Gaps' },
    { key: 'warranty_callbacks', header: 'Callbacks' },
    { key: 'invoice_disputes', header: 'Invoice Disputes' },
    { key: 'avg_rating', header: 'Avg Rating' },
    { key: 'quality_pct', header: 'Quality %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'partner_firm', header: 'Partner Firm' },
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'sla_met_jobs', header: 'SLA Met' },
    { key: 'first_time_fix_jobs', header: 'First-Time Fix' },
    { key: 'avg_rating', header: 'Avg Rating' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'job_date', header: 'Date' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'sla_met_jobs', header: 'SLA Met' },
    { key: 'first_time_fix_jobs', header: 'First-Time Fix' },
    { key: 'rework_rejected', header: 'Rework / Rejected' },
    { key: 'safety_gaps', header: 'Safety Gaps' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'escalated_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const riskCols: Column<RiskDigestRow>[] = [
    { key: 'risk_level', header: 'Risk Level' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'partner_firm', header: 'Partner Firm' },
    { key: 'partner_technician', header: 'Technician' },
    { key: 'region', header: 'Region' },
    { key: 'job_code', header: 'Job Code' },
    { key: 'job_date', header: 'Date' },
    { key: 'partner_verdict', header: 'Verdict' },
    { key: 'workmanship_grade', header: 'Workmanship' },
    { key: 'safety_compliance', header: 'Safety' },
    { key: 'customer_rating', header: 'Rating' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Subcontractor &amp; Channel-Partner Field-Work Quality Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Third-party partner-technician governance for cities without own engineers &mdash; partner
        firm &times; equipment type &times; SLA adherence &times; first-time-fix &times; workmanship
        grade &times; safety compliance &times; customer rating &times; warranty callbacks &amp;
        invoice disputes, rolled to a partner verdict of preferred &rarr; approved &rarr; on-watch
        &rarr; probation &rarr; blacklisted. Founder-gated view: verdict rollup, firm scorecards,
        root-cause pareto, and risk-impact digest with CAPA closure for on-watch &amp; probation
        partners.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Partner verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No partner jobs logged yet."
          rowKey={(r, i) => String(r.partner_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Partner-firm quality scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No partner-firm rollups."
          rowKey={(r, i) => String(r.partner_firm ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Partner firm &times; equipment matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No jobs by firm/equipment."
          rowKey={(r, i) => `${r.partner_firm}-${r.equipment_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily quality trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Risk-impact &amp; cost digest</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No risk-impact rollups."
          rowKey={(r, i) => String(r.risk_level ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk partner-job queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk partner jobs."
          rowKey={(r, i) => `${r.job_code}-${r.job_date}-${i}`}
        />
      </section>
    </main>
  );
}
