import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { unit_econ_verdict: string; cohorts: number; pct: number };
type SegmentRow = {
  customer_segment: string;
  cohorts: number;
  customers: number;
  avg_ltv_cac: number;
  avg_payback_months: number;
  avg_churn_pct: number;
  total_contribution_rupees: number;
  unprofitable: number;
};
type MatrixRow = {
  customer_segment: string;
  acquisition_channel: string;
  cohorts: number;
  customers: number;
  avg_ltv_cac: number;
  avg_payback_months: number;
};
type TrendRow = {
  cohort_quarter: string;
  cohorts: number;
  customers: number;
  avg_ltv_cac: number;
  avg_cac_rupees: number;
  avg_churn_pct: number;
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
type ImpactRow = {
  impact_area: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  cohort_code: string;
  customer_segment: string;
  acquisition_channel: string;
  cohort_quarter: string;
  ltv_cac_ratio: number;
  payback_months: number;
  churn_rate_pct: number;
  unit_econ_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    segmentRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3417_verdict_rollup'),
    supabase.rpc('founder_r3417_segment_scorecard'),
    supabase.rpc('founder_r3417_segment_channel_matrix'),
    supabase.rpc('founder_r3417_cohort_quarter_trend'),
    supabase.rpc('founder_r3417_capa_status_board'),
    supabase.rpc('founder_r3417_root_cause_pareto'),
    supabase.rpc('founder_r3417_impact_digest'),
    supabase.rpc('founder_r3417_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const segmentRows: SegmentRow[] = (segmentRes.data as SegmentRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'unit_econ_verdict', header: 'Verdict' },
    { key: 'cohorts', header: 'Cohorts' },
    { key: 'pct', header: 'Share %' },
  ];

  const segmentCols: Column<SegmentRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'cohorts', header: 'Cohorts' },
    { key: 'customers', header: 'Customers' },
    { key: 'avg_ltv_cac', header: 'Avg LTV:CAC' },
    { key: 'avg_payback_months', header: 'Avg Payback (mo)' },
    { key: 'avg_churn_pct', header: 'Avg Churn %' },
    { key: 'total_contribution_rupees', header: 'Total Contribution (INR)' },
    { key: 'unprofitable', header: 'Unprofitable' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'acquisition_channel', header: 'Channel' },
    { key: 'cohorts', header: 'Cohorts' },
    { key: 'customers', header: 'Customers' },
    { key: 'avg_ltv_cac', header: 'Avg LTV:CAC' },
    { key: 'avg_payback_months', header: 'Avg Payback (mo)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cohort_quarter', header: 'Cohort Quarter' },
    { key: 'cohorts', header: 'Cohorts' },
    { key: 'customers', header: 'Customers' },
    { key: 'avg_ltv_cac', header: 'Avg LTV:CAC' },
    { key: 'avg_cac_rupees', header: 'Avg CAC (INR)' },
    { key: 'avg_churn_pct', header: 'Avg Churn %' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'impact_area', header: 'Impact Area' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'cohort_code', header: 'Cohort' },
    { key: 'customer_segment', header: 'Segment' },
    { key: 'acquisition_channel', header: 'Channel' },
    { key: 'cohort_quarter', header: 'Quarter' },
    { key: 'ltv_cac_ratio', header: 'LTV:CAC' },
    { key: 'payback_months', header: 'Payback (mo)' },
    { key: 'churn_rate_pct', header: 'Churn %' },
    { key: 'unit_econ_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder LTV:CAC Ratio &amp; CAC-Payback Unit-Economics Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Unit-economics governance across EquipSeva customer segments and acquisition channels —
        customer segment (govt hospital, large private chain, standalone private, nursing home,
        diagnostic centre, medical college) &times; acquisition channel (direct sales, referral,
        tender, partner, inbound digital, OEM lead) &times; cohort quarter &times; CAC &times; LTV
        &times; LTV:CAC ratio &times; CAC-payback months &times; gross margin &times; churn &times;
        contribution margin &amp; CAPA closure. Founder-gated view: verdict rollup, segment
        scorecards, root-cause pareto, and impact digest for cohorts where LTV:CAC &lt; 3 or payback
        &gt; 24 months.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Unit-economics verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No cohorts logged yet."
          rowKey={(r, i) => String(r.unit_econ_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Segment scorecard</h2>
        <DataTable
          rows={segmentRows}
          columns={segmentCols}
          emptyMessage="No segment rollups."
          rowKey={(r, i) => String(r.customer_segment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Segment &times; channel matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cohorts by segment and channel."
          rowKey={(r, i) => `${r.customer_segment}-${r.acquisition_channel}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Cohort-quarter trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.cohort_quarter ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Impact-area digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact-area rollups."
          rowKey={(r, i) => String(r.impact_area ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk unit-economics queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cohorts."
          rowKey={(r, i) => `${r.cohort_code}-${i}`}
        />
      </section>
    </main>
  );
}
