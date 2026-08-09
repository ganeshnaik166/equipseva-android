import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; vehicles: number; pct: number };
type RegionRow = {
  home_region: string;
  total_vehicles: number;
  fully_current: number;
  renewal_due: number;
  lapsed_or_off_road: number;
  challan_pending: number;
  total_open_challans: number;
  total_challan_amount_rupees: number;
  avg_docs_current_pct: number;
};
type MatrixRow = {
  vehicle_class: string;
  compliance_status: string;
  vehicles: number;
  avg_docs_current_pct: number;
  total_challan_amount_rupees: number;
};
type TrendRow = {
  period_month: string;
  vehicles: number;
  renewal_due: number;
  doc_lapsed: number;
  off_road_risk: number;
  avg_nearest_expiry_days: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_exposure_rupees: number;
  pct: number;
};
type ChallanRow = {
  vehicle_class: string;
  vehicles: number;
  vehicles_with_challans: number;
  total_open_challans: number;
  total_challan_amount_rupees: number;
  max_single_vehicle_amount_rupees: number;
};
type RiskRow = {
  vehicle_reg_no: string;
  home_region: string;
  vehicle_class: string;
  period_month: string;
  compliance_status: string;
  nearest_expiry_days: number | null;
  open_challans: number;
  challan_amount_rupees: number;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    challanRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3685_compliance_status_rollup'),
    supabase.rpc('founder_r3685_region_scorecard'),
    supabase.rpc('founder_r3685_class_status_matrix'),
    supabase.rpc('founder_r3685_monthly_expiry_trend'),
    supabase.rpc('founder_r3685_capa_status_board'),
    supabase.rpc('founder_r3685_root_cause_pareto'),
    supabase.rpc('founder_r3685_challan_exposure_digest'),
    supabase.rpc('founder_r3685_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const challanRows: ChallanRow[] = (challanRes.data as ChallanRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'vehicles', header: 'Vehicles' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'home_region', header: 'Region' },
    { key: 'total_vehicles', header: 'Vehicles' },
    { key: 'fully_current', header: 'All Current' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'lapsed_or_off_road', header: 'Lapsed / Off-Road' },
    { key: 'challan_pending', header: 'Challan Pending' },
    { key: 'total_open_challans', header: 'Open Challans' },
    { key: 'total_challan_amount_rupees', header: 'Challan Amount (INR)' },
    { key: 'avg_docs_current_pct', header: 'Avg Docs Current %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'vehicle_class', header: 'Vehicle Class' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'vehicles', header: 'Vehicles' },
    { key: 'avg_docs_current_pct', header: 'Avg Docs Current %' },
    { key: 'total_challan_amount_rupees', header: 'Challan Amount (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'vehicles', header: 'Vehicles' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'doc_lapsed', header: 'Doc Lapsed' },
    { key: 'off_road_risk', header: 'Off-Road Risk' },
    { key: 'avg_nearest_expiry_days', header: 'Avg Nearest Expiry (days)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_exposure_rupees', header: 'Avg Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const challanCols: Column<ChallanRow>[] = [
    { key: 'vehicle_class', header: 'Vehicle Class' },
    { key: 'vehicles', header: 'Vehicles' },
    { key: 'vehicles_with_challans', header: 'With Challans' },
    { key: 'total_open_challans', header: 'Open Challans' },
    { key: 'total_challan_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'max_single_vehicle_amount_rupees', header: 'Max Single Vehicle (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'vehicle_reg_no', header: 'Reg No' },
    { key: 'home_region', header: 'Region' },
    { key: 'vehicle_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'nearest_expiry_days', header: 'Nearest Expiry (days)' },
    { key: 'open_challans', header: 'Open Challans' },
    { key: 'challan_amount_rupees', header: 'Challan Amount (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Own-Fleet Vehicle Statutory-Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Statutory-document compliance for the company&apos;s own service vans, delivery trucks,
        two-wheelers, car-pool vehicles and registered forklifts — insurance &times; PUC &times;
        fitness &times; permit &times; road tax &times; open challans across Mumbai HQ, Chennai
        Branch, Delhi Warehouse &amp; Bengaluru Refurb Center. Founder-gated view: compliance-status
        rollups, region scorecards, monthly expiry trend, challan-exposure digest, root-cause
        pareto and CAPA closure for vehicles at doc-lapse or off-road risk.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No vehicle compliance snapshots logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region compliance scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.home_region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Vehicle class &times; compliance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No snapshots by vehicle class."
          rowKey={(r, i) => `${r.vehicle_class}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly expiry trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Challan exposure digest</h2>
        <DataTable
          rows={challanRows}
          columns={challanCols}
          emptyMessage="No challan-exposure rollups."
          rowKey={(r, i) => String(r.vehicle_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk vehicle queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk vehicles."
          rowKey={(r, i) => `${r.vehicle_reg_no}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
