import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  coverage_status: string;
  assets: number;
  total_value_rupees: number;
  pct: number;
};
type TypeRow = {
  coverage_type: string;
  assets: number;
  orphan_assets: number;
  lapsed_assets: number;
  critical_assets: number;
  total_value_rupees: number;
  avg_days_uncovered: number;
};
type MatrixRow = {
  coverage_type: string;
  criticality: string;
  assets: number;
  uncovered_assets: number;
  total_value_rupees: number;
};
type TrendRow = {
  coverage_month: string;
  expiring_assets: number;
  total_value_rupees: number;
  uncovered_assets: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_recoverable_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_recoverable_rupees: number;
  pct: number;
};
type ImpactRow = {
  hospital_name: string;
  assets: number;
  uncovered_assets: number;
  total_annual_value_rupees: number;
  value_at_risk_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  device_model: string;
  asset_tag: string;
  coverage_type: string;
  coverage_status: string;
  criticality: string;
  days_uncovered: number | null;
  annual_service_value_rupees: number | null;
  recovery_action: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    typeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3500_coverage_status_rollup'),
    supabase.rpc('founder_r3500_coverage_type_scorecard'),
    supabase.rpc('founder_r3500_type_criticality_matrix'),
    supabase.rpc('founder_r3500_monthly_coverage_trend'),
    supabase.rpc('founder_r3500_capa_status_board'),
    supabase.rpc('founder_r3500_root_cause_pareto'),
    supabase.rpc('founder_r3500_service_value_impact_digest'),
    supabase.rpc('founder_r3500_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const typeRows: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'coverage_status', header: 'Coverage Status' },
    { key: 'assets', header: 'Assets' },
    { key: 'total_value_rupees', header: 'Annual Value (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'coverage_type', header: 'Coverage Type' },
    { key: 'assets', header: 'Assets' },
    { key: 'orphan_assets', header: 'Orphan' },
    { key: 'lapsed_assets', header: 'Lapsed' },
    { key: 'critical_assets', header: 'Critical' },
    { key: 'total_value_rupees', header: 'Annual Value (INR)' },
    { key: 'avg_days_uncovered', header: 'Avg Days Uncovered' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'coverage_type', header: 'Coverage Type' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'assets', header: 'Assets' },
    { key: 'uncovered_assets', header: 'Uncovered' },
    { key: 'total_value_rupees', header: 'Annual Value (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'coverage_month', header: 'Expiry Month' },
    { key: 'expiring_assets', header: 'Assets' },
    { key: 'total_value_rupees', header: 'Annual Value (INR)' },
    { key: 'uncovered_assets', header: 'Uncovered' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_recoverable_rupees', header: 'Avg Recoverable (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_recoverable_rupees', header: 'Total Recoverable (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'assets', header: 'Assets' },
    { key: 'uncovered_assets', header: 'Uncovered' },
    { key: 'total_annual_value_rupees', header: 'Annual Value (INR)' },
    { key: 'value_at_risk_rupees', header: 'Value At Risk (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_model', header: 'Device Model' },
    { key: 'asset_tag', header: 'Asset Tag' },
    { key: 'coverage_type', header: 'Type' },
    { key: 'coverage_status', header: 'Status' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'days_uncovered', header: 'Days Uncovered' },
    { key: 'annual_service_value_rupees', header: 'Annual Value (INR)' },
    { key: 'recovery_action', header: 'Recovery Action' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Installed-Base Service-Coverage-Gap / Orphan-Equipment Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Installed-base service-coverage gap and orphan (uncovered) equipment tracker — hospital &times;
        device model &times; asset tag &times; install year &times; coverage type (AMC, CMC, warranty,
        uncovered, expired) &times; coverage expiry &times; days uncovered &times; annual service value
        &times; criticality &times; coverage status &times; recovery action &amp; CAPA closure.
        Founder-gated view: coverage-status distribution, coverage-type scorecard, criticality matrix,
        monthly expiry trend, root-cause pareto, and service-value at risk across the installed base.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Coverage-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No coverage records logged yet."
          rowKey={(r, i) => String(r.coverage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Coverage-type scorecard</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No coverage-type rollups."
          rowKey={(r, i) => String(r.coverage_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Coverage type &times; criticality matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No assets by coverage type."
          rowKey={(r, i) => `${r.coverage_type}-${r.criticality}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly coverage-expiry trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No expiry trend data."
          rowKey={(r, i) => String(r.coverage_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Service-value impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No service-value rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk coverage queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk assets."
          rowKey={(r, i) => `${r.asset_tag}-${i}`}
        />
      </section>
    </main>
  );
}
