import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type MarginStatusRow = { margin_status: string; quotes: number; pct: number };
type TierScoreRow = {
  pricing_tier: string;
  total_quotes: number;
  above_target: number;
  on_target: number;
  below_target: number;
  below_floor: number;
  approved: number;
  avg_margin_pct: number;
  avg_markup_pct: number;
};
type MatrixRow = {
  pricing_tier: string;
  margin_status: string;
  quotes: number;
  avg_margin_pct: number;
  avg_markup_pct: number;
  total_quoted_rupees: number;
};
type TrendRow = {
  month: string;
  quotes: number;
  avg_margin_pct: number;
  avg_markup_pct: number;
  below_floor: number;
  total_quoted_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  engineer_name: string;
  quotes: number;
  total_cost_rupees: number;
  total_quoted_rupees: number;
  total_margin_rupees: number;
  avg_margin_pct: number;
  below_floor: number;
};
type RiskRow = {
  engineer_name: string;
  quote_ref: string;
  part_name: string;
  part_code: string;
  device_model: string;
  pricing_tier: string;
  cost_price_rupees: number;
  quoted_price_rupees: number;
  margin_pct: number | null;
  margin_status: string;
  approved: boolean;
  quote_date: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    marginRes,
    tierRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3464_margin_status_rollup'),
    supabase.rpc('founder_r3464_pricing_tier_scorecard'),
    supabase.rpc('founder_r3464_tier_margin_matrix'),
    supabase.rpc('founder_r3464_monthly_margin_trend'),
    supabase.rpc('founder_r3464_capa_status_board'),
    supabase.rpc('founder_r3464_root_cause_pareto'),
    supabase.rpc('founder_r3464_margin_impact_digest'),
    supabase.rpc('founder_r3464_high_risk_queue'),
  ]);

  const marginRows: MarginStatusRow[] = (marginRes.data as MarginStatusRow[]) ?? [];
  const tierRows: TierScoreRow[] = (tierRes.data as TierScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const marginCols: Column<MarginStatusRow>[] = [
    { key: 'margin_status', header: 'Margin Status' },
    { key: 'quotes', header: 'Quotes' },
    { key: 'pct', header: 'Share %' },
  ];

  const tierCols: Column<TierScoreRow>[] = [
    { key: 'pricing_tier', header: 'Pricing Tier' },
    { key: 'total_quotes', header: 'Quotes' },
    { key: 'above_target', header: 'Above Target' },
    { key: 'on_target', header: 'On Target' },
    { key: 'below_target', header: 'Below Target' },
    { key: 'below_floor', header: 'Below Floor' },
    { key: 'approved', header: 'Approved' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'avg_markup_pct', header: 'Avg Markup %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'pricing_tier', header: 'Pricing Tier' },
    { key: 'margin_status', header: 'Margin Status' },
    { key: 'quotes', header: 'Quotes' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'avg_markup_pct', header: 'Avg Markup %' },
    { key: 'total_quoted_rupees', header: 'Total Quoted (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month', header: 'Month' },
    { key: 'quotes', header: 'Quotes' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'avg_markup_pct', header: 'Avg Markup %' },
    { key: 'below_floor', header: 'Below Floor' },
    { key: 'total_quoted_rupees', header: 'Total Quoted (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'quotes', header: 'Quotes' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'total_quoted_rupees', header: 'Total Quoted (INR)' },
    { key: 'total_margin_rupees', header: 'Total Margin (INR)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'below_floor', header: 'Below Floor' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'quote_ref', header: 'Quote' },
    { key: 'part_name', header: 'Part' },
    { key: 'part_code', header: 'Code' },
    { key: 'device_model', header: 'Device Model' },
    { key: 'pricing_tier', header: 'Tier' },
    { key: 'cost_price_rupees', header: 'Cost (INR)' },
    { key: 'quoted_price_rupees', header: 'Quoted (INR)' },
    { key: 'margin_pct', header: 'Margin %' },
    { key: 'margin_status', header: 'Status' },
    { key: 'quote_date', header: 'Date' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Spare-Part Pricing / Markup / Quote-Margin Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Service-quote spare-part pricing governance — engineer &times; part &amp; device model &times;
        cost price &times; quoted price &times; markup % &times; margin % &times; pricing tier (list,
        contract, AMC-bundled, goodwill, emergency) &times; margin status (above / on / below target,
        below floor) &times; approval &amp; CAPA closure. Founder-gated view: margin-status
        distribution, pricing-tier scorecards, tier &times; status matrix, monthly margin trend,
        root-cause pareto, and a high-risk queue of below-floor &amp; unapproved quotes.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Margin-status distribution</h2>
        <DataTable
          rows={marginRows}
          columns={marginCols}
          emptyMessage="No quotes logged yet."
          rowKey={(r, i) => String(r.margin_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Pricing-tier scorecard</h2>
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No pricing-tier rollups."
          rowKey={(r, i) => String(r.pricing_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Pricing-tier &times; margin-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No quotes by tier."
          rowKey={(r, i) => `${r.pricing_tier}-${r.margin_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly margin trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Margin-impact digest (per engineer)</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No margin-impact rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk quote queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk quotes."
          rowKey={(r, i) => `${r.quote_ref}-${i}`}
        />
      </section>
    </main>
  );
}
