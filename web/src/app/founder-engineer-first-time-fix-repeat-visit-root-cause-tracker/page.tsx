import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { job_verdict: string; jobs: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_jobs: number;
  fixed_first: number;
  repeat_jobs: number;
  escalated: number;
  ftf_pct: number;
  avg_resolution_days: number;
};
type CategoryRow = {
  equipment_category: string;
  complaint_type: string;
  jobs: number;
  fixed_first: number;
  ftf_pct: number;
  avg_labor_hours: number;
};
type TrendRow = {
  first_visit_date: string;
  jobs: number;
  fixed_first: number;
  repeat_jobs: number;
  escalated: number;
  avg_visits: number;
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
type QueueRow = {
  hospital_name: string;
  engineer_name: string;
  equipment_category: string;
  job_code: string;
  first_visit_date: string;
  job_outcome: string;
  repeat_reason: string | null;
  visits_count: number;
  job_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    categoryRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3172_verdict_rollup'),
    supabase.rpc('founder_r3172_hospital_scorecard'),
    supabase.rpc('founder_r3172_category_matrix'),
    supabase.rpc('founder_r3172_daily_trend'),
    supabase.rpc('founder_r3172_capa_status_board'),
    supabase.rpc('founder_r3172_root_cause_pareto'),
    supabase.rpc('founder_r3172_regulatory_impact_digest'),
    supabase.rpc('founder_r3172_priority_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'job_verdict', header: 'Verdict' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_jobs', header: 'Jobs' },
    { key: 'fixed_first', header: 'Fixed First' },
    { key: 'repeat_jobs', header: 'Repeat' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'ftf_pct', header: 'FTF %' },
    { key: 'avg_resolution_days', header: 'Avg Days' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'equipment_category', header: 'Category' },
    { key: 'complaint_type', header: 'Complaint' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'fixed_first', header: 'Fixed First' },
    { key: 'ftf_pct', header: 'FTF %' },
    { key: 'avg_labor_hours', header: 'Avg Labor Hrs' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'first_visit_date', header: 'Date' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'fixed_first', header: 'Fixed First' },
    { key: 'repeat_jobs', header: 'Repeat' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'avg_visits', header: 'Avg Visits' },
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

  const queueCols: Column<QueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'equipment_category', header: 'Category' },
    { key: 'job_code', header: 'Job' },
    { key: 'first_visit_date', header: 'First Visit' },
    { key: 'job_outcome', header: 'Outcome' },
    { key: 'repeat_reason', header: 'Repeat Reason' },
    { key: 'visits_count', header: 'Visits' },
    { key: 'job_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer First-Time-Fix-Rate &amp; Repeat-Visit Root-Cause Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-service repair log — engineer &times; equipment category &times; job outcome
        (fixed-first / repeat / escalated) &times; repeat reason &times; visits &times; resolution
        days &amp; CAPA closure. Founder-gated view: verdict rollups, hospital FTF scorecards,
        root-cause pareto, and regulatory-impact digest across NABH &amp; SLA surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Job verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No repair jobs logged yet."
          rowKey={(r, i) => String(r.job_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital first-time-fix scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment category &times; complaint matrix</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No jobs by category."
          rowKey={(r, i) => `${r.equipment_category}-${r.complaint_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily first-visit trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.first_visit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk repair queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk jobs."
          rowKey={(r, i) => `${r.job_code}-${i}`}
        />
      </section>
    </main>
  );
}
