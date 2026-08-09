import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { utilization_status: string; rooms: number; pct: number };
type SiteRow = {
  site_name: string;
  rooms: number;
  total_bookings: number;
  avg_utilization_pct: number;
  total_no_shows: number;
  avg_no_show_pct: number;
  av_faults: number;
  optimal_rooms: number;
  at_risk_rooms: number;
};
type MatrixRow = {
  room_class: string;
  utilization_status: string;
  rooms: number;
  avg_utilization_pct: number;
  total_no_shows: number;
};
type TrendRow = {
  period_month: string;
  rooms: number;
  total_bookings: number;
  total_hours_booked: number;
  total_hours_used: number;
  avg_utilization_pct: number;
  total_no_shows: number;
  av_faults: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_hours_lost: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_hours_lost: number;
  pct: number;
};
type NoShowRow = {
  site_name: string;
  rooms: number;
  total_bookings: number;
  total_no_shows: number;
  avg_no_show_pct: number;
  no_show_heavy_rooms: number;
  worsening_rooms: number;
};
type RiskRow = {
  room_code: string;
  room_name: string;
  site_name: string;
  room_class: string;
  period_month: string;
  utilization_status: string;
  no_show_pct: number | null;
  av_equipment_faults: number | null;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    siteRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    noShowRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3697_utilization_status_rollup'),
    supabase.rpc('founder_r3697_site_scorecard'),
    supabase.rpc('founder_r3697_room_class_status_matrix'),
    supabase.rpc('founder_r3697_monthly_utilization_trend'),
    supabase.rpc('founder_r3697_capa_status_board'),
    supabase.rpc('founder_r3697_root_cause_pareto'),
    supabase.rpc('founder_r3697_no_show_digest'),
    supabase.rpc('founder_r3697_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const noShowRows: NoShowRow[] = (noShowRes.data as NoShowRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'utilization_status', header: 'Utilization Status' },
    { key: 'rooms', header: 'Room-Months' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'rooms', header: 'Room-Months' },
    { key: 'total_bookings', header: 'Bookings' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_no_shows', header: 'No-Shows' },
    { key: 'avg_no_show_pct', header: 'Avg No-Show %' },
    { key: 'av_faults', header: 'AV Faults' },
    { key: 'optimal_rooms', header: 'Optimal' },
    { key: 'at_risk_rooms', header: 'At Risk' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'room_class', header: 'Room Class' },
    { key: 'utilization_status', header: 'Status' },
    { key: 'rooms', header: 'Room-Months' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_no_shows', header: 'No-Shows' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'rooms', header: 'Rooms' },
    { key: 'total_bookings', header: 'Bookings' },
    { key: 'total_hours_booked', header: 'Hours Booked' },
    { key: 'total_hours_used', header: 'Hours Used' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'total_no_shows', header: 'No-Shows' },
    { key: 'av_faults', header: 'AV Faults' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_hours_lost', header: 'Avg Hours Lost' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_hours_lost', header: 'Total Hours Lost' },
    { key: 'pct', header: 'Share %' },
  ];

  const noShowCols: Column<NoShowRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'rooms', header: 'Room-Months' },
    { key: 'total_bookings', header: 'Bookings' },
    { key: 'total_no_shows', header: 'No-Shows' },
    { key: 'avg_no_show_pct', header: 'Avg No-Show %' },
    { key: 'no_show_heavy_rooms', header: 'No-Show Heavy' },
    { key: 'worsening_rooms', header: 'Worsening' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'room_code', header: 'Room Code' },
    { key: 'room_name', header: 'Room' },
    { key: 'site_name', header: 'Site' },
    { key: 'room_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'utilization_status', header: 'Status' },
    { key: 'no_show_pct', header: 'No-Show %' },
    { key: 'av_equipment_faults', header: 'AV Faults' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Meeting-Room / Workspace Utilization Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Meeting-room and workspace utilization discipline — room &times; site (Mumbai HQ, Chennai,
        Delhi, Bengaluru) &times; period &times; bookings &times; hours booked vs used &times;
        utilization % &times; no-shows &amp; no-show % &times; overruns &times; AV equipment faults
        &times; occupancy ratio &amp; CAPA closure. Founder-gated view: utilization-status rollups,
        site scorecards, room-class &times; status matrix, monthly trend, root-cause pareto, and the
        no-show-heavy / equipment-issues queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Utilization-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No room utilization rows logged yet."
          rowKey={(r, i) => String(r.utilization_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site workspace scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Room class &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No rooms by class."
          rowKey={(r, i) => `${r.room_class}-${r.utilization_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly utilization trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. No-show digest by site</h2>
        <DataTable
          rows={noShowRows}
          columns={noShowCols}
          emptyMessage="No no-show rollups."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk room queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk rooms."
          rowKey={(r, i) => `${r.room_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
