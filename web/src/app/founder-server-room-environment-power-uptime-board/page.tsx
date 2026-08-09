import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { environment_status: string; rooms: number; pct: number };
type SiteRow = {
  site_name: string;
  rooms: number;
  healthy: number;
  watch: number;
  excursion_prone: number;
  power_risk: number;
  critical: number;
  total_excursions: number;
  healthy_pct: number;
};
type MatrixRow = {
  room_class: string;
  environment_status: string;
  rooms: number;
  avg_temp_c: number;
  total_excursions: number;
};
type TrendRow = {
  period_month: string;
  rooms: number;
  total_excursions: number;
  total_power_events: number;
  total_generator_takeovers: number;
  avg_max_temp_c: number;
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
type PowerRow = {
  site_name: string;
  rooms: number;
  total_power_events: number;
  total_generator_takeovers: number;
  avg_ups_runtime_min: number;
  total_ups_capacity_kva: number;
  no_redundancy_rooms: number;
};
type RiskRow = {
  room_code: string;
  room_name: string;
  site_name: string;
  period_month: string;
  room_class: string;
  environment_status: string;
  temp_excursions: number;
  power_events: number;
  ups_runtime_min: number | null;
  cooling_redundancy: boolean;
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
    powerRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3683_environment_status_rollup'),
    supabase.rpc('founder_r3683_site_scorecard'),
    supabase.rpc('founder_r3683_room_class_status_matrix'),
    supabase.rpc('founder_r3683_monthly_excursion_trend'),
    supabase.rpc('founder_r3683_capa_status_board'),
    supabase.rpc('founder_r3683_root_cause_pareto'),
    supabase.rpc('founder_r3683_power_event_digest'),
    supabase.rpc('founder_r3683_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const powerRows: PowerRow[] = (powerRes.data as PowerRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'environment_status', header: 'Environment Status' },
    { key: 'rooms', header: 'Rooms' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'rooms', header: 'Rooms' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'watch', header: 'Watch' },
    { key: 'excursion_prone', header: 'Excursion-Prone' },
    { key: 'power_risk', header: 'Power Risk' },
    { key: 'critical', header: 'Critical' },
    { key: 'total_excursions', header: 'Temp Excursions' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'room_class', header: 'Room Class' },
    { key: 'environment_status', header: 'Status' },
    { key: 'rooms', header: 'Rooms' },
    { key: 'avg_temp_c', header: 'Avg Temp °C' },
    { key: 'total_excursions', header: 'Excursions' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'rooms', header: 'Rooms' },
    { key: 'total_excursions', header: 'Temp Excursions' },
    { key: 'total_power_events', header: 'Power Events' },
    { key: 'total_generator_takeovers', header: 'Genset Takeovers' },
    { key: 'avg_max_temp_c', header: 'Avg Max Temp °C' },
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

  const powerCols: Column<PowerRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'rooms', header: 'Rooms' },
    { key: 'total_power_events', header: 'Power Events' },
    { key: 'total_generator_takeovers', header: 'Genset Takeovers' },
    { key: 'avg_ups_runtime_min', header: 'Avg UPS Runtime (min)' },
    { key: 'total_ups_capacity_kva', header: 'UPS Capacity (kVA)' },
    { key: 'no_redundancy_rooms', header: 'No Cooling Redundancy' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'room_code', header: 'Room' },
    { key: 'room_name', header: 'Name' },
    { key: 'site_name', header: 'Site' },
    { key: 'period_month', header: 'Month' },
    { key: 'room_class', header: 'Class' },
    { key: 'environment_status', header: 'Status' },
    { key: 'temp_excursions', header: 'Excursions' },
    { key: 'power_events', header: 'Power Events' },
    { key: 'ups_runtime_min', header: 'UPS Runtime (min)' },
    { key: 'cooling_redundancy', header: 'Cooling Redundancy' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Server-Room Environment / Power / Uptime Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Own server &amp; network-room environment log — room class (server rooms, network closets,
        UPS rooms, telecom racks, edge cabinets) &times; site &times; avg/max temp &times; humidity
        &times; temp excursions &times; UPS capacity &amp; runtime &times; power events &times;
        generator takeovers &times; cooling redundancy &times; thermal audit currency &amp; CAPA
        closure. Founder-gated view: status rollups, site scorecards, monthly excursion trends,
        power-event digests, and the high-risk (critical / power-risk) room queue across Mumbai HQ,
        Chennai branch, Delhi warehouse &amp; Bengaluru refurb center.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Environment status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No room logs yet."
          rowKey={(r, i) => String(r.environment_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site environment scorecard</h2>
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
          rowKey={(r, i) => `${r.room_class}-${r.environment_status}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Power-event digest</h2>
        <DataTable
          rows={powerRows}
          columns={powerCols}
          emptyMessage="No power-event rollups."
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
