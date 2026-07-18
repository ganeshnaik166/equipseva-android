import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { competitiveness_verdict: string; bids: number; pct: number };
type EngRow = {
  engineer_name: string;
  total_bids: number;
  wins: number;
  win_rate_pct: number;
  avg_time_to_bid_min: number;
  avg_bid_rank: number;
  avg_delta_pct: number;
};
type CatRow = {
  job_category: string;
  bids: number;
  wins: number;
  avg_bid_rupees: number;
  avg_delta_pct: number;
};
type TrendRow = {
  job_date: string;
  bids: number;
  wins: number;
  avg_time_to_bid_min: number;
  fast_responses: number;
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
  hospital_name: string;
  engineer_name: string;
  job_reference: string;
  job_category: string;
  job_date: string;
  bid_rank: number | null;
  time_to_bid_minutes: number | null;
  bid_vs_winning_delta_pct: number | null;
  competitiveness_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    catRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3220_verdict_rollup'),
    supabase.rpc('founder_r3220_engineer_scorecard'),
    supabase.rpc('founder_r3220_category_matrix'),
    supabase.rpc('founder_r3220_daily_trend'),
    supabase.rpc('founder_r3220_capa_status_board'),
    supabase.rpc('founder_r3220_root_cause_pareto'),
    supabase.rpc('founder_r3220_regulatory_impact_digest'),
    supabase.rpc('founder_r3220_high_risk_bids'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const catRows: CatRow[] = (catRes.data as CatRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'competitiveness_verdict', header: 'Verdict' },
    { key: 'bids', header: 'Bids' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_bids', header: 'Bids' },
    { key: 'wins', header: 'Wins' },
    { key: 'win_rate_pct', header: 'Win Rate %' },
    { key: 'avg_time_to_bid_min', header: 'Avg Time-to-Bid (min)' },
    { key: 'avg_bid_rank', header: 'Avg Rank' },
    { key: 'avg_delta_pct', header: 'Avg Delta vs Winner %' },
  ];

  const catCols: Column<CatRow>[] = [
    { key: 'job_category', header: 'Job Category' },
    { key: 'bids', header: 'Bids' },
    { key: 'wins', header: 'Wins' },
    { key: 'avg_bid_rupees', header: 'Avg Bid (INR)' },
    { key: 'avg_delta_pct', header: 'Avg Delta vs Winner %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'job_date', header: 'Date' },
    { key: 'bids', header: 'Bids' },
    { key: 'wins', header: 'Wins' },
    { key: 'avg_time_to_bid_min', header: 'Avg Time-to-Bid (min)' },
    { key: 'fast_responses', header: 'Fast Responses (Top 25%)' },
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
    { key: 'regulatory_impact', header: 'Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'job_reference', header: 'Job Ref' },
    { key: 'job_category', header: 'Category' },
    { key: 'job_date', header: 'Date' },
    { key: 'bid_rank', header: 'Rank' },
    { key: 'time_to_bid_minutes', header: 'Time-to-Bid (min)' },
    { key: 'bid_vs_winning_delta_pct', header: 'Delta vs Winner %' },
    { key: 'competitiveness_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Job-Acceptance Speed &amp; Bid-Competitiveness Analytics Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Bid analytics log — engineer &times; job category &times; time-to-first-bid &times;
        bid rank &times; win flag &times; bid-vs-winning delta % &times; response-time percentile
        &amp; CAPA coaching closure. Founder-gated view: verdict rollups, engineer scorecards,
        category matrix, daily bid-speed trend, root-cause pareto, and high-risk bid queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Competitiveness verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No bids logged yet."
          rowKey={(r, i) => String(r.competitiveness_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer bid-speed &amp; win-rate scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Job-category competitiveness matrix</h2>
        <DataTable
          rows={catRows}
          columns={catCols}
          emptyMessage="No bids by category."
          rowKey={(r, i) => String(r.job_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily bid-speed trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.job_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory / marketplace impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk bids queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk bids."
          rowKey={(r, i) => `${r.job_reference}-${r.engineer_name}-${i}`}
        />
      </section>
    </main>
  );
}
