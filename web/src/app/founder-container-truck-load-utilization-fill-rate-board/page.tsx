import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { utilization_status: string; entries: number; pct: number };
type LaneRow = {
  lane_name: string;
  entries: number;
  total_trips: number;
  avg_fill_rate_pct: number;
  avg_target_fill_pct: number;
  avg_cube_utilization_pct: number;
  part_load_trips: number;
  consolidation_missed: number;
  avg_cost_per_trip_rupees: number;
};
type MatrixRow = {
  load_mode: string;
  utilization_status: string;
  entries: number;
  avg_fill_rate_pct: number;
  avg_cost_per_trip_rupees: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_trips: number;
  avg_fill_rate_pct: number;
  avg_target_fill_pct: number;
  avg_cube_utilization_pct: number;
  underfilled_entries: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_savings_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_savings_rupees: number;
  pct: number;
};
type MissRow = {
  lane_name: string;
  entries: number;
  total_trips: number;
  part_load_trips: number;
  consolidation_missed: number;
  miss_rate_pct: number;
  est_leakage_rupees: number;
};
type RiskRow = {
  lane_code: string;
  lane_name: string;
  vehicle_type: string;
  load_mode: string;
  period_month: string;
  fill_rate_pct: number | null;
  target_fill_pct: number | null;
  cube_utilization_pct: number | null;
  utilization_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    laneRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    missRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3670_utilization_status_rollup'),
    supabase.rpc('founder_r3670_lane_scorecard'),
    supabase.rpc('founder_r3670_load_mode_status_matrix'),
    supabase.rpc('founder_r3670_monthly_fill_rate_trend'),
    supabase.rpc('founder_r3670_capa_status_board'),
    supabase.rpc('founder_r3670_root_cause_pareto'),
    supabase.rpc('founder_r3670_consolidation_miss_digest'),
    supabase.rpc('founder_r3670_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const laneRows: LaneRow[] = (laneRes.data as LaneRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const missRows: MissRow[] = (missRes.data as MissRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'utilization_status', header: 'Utilization Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const laneCols: Column<LaneRow>[] = [
    { key: 'lane_name', header: 'Lane' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_trips', header: 'Trips' },
    { key: 'avg_fill_rate_pct', header: 'Avg Fill %' },
    { key: 'avg_target_fill_pct', header: 'Target Fill %' },
    { key: 'avg_cube_utilization_pct', header: 'Avg Cube %' },
    { key: 'part_load_trips', header: 'Part-Load Trips' },
    { key: 'consolidation_missed', header: 'Consol. Missed' },
    { key: 'avg_cost_per_trip_rupees', header: 'Avg Cost/Trip (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'load_mode', header: 'Load Mode' },
    { key: 'utilization_status', header: 'Utilization Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_fill_rate_pct', header: 'Avg Fill %' },
    { key: 'avg_cost_per_trip_rupees', header: 'Avg Cost/Trip (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_trips', header: 'Trips' },
    { key: 'avg_fill_rate_pct', header: 'Avg Fill %' },
    { key: 'avg_target_fill_pct', header: 'Target Fill %' },
    { key: 'avg_cube_utilization_pct', header: 'Avg Cube %' },
    { key: 'underfilled_entries', header: 'Under / Frag / Wasteful' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_savings_rupees', header: 'Avg Savings (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const missCols: Column<MissRow>[] = [
    { key: 'lane_name', header: 'Lane' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_trips', header: 'Trips' },
    { key: 'part_load_trips', header: 'Part-Load Trips' },
    { key: 'consolidation_missed', header: 'Consol. Missed' },
    { key: 'miss_rate_pct', header: 'Miss Rate %' },
    { key: 'est_leakage_rupees', header: 'Est. Leakage (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'lane_code', header: 'Code' },
    { key: 'lane_name', header: 'Lane' },
    { key: 'vehicle_type', header: 'Vehicle' },
    { key: 'load_mode', header: 'Mode' },
    { key: 'period_month', header: 'Month' },
    { key: 'fill_rate_pct', header: 'Fill %' },
    { key: 'target_fill_pct', header: 'Target %' },
    { key: 'cube_utilization_pct', header: 'Cube %' },
    { key: 'utilization_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Container / Truck Load-Utilization &amp; Fill-Rate Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Container and truck load-utilization board — lane &times; vehicle type &times; load mode
        (FTL, PTL, 20ft &amp; 40ft containers, small tempo) &times; trips &times; fill rate vs
        target &times; cube utilization &times; part-load share &times; missed consolidation
        windows &times; cost per trip &amp; CAPA closure. Founder-gated view: utilization-status
        distribution, lane scorecards, monthly fill-rate trend, root-cause pareto, and the
        consolidation-miss leakage digest across Bhiwandi, Nhava Sheva &amp; Delhi Air lanes.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Utilization status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No load-utilization entries logged yet."
          rowKey={(r, i) => String(r.utilization_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Lane utilization scorecard</h2>
        <DataTable
          rows={laneRows}
          columns={laneCols}
          emptyMessage="No lane rollups."
          rowKey={(r, i) => String(r.lane_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Load mode &times; utilization status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by load mode."
          rowKey={(r, i) => `${r.load_mode}-${r.utilization_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly fill-rate trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Consolidation-miss digest</h2>
        <DataTable
          rows={missRows}
          columns={missCols}
          emptyMessage="No consolidation-miss rollups."
          rowKey={(r, i) => `${r.lane_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk lane queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lanes."
          rowKey={(r, i) => `${r.lane_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
