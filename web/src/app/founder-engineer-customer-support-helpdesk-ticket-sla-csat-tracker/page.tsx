import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { ticket_verdict: string; tickets: number; pct: number };
type AgentRow = {
  agent_name: string;
  total_tickets: number;
  within_sla: number;
  breached: number;
  fr_sla_met: number;
  res_sla_met: number;
  escalated: number;
  avg_csat: number;
  sla_met_pct: number;
};
type MatrixRow = {
  channel: string;
  category: string;
  tickets: number;
  within_sla: number;
  avg_first_response_minutes: number;
  avg_resolution_hours: number;
};
type TrendRow = {
  created_date: string;
  tickets: number;
  within_sla: number;
  breached: number;
  fr_breach: number;
  escalated: number;
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
type ImpactRow = {
  customer_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  ticket_code: string;
  agent_name: string;
  created_date: string;
  channel: string;
  category: string;
  priority: string;
  ticket_verdict: string;
  reopened_count: number;
  csat_score: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    agentRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3284_ticket_verdict_rollup'),
    supabase.rpc('founder_r3284_agent_scorecard'),
    supabase.rpc('founder_r3284_channel_category_matrix'),
    supabase.rpc('founder_r3284_daily_ticket_trend'),
    supabase.rpc('founder_r3284_capa_status_board'),
    supabase.rpc('founder_r3284_root_cause_pareto'),
    supabase.rpc('founder_r3284_customer_impact_digest'),
    supabase.rpc('founder_r3284_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const agentRows: AgentRow[] = (agentRes.data as AgentRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'ticket_verdict', header: 'Verdict' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'pct', header: 'Share %' },
  ];

  const agentCols: Column<AgentRow>[] = [
    { key: 'agent_name', header: 'Agent' },
    { key: 'total_tickets', header: 'Tickets' },
    { key: 'within_sla', header: 'Within SLA' },
    { key: 'breached', header: 'Breached' },
    { key: 'fr_sla_met', header: 'First-Resp SLA Met' },
    { key: 'res_sla_met', header: 'Resolution SLA Met' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'avg_csat', header: 'Avg CSAT' },
    { key: 'sla_met_pct', header: 'SLA Met %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'channel', header: 'Channel' },
    { key: 'category', header: 'Category' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'within_sla', header: 'Within SLA' },
    { key: 'avg_first_response_minutes', header: 'Avg First-Resp (min)' },
    { key: 'avg_resolution_hours', header: 'Avg Resolution (h)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'created_date', header: 'Date' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'within_sla', header: 'Within SLA' },
    { key: 'breached', header: 'Breached' },
    { key: 'fr_breach', header: 'First-Resp Breach' },
    { key: 'escalated', header: 'Escalated' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'customer_impact', header: 'Customer Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ticket_code', header: 'Ticket' },
    { key: 'agent_name', header: 'Agent' },
    { key: 'created_date', header: 'Date' },
    { key: 'channel', header: 'Channel' },
    { key: 'category', header: 'Category' },
    { key: 'priority', header: 'Priority' },
    { key: 'ticket_verdict', header: 'Verdict' },
    { key: 'reopened_count', header: 'Reopens' },
    { key: 'csat_score', header: 'CSAT' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Customer-Support Helpdesk Ticket SLA &amp; CSAT Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Service-desk QA log — ticket channel &times; category &times; priority &times; first-response
        SLA &times; resolution SLA &times; reopen count &times; field-escalation &times; CSAT score
        &amp; coaching CAPA closure. The EquipSeva desk triages hospital equipment complaints before
        dispatching field engineers. Founder-gated view: verdict mix, agent scorecards, root-cause
        pareto, and customer-impact / SLA-risk digest across Apollo, Fortis, Manipal, AIIMS &amp; CMC.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Ticket verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No support tickets logged yet."
          rowKey={(r, i) => String(r.ticket_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Agent SLA &amp; CSAT scorecard</h2>
        <DataTable
          rows={agentRows}
          columns={agentCols}
          emptyMessage="No agent rollups."
          rowKey={(r, i) => String(r.agent_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Channel &times; category matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No tickets by channel."
          rowKey={(r, i) => `${r.channel}-${r.category}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily ticket SLA trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.created_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Customer-impact / SLA-risk digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No customer-impact rollups."
          rowKey={(r, i) => String(r.customer_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk ticket queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk tickets."
          rowKey={(r, i) => `${r.ticket_code}-${r.created_date}-${i}`}
        />
      </section>
    </main>
  );
}
