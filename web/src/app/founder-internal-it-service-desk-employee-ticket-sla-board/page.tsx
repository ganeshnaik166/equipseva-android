import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { ticket_status: string; tickets: number; pct: number };
type ScoreRow = {
  department: string;
  total_raised: number;
  total_resolved: number;
  avg_first_response_hours: number;
  avg_resolution_hours: number;
  total_sla_breaches: number;
  total_repeat_tickets: number;
  avg_csat_score: number;
};
type MatrixRow = {
  issue_class: string;
  ticket_status: string;
  tickets: number;
  avg_resolution_hours: number;
};
type TrendRow = {
  period_month: string;
  tickets_raised: number;
  tickets_resolved: number;
  avg_resolution_hours: number;
  sla_breaches: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  issue_class: string;
  breached_tickets: number;
  total_sla_breaches: number;
  avg_resolution_hours: number;
  vendor_escalations: number;
};
type RiskRow = {
  ticket_ref: string;
  department: string;
  issue_class: string;
  ticket_status: string;
  period_month: string;
  avg_resolution_hours: number | null;
  sla_breaches: number | null;
  csat_score: number | null;
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
    supabase.rpc('founder_r3720_ticket_status_rollup'),
    supabase.rpc('founder_r3720_department_scorecard'),
    supabase.rpc('founder_r3720_issue_class_status_matrix'),
    supabase.rpc('founder_r3720_monthly_resolution_trend'),
    supabase.rpc('founder_r3720_capa_status_board'),
    supabase.rpc('founder_r3720_root_cause_pareto'),
    supabase.rpc('founder_r3720_breach_digest'),
    supabase.rpc('founder_r3720_high_risk_queue'),
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
    { key: 'ticket_status', header: 'Ticket Status' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'total_raised', header: 'Raised' },
    { key: 'total_resolved', header: 'Resolved' },
    { key: 'avg_first_response_hours', header: 'Avg First Response (hrs)' },
    { key: 'avg_resolution_hours', header: 'Avg Resolution (hrs)' },
    { key: 'total_sla_breaches', header: 'SLA Breaches' },
    { key: 'total_repeat_tickets', header: 'Repeat Tickets' },
    { key: 'avg_csat_score', header: 'Avg CSAT' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'issue_class', header: 'Issue Class' },
    { key: 'ticket_status', header: 'Ticket Status' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'avg_resolution_hours', header: 'Avg Resolution (hrs)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'tickets_raised', header: 'Raised' },
    { key: 'tickets_resolved', header: 'Resolved' },
    { key: 'avg_resolution_hours', header: 'Avg Resolution (hrs)' },
    { key: 'sla_breaches', header: 'SLA Breaches' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'issue_class', header: 'Issue Class' },
    { key: 'breached_tickets', header: 'Breached Tickets' },
    { key: 'total_sla_breaches', header: 'Total SLA Breaches' },
    { key: 'avg_resolution_hours', header: 'Avg Resolution (hrs)' },
    { key: 'vendor_escalations', header: 'Vendor Escalations' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'ticket_ref', header: 'Ticket Ref' },
    { key: 'department', header: 'Department' },
    { key: 'issue_class', header: 'Issue Class' },
    { key: 'ticket_status', header: 'Status' },
    { key: 'period_month', header: 'Month' },
    { key: 'avg_resolution_hours', header: 'Avg Resolution (hrs)' },
    { key: 'sla_breaches', header: 'SLA Breaches' },
    { key: 'csat_score', header: 'CSAT' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Internal IT Service-Desk Employee Ticket SLA Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        INTERNAL employee IT support tickets &mdash; hardware, access provisioning, software /
        app, network connectivity &amp; security incidents &times; department &times; first
        response time &times; resolution time &times; SLA breaches &times; repeat-ticket rate
        &amp; vendor escalation. Distinct from any customer/engineer-facing support helpdesk
        ticket SLA &amp; CSAT board &mdash; this view is purely internal/employee-facing IT
        support. Founder-gated view: ticket-status rollups, department scorecards, root-cause
        pareto, and the SLA-breach digest &amp; high-risk queue across open service-desk tickets.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Ticket status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No service-desk tickets logged yet."
          rowKey={(r, i) => String(r.ticket_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Issue class &times; ticket status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No tickets by issue class."
          rowKey={(r, i) => `${r.issue_class}-${r.ticket_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly resolution trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. SLA breach digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No SLA-breach data."
          rowKey={(r, i) => String(r.issue_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk tickets."
          rowKey={(r, i) => `${r.ticket_ref}-${i}`}
        />
      </section>
    </main>
  );
}
