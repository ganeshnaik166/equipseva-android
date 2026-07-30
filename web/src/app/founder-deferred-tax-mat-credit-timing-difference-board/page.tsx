import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { dt_status: string; entries: number; pct: number };
type EntityRow = {
  entity_name: string;
  total_entries: number;
  dta_dominant: number;
  dtl_dominant: number;
  mat_credit_risk: number;
  unrecognized_dta: number;
  net_deferred_tax_rupees: number;
  mat_credit_outstanding_rupees: number;
  avg_effective_tax_rate_pct: number;
};
type MatrixRow = {
  entity_name: string;
  dt_status: string;
  entries: number;
  net_deferred_tax_rupees: number;
  timing_difference_rupees: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  net_deferred_tax_rupees: number;
  dta_rupees: number;
  dtl_rupees: number;
  mat_credit_rupees: number;
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
  trend_dir: string;
  entries: number;
  total_timing_difference_rupees: number;
  total_net_deferred_tax_rupees: number;
  avg_effective_tax_rate_pct: number;
};
type RiskRow = {
  entity_name: string;
  entry_code: string;
  period_month: string;
  dt_status: string;
  trend_dir: string;
  timing_difference_rupees: number;
  net_deferred_tax_rupees: number;
  mat_credit_rupees: number;
  effective_tax_rate_pct: number;
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
    supabase.rpc('founder_r3606_dt_status_rollup'),
    supabase.rpc('founder_r3606_entity_scorecard'),
    supabase.rpc('founder_r3606_entity_status_matrix'),
    supabase.rpc('founder_r3606_monthly_deferred_tax_trend'),
    supabase.rpc('founder_r3606_capa_status_board'),
    supabase.rpc('founder_r3606_root_cause_pareto'),
    supabase.rpc('founder_r3606_timing_difference_digest'),
    supabase.rpc('founder_r3606_high_risk_queue'),
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
    { key: 'dt_status', header: 'Deferred-Tax Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity / Segment' },
    { key: 'total_entries', header: 'Entries' },
    { key: 'dta_dominant', header: 'DTA-Dom' },
    { key: 'dtl_dominant', header: 'DTL-Dom' },
    { key: 'mat_credit_risk', header: 'MAT Risk' },
    { key: 'unrecognized_dta', header: 'Unrecog DTA' },
    { key: 'net_deferred_tax_rupees', header: 'Net Deferred Tax (INR)' },
    { key: 'mat_credit_outstanding_rupees', header: 'MAT Credit O/S (INR)' },
    { key: 'avg_effective_tax_rate_pct', header: 'Avg ETR %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'entity_name', header: 'Entity / Segment' },
    { key: 'dt_status', header: 'Deferred-Tax Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'net_deferred_tax_rupees', header: 'Net Deferred Tax (INR)' },
    { key: 'timing_difference_rupees', header: 'Timing Diff (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'entries', header: 'Entries' },
    { key: 'net_deferred_tax_rupees', header: 'Net Deferred Tax (INR)' },
    { key: 'dta_rupees', header: 'DTA (INR)' },
    { key: 'dtl_rupees', header: 'DTL (INR)' },
    { key: 'mat_credit_rupees', header: 'MAT Credit (INR)' },
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
    { key: 'trend_dir', header: 'Trend' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_timing_difference_rupees', header: 'Total Timing Diff (INR)' },
    { key: 'total_net_deferred_tax_rupees', header: 'Total Net Deferred Tax (INR)' },
    { key: 'avg_effective_tax_rate_pct', header: 'Avg ETR %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_name', header: 'Entity / Segment' },
    { key: 'entry_code', header: 'Entry' },
    { key: 'period_month', header: 'Period' },
    { key: 'dt_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'timing_difference_rupees', header: 'Timing Diff (INR)' },
    { key: 'net_deferred_tax_rupees', header: 'Net Deferred Tax (INR)' },
    { key: 'mat_credit_rupees', header: 'MAT Credit (INR)' },
    { key: 'effective_tax_rate_pct', header: 'ETR %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Deferred-Tax / MAT-Credit / Timing-Difference Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated deferred-tax view across entities and segments (AMC services, spare parts,
        turnkey projects, diagnostics, rentals, biomedical engineering, imports &amp; distribution)
        &mdash; accounting profit &times; taxable profit &times; book-vs-tax timing difference
        &times; DTA &amp; DTL &times; net deferred tax &times; MAT credit build &amp; utilization
        &times; effective tax rate &times; deferred-tax status &amp; trend, with CAPA closure.
        Surfaces status distribution, entity scorecards, root-cause pareto, and a high-risk queue
        for MAT-credit-risk &amp; unrecognized-DTA positions.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Deferred-tax status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No deferred-tax entries logged yet."
          rowKey={(r, i) => String(r.dt_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity deferred-tax scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Entity &times; deferred-tax status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by entity."
          rowKey={(r, i) => `${r.entity_name}-${r.dt_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly deferred-tax trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Timing-difference digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No timing-difference data."
          rowKey={(r, i) => String(r.trend_dir ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk deferred-tax queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk entries."
          rowKey={(r, i) => `${r.entry_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
