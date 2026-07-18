import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { readiness_verdict: string; drills: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_drills: number;
  participated: number;
  fully_ready: number;
  retraining_required: number;
  not_ready: number;
  avg_response_min: number;
  avg_checklist_pct: number;
  readiness_pct: number;
};
type MatrixRow = {
  drill_type: string;
  weak_step_identified: string;
  drills: number;
  avg_checklist_pct: number;
};
type TrendRow = {
  drill_date: string;
  drills: number;
  participated: number;
  fully_ready: number;
  retrain_flagged: number;
  avg_response_min: number;
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
  drill_ref: string;
  drill_date: string;
  drill_type: string;
  response_time_minutes: number | null;
  checklist_score_pct: number | null;
  weak_step_identified: string;
  retrain_due_date: string | null;
  readiness_verdict: string;
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
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3232_readiness_verdict_rollup'),
    supabase.rpc('founder_r3232_hospital_scorecard'),
    supabase.rpc('founder_r3232_drill_weak_step_matrix'),
    supabase.rpc('founder_r3232_daily_drill_trend'),
    supabase.rpc('founder_r3232_capa_status_board'),
    supabase.rpc('founder_r3232_root_cause_pareto'),
    supabase.rpc('founder_r3232_regulatory_impact_digest'),
    supabase.rpc('founder_r3232_retrain_priority_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'readiness_verdict', header: 'Readiness Verdict' },
    { key: 'drills', header: 'Drills' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_drills', header: 'Drills' },
    { key: 'participated', header: 'Participated' },
    { key: 'fully_ready', header: 'Fully Ready' },
    { key: 'retraining_required', header: 'Retrain Reqd' },
    { key: 'not_ready', header: 'Not Ready' },
    { key: 'avg_response_min', header: 'Avg Response (min)' },
    { key: 'avg_checklist_pct', header: 'Avg Checklist %' },
    { key: 'readiness_pct', header: 'Readiness %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'drill_type', header: 'Drill Type' },
    { key: 'weak_step_identified', header: 'Weak Step' },
    { key: 'drills', header: 'Drills' },
    { key: 'avg_checklist_pct', header: 'Avg Checklist %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'drill_date', header: 'Date' },
    { key: 'drills', header: 'Drills' },
    { key: 'participated', header: 'Participated' },
    { key: 'fully_ready', header: 'Fully Ready' },
    { key: 'retrain_flagged', header: 'Retrain Flagged' },
    { key: 'avg_response_min', header: 'Avg Response (min)' },
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
    { key: 'drill_ref', header: 'Drill' },
    { key: 'drill_date', header: 'Date' },
    { key: 'drill_type', header: 'Type' },
    { key: 'response_time_minutes', header: 'Response (min)' },
    { key: 'checklist_score_pct', header: 'Checklist %' },
    { key: 'weak_step_identified', header: 'Weak Step' },
    { key: 'retrain_due_date', header: 'Retrain Due' },
    { key: 'readiness_verdict', header: 'Verdict' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Emergency-Response Drill Participation &amp; Code-Red Readiness Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Emergency drill log &mdash; drill type &times; participation &times; response time &times;
        checklist score &times; weak step &times; retrain flag &amp; CAPA closure. Founder-gated view:
        readiness verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest
        across NABH &amp; fire-NOC surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No drills logged yet."
          rowKey={(r, i) => String(r.readiness_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital readiness scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Drill type &times; weak step matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No drills by type."
          rowKey={(r, i) => `${r.drill_type}-${r.weak_step_identified}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily drill trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.drill_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Retrain priority queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No engineers flagged for retraining."
          rowKey={(r, i) => `${r.drill_ref}-${i}`}
        />
      </section>
    </main>
  );
}
