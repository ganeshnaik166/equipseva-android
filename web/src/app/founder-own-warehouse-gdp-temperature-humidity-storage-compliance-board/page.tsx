import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { gdp_status: string; zones: number; pct: number };
type WarehouseRow = {
  warehouse_name: string;
  zones: number;
  compliant: number;
  excursion_managed: number;
  non_compliant: number;
  total_excursions: number;
  total_excursion_minutes: number;
  quarantine_events: number;
  avg_logger_cal_pct: number;
};
type MatrixRow = {
  zone_class: string;
  gdp_status: string;
  zones: number;
  total_excursions: number;
  avg_temp_c: number;
};
type TrendRow = {
  period_month: string;
  zones: number;
  total_excursions: number;
  total_excursion_minutes: number;
  quarantine_events: number;
  non_compliant: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_stock_value_at_risk_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_stock_value_at_risk_rupees: number;
  pct: number;
};
type ImpactRow = {
  zone_class: string;
  zones: number;
  total_excursions: number;
  total_excursion_minutes: number;
  quarantine_events: number;
  avg_humidity_pct: number;
};
type RiskRow = {
  warehouse_name: string;
  zone_code: string;
  storage_zone: string;
  zone_class: string;
  period_month: string;
  gdp_status: string;
  temp_excursions: number;
  excursion_minutes: number;
  loggers_calibrated_pct: number | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    warehouseRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3684_gdp_status_rollup'),
    supabase.rpc('founder_r3684_warehouse_scorecard'),
    supabase.rpc('founder_r3684_zone_class_status_matrix'),
    supabase.rpc('founder_r3684_monthly_excursion_trend'),
    supabase.rpc('founder_r3684_capa_status_board'),
    supabase.rpc('founder_r3684_root_cause_pareto'),
    supabase.rpc('founder_r3684_excursion_impact_digest'),
    supabase.rpc('founder_r3684_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const warehouseRows: WarehouseRow[] = (warehouseRes.data as WarehouseRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'gdp_status', header: 'GDP Status' },
    { key: 'zones', header: 'Zone-Months' },
    { key: 'pct', header: 'Share %' },
  ];

  const warehouseCols: Column<WarehouseRow>[] = [
    { key: 'warehouse_name', header: 'Warehouse' },
    { key: 'zones', header: 'Zone-Months' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'excursion_managed', header: 'Excursion Managed' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'total_excursions', header: 'Excursions' },
    { key: 'total_excursion_minutes', header: 'Excursion Min' },
    { key: 'quarantine_events', header: 'Quarantines' },
    { key: 'avg_logger_cal_pct', header: 'Avg Logger Cal %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'zone_class', header: 'Zone Class' },
    { key: 'gdp_status', header: 'GDP Status' },
    { key: 'zones', header: 'Zone-Months' },
    { key: 'total_excursions', header: 'Excursions' },
    { key: 'avg_temp_c', header: 'Avg Temp C' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'zones', header: 'Zone-Months' },
    { key: 'total_excursions', header: 'Excursions' },
    { key: 'total_excursion_minutes', header: 'Excursion Min' },
    { key: 'quarantine_events', header: 'Quarantines' },
    { key: 'non_compliant', header: 'Non-Compliant' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_stock_value_at_risk_rupees', header: 'Avg Stock at Risk (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_stock_value_at_risk_rupees', header: 'Total Stock at Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'zone_class', header: 'Zone Class' },
    { key: 'zones', header: 'Zone-Months' },
    { key: 'total_excursions', header: 'Excursions' },
    { key: 'total_excursion_minutes', header: 'Excursion Min' },
    { key: 'quarantine_events', header: 'Quarantines' },
    { key: 'avg_humidity_pct', header: 'Avg RH %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'warehouse_name', header: 'Warehouse' },
    { key: 'zone_code', header: 'Zone Code' },
    { key: 'storage_zone', header: 'Storage Zone' },
    { key: 'zone_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'gdp_status', header: 'GDP Status' },
    { key: 'temp_excursions', header: 'Excursions' },
    { key: 'excursion_minutes', header: 'Excursion Min' },
    { key: 'loggers_calibrated_pct', header: 'Logger Cal %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Own-Warehouse GDP Temperature / Humidity Storage-Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        GDP storage-condition compliance across our OWN spare-parts &amp; device warehouses —
        Mumbai HQ, Chennai branch, Delhi warehouse &amp; Bengaluru refurb center. Zone class
        (ambient, controlled 15&ndash;25, cold 2&ndash;8, dehumidified, flammable store) &times;
        avg temp &times; excursion count &amp; minutes &times; humidity &times; logger deployment
        &amp; calibration &times; mapping-study currency &times; quarantine events &amp; CAPA
        closure. Founder-gated view: status rollups, warehouse scorecards, root-cause pareto,
        and the high-risk zone queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. GDP status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No GDP zone records logged yet."
          rowKey={(r, i) => String(r.gdp_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Warehouse GDP scorecard</h2>
        <DataTable
          rows={warehouseRows}
          columns={warehouseCols}
          emptyMessage="No warehouse rollups."
          rowKey={(r, i) => String(r.warehouse_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Zone class &times; GDP status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by zone class."
          rowKey={(r, i) => `${r.zone_class}-${r.gdp_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly excursion trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Excursion impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No excursion-impact rollups."
          rowKey={(r, i) => String(r.zone_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk zone queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk zones."
          rowKey={(r, i) => `${r.zone_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
