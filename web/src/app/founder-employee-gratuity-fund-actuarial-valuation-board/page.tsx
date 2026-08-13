import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { funding_status: string; records: number; pct: number };
type EntityRow = {
  entity_name: string;
  records: number;
  fully_funded: number;
  adequately_funded: number;
  funding_gap: number;
  significant_deficit: number;
  valuation_overdue: number;
  total_dbo_rupees: number | null;
  total_fva_rupees: number | null;
  avg_discount_rate_pct: number | null;
};
type MatrixRow = {
  valuation_class: string;
  funding_status: string;
  records: number;
  avg_funding_gap_rupees: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  total_dbo_rupees: number | null;
  total_fva_rupees: number | null;
  total_funding_gap_rupees: number | null;
  significant_deficit_records: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  entity_name: string;
  records: number;
  funding_gap_records: number;
  significant_deficit_records: number;
  avg_funding_gap_rupees: number | null;
  total_funding_gap_rupees: number | null;
};
type RiskRow = {
  entity_name: string;
  valuation_date: string;
  period_month: string;
  valuation_class: string;
  funding_status: string;
  funding_gap_rupees: number | null;
  discount_rate_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    entityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3748_funding_status_rollup'),
    supabase.rpc('founder_r3748_entity_scorecard'),
    supabase.rpc('founder_r3748_valuation_class_status_matrix'),
    supabase.rpc('founder_r3748_monthly_funding_gap_trend'),
    supabase.rpc('founder_r3748_capa_status_board'),
    supabase.rpc('founder_r3748_root_cause_pareto'),
    supabase.rpc('founder_r3748_deficit_digest'),
    supabase.rpc('founder_r3748_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'funding_status', header: 'Funding Status' },
    { key: 'records', header: 'Valuations' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'records', header: 'Valuations' },
    { key: 'fully_funded', header: 'Fully Funded' },
    { key: 'adequately_funded', header: 'Adequately Funded' },
    { key: 'funding_gap', header: 'Funding Gap' },
    { key: 'significant_deficit', header: 'Significant Deficit' },
    { key: 'valuation_overdue', header: 'Valuation Overdue' },
    { key: 'total_dbo_rupees', header: 'Total DBO (Rs)' },
    { key: 'total_fva_rupees', header: 'Total Plan Assets (Rs)' },
    { key: 'avg_discount_rate_pct', header: 'Avg Discount Rate %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'valuation_class', header: 'Valuation Class' },
    { key: 'funding_status', header: 'Funding Status' },
    { key: 'records', header: 'Valuations' },
    { key: 'avg_funding_gap_rupees', header: 'Avg Funding Gap (Rs)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Valuations' },
    { key: 'total_dbo_rupees', header: 'Total DBO (Rs)' },
    { key: 'total_fva_rupees', header: 'Total Plan Assets (Rs)' },
    { key: 'total_funding_gap_rupees', header: 'Total Funding Gap (Rs)' },
    { key: 'significant_deficit_records', header: 'Significant Deficit' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'records', header: 'Valuations' },
    { key: 'funding_gap_records', header: 'Funding Gap' },
    { key: 'significant_deficit_records', header: 'Significant Deficit' },
    { key: 'avg_funding_gap_rupees', header: 'Avg Funding Gap (Rs)' },
    { key: 'total_funding_gap_rupees', header: 'Total Funding Gap (Rs)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'valuation_date', header: 'Valuation Date' },
    { key: 'period_month', header: 'Month' },
    { key: 'valuation_class', header: 'Valuation Class' },
    { key: 'funding_status', header: 'Funding Status' },
    { key: 'funding_gap_rupees', header: 'Funding Gap (Rs)' },
    { key: 'discount_rate_pct', header: 'Discount Rate %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Employee Gratuity Fund Actuarial Valuation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Company-wide employee gratuity defined-benefit obligation &mdash; actuarial valuation
        (Ind AS 19), fund adequacy, discount-rate sensitivity, and funding gap per entity.
        Distinct from any employee-exit full-final-settlement-gratuity page, which tracks
        per-employee EXIT settlement processing &amp; TAT, not company-wide actuarial fund
        valuation. Founder-gated view: funding-status distribution, entity scorecards,
        valuation-class &times; status matrix, monthly funding-gap trend, CAPA status board,
        root-cause pareto, a deficit digest, and a high-risk queue of significant-deficit &amp;
        overdue valuations.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Funding-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No actuarial valuation rows logged yet."
          rowKey={(r, i) => String(r.funding_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Valuation class &times; funding status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No valuations by class."
          rowKey={(r, i) => `${r.valuation_class}-${r.funding_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly funding-gap trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Deficit digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No funding-gap or significant-deficit entities."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk valuations."
          rowKey={(r, i) => `${r.entity_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
