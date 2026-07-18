import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { asset_verdict: string; assets: number; pct: number };
type LocationRow = {
  location_city: string;
  total_assets: number;
  in_use_healthy: number;
  underutilized: number;
  impairment_review: number;
  disposal_candidate: number;
  not_located: number;
  net_book_value_rupees: number;
  insured_pct: number;
};
type MatrixRow = {
  asset_class: string;
  depreciation_method: string;
  assets: number;
  capitalized_cost_rupees: number;
  net_book_value_rupees: number;
  avg_useful_life_years: number;
};
type TrendRow = {
  acquisition_date: string;
  assets: number;
  capitalized_cost_rupees: number;
  net_book_value_rupees: number;
  impairment_review: number;
  disposal_candidate: number;
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
type GovRow = {
  governance_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  asset_tag: string;
  asset_class: string;
  location_city: string;
  acquisition_date: string;
  net_book_value_rupees: number;
  physical_verification_status: string;
  insured: boolean;
  asset_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    locationRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    govRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3273_asset_verdict_rollup'),
    supabase.rpc('founder_r3273_location_scorecard'),
    supabase.rpc('founder_r3273_class_method_matrix'),
    supabase.rpc('founder_r3273_acquisition_trend'),
    supabase.rpc('founder_r3273_capa_status_board'),
    supabase.rpc('founder_r3273_root_cause_pareto'),
    supabase.rpc('founder_r3273_governance_impact_digest'),
    supabase.rpc('founder_r3273_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const locationRows: LocationRow[] = (locationRes.data as LocationRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const govRows: GovRow[] = (govRes.data as GovRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'asset_verdict', header: 'Asset Verdict' },
    { key: 'assets', header: 'Assets' },
    { key: 'pct', header: 'Share %' },
  ];

  const locationCols: Column<LocationRow>[] = [
    { key: 'location_city', header: 'Location' },
    { key: 'total_assets', header: 'Assets' },
    { key: 'in_use_healthy', header: 'In-Use Healthy' },
    { key: 'underutilized', header: 'Underutilized' },
    { key: 'impairment_review', header: 'Impairment Review' },
    { key: 'disposal_candidate', header: 'Disposal Candidate' },
    { key: 'not_located', header: 'Not Located' },
    { key: 'net_book_value_rupees', header: 'Net Book Value (INR)' },
    { key: 'insured_pct', header: 'Insured %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'asset_class', header: 'Asset Class' },
    { key: 'depreciation_method', header: 'Depreciation Method' },
    { key: 'assets', header: 'Assets' },
    { key: 'capitalized_cost_rupees', header: 'Capitalized Cost (INR)' },
    { key: 'net_book_value_rupees', header: 'Net Book Value (INR)' },
    { key: 'avg_useful_life_years', header: 'Avg Useful Life (yrs)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'acquisition_date', header: 'Acquisition Date' },
    { key: 'assets', header: 'Assets' },
    { key: 'capitalized_cost_rupees', header: 'Capitalized Cost (INR)' },
    { key: 'net_book_value_rupees', header: 'Net Book Value (INR)' },
    { key: 'impairment_review', header: 'Impairment Review' },
    { key: 'disposal_candidate', header: 'Disposal Candidate' },
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

  const govCols: Column<GovRow>[] = [
    { key: 'governance_impact', header: 'Governance Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'asset_tag', header: 'Asset Tag' },
    { key: 'asset_class', header: 'Class' },
    { key: 'location_city', header: 'Location' },
    { key: 'acquisition_date', header: 'Acquired' },
    { key: 'net_book_value_rupees', header: 'Net Book Value (INR)' },
    { key: 'physical_verification_status', header: 'Phys. Verification' },
    { key: 'insured', header: 'Insured' },
    { key: 'asset_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Fixed-Asset Register, Depreciation &amp; Capex Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Fixed-asset register — asset class &times; depreciation method (SLM / WDV) &times;
        capitalized cost &times; accumulated depreciation &times; net book value &times; physical
        verification &times; insurance cover &times; capex approval &times; asset verdict &amp; CAPA
        closure. Founder-gated view: verdict rollups, location scorecards, root-cause pareto, and
        governance-impact digest across statutory-audit &amp; Ind-AS impairment surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Asset verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No fixed assets registered yet."
          rowKey={(r, i) => String(r.asset_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Location asset scorecard</h2>
        <DataTable
          rows={locationRows}
          columns={locationCols}
          emptyMessage="No location rollups."
          rowKey={(r, i) => String(r.location_city ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Asset class &times; depreciation method matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No assets by class."
          rowKey={(r, i) => `${r.asset_class}-${r.depreciation_method}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Acquisition-date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.acquisition_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Governance impact digest</h2>
        <DataTable
          rows={govRows}
          columns={govCols}
          emptyMessage="No governance-impact rollups."
          rowKey={(r, i) => String(r.governance_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk asset queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk assets."
          rowKey={(r, i) => `${r.asset_tag}-${i}`}
        />
      </section>
    </main>
  );
}
