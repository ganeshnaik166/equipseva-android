import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type HandoffRow = { handoff_status: string; tickets: number; pct: number };
type TierRow = {
  current_tier: string;
  total_tickets: number;
  resolved: number;
  open_tickets: number;
  bounced: number;
  breached: number;
  avg_elapsed_hours: number;
  breach_pct: number;
};
type MatrixRow = {
  current_tier: string;
  escalation_reason: string;
  tickets: number;
  resolved: number;
  breached: number;
  avg_elapsed_hours: number;
};
type TrendRow = {
  escalation_month: string;
  tickets: number;
  resolved: number;
  breached: number;
  bounced: number;
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
  breach_severity: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  ticket_code: string;
  engineer_name: string;
  current_tier: string;
  escalation_reason: string;
  handoff_status: string;
  sla_hours: number | null;
  elapsed_hours: number | null;
  breached: boolean;
  raised_date: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    handoffRes,
    tierRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3436_handoff_status_rollup'),
    supabase.rpc('founder_r3436_tier_scorecard'),
    supabase.rpc('founder_r3436_tier_reason_matrix'),
    supabase.rpc('founder_r3436_monthly_escalation_trend'),
    supabase.rpc('founder_r3436_capa_status_board'),
    supabase.rpc('founder_r3436_root_cause_pareto'),
    supabase.rpc('founder_r3436_sla_breach_impact_digest'),
    supabase.rpc('founder_r3436_high_risk_queue'),
  ]);

  const handoffRows: HandoffRow[] = (handoffRes.data as HandoffRow[]) ?? [];
  const tierRows: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const handoffCols: Column<HandoffRow>[] = [
    { key: 'handoff_status', header: 'Handoff Status' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'pct', header: 'Share %' },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'current_tier', header: 'Tier' },
    { key: 'total_tickets', header: 'Tickets' },
    { key: 'resolved', header: 'Resolved' },
    { key: 'open_tickets', header: 'Open / WIP' },
    { key: 'bounced', header: 'Bounced' },
    { key: 'breached', header: 'Breached' },
    { key: 'avg_elapsed_hours', header: 'Avg Elapsed Hrs' },
    { key: 'breach_pct', header: 'Breach %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'current_tier', header: 'Tier' },
    { key: 'escalation_reason', header: 'Escalation Reason' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'resolved', header: 'Resolved' },
    { key: 'breached', header: 'Breached' },
    { key: 'avg_elapsed_hours', header: 'Avg Elapsed Hrs' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'escalation_month', header: 'Month' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'resolved', header: 'Resolved' },
    { key: 'breached', header: 'Breached' },
    { key: 'bounced', header: 'Bounced' },
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
    { key: 'breach_severity', header: 'Breach Severity' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ticket_code', header: 'Ticket' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'current_tier', header: 'Tier' },
    { key: 'escalation_reason', header: 'Reason' },
    { key: 'handoff_status', header: 'Status' },
    { key: 'sla_hours', header: 'SLA Hrs' },
    { key: 'elapsed_hours', header: 'Elapsed Hrs' },
    { key: 'breached', header: 'Breached' },
    { key: 'raised_date', header: 'Raised' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Escalation-Matrix L1/L2/L3 Handoff &amp; SLA Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Support-ticket escalation-matrix log — engineer &times; ticket &times; hospital &times; current
        tier (L1 &rarr; L2 &rarr; L3 &rarr; OEM) &times; escalation reason &times; escalated-from &times;
        handoff status &times; SLA hours &times; elapsed hours &times; breach flag &times; raised /
        resolved dates &amp; CAPA closure. Founder-gated view: handoff-status mix, tier scorecards, tier
        &times; reason matrix, monthly trend, root-cause pareto, and SLA-breach impact digest across the
        L1/L2/L3 handoff chain.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Handoff-status distribution</h2>
        <DataTable
          rows={handoffRows}
          columns={handoffCols}
          emptyMessage="No escalation tickets logged yet."
          rowKey={(r, i) => String(r.handoff_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Tier scorecard</h2>
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No tier rollups."
          rowKey={(r, i) => String(r.current_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Tier &times; reason matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No tickets by tier and reason."
          rowKey={(r, i) => `${r.current_tier}-${r.escalation_reason}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly escalation trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.escalation_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. SLA-breach impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No breach-impact rollups."
          rowKey={(r, i) => String(r.breach_severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk escalation queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk escalations."
          rowKey={(r, i) => `${r.ticket_code}-${r.raised_date}-${i}`}
        />
      </section>
    </main>
  );
}
