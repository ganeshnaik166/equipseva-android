import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { reclosure_status: string; tickets: number; pct: number };
type EngineerRow = {
  engineer_name: string;
  total_tickets: number;
  permanently_closed: number;
  reopened_again: number;
  escalated: number;
  poor_quality: number;
  repeat_reopens: number;
  avg_days_to_reopen: number;
  good_close_pct: number;
};
type MatrixRow = {
  reopen_reason: string;
  first_close_quality: string;
  tickets: number;
  reopened_again: number;
  avg_days_to_reopen: number;
};
type TrendRow = {
  reopen_month: string;
  tickets: number;
  reopened_again: number;
  escalated: number;
  poor_quality: number;
  avg_days_to_reopen: number;
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
  impact_severity: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  ticket_code: string;
  device_model: string;
  reopen_reason: string;
  reopen_count: number;
  days_to_reopen: number;
  reclosure_status: string;
  first_close_quality: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    engineerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3548_reclosure_status_rollup'),
    supabase.rpc('founder_r3548_engineer_scorecard'),
    supabase.rpc('founder_r3548_reason_quality_matrix'),
    supabase.rpc('founder_r3548_monthly_reopen_trend'),
    supabase.rpc('founder_r3548_capa_status_board'),
    supabase.rpc('founder_r3548_root_cause_pareto'),
    supabase.rpc('founder_r3548_reopen_impact_digest'),
    supabase.rpc('founder_r3548_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const engineerRows: EngineerRow[] = (engineerRes.data as EngineerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'reclosure_status', header: 'Reclosure Status' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'pct', header: 'Share %' },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_tickets', header: 'Tickets' },
    { key: 'permanently_closed', header: 'Perm Closed' },
    { key: 'reopened_again', header: 'Reopened Again' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'poor_quality', header: 'Poor Quality' },
    { key: 'repeat_reopens', header: 'Repeat Reopens' },
    { key: 'avg_days_to_reopen', header: 'Avg Days to Reopen' },
    { key: 'good_close_pct', header: 'Good Close %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'reopen_reason', header: 'Reopen Reason' },
    { key: 'first_close_quality', header: 'First-Close Quality' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'reopened_again', header: 'Reopened Again' },
    { key: 'avg_days_to_reopen', header: 'Avg Days to Reopen' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'reopen_month', header: 'Month' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'reopened_again', header: 'Reopened Again' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'poor_quality', header: 'Poor Quality' },
    { key: 'avg_days_to_reopen', header: 'Avg Days to Reopen' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Rework Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'impact_severity', header: 'Impact Severity' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ticket_code', header: 'Ticket' },
    { key: 'device_model', header: 'Device' },
    { key: 'reopen_reason', header: 'Reopen Reason' },
    { key: 'reopen_count', header: 'Reopens' },
    { key: 'days_to_reopen', header: 'Days to Reopen' },
    { key: 'reclosure_status', header: 'Reclosure' },
    { key: 'first_close_quality', header: 'First-Close Quality' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Service-Ticket Reopen / Reclosure Quality Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        First-close quality &amp; reopen analytics across the field service base &mdash; reopen reason
        (issue recurred, incomplete fix, wrong diagnosis, customer dissatisfied, part failed,
        documentation) &times; first-close quality &times; reclosure status &times; days-to-reopen
        &times; repeat-reopen count &amp; CAPA closure. Founder-gated view: reclosure-status
        distribution, engineer scorecards, root-cause pareto, and reopen-impact digest to drive
        first-time-fix quality up and rework cost down.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Reclosure status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No reopened tickets logged yet."
          rowKey={(r, i) => String(r.reclosure_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer first-close scorecard</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Reopen reason &times; first-close quality matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No tickets by reason."
          rowKey={(r, i) => `${r.reopen_reason}-${r.first_close_quality}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly reopen trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.reopen_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Reopen impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.impact_severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk reclosure queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk tickets."
          rowKey={(r, i) => `${r.ticket_code}-${i}`}
        />
      </section>
    </main>
  );
}
