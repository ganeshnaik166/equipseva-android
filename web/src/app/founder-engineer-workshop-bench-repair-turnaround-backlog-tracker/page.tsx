import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { job_verdict: string; jobs: number; pct: number };
type WorkshopRow = {
  workshop_city: string;
  total_jobs: number;
  closed_on_time: number;
  closed_late: number;
  in_progress: number;
  stalled: number;
  avg_promised_tat_days: number;
  avg_actual_tat_days: number;
  on_time_close_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  delay_reason: string;
  jobs: number;
  avg_actual_tat_days: number;
  total_rework: number;
};
type TrendRow = {
  intake_date: string;
  jobs: number;
  closed: number;
  stalled_jobs: number;
  avg_promised_tat_days: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
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
  customer_impact: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type RiskRow = {
  workshop_city: string;
  bench_engineer_name: string;
  job_code: string;
  equipment_type: string;
  intake_date: string;
  promised_tat_days: number;
  actual_tat_days: number | null;
  delay_reason: string;
  bench_test_result: string;
  job_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    workshopRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3260_job_verdict_rollup'),
    supabase.rpc('founder_r3260_workshop_scorecard'),
    supabase.rpc('founder_r3260_equipment_delay_matrix'),
    supabase.rpc('founder_r3260_daily_intake_trend'),
    supabase.rpc('founder_r3260_capa_status_board'),
    supabase.rpc('founder_r3260_root_cause_pareto'),
    supabase.rpc('founder_r3260_customer_impact_digest'),
    supabase.rpc('founder_r3260_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const workshopRows: WorkshopRow[] = (workshopRes.data as WorkshopRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'job_verdict', header: 'Job Verdict' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'pct', header: 'Share %' },
  ];

  const workshopCols: Column<WorkshopRow>[] = [
    { key: 'workshop_city', header: 'Workshop' },
    { key: 'total_jobs', header: 'Jobs' },
    { key: 'closed_on_time', header: 'On-Time' },
    { key: 'closed_late', header: 'Late' },
    { key: 'in_progress', header: 'In Progress' },
    { key: 'stalled', header: 'Stalled' },
    { key: 'avg_promised_tat_days', header: 'Avg Promised TAT (d)' },
    { key: 'avg_actual_tat_days', header: 'Avg Actual TAT (d)' },
    { key: 'on_time_close_pct', header: 'On-Time Close %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'delay_reason', header: 'Delay Reason' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'avg_actual_tat_days', header: 'Avg Actual TAT (d)' },
    { key: 'total_rework', header: 'Total Rework' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'intake_date', header: 'Intake Date' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'closed', header: 'Closed' },
    { key: 'stalled_jobs', header: 'Stalled' },
    { key: 'avg_promised_tat_days', header: 'Avg Promised TAT (d)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
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
    { key: 'customer_impact', header: 'Customer Impact' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'workshop_city', header: 'Workshop' },
    { key: 'bench_engineer_name', header: 'Engineer' },
    { key: 'job_code', header: 'Job' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'intake_date', header: 'Intake' },
    { key: 'promised_tat_days', header: 'Promised TAT (d)' },
    { key: 'actual_tat_days', header: 'Actual TAT (d)' },
    { key: 'delay_reason', header: 'Delay Reason' },
    { key: 'bench_test_result', header: 'Bench Test' },
    { key: 'job_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Workshop Bench-Repair Turnaround &amp; Backlog Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Regional workshop bench log — workshop city &times; bench engineer &times; equipment type
        &times; intake / diagnosis / parts / completion dates &times; promised vs actual TAT days
        &times; delay reason &times; bench-test result &times; rework count &amp; CAPA expedite
        actions. Founder-gated view: job verdicts, workshop scorecards, delay-reason matrix,
        root-cause pareto, and the aged high-risk backlog queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Job verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No bench-repair jobs logged yet."
          rowKey={(r, i) => String(r.job_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Workshop TAT scorecard</h2>
        <DataTable
          rows={workshopRows}
          columns={workshopCols}
          emptyMessage="No workshop rollups."
          rowKey={(r, i) => String(r.workshop_city ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment type &times; delay reason matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No jobs by equipment type."
          rowKey={(r, i) => `${r.equipment_type}-${r.delay_reason}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily intake trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.intake_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Customer impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No customer-impact rollups."
          rowKey={(r, i) => String(r.customer_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk backlog queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk jobs."
          rowKey={(r, i) => `${r.job_code}-${r.intake_date}-${i}`}
        />
      </section>
    </main>
  );
}
