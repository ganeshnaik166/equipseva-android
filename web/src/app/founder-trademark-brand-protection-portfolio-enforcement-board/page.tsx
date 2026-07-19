import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { brand_verdict: string; assets: number; pct: number };
type ScoreRow = {
  jurisdiction: string;
  total_assets: number;
  registered: number;
  pending: number;
  opposed: number;
  expired_abandoned: number;
  enforcement_open: number;
  lapse_risk: number;
  registered_pct: number;
};
type MatrixRow = {
  asset_type: string;
  jurisdiction: string;
  assets: number;
  protected: number;
  avg_days_to_renewal: number;
  total_exposure_rupees: number;
};
type TrendRow = {
  renewal_due_date: string;
  assets: number;
  renewal_action: number;
  lapse_risk: number;
  enforcement_needed: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type LegalRow = {
  legal_impact: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type RiskRow = {
  asset_name: string;
  asset_type: string;
  jurisdiction: string;
  registration_status: string;
  renewal_due_date: string | null;
  days_to_renewal: number | null;
  infringement_matter: string | null;
  enforcement_status: string | null;
  brand_verdict: string;
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
    legalRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3365_brand_verdict_rollup'),
    supabase.rpc('founder_r3365_jurisdiction_scorecard'),
    supabase.rpc('founder_r3365_type_jurisdiction_matrix'),
    supabase.rpc('founder_r3365_renewal_due_trend'),
    supabase.rpc('founder_r3365_capa_status_board'),
    supabase.rpc('founder_r3365_root_cause_pareto'),
    supabase.rpc('founder_r3365_legal_impact_digest'),
    supabase.rpc('founder_r3365_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const legalRows: LegalRow[] = (legalRes.data as LegalRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'brand_verdict', header: 'Brand Verdict' },
    { key: 'assets', header: 'Assets' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'jurisdiction', header: 'Jurisdiction' },
    { key: 'total_assets', header: 'Assets' },
    { key: 'registered', header: 'Registered' },
    { key: 'pending', header: 'Pending' },
    { key: 'opposed', header: 'Opposed/Objected' },
    { key: 'expired_abandoned', header: 'Expired/Abandoned' },
    { key: 'enforcement_open', header: 'Enforcement Open' },
    { key: 'lapse_risk', header: 'Lapse Risk' },
    { key: 'registered_pct', header: 'Registered %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'asset_type', header: 'Asset Type' },
    { key: 'jurisdiction', header: 'Jurisdiction' },
    { key: 'assets', header: 'Assets' },
    { key: 'protected', header: 'Protected' },
    { key: 'avg_days_to_renewal', header: 'Avg Days to Renewal' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'renewal_due_date', header: 'Renewal Due' },
    { key: 'assets', header: 'Assets' },
    { key: 'renewal_action', header: 'Renewal Action' },
    { key: 'lapse_risk', header: 'Lapse Risk' },
    { key: 'enforcement_needed', header: 'Enforcement Needed' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const legalCols: Column<LegalRow>[] = [
    { key: 'legal_impact', header: 'Legal Impact' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'asset_name', header: 'Asset' },
    { key: 'asset_type', header: 'Type' },
    { key: 'jurisdiction', header: 'Jurisdiction' },
    { key: 'registration_status', header: 'Status' },
    { key: 'renewal_due_date', header: 'Renewal Due' },
    { key: 'days_to_renewal', header: 'Days to Renewal' },
    { key: 'infringement_matter', header: 'Infringement' },
    { key: 'enforcement_status', header: 'Enforcement' },
    { key: 'brand_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Trademark &amp; Brand-Protection Portfolio &amp; Enforcement Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        IP/brand governance log — asset type &times; jurisdiction &times; registration status &times;
        renewal timeline &times; infringement matter &times; enforcement status &times; estimated
        exposure &times; brand verdict &amp; CAPA closure. Founder-gated view: verdict rollups,
        jurisdiction scorecards, root-cause pareto, and legal-impact digest across IP-India, Madrid,
        USA, UAE &amp; Singapore surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Brand verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No brand assets logged yet."
          rowKey={(r, i) => String(r.brand_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Jurisdiction portfolio scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No jurisdiction rollups."
          rowKey={(r, i) => String(r.jurisdiction ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Asset-type &times; jurisdiction matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No assets by type."
          rowKey={(r, i) => `${r.asset_type}-${r.jurisdiction}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Renewal-due timeline trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No renewal timeline data."
          rowKey={(r, i) => String(r.renewal_due_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Legal impact digest</h2>
        <DataTable
          rows={legalRows}
          columns={legalCols}
          emptyMessage="No legal-impact rollups."
          rowKey={(r, i) => String(r.legal_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk brand-protection queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk assets."
          rowKey={(r, i) => `${r.asset_name}-${r.jurisdiction}-${i}`}
        />
      </section>
    </main>
  );
}
