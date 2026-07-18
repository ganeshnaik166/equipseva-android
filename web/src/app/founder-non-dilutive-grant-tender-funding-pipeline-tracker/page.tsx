import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { status: string; applications: number; total_sought: number; pct: number };
type HospRow = {
  hospital_name: string;
  applications: number;
  awarded: number;
  disbursed: number;
  rejected: number;
  total_sought: number;
  total_awarded: number;
  win_pct: number;
};
type MatrixRow = {
  funding_stream: string;
  stage: string;
  applications: number;
  total_sought: number;
  avg_probability: number;
};
type TrendRow = {
  submitted_date: string;
  submissions: number;
  total_sought: number;
  avg_probability: number;
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
type RegRow = {
  regulatory_impact: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type QueueRow = {
  hospital_name: string;
  programme_code: string;
  application_ref: string;
  amount_sought_rupees: number;
  stage: string;
  probability_pct: number | null;
  status: string;
  decision_expected_date: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3145_status_rollup'),
    supabase.rpc('founder_r3145_hospital_scorecard'),
    supabase.rpc('founder_r3145_stream_stage_matrix'),
    supabase.rpc('founder_r3145_submission_trend'),
    supabase.rpc('founder_r3145_capa_status_board'),
    supabase.rpc('founder_r3145_root_cause_pareto'),
    supabase.rpc('founder_r3145_regulatory_impact_digest'),
    supabase.rpc('founder_r3145_priority_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'status', header: 'Status' },
    { key: 'applications', header: 'Applications' },
    { key: 'total_sought', header: 'Sought (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital / Entity' },
    { key: 'applications', header: 'Applications' },
    { key: 'awarded', header: 'Awarded' },
    { key: 'disbursed', header: 'Disbursed' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'total_sought', header: 'Sought (INR)' },
    { key: 'total_awarded', header: 'Awarded (INR)' },
    { key: 'win_pct', header: 'Win %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'funding_stream', header: 'Funding Stream' },
    { key: 'stage', header: 'Stage' },
    { key: 'applications', header: 'Applications' },
    { key: 'total_sought', header: 'Sought (INR)' },
    { key: 'avg_probability', header: 'Avg Prob %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'submitted_date', header: 'Submitted' },
    { key: 'submissions', header: 'Submissions' },
    { key: 'total_sought', header: 'Sought (INR)' },
    { key: 'avg_probability', header: 'Avg Prob %' },
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

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital / Entity' },
    { key: 'programme_code', header: 'Programme' },
    { key: 'application_ref', header: 'Ref' },
    { key: 'amount_sought_rupees', header: 'Sought (INR)' },
    { key: 'stage', header: 'Stage' },
    { key: 'probability_pct', header: 'Prob %' },
    { key: 'status', header: 'Status' },
    { key: 'decision_expected_date', header: 'Decision Due' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Non-Dilutive Grant &amp; Tender Funding Pipeline Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Grant &amp; tender pipeline — programme (BIRAC / SIDBI / Startup India / state / hospital tender) &times;
        funding-stream &times; stage &times; probability &times; dilution=none &times; status &amp; CAPA follow-up.
        Founder-gated view: status rollups, hospital scorecards, root-cause pareto, and regulatory-impact digest
        across central-grant &amp; hospital-tender surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No applications logged yet."
          rowKey={(r, i) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital / entity scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Funding stream &times; stage matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No applications by stage."
          rowKey={(r, i) => `${r.funding_stream}-${r.stage}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Submission time trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.submitted_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-priority pipeline queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No priority applications."
          rowKey={(r, i) => `${r.application_ref}-${i}`}
        />
      </section>
    </main>
  );
}
