import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  adoption_status: string;
  areas: number;
  total_adjustment_rupees: number;
  pct: number;
};
type AreaRow = {
  gaap_area: string;
  line_items: number;
  adopted: number;
  in_progress: number;
  under_assessment: number;
  deferred: number;
  total_transition_adj_rupees: number;
  total_oci_impact_rupees: number;
  total_re_impact_rupees: number;
  disclosure_ready_pct: number;
};
type MatrixRow = {
  gaap_area: string;
  adoption_status: string;
  line_items: number;
  total_adjustment_rupees: number;
  avg_materiality_pct: number;
};
type TrendRow = {
  period_month: string;
  line_items: number;
  adopted: number;
  under_assessment: number;
  total_adjustment_rupees: number;
  total_oci_impact_rupees: number;
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
  entity_name: string;
  area_code: string;
  gaap_area: string;
  standard_ref: string;
  period_month: string;
  adoption_status: string;
  transition_adjustment_rupees: number;
  materiality_pct: number | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    areaRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3636_adoption_status_rollup'),
    supabase.rpc('founder_r3636_gaap_area_scorecard'),
    supabase.rpc('founder_r3636_area_status_matrix'),
    supabase.rpc('founder_r3636_monthly_adoption_trend'),
    supabase.rpc('founder_r3636_capa_status_board'),
    supabase.rpc('founder_r3636_root_cause_pareto'),
    supabase.rpc('founder_r3636_adjustment_impact_digest'),
    supabase.rpc('founder_r3636_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const areaRows: AreaRow[] = (areaRes.data as AreaRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'adoption_status', header: 'Adoption Status' },
    { key: 'areas', header: 'Line Items' },
    { key: 'total_adjustment_rupees', header: 'Total Adjustment (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const areaCols: Column<AreaRow>[] = [
    { key: 'gaap_area', header: 'GAAP Area' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'adopted', header: 'Adopted' },
    { key: 'in_progress', header: 'In Progress' },
    { key: 'under_assessment', header: 'Under Assessment' },
    { key: 'deferred', header: 'Deferred' },
    { key: 'total_transition_adj_rupees', header: 'Transition Adj (INR)' },
    { key: 'total_oci_impact_rupees', header: 'OCI Impact (INR)' },
    { key: 'total_re_impact_rupees', header: 'Retained Earnings Impact (INR)' },
    { key: 'disclosure_ready_pct', header: 'Disclosure Ready %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'gaap_area', header: 'GAAP Area' },
    { key: 'adoption_status', header: 'Adoption Status' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_adjustment_rupees', header: 'Total Adjustment (INR)' },
    { key: 'avg_materiality_pct', header: 'Avg Materiality %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'adopted', header: 'Adopted' },
    { key: 'under_assessment', header: 'Under Assessment / Deferred' },
    { key: 'total_adjustment_rupees', header: 'Total Adjustment (INR)' },
    { key: 'total_oci_impact_rupees', header: 'OCI Impact (INR)' },
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
    { key: 'entity_name', header: 'Entity' },
    { key: 'area_code', header: 'Area Code' },
    { key: 'gaap_area', header: 'GAAP Area' },
    { key: 'standard_ref', header: 'Standard' },
    { key: 'period_month', header: 'Period' },
    { key: 'adoption_status', header: 'Adoption Status' },
    { key: 'transition_adjustment_rupees', header: 'Transition Adj (INR)' },
    { key: 'materiality_pct', header: 'Materiality %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Ind-AS Transition / First-Time-Adoption GAAP-Gap Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        First-time-adoption GAAP-gap register &mdash; iGAAP vs Ind-AS transition adjustments by GAAP area
        (PPE, leases, financial instruments, revenue, employee benefits, income taxes, business
        combinations, provisions) &times; standard reference &times; period &times; iGAAP value &times;
        Ind-AS value &times; transition adjustment &times; OCI impact &times; retained-earnings impact
        &times; materiality &times; disclosure readiness &amp; CAPA closure. Founder-gated view: adoption
        status, GAAP-area scorecards, root-cause pareto, and adjustment-impact digest across the opening
        Ind-AS balance sheet.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Adoption status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No transition lines logged yet."
          rowKey={(r, i) => String(r.adoption_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. GAAP-area scorecard</h2>
        <DataTable
          rows={areaRows}
          columns={areaCols}
          emptyMessage="No GAAP-area rollups."
          rowKey={(r, i) => String(r.gaap_area ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. GAAP area &times; adoption status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by GAAP area."
          rowKey={(r, i) => `${r.gaap_area}-${r.adoption_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly adoption trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Adjustment-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No adjustment-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk transition queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk transition lines."
          rowKey={(r, i) => `${r.area_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
