import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  lease_status: string;
  leases: number;
  total_liability_rupees: number;
  total_rou_rupees: number;
  pct: number;
};
type ClassRow = {
  asset_class: string;
  leases: number;
  total_rou_rupees: number;
  total_liability_rupees: number;
  total_monthly_rental_rupees: number;
  expiring: number;
  modified: number;
  avg_discount_rate_pct: number;
};
type MatrixRow = {
  asset_class: string;
  lease_status: string;
  leases: number;
  total_liability_rupees: number;
  avg_term_months: number;
};
type TrendRow = {
  period_month: string;
  leases: number;
  total_liability_rupees: number;
  total_interest_ytd_rupees: number;
  total_depreciation_ytd_rupees: number;
  total_monthly_rental_rupees: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
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
  actions: number;
  open_actions: number;
  total_impact_rupees: number;
};
type RiskRow = {
  lease_name: string;
  lease_code: string;
  asset_class: string;
  lease_status: string;
  lease_liability_rupees: number;
  monthly_rental_rupees: number | null;
  discount_rate_pct: number | null;
  commencement_date: string | null;
  period_month: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    classRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3537_lease_status_rollup'),
    supabase.rpc('founder_r3537_asset_class_scorecard'),
    supabase.rpc('founder_r3537_asset_class_status_matrix'),
    supabase.rpc('founder_r3537_liability_amortization_trend'),
    supabase.rpc('founder_r3537_capa_status_board'),
    supabase.rpc('founder_r3537_root_cause_pareto'),
    supabase.rpc('founder_r3537_liability_impact_digest'),
    supabase.rpc('founder_r3537_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const classRows: ClassRow[] = (classRes.data as ClassRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'lease_status', header: 'Lease Status' },
    { key: 'leases', header: 'Leases' },
    { key: 'total_liability_rupees', header: 'Liability (INR)' },
    { key: 'total_rou_rupees', header: 'ROU Asset (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const classCols: Column<ClassRow>[] = [
    { key: 'asset_class', header: 'Asset Class' },
    { key: 'leases', header: 'Leases' },
    { key: 'total_rou_rupees', header: 'ROU Asset (INR)' },
    { key: 'total_liability_rupees', header: 'Liability (INR)' },
    { key: 'total_monthly_rental_rupees', header: 'Monthly Rental (INR)' },
    { key: 'expiring', header: 'Expiring' },
    { key: 'modified', header: 'Modified' },
    { key: 'avg_discount_rate_pct', header: 'Avg Discount %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'asset_class', header: 'Asset Class' },
    { key: 'lease_status', header: 'Lease Status' },
    { key: 'leases', header: 'Leases' },
    { key: 'total_liability_rupees', header: 'Liability (INR)' },
    { key: 'avg_term_months', header: 'Avg Term (months)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'leases', header: 'Leases' },
    { key: 'total_liability_rupees', header: 'Liability (INR)' },
    { key: 'total_interest_ytd_rupees', header: 'Interest YTD (INR)' },
    { key: 'total_depreciation_ytd_rupees', header: 'Depreciation YTD (INR)' },
    { key: 'total_monthly_rental_rupees', header: 'Monthly Rental (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
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
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'lease_name', header: 'Lease' },
    { key: 'lease_code', header: 'Code' },
    { key: 'asset_class', header: 'Class' },
    { key: 'lease_status', header: 'Status' },
    { key: 'lease_liability_rupees', header: 'Liability (INR)' },
    { key: 'monthly_rental_rupees', header: 'Monthly Rental (INR)' },
    { key: 'discount_rate_pct', header: 'Discount %' },
    { key: 'commencement_date', header: 'Commenced' },
    { key: 'period_month', header: 'Period' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Lease IND-AS-116 ROU-Asset / Liability Schedule Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder IND-AS-116 lease-accounting board — per-lease right-of-use (ROU) asset &amp; lease
        liability schedule across asset class (office, warehouse, vehicle, equipment, land &amp;
        IT hardware) &times; lease status &times; term &times; discount rate &times; interest &amp;
        depreciation YTD &times; monthly amortization trend &amp; CAPA closure. Founder-gated view:
        status rollups, asset-class scorecards, root-cause pareto, and liability-impact digest for
        remeasurement, disclosure &amp; classification findings.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Lease status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No leases logged yet."
          rowKey={(r, i) => String(r.lease_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Asset-class scorecard</h2>
        <DataTable
          rows={classRows}
          columns={classCols}
          emptyMessage="No asset-class rollups."
          rowKey={(r, i) => String(r.asset_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Asset-class &times; lease-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No leases by asset class."
          rowKey={(r, i) => `${r.asset_class}-${r.lease_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly liability-amortization trend</h2>
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
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Liability-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No liability-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk lease queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk leases."
          rowKey={(r, i) => `${r.lease_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
