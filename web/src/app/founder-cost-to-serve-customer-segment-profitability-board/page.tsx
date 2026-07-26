import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ProfitRow = {
  profitability: string;
  segments: number;
  total_revenue_rupees: number;
  avg_net_margin_pct: number;
  pct: number;
};
type ScoreRow = {
  customer_segment: string;
  segments: number;
  total_revenue_rupees: number;
  total_cost_to_serve_rupees: number;
  avg_gross_margin_pct: number;
  avg_net_margin_pct: number;
  loss_making: number;
  profitable_pct: number;
};
type MatrixRow = {
  customer_segment: string;
  profitability: string;
  segments: number;
  total_revenue_rupees: number;
  avg_net_margin_pct: number;
};
type TrendRow = {
  period_month: string;
  segments: number;
  total_revenue_rupees: number;
  total_cost_to_serve_rupees: number;
  avg_gross_margin_pct: number;
  avg_net_margin_pct: number;
  loss_making: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_margin_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_margin_impact_rupees: number;
  pct: number;
};
type ImpactRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_margin_impact_rupees: number;
};
type RiskRow = {
  customer_segment: string;
  segment_code: string;
  region: string;
  period_month: string;
  profitability: string;
  service_intensity: string;
  trend_dir: string;
  revenue_rupees: number;
  net_margin_pct: number;
  cost_to_serve_rupees: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    profitRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3453_profitability_rollup'),
    supabase.rpc('founder_r3453_segment_scorecard'),
    supabase.rpc('founder_r3453_segment_profitability_matrix'),
    supabase.rpc('founder_r3453_monthly_margin_trend'),
    supabase.rpc('founder_r3453_capa_status_board'),
    supabase.rpc('founder_r3453_root_cause_pareto'),
    supabase.rpc('founder_r3453_margin_impact_digest'),
    supabase.rpc('founder_r3453_high_risk_queue'),
  ]);

  const profitRows: ProfitRow[] = (profitRes.data as ProfitRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const profitCols: Column<ProfitRow>[] = [
    { key: 'profitability', header: 'Profitability' },
    { key: 'segments', header: 'Segments' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'avg_net_margin_pct', header: 'Avg Net Margin %' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'customer_segment', header: 'Customer Segment' },
    { key: 'segments', header: 'Segments' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_cost_to_serve_rupees', header: 'Cost-to-Serve (INR)' },
    { key: 'avg_gross_margin_pct', header: 'Avg Gross Margin %' },
    { key: 'avg_net_margin_pct', header: 'Avg Net Margin %' },
    { key: 'loss_making', header: 'Loss-Making' },
    { key: 'profitable_pct', header: 'Profitable %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'customer_segment', header: 'Customer Segment' },
    { key: 'profitability', header: 'Profitability' },
    { key: 'segments', header: 'Segments' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'avg_net_margin_pct', header: 'Avg Net Margin %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'segments', header: 'Segments' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_cost_to_serve_rupees', header: 'Cost-to-Serve (INR)' },
    { key: 'avg_gross_margin_pct', header: 'Avg Gross Margin %' },
    { key: 'avg_net_margin_pct', header: 'Avg Net Margin %' },
    { key: 'loss_making', header: 'Loss-Making' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_margin_impact_rupees', header: 'Margin Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_margin_impact_rupees', header: 'Margin Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_margin_impact_rupees', header: 'Margin Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'segment_code', header: 'Code' },
    { key: 'region', header: 'Region' },
    { key: 'period_month', header: 'Month' },
    { key: 'profitability', header: 'Profitability' },
    { key: 'service_intensity', header: 'Intensity' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'revenue_rupees', header: 'Revenue (INR)' },
    { key: 'net_margin_pct', header: 'Net Margin %' },
    { key: 'cost_to_serve_rupees', header: 'Cost-to-Serve (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Cost-to-Serve / Customer-Segment Profitability Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated cost-to-serve allocated across customer segments &mdash; revenue &times; direct
        service cost &times; allocated overhead &times; cost-to-serve &times; gross &amp; net margin
        &times; service intensity &times; profitability verdict &times; monthly trend &amp; CAPA
        margin-recovery closure. Segment profitability board across large hospital chains, standalone
        hospitals, diagnostic labs, dialysis centres, nursing homes &amp; government accounts:
        profitability rollups, segment scorecards, root-cause pareto, and a high-risk queue of
        loss-making, worsening &amp; high-intensity segments.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Profitability distribution</h2>
        <DataTable
          rows={profitRows}
          columns={profitCols}
          emptyMessage="No segment cost-to-serve rows logged yet."
          rowKey={(r, i) => String(r.profitability ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Customer-segment scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No segment scorecards."
          rowKey={(r, i) => String(r.customer_segment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Segment &times; profitability matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No segments by profitability."
          rowKey={(r, i) => `${r.customer_segment}-${r.profitability}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly margin trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Margin-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No margin-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk segment queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk segments."
          rowKey={(r, i) => `${r.segment_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
