import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { watch_verdict: string; moves: number; pct: number };
type CompRow = {
  competitor_name: string;
  total_moves: number;
  critical_moves: number;
  urgent_countermoves: number;
  live_countermoves: number;
  revenue_at_risk_rupees: number;
  responded_pct: number;
};
type MatrixRow = {
  move_type: string;
  severity: string;
  moves: number;
  urgent: number;
  revenue_at_risk_rupees: number;
};
type TrendRow = {
  observed_on: string;
  moves: number;
  critical_moves: number;
  urgent_verdicts: number;
  revenue_at_risk_rupees: number;
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
  competitor_name: string;
  hospital_name: string;
  move_type: string;
  severity: string;
  observed_on: string;
  our_response_status: string;
  response_owner: string;
  watch_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    compRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3181_verdict_rollup'),
    supabase.rpc('founder_r3181_competitor_scorecard'),
    supabase.rpc('founder_r3181_move_severity_matrix'),
    supabase.rpc('founder_r3181_daily_move_trend'),
    supabase.rpc('founder_r3181_capa_status_board'),
    supabase.rpc('founder_r3181_root_cause_pareto'),
    supabase.rpc('founder_r3181_regulatory_impact_digest'),
    supabase.rpc('founder_r3181_high_priority_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const compRows: CompRow[] = (compRes.data as CompRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'watch_verdict', header: 'Verdict' },
    { key: 'moves', header: 'Moves' },
    { key: 'pct', header: 'Share %' },
  ];

  const compCols: Column<CompRow>[] = [
    { key: 'competitor_name', header: 'Competitor' },
    { key: 'total_moves', header: 'Moves' },
    { key: 'critical_moves', header: 'Critical' },
    { key: 'urgent_countermoves', header: 'Urgent' },
    { key: 'live_countermoves', header: 'Countermoves Live' },
    { key: 'revenue_at_risk_rupees', header: 'Revenue at Risk (INR)' },
    { key: 'responded_pct', header: 'Responded %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'move_type', header: 'Move Type' },
    { key: 'severity', header: 'Severity' },
    { key: 'moves', header: 'Moves' },
    { key: 'urgent', header: 'Urgent' },
    { key: 'revenue_at_risk_rupees', header: 'Revenue at Risk (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'observed_on', header: 'Date' },
    { key: 'moves', header: 'Moves' },
    { key: 'critical_moves', header: 'Critical' },
    { key: 'urgent_verdicts', header: 'Urgent Verdicts' },
    { key: 'revenue_at_risk_rupees', header: 'Revenue at Risk (INR)' },
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
    { key: 'competitor_name', header: 'Competitor' },
    { key: 'hospital_name', header: 'Account' },
    { key: 'move_type', header: 'Move' },
    { key: 'severity', header: 'Severity' },
    { key: 'observed_on', header: 'Observed' },
    { key: 'our_response_status', header: 'Response Status' },
    { key: 'response_owner', header: 'Owner' },
    { key: 'watch_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Competitor-Move &amp; Market-Intelligence Watch Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Competitor intel log &mdash; competitor &times; move type &times; severity &times; source &times;
        response status &times; moat impact &amp; CAPA countermoves. Founder-gated view: verdict rollup,
        competitor threat scorecards, root-cause pareto, and the high-priority response queue across key accounts.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Watch verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No competitor moves logged yet."
          rowKey={(r, i) => String(r.watch_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Competitor threat scorecard</h2>
        <DataTable
          rows={compRows}
          columns={compCols}
          emptyMessage="No competitor rollups."
          rowKey={(r, i) => String(r.competitor_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Move type &times; severity matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No moves by type."
          rowKey={(r, i) => `${r.move_type}-${r.severity}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily observed-move trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.observed_on ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA countermoves."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-priority response queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No moves awaiting response."
          rowKey={(r, i) => `${r.competitor_name}-${r.observed_on}-${i}`}
        />
      </section>
    </main>
  );
}
