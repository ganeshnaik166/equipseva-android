import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { fulfilment_status: string; requests: number; pct: number };
type ScoreRow = {
  requester_type: string;
  total_requests: number;
  on_time: number;
  late: number;
  in_progress: number;
  overdue: number;
  escalated: number;
  sla_pct: number;
};
type MatrixRow = {
  request_class: string;
  fulfilment_status: string;
  requests: number;
  avg_days_to_fulfil: number;
  escalated_count: number;
};
type TrendRow = {
  period_month: string;
  requests: number;
  on_time: number;
  late: number;
  overdue: number;
  avg_days_to_fulfil: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_penalty_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_penalty_exposure_rupees: number;
  pct: number;
};
type DigestRow = {
  request_class: string;
  overdue_count: number;
  escalated_count: number;
  avg_records_systems_touched: number;
  oldest_due_date: string | null;
};
type RiskRow = {
  request_ref: string;
  requester_type: string;
  request_class: string;
  request_date: string;
  statutory_due_date: string;
  fulfilment_status: string;
  days_to_fulfil: number | null;
  escalated_to_dpo: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3717_fulfilment_status_rollup'),
    supabase.rpc('founder_r3717_requester_type_scorecard'),
    supabase.rpc('founder_r3717_request_class_status_matrix'),
    supabase.rpc('founder_r3717_monthly_fulfilment_trend'),
    supabase.rpc('founder_r3717_capa_status_board'),
    supabase.rpc('founder_r3717_root_cause_pareto'),
    supabase.rpc('founder_r3717_overdue_digest'),
    supabase.rpc('founder_r3717_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'fulfilment_status', header: 'Fulfilment Status' },
    { key: 'requests', header: 'Requests' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'requester_type', header: 'Requester Type' },
    { key: 'total_requests', header: 'Requests' },
    { key: 'on_time', header: 'On Time' },
    { key: 'late', header: 'Late' },
    { key: 'in_progress', header: 'In Progress' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'escalated', header: 'Escalated to DPO' },
    { key: 'sla_pct', header: 'SLA %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'request_class', header: 'Request Class' },
    { key: 'fulfilment_status', header: 'Fulfilment Status' },
    { key: 'requests', header: 'Requests' },
    { key: 'avg_days_to_fulfil', header: 'Avg Days to Fulfil' },
    { key: 'escalated_count', header: 'Escalated' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'requests', header: 'Requests' },
    { key: 'on_time', header: 'On Time' },
    { key: 'late', header: 'Late' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'avg_days_to_fulfil', header: 'Avg Days to Fulfil' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_penalty_exposure_rupees', header: 'Avg Penalty Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_penalty_exposure_rupees', header: 'Total Penalty Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'request_class', header: 'Request Class' },
    { key: 'overdue_count', header: 'Overdue' },
    { key: 'escalated_count', header: 'Escalated' },
    { key: 'avg_records_systems_touched', header: 'Avg Systems Touched' },
    { key: 'oldest_due_date', header: 'Oldest Due Date' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'request_ref', header: 'Request Ref' },
    { key: 'requester_type', header: 'Requester' },
    { key: 'request_class', header: 'Class' },
    { key: 'request_date', header: 'Requested' },
    { key: 'statutory_due_date', header: 'Due' },
    { key: 'fulfilment_status', header: 'Status' },
    { key: 'days_to_fulfil', header: 'Days to Fulfil' },
    { key: 'escalated_to_dpo', header: 'Escalated' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        DPDP Data-Principal Request (DSAR) Fulfilment Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        DPDP data-principal request log &mdash; access copy, correction, erasure, nominee exercise
        &amp; grievance requests &times; requester type &times; statutory due date &times; days to
        fulfil &times; identity verification &times; systems touched &times; partial fulfilment
        &times; DPO escalation &amp; CAPA closure. Founder-gated view: fulfilment-status rollups,
        requester-type scorecards, root-cause pareto, and the overdue &amp; high-risk queue across
        active DSAR SLAs.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Fulfilment status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No DSAR requests logged yet."
          rowKey={(r, i) => String(r.fulfilment_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Requester-type scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No requester-type rollups."
          rowKey={(r, i) => String(r.requester_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Request class &times; fulfilment status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No requests by class."
          rowKey={(r, i) => `${r.request_class}-${r.fulfilment_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly fulfilment trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Overdue digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No overdue requests."
          rowKey={(r, i) => String(r.request_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk requests."
          rowKey={(r, i) => `${r.request_ref}-${i}`}
        />
      </section>
    </main>
  );
}
