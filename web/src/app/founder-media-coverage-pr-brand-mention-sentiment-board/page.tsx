import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { mention_verdict: string; mentions: number; total_reach: number; pct: number };
type HospRow = {
  hospital_name: string;
  mentions: number;
  positive_mentions: number;
  negative_mentions: number;
  total_reach: number;
  avg_sentiment_score: number;
  amplify_count: number;
  positive_pct: number;
};
type MatrixRow = {
  outlet_tier: string;
  mention_type: string;
  mentions: number;
  total_reach: number;
  avg_sentiment_score: number;
};
type TrendRow = {
  coverage_date: string;
  mentions: number;
  positive_mentions: number;
  negative_mentions: number;
  total_reach: number;
  avg_sentiment_score: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  escalated_or_overdue: number;
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
  mention_ref: string;
  outlet_name: string;
  coverage_date: string;
  mention_type: string;
  sentiment: string;
  mention_verdict: string;
  reach_estimate: number;
  spokesperson_name: string | null;
  notes: string | null;
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
    supabase.rpc('founder_r3217_mention_verdict_rollup'),
    supabase.rpc('founder_r3217_hospital_scorecard'),
    supabase.rpc('founder_r3217_outlet_mention_matrix'),
    supabase.rpc('founder_r3217_coverage_daily_trend'),
    supabase.rpc('founder_r3217_capa_status_board'),
    supabase.rpc('founder_r3217_root_cause_pareto'),
    supabase.rpc('founder_r3217_regulatory_impact_digest'),
    supabase.rpc('founder_r3217_priority_mentions_queue'),
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
    { key: 'mention_verdict', header: 'Verdict' },
    { key: 'mentions', header: 'Mentions' },
    { key: 'total_reach', header: 'Total Reach' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'mentions', header: 'Mentions' },
    { key: 'positive_mentions', header: 'Positive' },
    { key: 'negative_mentions', header: 'Negative' },
    { key: 'total_reach', header: 'Total Reach' },
    { key: 'avg_sentiment_score', header: 'Avg Sentiment' },
    { key: 'amplify_count', header: 'Amplified' },
    { key: 'positive_pct', header: 'Positive %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'outlet_tier', header: 'Outlet Tier' },
    { key: 'mention_type', header: 'Mention Type' },
    { key: 'mentions', header: 'Mentions' },
    { key: 'total_reach', header: 'Total Reach' },
    { key: 'avg_sentiment_score', header: 'Avg Sentiment' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'coverage_date', header: 'Date' },
    { key: 'mentions', header: 'Mentions' },
    { key: 'positive_mentions', header: 'Positive' },
    { key: 'negative_mentions', header: 'Negative' },
    { key: 'total_reach', header: 'Total Reach' },
    { key: 'avg_sentiment_score', header: 'Avg Sentiment' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'escalated_or_overdue', header: 'Overdue / Escalated' },
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
    { key: 'mention_ref', header: 'Ref' },
    { key: 'outlet_name', header: 'Outlet' },
    { key: 'coverage_date', header: 'Date' },
    { key: 'mention_type', header: 'Type' },
    { key: 'sentiment', header: 'Sentiment' },
    { key: 'mention_verdict', header: 'Verdict' },
    { key: 'reach_estimate', header: 'Reach' },
    { key: 'spokesperson_name', header: 'Spokesperson' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Media-Coverage, PR &amp; Brand-Mention Sentiment Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        PR mention log &#8212; outlet tier &times; mention type &times; reach &times; sentiment &times;
        key message &times; spokesperson &amp; CAPA closure. Founder-gated view: verdict rollups,
        hospital PR scorecards, root-cause pareto, and regulatory-impact digest across earned,
        social &amp; awards surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Mention verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No mentions logged yet."
          rowKey={(r, i) => String(r.mention_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital PR scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Outlet tier &times; mention type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No mentions by outlet tier."
          rowKey={(r, i) => `${r.outlet_tier}-${r.mention_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Coverage daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.coverage_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Priority mentions queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No priority mentions."
          rowKey={(r, i) => `${r.mention_ref}-${i}`}
        />
      </section>
    </main>
  );
}
