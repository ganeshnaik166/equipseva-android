import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type FleetRow = {
  compliance_status: string;
  unit_count: number;
  pediatric_capable_count: number;
  avg_battery_age_months: number;
  pct_of_fleet: number;
};

type PadExpiryRow = {
  asset_tag: string;
  ward_location: string;
  manufacturer: string;
  adult_pad_expiry: string;
  pediatric_pad_expiry: string | null;
  days_to_adult_expiry: number;
  days_to_pediatric_expiry: number | null;
  urgency: string;
};

type EnergyRow = {
  asset_tag: string;
  manufacturer: string;
  tests_in_window: number;
  worst_deviation_pct: number;
  avg_deviation_pct: number;
  failing_tests: number;
  deviation_flag: string;
};

type BatteryRow = {
  ward_location: string;
  unit_count: number;
  avg_battery_age_months: number;
  units_past_rated_life: number;
  avg_last_voltage_v: number;
  battery_alert_flag: string;
};

type PediatricRow = {
  ward_location: string;
  pediatric_capable_units: number;
  pediatric_pad_valid: number;
  pediatric_pad_expired: number;
  pediatric_pad_missing: number;
  readiness_pct: number;
};

type MonthlyRow = {
  asset_tag: string;
  ward_location: string;
  last_test_at: string | null;
  next_test_due_at: string;
  days_overdue: number;
  last_result: string;
  compliance_flag: string;
};

type CapaRow = {
  capa_action: string;
  open_count: number;
  closed_count: number;
  total_cost_rupees: number;
  avg_close_days: number | null;
  latest_open_at: string | null;
};

type ManufacturerRow = {
  manufacturer: string;
  unit_count: number;
  total_tests: number;
  pass_count: number;
  fail_count: number;
  pass_rate_pct: number;
  avg_energy_deviation_pct: number;
};

type CostRow = {
  ward_location: string;
  test_count: number;
  capa_count: number;
  total_cost_rupees: number;
  avg_cost_per_test_rupees: number;
  high_cost_flag: string;
};

function fmtDate(value: string | null): string {
  if (!value) return '-';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toISOString().slice(0, 10);
}

function fmtDateTime(value: string | null): string {
  if (!value) return '-';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toISOString().replace('T', ' ').slice(0, 16) + 'Z';
}

function fmtINR(rupees: number | null | undefined): string {
  if (rupees == null) return '-';
  return 'Rs ' + rupees.toLocaleString('en-IN');
}

export default async function FounderDefibAedEnergyCompliancePage() {
  const supabase = await getSupabaseServerClient();

  const [
    fleetRes,
    padRes,
    energyRes,
    batteryRes,
    pediatricRes,
    monthlyRes,
    capaRes,
    mfgRes,
    costRes,
  ] = await Promise.all([
    supabase.rpc('founder_defib_aed_fleet_overview_r3116'),
    supabase.rpc('founder_defib_aed_pad_expiry_alerts_r3116'),
    supabase.rpc('founder_defib_aed_energy_deviation_r3116'),
    supabase.rpc('founder_defib_aed_battery_health_r3116'),
    supabase.rpc('founder_defib_aed_pediatric_readiness_r3116'),
    supabase.rpc('founder_defib_aed_monthly_test_compliance_r3116'),
    supabase.rpc('founder_defib_aed_capa_register_r3116'),
    supabase.rpc('founder_defib_aed_manufacturer_reliability_r3116'),
    supabase.rpc('founder_defib_aed_capa_cost_by_ward_r3116'),
  ]);

  const fleet = (fleetRes.data ?? []) as FleetRow[];
  const padAlerts = (padRes.data ?? []) as PadExpiryRow[];
  const energy = (energyRes.data ?? []) as EnergyRow[];
  const battery = (batteryRes.data ?? []) as BatteryRow[];
  const pediatric = (pediatricRes.data ?? []) as PediatricRow[];
  const monthly = (monthlyRes.data ?? []) as MonthlyRow[];
  const capa = (capaRes.data ?? []) as CapaRow[];
  const mfg = (mfgRes.data ?? []) as ManufacturerRow[];
  const cost = (costRes.data ?? []) as CostRow[];

  const fleetColumns: Column<FleetRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status', render: (r) => r.compliance_status.replaceAll('_', ' ') },
    { key: 'unit_count', header: 'Units' },
    { key: 'pediatric_capable_count', header: 'Pediatric Capable' },
    { key: 'avg_battery_age_months', header: 'Avg Battery Age (mo)' },
    { key: 'pct_of_fleet', header: 'Pct of Fleet', render: (r) => r.pct_of_fleet + '%' },
  ];

  const padColumns: Column<PadExpiryRow>[] = [
    { key: 'asset_tag', header: 'Asset Tag' },
    { key: 'ward_location', header: 'Ward', render: (r) => r.ward_location.replaceAll('_', ' ') },
    { key: 'manufacturer', header: 'Manufacturer', render: (r) => r.manufacturer.replaceAll('_', ' ') },
    { key: 'adult_pad_expiry', header: 'Adult Pad Expiry', render: (r) => fmtDate(r.adult_pad_expiry) },
    { key: 'pediatric_pad_expiry', header: 'Pediatric Pad Expiry', render: (r) => fmtDate(r.pediatric_pad_expiry) },
    { key: 'days_to_adult_expiry', header: 'Days to Adult Expiry' },
    { key: 'days_to_pediatric_expiry', header: 'Days to Pediatric Expiry', render: (r) => r.days_to_pediatric_expiry == null ? '-' : String(r.days_to_pediatric_expiry) },
    { key: 'urgency', header: 'Urgency', render: (r) => r.urgency.replaceAll('_', ' ') },
  ];

  const energyColumns: Column<EnergyRow>[] = [
    { key: 'asset_tag', header: 'Asset Tag' },
    { key: 'manufacturer', header: 'Manufacturer', render: (r) => r.manufacturer.replaceAll('_', ' ') },
    { key: 'tests_in_window', header: 'Tests (180d)' },
    { key: 'worst_deviation_pct', header: 'Worst Deviation %' },
    { key: 'avg_deviation_pct', header: 'Avg Deviation %' },
    { key: 'failing_tests', header: 'Failing Tests' },
    { key: 'deviation_flag', header: 'Flag', render: (r) => r.deviation_flag.replaceAll('_', ' ') },
  ];

  const batteryColumns: Column<BatteryRow>[] = [
    { key: 'ward_location', header: 'Ward', render: (r) => r.ward_location.replaceAll('_', ' ') },
    { key: 'unit_count', header: 'Units' },
    { key: 'avg_battery_age_months', header: 'Avg Battery Age (mo)' },
    { key: 'units_past_rated_life', header: 'Past Rated Life' },
    { key: 'avg_last_voltage_v', header: 'Avg Last Voltage (V)' },
    { key: 'battery_alert_flag', header: 'Battery Alert', render: (r) => r.battery_alert_flag.replaceAll('_', ' ') },
  ];

  const pediatricColumns: Column<PediatricRow>[] = [
    { key: 'ward_location', header: 'Ward', render: (r) => r.ward_location.replaceAll('_', ' ') },
    { key: 'pediatric_capable_units', header: 'Pediatric Capable' },
    { key: 'pediatric_pad_valid', header: 'Pads Valid' },
    { key: 'pediatric_pad_expired', header: 'Pads Expired' },
    { key: 'pediatric_pad_missing', header: 'Pads Missing' },
    { key: 'readiness_pct', header: 'Readiness %', render: (r) => r.readiness_pct + '%' },
  ];

  const monthlyColumns: Column<MonthlyRow>[] = [
    { key: 'asset_tag', header: 'Asset Tag' },
    { key: 'ward_location', header: 'Ward', render: (r) => r.ward_location.replaceAll('_', ' ') },
    { key: 'last_test_at', header: 'Last Test', render: (r) => fmtDateTime(r.last_test_at) },
    { key: 'next_test_due_at', header: 'Next Due', render: (r) => fmtDateTime(r.next_test_due_at) },
    { key: 'days_overdue', header: 'Days Overdue' },
    { key: 'last_result', header: 'Last Result', render: (r) => r.last_result.replaceAll('_', ' ') },
    { key: 'compliance_flag', header: 'Compliance', render: (r) => r.compliance_flag.replaceAll('_', ' ') },
  ];

  const capaColumns: Column<CapaRow>[] = [
    { key: 'capa_action', header: 'CAPA Action', render: (r) => r.capa_action.replaceAll('_', ' ') },
    { key: 'open_count', header: 'Open' },
    { key: 'closed_count', header: 'Closed' },
    { key: 'total_cost_rupees', header: 'Total Cost', render: (r) => fmtINR(r.total_cost_rupees) },
    { key: 'avg_close_days', header: 'Avg Close (days)', render: (r) => r.avg_close_days == null ? '-' : String(r.avg_close_days) },
    { key: 'latest_open_at', header: 'Latest Open', render: (r) => fmtDateTime(r.latest_open_at) },
  ];

  const mfgColumns: Column<ManufacturerRow>[] = [
    { key: 'manufacturer', header: 'Manufacturer', render: (r) => r.manufacturer.replaceAll('_', ' ') },
    { key: 'unit_count', header: 'Units' },
    { key: 'total_tests', header: 'Total Tests' },
    { key: 'pass_count', header: 'Pass' },
    { key: 'fail_count', header: 'Fail' },
    { key: 'pass_rate_pct', header: 'Pass Rate', render: (r) => r.pass_rate_pct + '%' },
    { key: 'avg_energy_deviation_pct', header: 'Avg Deviation %' },
  ];

  const costColumns: Column<CostRow>[] = [
    { key: 'ward_location', header: 'Ward', render: (r) => r.ward_location.replaceAll('_', ' ') },
    { key: 'test_count', header: 'Tests' },
    { key: 'capa_count', header: 'CAPA Count' },
    { key: 'total_cost_rupees', header: 'Total Cost', render: (r) => fmtINR(r.total_cost_rupees) },
    { key: 'avg_cost_per_test_rupees', header: 'Avg Cost / Test', render: (r) => fmtINR(r.avg_cost_per_test_rupees) },
    { key: 'high_cost_flag', header: 'Cost Tier', render: (r) => r.high_cost_flag.replaceAll('_', ' ') },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-8 px-4 py-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Defibrillator & AED Energy-Delivery Compliance</h1>
        <p className="text-sm text-gray-600">
          Monthly self-test plus quarterly manual shock verification across hospital fleet. Tracks
          delivered joules vs target, pad expiry (adult & pediatric), battery age & voltage,
          pediatric-mode readiness, and CAPA closure for any failed test.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Fleet Compliance Overview</h2>
        <DataTable
          rows={fleet}
          columns={fleetColumns}
          emptyMessage="No fleet rollup rows yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Pad Expiry Alerts (within 120 days)</h2>
        <DataTable
          rows={padAlerts}
          columns={padColumns}
          emptyMessage="No pads expiring soon."
          rowKey={(r, i) => String(r.asset_tag ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Energy Deviation per Unit (last 180 days)</h2>
        <p className="text-xs text-gray-500">
          Flag: critical when worst deviation &lt;= -10%, warning when &lt;= -5%.
        </p>
        <DataTable
          rows={energy}
          columns={energyColumns}
          emptyMessage="No shock-test data."
          rowKey={(r, i) => String(r.asset_tag ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Battery Health by Ward</h2>
        <DataTable
          rows={battery}
          columns={batteryColumns}
          emptyMessage="No battery telemetry."
          rowKey={(r, i) => String(r.ward_location ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Pediatric-Mode Readiness</h2>
        <p className="text-xs text-gray-500">
          Pediatric-capable units must have non-expired pediatric pads on board.
        </p>
        <DataTable
          rows={pediatric}
          columns={pediatricColumns}
          emptyMessage="No pediatric-capable units."
          rowKey={(r, i) => String(r.ward_location ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Monthly Self-Test Compliance</h2>
        <DataTable
          rows={monthly}
          columns={monthlyColumns}
          emptyMessage="No units."
          rowKey={(r, i) => String(r.asset_tag ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">CAPA Register</h2>
        <DataTable
          rows={capa}
          columns={capaColumns}
          emptyMessage="No CAPA actions logged."
          rowKey={(r, i) => String(r.capa_action ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Manufacturer Reliability Index</h2>
        <DataTable
          rows={mfg}
          columns={mfgColumns}
          emptyMessage="No manufacturer data."
          rowKey={(r, i) => String(r.manufacturer ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">CAPA Cost by Ward</h2>
        <DataTable
          rows={cost}
          columns={costColumns}
          emptyMessage="No cost data."
          rowKey={(r, i) => String(r.ward_location ?? i)}
        />
      </section>
    </div>
  );
}
