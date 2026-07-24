import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { roi_verdict: string; assets: number; pct: number };
type ScoreRow = {
  asset_category: string;
  assets: number;
  total_capex_rupees: number;
  total_actual_return_rupees: number;
  underperforming: number;
  write_off_review: number;
  avg_utilization_pct: number;
  avg_roi_variance_pct: number;
};
type MatrixRow = { asset_category: string; benefit_realization: string; assets: number; total_capex_rupees: number; avg_roi_variance_pct: number };
type TrendRow = { commissioned_month: string; assets: number; total_capex_rupees: number; underperforming: number; avg_roi_variance_pct: number };
type CapaRow = { capa_status: string; findings: number; avg_recovery_rupees: number; overdue_flag: number };
type CauseRow = { root_cause: string; occurrences: number; total_recovery_rupees: number; pct: number };
type ImpactRow = { financial_impact: string; findings: number; open_findings: number; total_recovery_rupees: number };
type RiskRow = {
  asset_name: string;
  asset_category: string;
  business_case_ref: string;
  capex_amount_rupees: number;
  actual_annual_return_rupees: number;
  utilization_pct: number;
  roi_variance_pct: number;
  benefit_realization: string;
  roi_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [verdictRes, scoreRes, matrixRes, trendRes, capaRes, causeRes, impactRes, riskRes] = await Promise.all([
    supabase.rpc('founder_r3393_roi_verdict_rollup'),
    supabase.rpc('founder_r3393_category_scorecard'),
    supabase.rpc('founder_r3393_category_realization_matrix'),
    supabase.rpc('founder_r3393_commissioning_trend'),
    supabase.rpc('founder_r3393_capa_status_board'),
    supabase.rpc('founder_r3393_root_cause_pareto'),
    supabase.rpc('founder_r3393_financial_impact_digest'),
    supabase.rpc('founder_r3393_high_risk_queue'),
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
    { key: 'roi_verdict', header: 'ROI Verdict' },
    { key: 'assets', header: 'Assets' },
    { key: 'pct', header: 'Share %' },
  ];
  const scoreCols: Column<ScoreRow>[] = [
    { key: 'asset_category', header: 'Asset Category' },
    { key: 'assets', header: 'Assets' },
    { key: 'total_capex_rupees', header: 'Capex (INR)' },
    { key: 'total_actual_return_rupees', header: 'Actual Return (INR)' },
    { key: 'underperforming', header: 'Underperforming' },
    { key: 'write_off_review', header: 'Write-off Review' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'avg_roi_variance_pct', header: 'Avg ROI Var %' },
  ];
  const matrixCols: Column<MatrixRow>[] = [
    { key: 'asset_category', header: 'Asset Category' },
    { key: 'benefit_realization', header: 'Benefit Realization' },
    { key: 'assets', header: 'Assets' },
    { key: 'total_capex_rupees', header: 'Capex (INR)' },
    { key: 'avg_roi_variance_pct', header: 'Avg ROI Var %' },
  ];
  const trendCols: Column<TrendRow>[] = [
    { key: 'commissioned_month', header: 'Commissioned' },
    { key: 'assets', header: 'Assets' },
    { key: 'total_capex_rupees', header: 'Capex (INR)' },
    { key: 'underperforming', header: 'Underperforming' },
    { key: 'avg_roi_variance_pct', header: 'Avg ROI Var %' },
  ];
  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_recovery_rupees', header: 'Avg Recovery (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];
  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_recovery_rupees', header: 'Total Recovery (INR)' },
    { key: 'pct', header: 'Share %' },
  ];
  const impactCols: Column<ImpactRow>[] = [
    { key: 'financial_impact', header: 'Financial Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_recovery_rupees', header: 'Total Recovery (INR)' },
  ];
  const riskCols: Column<RiskRow>[] = [
    { key: 'asset_name', header: 'Asset' },
    { key: 'asset_category', header: 'Category' },
    { key: 'business_case_ref', header: 'Business Case' },
    { key: 'capex_amount_rupees', header: 'Capex (INR)' },
    { key: 'actual_annual_return_rupees', header: 'Actual Return (INR)' },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'roi_variance_pct', header: 'ROI Var %' },
    { key: 'benefit_realization', header: 'Realization' },
    { key: 'roi_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Capex / Equipment-Investment ROI Post-Implementation-Audit Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Post-implementation review of capex investments &mdash; asset category &times; business case &times;
        projected vs actual return &times; payback slippage &times; utilization &times; ROI variance &times;
        benefit realization &amp; CAPA. Founder-gated view: ROI-verdict rollup, category scorecard, category
        &times; realization matrix, and underperforming-asset queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. ROI verdict distribution</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No capex assets audited yet." rowKey={(r, i) => String(r.roi_verdict ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Asset-category scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No category rollups." rowKey={(r, i) => String(r.asset_category ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; benefit-realization matrix</h2>
        <DataTable rows={matrixRows} columns={matrixCols} emptyMessage="No matrix data." rowKey={(r, i) => `${r.asset_category}-${r.benefit_realization}-${i}`} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Commissioning-cohort trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data." rowKey={(r, i) => String(r.commissioned_month ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable rows={capaRows} columns={capaCols} emptyMessage="No CAPA findings." rowKey={(r, i) => String(r.capa_status ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable rows={causeRows} columns={causeCols} emptyMessage="No root-cause data." rowKey={(r, i) => String(r.root_cause ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial-impact digest</h2>
        <DataTable rows={impactRows} columns={impactCols} emptyMessage="No financial-impact rollups." rowKey={(r, i) => String(r.financial_impact ?? i)} />
      </section>
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Underperforming-asset queue</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No underperforming assets." rowKey={(r, i) => `${r.business_case_ref}-${i}`} />
      </section>
    </main>
  );
}
