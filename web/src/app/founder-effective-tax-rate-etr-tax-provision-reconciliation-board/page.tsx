import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { provision_status: string; provisions: number; pct: number };
type EntityRow = {
  entity: string;
  total_provisions: number;
  reconciled: number;
  under_provided: number;
  over_provided: number;
  disputed: number;
  avg_effective_rate_pct: number;
  avg_variance_pct: number;
};
type MatrixRow = {
  reconciling_item: string;
  provision_status: string;
  provisions: number;
  avg_variance_pct: number;
  total_tax_rupees: number;
};
type TrendRow = {
  period_month: string;
  provisions: number;
  avg_statutory_rate_pct: number;
  avg_effective_rate_pct: number;
  avg_variance_pct: number;
  total_tax_rupees: number;
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
  finding_category: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  entity: string;
  provision_ref: string;
  period_month: string;
  reconciling_item: string;
  provision_status: string;
  effective_rate_pct: number;
  rate_variance_pct: number;
  total_tax_rupees: number;
  trend_dir: string | null;
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
    supabase.rpc('founder_r3497_provision_status_rollup'),
    supabase.rpc('founder_r3497_entity_scorecard'),
    supabase.rpc('founder_r3497_reconciling_item_status_matrix'),
    supabase.rpc('founder_r3497_monthly_etr_trend'),
    supabase.rpc('founder_r3497_capa_status_board'),
    supabase.rpc('founder_r3497_root_cause_pareto'),
    supabase.rpc('founder_r3497_tax_impact_digest'),
    supabase.rpc('founder_r3497_high_risk_queue'),
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
    { key: 'provision_status', header: 'Provision Status' },
    { key: 'provisions', header: 'Provisions' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity', header: 'Entity' },
    { key: 'total_provisions', header: 'Provisions' },
    { key: 'reconciled', header: 'Reconciled' },
    { key: 'under_provided', header: 'Under-Provided' },
    { key: 'over_provided', header: 'Over-Provided' },
    { key: 'disputed', header: 'Disputed' },
    { key: 'avg_effective_rate_pct', header: 'Avg ETR %' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'reconciling_item', header: 'Reconciling Item' },
    { key: 'provision_status', header: 'Provision Status' },
    { key: 'provisions', header: 'Provisions' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
    { key: 'total_tax_rupees', header: 'Total Tax (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'provisions', header: 'Provisions' },
    { key: 'avg_statutory_rate_pct', header: 'Avg Statutory %' },
    { key: 'avg_effective_rate_pct', header: 'Avg ETR %' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
    { key: 'total_tax_rupees', header: 'Total Tax (INR)' },
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
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity', header: 'Entity' },
    { key: 'provision_ref', header: 'Provision Ref' },
    { key: 'period_month', header: 'Period' },
    { key: 'reconciling_item', header: 'Reconciling Item' },
    { key: 'provision_status', header: 'Status' },
    { key: 'effective_rate_pct', header: 'ETR %' },
    { key: 'rate_variance_pct', header: 'Variance %' },
    { key: 'total_tax_rupees', header: 'Total Tax (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Effective-Tax-Rate (ETR) / Tax-Provision Reconciliation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated book-vs-tax reconciliation across entities &amp; periods &mdash; pretax profit
        &times; current, deferred &amp; total tax &times; statutory vs effective rate &times; rate
        variance &times; reconciling item (permanent &amp; timing differences, MAT credit, exempt
        income, disallowance, prior period) &times; provision status &amp; trend, with CAPA closure.
        Views: provision-status distribution, entity scorecards, reconciling-item &times; status
        matrix, monthly ETR trend, root-cause pareto, and a high-risk queue of under-provided,
        disputed &amp; high-variance provisions.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Provision status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No provisions logged yet."
          rowKey={(r, i) => String(r.provision_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity ETR scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Reconciling item &times; provision status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No reconciling-item breakdown."
          rowKey={(r, i) => `${r.reconciling_item}-${r.provision_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly ETR trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Tax-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No tax-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk provision queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk provisions."
          rowKey={(r, i) => `${r.provision_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
