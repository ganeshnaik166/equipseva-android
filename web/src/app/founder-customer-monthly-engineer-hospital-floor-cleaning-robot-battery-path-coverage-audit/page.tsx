import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type FleetSummary = {
  total_robots: number;
  hospitals_covered: number;
  avg_battery_health: number;
  avg_coverage_pct: number;
  critical_batteries: number;
  critical_paths: number;
};

type BatteryBreakdown = {
  battery_status: string;
  robot_count: number;
  avg_health: number;
  avg_cycles: number;
  replacement_count: number;
};

type HospitalScorecard = {
  hospital_code: string;
  robot_count: number;
  avg_battery: number;
  avg_coverage: number;
  urgent_replacements: number;
  remap_needed: number;
};

type EngineerPerf = {
  engineer_name: string;
  audits_completed: number;
  avg_battery_audited: number;
  flagged_robots: number;
};

type UrgentRep = {
  hospital_code: string;
  floor_label: string;
  robot_serial: string;
  battery_health_pct: number;
  battery_status: string;
  next_audit_due: string | null;
  notes: string | null;
};

type PathBreakdown = {
  path_status: string;
  zone_count: number;
  avg_coverage: number;
  total_missed: number;
  total_obstacles: number;
};

type LowZone = {
  hospital_code: string;
  floor_label: string;
  zone_name: string;
  coverage_pct: number;
  missed_zones_count: number;
  obstacle_events: number;
  path_status: string;
  audited_by: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    fleetRes,
    batteryRes,
    hospitalRes,
    engineerRes,
    urgentRes,
    pathRes,
    lowRes,
  ] = await Promise.all([
    supabase.rpc('r3076_fleet_summary'),
    supabase.rpc('r3076_battery_status_breakdown'),
    supabase.rpc('r3076_hospital_scorecard'),
    supabase.rpc('r3076_engineer_performance'),
    supabase.rpc('r3076_urgent_replacements'),
    supabase.rpc('r3076_path_status_breakdown'),
    supabase.rpc('r3076_low_coverage_zones'),
  ]);

  const fleet = (fleetRes.data ?? []) as FleetSummary[];
  const battery = (batteryRes.data ?? []) as BatteryBreakdown[];
  const hospital = (hospitalRes.data ?? []) as HospitalScorecard[];
  const engineer = (engineerRes.data ?? []) as EngineerPerf[];
  const urgent = (urgentRes.data ?? []) as UrgentRep[];
  const path = (pathRes.data ?? []) as PathBreakdown[];
  const low = (lowRes.data ?? []) as LowZone[];

  const fleetCols: Column<FleetSummary>[] = [
    { header: 'Total Robots', accessor: (r) => r.total_robots },
    { header: 'Hospitals', accessor: (r) => r.hospitals_covered },
    { header: 'Avg Battery %', accessor: (r) => r.avg_battery_health },
    { header: 'Avg Coverage %', accessor: (r) => r.avg_coverage_pct },
    { header: 'Critical Batteries', accessor: (r) => r.critical_batteries },
    { header: 'Critical Paths', accessor: (r) => r.critical_paths },
  ];

  const batteryCols: Column<BatteryBreakdown>[] = [
    { header: 'Status', accessor: (r) => r.battery_status },
    { header: 'Robots', accessor: (r) => r.robot_count },
    { header: 'Avg Health %', accessor: (r) => r.avg_health },
    { header: 'Avg Cycles', accessor: (r) => r.avg_cycles },
    { header: 'Replace Flagged', accessor: (r) => r.replacement_count },
  ];

  const hospitalCols: Column<HospitalScorecard>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_code },
    { header: 'Robots', accessor: (r) => r.robot_count },
    { header: 'Avg Battery %', accessor: (r) => r.avg_battery },
    { header: 'Avg Coverage %', accessor: (r) => r.avg_coverage },
    { header: 'Urgent Repl.', accessor: (r) => r.urgent_replacements },
    { header: 'Remap Needed', accessor: (r) => r.remap_needed },
  ];

  const engineerCols: Column<EngineerPerf>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits_completed },
    { header: 'Avg Battery %', accessor: (r) => r.avg_battery_audited },
    { header: 'Flagged Robots', accessor: (r) => r.flagged_robots },
  ];

  const urgentCols: Column<UrgentRep>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_code },
    { header: 'Floor', accessor: (r) => r.floor_label },
    { header: 'Robot', accessor: (r) => r.robot_serial },
    { header: 'Health %', accessor: (r) => r.battery_health_pct },
    { header: 'Status', accessor: (r) => r.battery_status },
    { header: 'Next Audit', accessor: (r) => r.next_audit_due ?? '-' },
    { header: 'Notes', accessor: (r) => r.notes ?? '-' },
  ];

  const pathCols: Column<PathBreakdown>[] = [
    { header: 'Path Status', accessor: (r) => r.path_status },
    { header: 'Zones', accessor: (r) => r.zone_count },
    { header: 'Avg Coverage %', accessor: (r) => r.avg_coverage },
    { header: 'Total Missed', accessor: (r) => r.total_missed },
    { header: 'Total Obstacles', accessor: (r) => r.total_obstacles },
  ];

  const lowCols: Column<LowZone>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_code },
    { header: 'Floor', accessor: (r) => r.floor_label },
    { header: 'Zone', accessor: (r) => r.zone_name },
    { header: 'Coverage %', accessor: (r) => r.coverage_pct },
    { header: 'Missed', accessor: (r) => r.missed_zones_count },
    { header: 'Obstacles', accessor: (r) => r.obstacle_events },
    { header: 'Path Status', accessor: (r) => r.path_status },
    { header: 'Auditor', accessor: (r) => r.audited_by ?? '-' },
  ];

  return (
    <main style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      <header>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 700 }}>
          Hospital Floor-Cleaning Robot Battery & Path Coverage Audit (r3076)
        </h1>
        <p style={{ color: '#555' }}>
          Monthly engineer-led audit covering battery health & path coverage across hospital robot fleet.
        </p>
      </header>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: '0.5rem' }}>Fleet Summary</h2>
        <DataTable
          rows={fleet}
          columns={fleetCols}
          emptyMessage="No fleet data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: '0.5rem' }}>Battery Status Breakdown</h2>
        <DataTable
          rows={battery}
          columns={batteryCols}
          emptyMessage="No battery data."
          rowKey={(r, i) => String(r.battery_status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: '0.5rem' }}>Hospital Scorecard</h2>
        <DataTable
          rows={hospital}
          columns={hospitalCols}
          emptyMessage="No hospital data."
          rowKey={(r, i) => String(r.hospital_code ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: '0.5rem' }}>Engineer Audit Performance</h2>
        <DataTable
          rows={engineer}
          columns={engineerCols}
          emptyMessage="No engineer data."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: '0.5rem' }}>Urgent Battery Replacements</h2>
        <DataTable
          rows={urgent}
          columns={urgentCols}
          emptyMessage="No urgent replacements."
          rowKey={(r, i) => String(r.robot_serial ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: '0.5rem' }}>Path Coverage by Status</h2>
        <DataTable
          rows={path}
          columns={pathCols}
          emptyMessage="No path data."
          rowKey={(r, i) => String(r.path_status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: '0.5rem' }}>Low Coverage Zones (&lt; 90%)</h2>
        <DataTable
          rows={low}
          columns={lowCols}
          emptyMessage="No low coverage zones."
          rowKey={(r, i) => String(i)}
        />
      </section>
    </main>
  );
}
