import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type AlignRow = { policy_alignment: string; parts: number; pct: number };
type AbcRow = {
  abc_class: string;
  parts: number;
  aligned: number;
  over_stocked: number;
  under_stocked: number;
  mismatched: number;
  total_annual_value_rupees: number;
  avg_turns: number;
  aligned_pct: number;
};
type MatrixRow = {
  abc_class: string;
  xyz_class: string;
  parts: number;
  aligned: number;
  mismatched: number;
  total_annual_value_rupees: number;
  avg_demand_cv_pct: number;
};
type TrendRow = {
  review_month: string;
  parts: number;
  total_annual_value_rupees: number;
  avg_turns: number;
  misaligned: number;
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
  part_name: string;
  part_code: string;
  category: string;
  abc_class: string;
  xyz_class: string;
  policy_alignment: string;
  stocking_policy: string;
  annual_consumption_value_rupees: number;
  turns_per_year: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    alignRes,
    abcRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3445_policy_alignment_rollup'),
    supabase.rpc('founder_r3445_abc_class_scorecard'),
    supabase.rpc('founder_r3445_abc_xyz_matrix'),
    supabase.rpc('founder_r3445_monthly_value_trend'),
    supabase.rpc('founder_r3445_capa_status_board'),
    supabase.rpc('founder_r3445_root_cause_pareto'),
    supabase.rpc('founder_r3445_value_impact_digest'),
    supabase.rpc('founder_r3445_high_risk_queue'),
  ]);

  const alignRows: AlignRow[] = (alignRes.data as AlignRow[]) ?? [];
  const abcRows: AbcRow[] = (abcRes.data as AbcRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const alignCols: Column<AlignRow>[] = [
    { key: 'policy_alignment', header: 'Policy Alignment' },
    { key: 'parts', header: 'Parts' },
    { key: 'pct', header: 'Share %' },
  ];

  const abcCols: Column<AbcRow>[] = [
    { key: 'abc_class', header: 'ABC Class' },
    { key: 'parts', header: 'Parts' },
    { key: 'aligned', header: 'Aligned' },
    { key: 'over_stocked', header: 'Over-stocked' },
    { key: 'under_stocked', header: 'Under-stocked' },
    { key: 'mismatched', header: 'Mismatched' },
    { key: 'total_annual_value_rupees', header: 'Annual Value (INR)' },
    { key: 'avg_turns', header: 'Avg Turns/yr' },
    { key: 'aligned_pct', header: 'Aligned %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'abc_class', header: 'ABC Class' },
    { key: 'xyz_class', header: 'XYZ Class' },
    { key: 'parts', header: 'Parts' },
    { key: 'aligned', header: 'Aligned' },
    { key: 'mismatched', header: 'Misaligned' },
    { key: 'total_annual_value_rupees', header: 'Annual Value (INR)' },
    { key: 'avg_demand_cv_pct', header: 'Avg Demand CV %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'review_month', header: 'Month' },
    { key: 'parts', header: 'Parts' },
    { key: 'total_annual_value_rupees', header: 'Annual Value (INR)' },
    { key: 'avg_turns', header: 'Avg Turns/yr' },
    { key: 'misaligned', header: 'Misaligned' },
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
    { key: 'part_name', header: 'Part' },
    { key: 'part_code', header: 'Code' },
    { key: 'category', header: 'Category' },
    { key: 'abc_class', header: 'ABC' },
    { key: 'xyz_class', header: 'XYZ' },
    { key: 'policy_alignment', header: 'Alignment' },
    { key: 'stocking_policy', header: 'Policy' },
    { key: 'annual_consumption_value_rupees', header: 'Annual Value (INR)' },
    { key: 'turns_per_year', header: 'Turns/yr' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Inventory ABC-XYZ Classification / Stocking-Policy Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Spare-parts inventory ABC (annual consumption value) &times; XYZ (demand variability)
        classification &amp; stocking-policy alignment — part &times; category &times; ABC class
        &times; XYZ class &times; annual value &times; demand CV% &times; stock / reorder / safety
        &times; stocking policy (tight JIT, moderate &amp; high buffer, make-to-order, review-obsolete)
        &times; policy alignment &times; turns/yr &amp; CAPA closure. Founder-gated view: alignment
        distribution, ABC scorecards, ABC &times; XYZ matrix, root-cause pareto, and value-impact
        digest for working-capital &amp; service-level control.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Policy-alignment distribution</h2>
        <DataTable
          rows={alignRows}
          columns={alignCols}
          emptyMessage="No inventory parts classified yet."
          rowKey={(r, i) => String(r.policy_alignment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. ABC-class scorecard</h2>
        <DataTable
          rows={abcRows}
          columns={abcCols}
          emptyMessage="No ABC-class rollups."
          rowKey={(r, i) => String(r.abc_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. ABC class &times; XYZ class matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No parts by ABC/XYZ class."
          rowKey={(r, i) => `${r.abc_class}-${r.xyz_class}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly value &amp; turns trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.review_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Value-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No value-impact rollups."
          rowKey={(r, i) => String(r.business_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk stocking queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk parts."
          rowKey={(r, i) => `${r.part_code}-${i}`}
        />
      </section>
    </main>
  );
}
