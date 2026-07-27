import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; facilities: number; pct: number };
type LenderRow = {
  lender: string;
  facilities: number;
  compliant: number;
  watch: number;
  breach_risk: number;
  breached: number;
  waived: number;
  total_outstanding_rupees: number;
  avg_headroom_pct: number;
  compliant_pct: number;
};
type MatrixRow = {
  covenant_type: string;
  compliance_status: string;
  facilities: number;
  avg_headroom_pct: number;
  total_outstanding_rupees: number;
};
type TrendRow = {
  test_month: string;
  tests: number;
  avg_headroom_pct: number;
  breached: number;
  breach_risk: number;
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
type ExposureRow = {
  covenant_type: string;
  facilities: number;
  total_outstanding_rupees: number;
  avg_headroom_pct: number;
  breached: number;
};
type RiskRow = {
  facility_name: string;
  lender: string;
  covenant_ref: string;
  covenant_type: string;
  required_value: number | null;
  actual_value: number | null;
  headroom_pct: number | null;
  compliance_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    lenderRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3485_compliance_status_rollup'),
    supabase.rpc('founder_r3485_lender_scorecard'),
    supabase.rpc('founder_r3485_covenant_status_matrix'),
    supabase.rpc('founder_r3485_monthly_headroom_trend'),
    supabase.rpc('founder_r3485_capa_status_board'),
    supabase.rpc('founder_r3485_root_cause_pareto'),
    supabase.rpc('founder_r3485_exposure_impact_digest'),
    supabase.rpc('founder_r3485_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const lenderRows: LenderRow[] = (lenderRes.data as LenderRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'facilities', header: 'Facilities' },
    { key: 'pct', header: 'Share %' },
  ];

  const lenderCols: Column<LenderRow>[] = [
    { key: 'lender', header: 'Lender' },
    { key: 'facilities', header: 'Facilities' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'watch', header: 'Watch' },
    { key: 'breach_risk', header: 'Breach Risk' },
    { key: 'breached', header: 'Breached' },
    { key: 'waived', header: 'Waived' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'avg_headroom_pct', header: 'Avg Headroom %' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'covenant_type', header: 'Covenant Type' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'facilities', header: 'Facilities' },
    { key: 'avg_headroom_pct', header: 'Avg Headroom %' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'test_month', header: 'Month' },
    { key: 'tests', header: 'Tests' },
    { key: 'avg_headroom_pct', header: 'Avg Headroom %' },
    { key: 'breached', header: 'Breached' },
    { key: 'breach_risk', header: 'Breach Risk' },
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

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'covenant_type', header: 'Covenant Type' },
    { key: 'facilities', header: 'Facilities' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'avg_headroom_pct', header: 'Avg Headroom %' },
    { key: 'breached', header: 'Breached / Risk' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'facility_name', header: 'Facility' },
    { key: 'lender', header: 'Lender' },
    { key: 'covenant_ref', header: 'Ref' },
    { key: 'covenant_type', header: 'Covenant Type' },
    { key: 'required_value', header: 'Required' },
    { key: 'actual_value', header: 'Actual' },
    { key: 'headroom_pct', header: 'Headroom %' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Capital-Structure / Debt-Covenant Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated view of the debt book&apos;s covenant health — facility &times; lender &times;
        covenant type (leverage ratio, DSCR, interest &amp; current-ratio coverage, min-net-worth,
        capex cap) &times; required vs actual &times; headroom % &times; outstanding exposure &times;
        compliance status &times; test cadence &times; trend &amp; CAPA closure. Rollups cover status
        distribution, lender scorecards, covenant-type &times; status matrix, monthly headroom trend,
        root-cause pareto, exposure-impact digest, and a high-risk (breach-risk / breached / worsening)
        remediation queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No covenant tests logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Lender scorecard</h2>
        <DataTable
          rows={lenderRows}
          columns={lenderCols}
          emptyMessage="No lender rollups."
          rowKey={(r, i) => String(r.lender ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Covenant type &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.covenant_type}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly headroom trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.test_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Exposure-impact digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure rollups."
          rowKey={(r, i) => String(r.covenant_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk covenant queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk covenants."
          rowKey={(r, i) => `${r.covenant_ref}-${i}`}
        />
      </section>
    </main>
  );
}
