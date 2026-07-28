import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { usage_status: string; meters: number; pct: number };
type ModelRow = {
  device_model: string;
  total_meters: number;
  normal: number;
  approaching: number;
  due_cnt: number;
  overdue: number;
  over_utilized: number;
  pm_triggered_cnt: number;
  avg_pct_to_threshold: number;
};
type MatrixRow = {
  meter_type: string;
  usage_status: string;
  meters: number;
  avg_usage_since_pm: number;
  avg_pct_to_threshold: number;
};
type TrendRow = {
  reading_month: string;
  meters: number;
  pm_triggered_cnt: number;
  due_or_overdue: number;
  avg_pct_to_threshold: number;
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
  utilization_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  device_model: string;
  asset_tag: string;
  meter_type: string;
  usage_status: string;
  current_reading: number;
  usage_since_pm: number | null;
  pm_threshold: number | null;
  pct_to_threshold: number | null;
  reading_date: string;
  pm_triggered: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    modelRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3532_usage_status_rollup'),
    supabase.rpc('founder_r3532_device_model_scorecard'),
    supabase.rpc('founder_r3532_meter_type_status_matrix'),
    supabase.rpc('founder_r3532_monthly_usage_trend'),
    supabase.rpc('founder_r3532_capa_status_board'),
    supabase.rpc('founder_r3532_root_cause_pareto'),
    supabase.rpc('founder_r3532_utilization_impact_digest'),
    supabase.rpc('founder_r3532_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const modelRows: ModelRow[] = (modelRes.data as ModelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'usage_status', header: 'Usage Status' },
    { key: 'meters', header: 'Meters' },
    { key: 'pct', header: 'Share %' },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'device_model', header: 'Device Model' },
    { key: 'total_meters', header: 'Meters' },
    { key: 'normal', header: 'Normal' },
    { key: 'approaching', header: 'Approaching' },
    { key: 'due_cnt', header: 'Due' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'over_utilized', header: 'Over-Utilized' },
    { key: 'pm_triggered_cnt', header: 'PM Triggered' },
    { key: 'avg_pct_to_threshold', header: 'Avg % to Threshold' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'meter_type', header: 'Meter Type' },
    { key: 'usage_status', header: 'Usage Status' },
    { key: 'meters', header: 'Meters' },
    { key: 'avg_usage_since_pm', header: 'Avg Usage Since PM' },
    { key: 'avg_pct_to_threshold', header: 'Avg % to Threshold' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'reading_month', header: 'Month' },
    { key: 'meters', header: 'Meters' },
    { key: 'pm_triggered_cnt', header: 'PM Triggered' },
    { key: 'due_or_overdue', header: 'Due / Overdue' },
    { key: 'avg_pct_to_threshold', header: 'Avg % to Threshold' },
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
    { key: 'utilization_impact', header: 'Utilization Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_model', header: 'Device Model' },
    { key: 'asset_tag', header: 'Asset' },
    { key: 'meter_type', header: 'Meter' },
    { key: 'usage_status', header: 'Status' },
    { key: 'current_reading', header: 'Current Reading' },
    { key: 'usage_since_pm', header: 'Usage Since PM' },
    { key: 'pm_threshold', header: 'PM Threshold' },
    { key: 'pct_to_threshold', header: '% to Threshold' },
    { key: 'reading_date', header: 'Date' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Equipment Usage-Hours / Hour-Meter Reading Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Usage-based preventive-maintenance trigger tracker &mdash; hour-meter &amp; usage readings
        (run hours, sterilization cycle counts, X-ray &amp; CT tube shots, ultrasound patient counts,
        ambulance km, printer print-hours) &times; device model &times; current vs previous reading
        &times; usage-since-PM &times; PM threshold &times; percent-to-threshold &times; usage status
        &amp; CAPA closure. Founder-gated view: usage-status distribution, device-model scorecards,
        meter-type &times; status matrix, monthly trend, root-cause pareto, and utilization-impact
        digest across the fleet.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Usage-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No meter readings logged yet."
          rowKey={(r, i) => String(r.usage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-model scorecard</h2>
        <DataTable
          rows={modelRows}
          columns={modelCols}
          emptyMessage="No device-model rollups."
          rowKey={(r, i) => String(r.device_model ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Meter-type &times; usage-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No meters by meter type."
          rowKey={(r, i) => `${r.meter_type}-${r.usage_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly usage trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.reading_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Utilization-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No utilization-impact rollups."
          rowKey={(r, i) => String(r.utilization_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk usage queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk meters."
          rowKey={(r, i) => `${r.asset_tag}-${r.reading_date}-${i}`}
        />
      </section>
    </main>
  );
}
