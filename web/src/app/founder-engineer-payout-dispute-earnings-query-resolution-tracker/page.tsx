import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { dispute_verdict: string; disputes: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_disputes: number;
  resolved: number;
  paid: number;
  adjusted: number;
  rejected: number;
  avg_resolution_days: number | null;
  total_disputed_rupees: number;
  resolution_pct: number;
};
type MatrixRow = {
  query_type: string;
  outcome: string;
  disputes: number;
  avg_resolution_days: number | null;
  disputed_rupees: number;
};
type TrendRow = {
  raised_date: string;
  disputes: number;
  resolved: number;
  pending: number;
  disputed_rupees: number;
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
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  dispute_ref: string;
  query_type: string;
  raised_date: string;
  disputed_amount_rupees: number;
  dispute_verdict: string;
  engineer_satisfaction: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3216_verdict_rollup'),
    supabase.rpc('founder_r3216_engineer_scorecard'),
    supabase.rpc('founder_r3216_query_outcome_matrix'),
    supabase.rpc('founder_r3216_daily_trend'),
    supabase.rpc('founder_r3216_capa_status_board'),
    supabase.rpc('founder_r3216_root_cause_pareto'),
    supabase.rpc('founder_r3216_regulatory_impact_digest'),
    supabase.rpc('founder_r3216_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'dispute_verdict', header: 'Verdict' },
    { key: 'disputes', header: 'Disputes' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_disputes', header: 'Disputes' },
    { key: 'resolved', header: 'Resolved' },
    { key: 'paid', header: 'Paid' },
    { key: 'adjusted', header: 'Adjusted' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'avg_resolution_days', header: 'Avg Days' },
    { key: 'total_disputed_rupees', header: 'Disputed (INR)' },
    { key: 'resolution_pct', header: 'Resolution %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'query_type', header: 'Query Type' },
    { key: 'outcome', header: 'Outcome' },
    { key: 'disputes', header: 'Disputes' },
    { key: 'avg_resolution_days', header: 'Avg Days' },
    { key: 'disputed_rupees', header: 'Disputed (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'raised_date', header: 'Date' },
    { key: 'disputes', header: 'Raised' },
    { key: 'resolved', header: 'Resolved' },
    { key: 'pending', header: 'Pending' },
    { key: 'disputed_rupees', header: 'Disputed (INR)' },
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

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'dispute_ref', header: 'Ref' },
    { key: 'query_type', header: 'Query Type' },
    { key: 'raised_date', header: 'Raised' },
    { key: 'disputed_amount_rupees', header: 'Amount (INR)' },
    { key: 'dispute_verdict', header: 'Verdict' },
    { key: 'engineer_satisfaction', header: 'Satisfaction' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Payout-Dispute &amp; Earnings-Query Resolution Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Payout dispute log — query type &times; raised channel &times; resolution days &times;
        outcome &times; satisfaction &amp; CAPA closure. Founder-gated view: dispute verdicts,
        engineer scorecards, root-cause pareto, and regulatory-impact digest across TDS &amp; GST surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Dispute verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No disputes logged yet."
          rowKey={(r, i) => String(r.dispute_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer dispute scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Query type &times; outcome matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No disputes by query type."
          rowKey={(r, i) => `${r.query_type}-${r.outcome}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily raised &amp; resolved trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.raised_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk dispute queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk disputes."
          rowKey={(r, i) => `${r.dispute_ref}-${i}`}
        />
      </section>
    </main>
  );
}
