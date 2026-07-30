import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { efficiency_status: string; entries: number; pct: number };
type UnitRow = {
  business_unit: string;
  entries: number;
  avg_sga_ratio_pct: number;
  avg_target_sga_ratio_pct: number;
  avg_opex_ratio_pct: number;
  total_revenue_rupees: number;
  total_sga_rupees: number;
  bloated_or_elevated: number;
};
type MatrixRow = {
  business_unit: string;
  efficiency_status: string;
  entries: number;
  avg_sga_ratio_pct: number;
  avg_opex_ratio_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  avg_sga_ratio_pct: number;
  avg_opex_ratio_pct: number;
  elevated_or_bloated: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  escalated_overdue: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ImpactRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  business_unit: string;
  entry_code: string;
  period_month: string;
  revenue_rupees: number;
  sga_ratio_pct: number;
  target_sga_ratio_pct: number;
  opex_ratio_pct: number;
  efficiency_status: string;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    unitRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3595_efficiency_status_rollup'),
    supabase.rpc('founder_r3595_business_unit_scorecard'),
    supabase.rpc('founder_r3595_unit_efficiency_matrix'),
    supabase.rpc('founder_r3595_monthly_sga_ratio_trend'),
    supabase.rpc('founder_r3595_capa_status_board'),
    supabase.rpc('founder_r3595_root_cause_pareto'),
    supabase.rpc('founder_r3595_cost_impact_digest'),
    supabase.rpc('founder_r3595_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const unitRows: UnitRow[] = (unitRes.data as UnitRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'efficiency_status', header: 'Efficiency Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const unitCols: Column<UnitRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_sga_ratio_pct', header: 'Avg SG&A %' },
    { key: 'avg_target_sga_ratio_pct', header: 'Avg Target %' },
    { key: 'avg_opex_ratio_pct', header: 'Avg Opex %' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_sga_rupees', header: 'SG&A (INR)' },
    { key: 'bloated_or_elevated', header: 'Elevated / Bloated' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'efficiency_status', header: 'Efficiency Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_sga_ratio_pct', header: 'Avg SG&A %' },
    { key: 'avg_opex_ratio_pct', header: 'Avg Opex %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_sga_ratio_pct', header: 'Avg SG&A %' },
    { key: 'avg_opex_ratio_pct', header: 'Avg Opex %' },
    { key: 'elevated_or_bloated', header: 'Elevated / Bloated' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Impact (INR)' },
    { key: 'escalated_overdue', header: 'Escalated / Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'entry_code', header: 'Entry' },
    { key: 'period_month', header: 'Month' },
    { key: 'revenue_rupees', header: 'Revenue (INR)' },
    { key: 'sga_ratio_pct', header: 'SG&A %' },
    { key: 'target_sga_ratio_pct', header: 'Target %' },
    { key: 'opex_ratio_pct', header: 'Opex %' },
    { key: 'efficiency_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        SG&amp;A / Opex-Ratio Cost-Efficiency Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder cost-efficiency board — SG&amp;A and operating-expense ratios per business unit
        (Diagnostics Sales, AMC Services, Spare Parts, Rental Fleet, Field Service, Marketplace
        &amp; Consumables) &times; month &times; revenue &times; SG&amp;A ratio vs target &times;
        selling &amp; admin split &times; opex ratio &times; efficiency status &times; trend
        direction &amp; CAPA closure. Founder-gated view: efficiency-status distribution, business-unit
        scorecards, root-cause pareto, and cost-impact digest across bloated &amp; elevated units.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Efficiency-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No cost-efficiency entries logged yet."
          rowKey={(r, i) => String(r.efficiency_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit scorecard</h2>
        <DataTable
          rows={unitRows}
          columns={unitCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business unit &times; efficiency-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.efficiency_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly SG&amp;A / opex ratio trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cost-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No cost-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk cost-efficiency queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk units."
          rowKey={(r, i) => `${r.entry_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
