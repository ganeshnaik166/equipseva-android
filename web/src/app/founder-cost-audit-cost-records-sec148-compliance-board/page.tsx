import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  compliance_status: string;
  records: number;
  observations: number;
  pct: number;
};
type GroupRow = {
  product_group: string;
  total_records: number;
  compliant: number;
  records_gap: number;
  non_compliant: number;
  observations: number;
  records_maintained: number;
  avg_variance_pct: number;
  compliant_pct: number;
};
type MatrixRow = {
  product_group: string;
  compliance_status: string;
  records: number;
  observations: number;
  total_under_over_absorption_rupees: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  compliant: number;
  non_compliant: number;
  records_gap: number;
  observations: number;
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
  product_group: string;
  records: number;
  total_material_cost_rupees: number;
  total_conversion_cost_rupees: number;
  total_overhead_absorbed_rupees: number;
  total_under_over_absorption_rupees: number;
  avg_variance_pct: number;
};
type RiskRow = {
  record_ref: string;
  cost_centre: string;
  product_group: string;
  period_month: string;
  compliance_status: string;
  cost_records_maintained: boolean | null;
  reconciliation_variance_pct: number | null;
  under_over_absorption_rupees: number | null;
  observations_count: number | null;
  filing_due_date: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    groupRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3633_compliance_status_rollup'),
    supabase.rpc('founder_r3633_product_group_scorecard'),
    supabase.rpc('founder_r3633_product_group_status_matrix'),
    supabase.rpc('founder_r3633_monthly_compliance_trend'),
    supabase.rpc('founder_r3633_capa_status_board'),
    supabase.rpc('founder_r3633_root_cause_pareto'),
    supabase.rpc('founder_r3633_absorption_variance_digest'),
    supabase.rpc('founder_r3633_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const groupRows: GroupRow[] = (groupRes.data as GroupRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'observations', header: 'Observations' },
    { key: 'pct', header: 'Share %' },
  ];

  const groupCols: Column<GroupRow>[] = [
    { key: 'product_group', header: 'Product Group' },
    { key: 'total_records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'records_gap', header: 'Records Gap' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'observations', header: 'Observations' },
    { key: 'records_maintained', header: 'Records Maintained' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'product_group', header: 'Product Group' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'observations', header: 'Observations' },
    { key: 'total_under_over_absorption_rupees', header: 'Under/Over Absorption (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'records_gap', header: 'Records Gap' },
    { key: 'observations', header: 'Observations' },
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
    { key: 'product_group', header: 'Product Group' },
    { key: 'records', header: 'Records' },
    { key: 'total_material_cost_rupees', header: 'Material Cost (INR)' },
    { key: 'total_conversion_cost_rupees', header: 'Conversion Cost (INR)' },
    { key: 'total_overhead_absorbed_rupees', header: 'Overhead Absorbed (INR)' },
    { key: 'total_under_over_absorption_rupees', header: 'Under/Over Absorption (INR)' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'record_ref', header: 'Record' },
    { key: 'cost_centre', header: 'Cost Centre' },
    { key: 'product_group', header: 'Product Group' },
    { key: 'period_month', header: 'Period' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'cost_records_maintained', header: 'Records Maintained' },
    { key: 'reconciliation_variance_pct', header: 'Variance %' },
    { key: 'under_over_absorption_rupees', header: 'Under/Over Absorption (INR)' },
    { key: 'observations_count', header: 'Observations' },
    { key: 'filing_due_date', header: 'Filing Due' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Cost-Audit / Cost-Records (Sec-148) Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Companies Act sec-148 cost-records compliance log — cost-centre &times; product-group
        (AMC services, spare parts, projects, diagnostics, consumables &amp; refurbishment) &times;
        period &times; cost-records maintained &times; reconciliation variance &times; material,
        conversion &amp; overhead cost &times; under/over absorption &times; observations &times;
        filing due-date &amp; CAPA closure. Founder-gated view: compliance-status rollups, product-group
        scorecards, root-cause pareto, and absorption-variance digest for cost-auditor readiness.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No cost records logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Product-group scorecard</h2>
        <DataTable
          rows={groupRows}
          columns={groupCols}
          emptyMessage="No product-group rollups."
          rowKey={(r, i) => String(r.product_group ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Product-group &times; compliance-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by product group."
          rowKey={(r, i) => `${r.product_group}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly compliance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Absorption-variance digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No absorption data."
          rowKey={(r, i) => String(r.product_group ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk cost-records queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cost records."
          rowKey={(r, i) => `${r.record_ref}-${i}`}
        />
      </section>
    </main>
  );
}
