import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { recon_verdict: string; cycles: number; pct: number };
type RegionRow = {
  region: string;
  total_cycles: number;
  clean: number;
  minor_gaps: number;
  major_gaps: number;
  total_unreconciled_rupees: number;
  total_missing_receipts: number;
  clean_pct: number;
};
type MatrixRow = {
  top_spend_category: string;
  settlement_status: string;
  cycles: number;
  clean: number;
  avg_spent_rupees: number;
  avg_unreconciled_rupees: number;
};
type TrendRow = {
  cycle_month: string;
  cycles: number;
  clean: number;
  major_gaps: number;
  total_unreconciled_rupees: number;
  total_missing_receipts: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_recovery_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_recovery_rupees: number;
  pct: number;
};
type ImpactRow = {
  financial_impact: string;
  findings: number;
  open_findings: number;
  total_recovery_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  cycle_month: string;
  unreconciled_rupees: number;
  missing_receipt_count: number;
  top_spend_category: string;
  policy_violation: string | null;
  settlement_status: string | null;
  recon_verdict: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3268_recon_verdict_rollup'),
    supabase.rpc('founder_r3268_region_scorecard'),
    supabase.rpc('founder_r3268_category_settlement_matrix'),
    supabase.rpc('founder_r3268_monthly_recon_trend'),
    supabase.rpc('founder_r3268_capa_status_board'),
    supabase.rpc('founder_r3268_root_cause_pareto'),
    supabase.rpc('founder_r3268_financial_impact_digest'),
    supabase.rpc('founder_r3268_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'recon_verdict', header: 'Recon Verdict' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_cycles', header: 'Cycles' },
    { key: 'clean', header: 'Clean' },
    { key: 'minor_gaps', header: 'Minor Gaps' },
    { key: 'major_gaps', header: 'Major / Escalated' },
    { key: 'total_unreconciled_rupees', header: 'Unreconciled (INR)' },
    { key: 'total_missing_receipts', header: 'Missing Receipts' },
    { key: 'clean_pct', header: 'Clean %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'top_spend_category', header: 'Spend Category' },
    { key: 'settlement_status', header: 'Settlement' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'clean', header: 'Clean' },
    { key: 'avg_spent_rupees', header: 'Avg Spent (INR)' },
    { key: 'avg_unreconciled_rupees', header: 'Avg Unreconciled (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cycle_month', header: 'Cycle Month' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'clean', header: 'Clean' },
    { key: 'major_gaps', header: 'Major / Escalated' },
    { key: 'total_unreconciled_rupees', header: 'Unreconciled (INR)' },
    { key: 'total_missing_receipts', header: 'Missing Receipts' },
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
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'cycle_month', header: 'Cycle' },
    { key: 'unreconciled_rupees', header: 'Unreconciled (INR)' },
    { key: 'missing_receipt_count', header: 'Missing Receipts' },
    { key: 'top_spend_category', header: 'Top Category' },
    { key: 'policy_violation', header: 'Policy Violation' },
    { key: 'settlement_status', header: 'Settlement' },
    { key: 'recon_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Field Petty-Cash Float &amp; Expense-Reconciliation Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-ops cash discipline — float issued &times; spend &times; receipts submitted &times;
        unreconciled balance &times; missing-receipt count &times; spend category &times; policy
        violation &times; settlement status &times; reconciliation verdict &amp; CAPA recovery.
        Founder-gated view: recon verdicts, region scorecards, root-cause pareto, and
        financial-impact digest across salary-recovery &amp; write-off surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Reconciliation verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No float cycles logged yet."
          rowKey={(r, i) => String(r.recon_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region reconciliation scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Spend category &times; settlement matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cycles by category."
          rowKey={(r, i) => `${r.top_spend_category}-${r.settlement_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly reconciliation trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.cycle_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No financial-impact rollups."
          rowKey={(r, i) => String(r.financial_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk reconciliation queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cycles."
          rowKey={(r, i) => `${r.engineer_name}-${r.cycle_month}-${i}`}
        />
      </section>
    </main>
  );
}
