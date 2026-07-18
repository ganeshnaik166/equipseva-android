import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { property_verdict: string; properties: number; pct: number };
type ScoreRow = {
  property_type: string;
  total_properties: number;
  healthy: number;
  at_risk: number;
  ssl_invalid: number;
  total_monthly_visits: number;
  avg_uptime_pct: number;
  total_unanswered_reviews: number;
  total_lead_conversions: number;
  healthy_pct: number;
};
type MatrixRow = {
  property_type: string;
  owner_team: string;
  properties: number;
  healthy: number;
  avg_monthly_visits: number;
  avg_page_load_seconds: number;
};
type TrendRow = {
  last_updated_date: string;
  properties: number;
  healthy: number;
  at_risk: number;
  total_monthly_visits: number;
  total_lead_conversions: number;
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
  business_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  property_name: string;
  property_type: string;
  owner_team: string;
  last_updated_date: string;
  property_verdict: string;
  avg_position: number | null;
  uptime_pct: number | null;
  ssl_valid: boolean | null;
  unanswered_reviews: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3285_property_verdict_rollup'),
    supabase.rpc('founder_r3285_property_type_scorecard'),
    supabase.rpc('founder_r3285_type_owner_matrix'),
    supabase.rpc('founder_r3285_daily_update_trend'),
    supabase.rpc('founder_r3285_capa_status_board'),
    supabase.rpc('founder_r3285_root_cause_pareto'),
    supabase.rpc('founder_r3285_business_impact_digest'),
    supabase.rpc('founder_r3285_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'property_verdict', header: 'Verdict' },
    { key: 'properties', header: 'Properties' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'property_type', header: 'Property Type' },
    { key: 'total_properties', header: 'Properties' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'ssl_invalid', header: 'SSL Invalid' },
    { key: 'total_monthly_visits', header: 'Monthly Visits' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'total_unanswered_reviews', header: 'Unanswered Reviews' },
    { key: 'total_lead_conversions', header: 'Lead Conversions' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'property_type', header: 'Property Type' },
    { key: 'owner_team', header: 'Owner Team' },
    { key: 'properties', header: 'Properties' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'avg_monthly_visits', header: 'Avg Monthly Visits' },
    { key: 'avg_page_load_seconds', header: 'Avg Page Load (s)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'last_updated_date', header: 'Last Updated' },
    { key: 'properties', header: 'Properties' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'total_monthly_visits', header: 'Monthly Visits' },
    { key: 'total_lead_conversions', header: 'Lead Conversions' },
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
    { key: 'business_impact', header: 'Business Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'property_name', header: 'Property' },
    { key: 'property_type', header: 'Type' },
    { key: 'owner_team', header: 'Owner' },
    { key: 'last_updated_date', header: 'Last Updated' },
    { key: 'property_verdict', header: 'Verdict' },
    { key: 'avg_position', header: 'SEO Position' },
    { key: 'uptime_pct', header: 'Uptime %' },
    { key: 'ssl_valid', header: 'SSL Valid' },
    { key: 'unanswered_reviews', header: 'Unanswered Reviews' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Digital-Presence, Website/SEO Health &amp; Online-Reputation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Marketing governance view — digital property &times; owner team &times; SEO rank &times;
        uptime &amp; SSL &times; page-speed &times; reviews &amp; reputation &times; lead conversion
        &amp; CAPA closure. Founder-gated: verdict rollups, property-type scorecards, root-cause
        pareto, and business-impact digest across EquipSeva&rsquo;s website, listings, and
        online-reputation surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Property verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No digital properties logged yet."
          rowKey={(r, i) => String(r.property_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Property-type scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No property-type rollups."
          rowKey={(r, i) => String(r.property_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Property-type &times; owner-team matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No properties by type and team."
          rowKey={(r, i) => `${r.property_type}-${r.owner_team}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Freshness trend (by last-updated)</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.last_updated_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Business-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No business-impact rollups."
          rowKey={(r, i) => String(r.business_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk property queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk properties."
          rowKey={(r, i) => `${r.property_name}-${r.last_updated_date}-${i}`}
        />
      </section>
    </main>
  );
}
