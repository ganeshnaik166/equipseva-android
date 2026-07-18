import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { rollout_verdict: string; jobs: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_jobs: number;
  on_time: number;
  late: number;
  failed: number;
  overdue_or_deferred: number;
  backup_missed: number;
  avg_downtime_minutes: number;
  on_time_pct: number;
};
type MatrixRow = {
  device_family: string;
  criticality: string;
  jobs: number;
  completed: number;
  failed: number;
  avg_downtime_minutes: number;
};
type TrendRow = {
  scheduled_date: string;
  jobs: number;
  completed: number;
  failed: number;
  security_critical_jobs: number;
  backup_missed: number;
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
  device_family: string;
  device_code: string;
  advisory_ref: string;
  criticality: string;
  scheduled_date: string;
  rollout_verdict: string;
  post_update_verification: string | null;
  backup_taken: boolean;
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
    supabase.rpc('founder_r3244_rollout_verdict_rollup'),
    supabase.rpc('founder_r3244_engineer_scorecard'),
    supabase.rpc('founder_r3244_family_criticality_matrix'),
    supabase.rpc('founder_r3244_daily_rollout_trend'),
    supabase.rpc('founder_r3244_capa_status_board'),
    supabase.rpc('founder_r3244_root_cause_pareto'),
    supabase.rpc('founder_r3244_regulatory_impact_digest'),
    supabase.rpc('founder_r3244_high_risk_queue'),
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
    { key: 'rollout_verdict', header: 'Verdict' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_jobs', header: 'Jobs' },
    { key: 'on_time', header: 'On Time' },
    { key: 'late', header: 'Late' },
    { key: 'failed', header: 'Failed' },
    { key: 'overdue_or_deferred', header: 'Overdue / Deferred' },
    { key: 'backup_missed', header: 'Backup Missed' },
    { key: 'avg_downtime_minutes', header: 'Avg Downtime (min)' },
    { key: 'on_time_pct', header: 'On-Time %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_family', header: 'Device Family' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'completed', header: 'Completed' },
    { key: 'failed', header: 'Failed' },
    { key: 'avg_downtime_minutes', header: 'Avg Downtime (min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'scheduled_date', header: 'Scheduled Date' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'completed', header: 'Completed' },
    { key: 'failed', header: 'Failed' },
    { key: 'security_critical_jobs', header: 'Security-Critical' },
    { key: 'backup_missed', header: 'Backup Missed' },
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
    { key: 'device_family', header: 'Family' },
    { key: 'device_code', header: 'Device' },
    { key: 'advisory_ref', header: 'Advisory' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'scheduled_date', header: 'Scheduled' },
    { key: 'rollout_verdict', header: 'Verdict' },
    { key: 'post_update_verification', header: 'Verification' },
    { key: 'backup_taken', header: 'Backup' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Device Firmware &amp; Software Update Rollout Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer rollout discipline — device family &times; manufacturer advisory ref
        &times; version jump &times; criticality &times; backup taken &times; post-update
        verification &times; downtime minutes &times; rollout verdict &amp; CAPA closure.
        Founder-gated view: verdict rollups, engineer scorecards, family &times; criticality
        matrix, root-cause pareto, and regulatory-impact digest across CDSCO &amp;
        cybersecurity-advisory surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Rollout verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No rollout jobs logged yet."
          rowKey={(r, i) => String(r.rollout_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer rollout scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device family &times; criticality matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No jobs by family."
          rowKey={(r, i) => `${r.device_family}-${r.criticality}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily rollout trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk rollout queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk rollouts."
          rowKey={(r, i) => `${r.device_code}-${r.scheduled_date}-${i}`}
        />
      </section>
    </main>
  );
}
