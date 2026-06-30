import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type MonthlyVerdict = {
  calibration_month: string;
  total_runs: number;
  passed: number;
  with_observation: number;
  conditional: number;
  out_of_service: number;
  capa_required: number;
  pass_rate_pct: number | null;
};

type TidalHot = {
  asset_tag: string;
  ventilator_model: string;
  icu_bay: string;
  set_tidal_volume_ml: number;
  delivered_tidal_volume_ml: number;
  tidal_deviation_pct: number;
  overall_verdict: string;
  next_due_date: string;
};

type PeepBand = {
  band: string;
  unit_count: number;
  avg_deviation: number | null;
  worst_deviation: number | null;
};

type Fio2ByModel = {
  ventilator_model: string;
  units_tested: number;
  avg_fio2_deviation: number | null;
  worst_fio2_dev: number | null;
  failing_units: number;
};

type AlarmLeak = {
  alarm_test_result: string;
  leak_verdict: string;
  unit_count: number;
  avg_leak_ml_min: number | null;
};

type OpenCapa = {
  capa_id: string;
  asset_tag: string;
  capa_category: string;
  severity: string;
  raised_against: string;
  capa_status: string;
  due_within_hours: number;
  patient_safety_event: boolean;
  cost_to_close_rupees: number;
  notes: string | null;
};

type CapaLeader = {
  capa_category: string;
  total_capas: number;
  open_capas: number;
  patient_safety_evts: number;
  total_cost_rupees: number;
  avg_hours_to_close: number | null;
};

type CdscoEvent = {
  asset_tag: string;
  ventilator_model: string;
  capa_category: string;
  severity: string;
  reported_to_cdsco: boolean;
  patient_safety_event: boolean;
  capa_status: string;
  notes: string | null;
};

type NextDue = {
  asset_tag: string;
  ventilator_model: string;
  icu_bay: string;
  overall_verdict: string;
  next_due_date: string;
  days_until_due: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    monthly,
    tidalHot,
    peepDist,
    fio2Model,
    alarmLeak,
    openCapa,
    capaLeader,
    cdsco,
    nextDue,
  ] = await Promise.all([
    supabase.rpc('r3106_monthly_verdict_rollup'),
    supabase.rpc('r3106_tidal_deviation_hotlist'),
    supabase.rpc('r3106_peep_accuracy_distribution'),
    supabase.rpc('r3106_fio2_accuracy_by_model'),
    supabase.rpc('r3106_alarm_leak_failure_breakdown'),
    supabase.rpc('r3106_open_capa_queue'),
    supabase.rpc('r3106_capa_category_leaderboard'),
    supabase.rpc('r3106_cdsco_reportable_events'),
    supabase.rpc('r3106_next_due_calibration_schedule'),
  ]);

  const monthlyRows      = (monthly.data    ?? []) as MonthlyVerdict[];
  const tidalRows        = (tidalHot.data   ?? []) as TidalHot[];
  const peepRows         = (peepDist.data   ?? []) as PeepBand[];
  const fio2Rows         = (fio2Model.data  ?? []) as Fio2ByModel[];
  const alarmRows        = (alarmLeak.data  ?? []) as AlarmLeak[];
  const openCapaRows     = (openCapa.data   ?? []) as OpenCapa[];
  const capaLeaderRows   = (capaLeader.data ?? []) as CapaLeader[];
  const cdscoRows        = (cdsco.data      ?? []) as CdscoEvent[];
  const nextDueRows      = (nextDue.data    ?? []) as NextDue[];

  const monthlyCols: Column<MonthlyVerdict>[] = [
    { key: 'calibration_month', header: 'Month' },
    { key: 'total_runs',        header: 'Total runs' },
    { key: 'passed',            header: 'Passed' },
    { key: 'with_observation',  header: 'Observation' },
    { key: 'conditional',       header: 'Conditional' },
    { key: 'out_of_service',    header: 'Out of service' },
    { key: 'capa_required',     header: 'CAPA required' },
    { key: 'pass_rate_pct',     header: 'Pass rate %', render: (r) => (r.pass_rate_pct ?? 0) + '%' },
  ];

  const tidalCols: Column<TidalHot>[] = [
    { key: 'asset_tag',                 header: 'Asset' },
    { key: 'ventilator_model',          header: 'Model' },
    { key: 'icu_bay',                   header: 'Bay' },
    { key: 'set_tidal_volume_ml',       header: 'Set Vt (mL)' },
    { key: 'delivered_tidal_volume_ml', header: 'Delivered Vt (mL)' },
    { key: 'tidal_deviation_pct',       header: 'Deviation %' },
    { key: 'overall_verdict',           header: 'Verdict' },
    { key: 'next_due_date',             header: 'Next due' },
  ];

  const peepCols: Column<PeepBand>[] = [
    { key: 'band',            header: 'PEEP accuracy band' },
    { key: 'unit_count',      header: 'Units' },
    { key: 'avg_deviation',   header: 'Avg deviation (cmH2O)' },
    { key: 'worst_deviation', header: 'Worst deviation (cmH2O)' },
  ];

  const fio2Cols: Column<Fio2ByModel>[] = [
    { key: 'ventilator_model',   header: 'Ventilator model' },
    { key: 'units_tested',       header: 'Units tested' },
    { key: 'avg_fio2_deviation', header: 'Avg FiO2 deviation %' },
    { key: 'worst_fio2_dev',     header: 'Worst FiO2 deviation %' },
    { key: 'failing_units',      header: 'Units > 5% deviation' },
  ];

  const alarmCols: Column<AlarmLeak>[] = [
    { key: 'alarm_test_result', header: 'Alarm test' },
    { key: 'leak_verdict',      header: 'Leak verdict' },
    { key: 'unit_count',        header: 'Units' },
    { key: 'avg_leak_ml_min',   header: 'Avg leak (mL/min)' },
  ];

  const openCapaCols: Column<OpenCapa>[] = [
    { key: 'asset_tag',            header: 'Asset' },
    { key: 'capa_category',        header: 'Category' },
    { key: 'severity',             header: 'Severity' },
    { key: 'raised_against',       header: 'Raised against' },
    { key: 'capa_status',          header: 'Status' },
    { key: 'due_within_hours',     header: 'SLA (hrs)' },
    { key: 'patient_safety_event', header: 'PSE', render: (r) => (r.patient_safety_event ? 'yes' : 'no') },
    { key: 'cost_to_close_rupees', header: 'Cost (INR)' },
    { key: 'notes',                header: 'Notes' },
  ];

  const capaLeaderCols: Column<CapaLeader>[] = [
    { key: 'capa_category',       header: 'Category' },
    { key: 'total_capas',         header: 'Total' },
    { key: 'open_capas',          header: 'Open' },
    { key: 'patient_safety_evts', header: 'PSE count' },
    { key: 'total_cost_rupees',   header: 'Total cost (INR)' },
    { key: 'avg_hours_to_close',  header: 'Avg hrs to close' },
  ];

  const cdscoCols: Column<CdscoEvent>[] = [
    { key: 'asset_tag',            header: 'Asset' },
    { key: 'ventilator_model',     header: 'Model' },
    { key: 'capa_category',        header: 'CAPA category' },
    { key: 'severity',             header: 'Severity' },
    { key: 'reported_to_cdsco',    header: 'CDSCO reported', render: (r) => (r.reported_to_cdsco ? 'yes' : 'no') },
    { key: 'patient_safety_event', header: 'PSE', render: (r) => (r.patient_safety_event ? 'yes' : 'no') },
    { key: 'capa_status',          header: 'Status' },
    { key: 'notes',                header: 'Notes' },
  ];

  const nextDueCols: Column<NextDue>[] = [
    { key: 'asset_tag',        header: 'Asset' },
    { key: 'ventilator_model', header: 'Model' },
    { key: 'icu_bay',          header: 'Bay' },
    { key: 'overall_verdict',  header: 'Last verdict' },
    { key: 'next_due_date',    header: 'Next due' },
    { key: 'days_until_due',   header: 'Days until due' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-10 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold tracking-tight">
          Ventilator Calibration & Tidal-Volume Accuracy Audit
        </h1>
        <p className="text-sm text-gray-600">
          Monthly ICU ventilator calibration rollup — set vs delivered tidal volume, PEEP accuracy,
          FiO2 mix drift, alarm + leak tests, and the CAPA queue. Patient-safety events and CDSCO
          reportables surfaced at the top.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Monthly verdict rollup</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No calibration runs recorded yet."
          rowKey={(r, i) => String(r.calibration_month ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Tidal volume deviation hotlist (&gt;= 2% absolute)</h2>
        <DataTable
          rows={tidalRows}
          columns={tidalCols}
          emptyMessage="No units exceed the 2% tidal deviation threshold."
          rowKey={(r, i) => String(r.asset_tag ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">PEEP accuracy distribution</h2>
        <DataTable
          rows={peepRows}
          columns={peepCols}
          emptyMessage="No PEEP data."
          rowKey={(r, i) => String(r.band ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">FiO2 mix accuracy by model</h2>
        <DataTable
          rows={fio2Rows}
          columns={fio2Cols}
          emptyMessage="No FiO2 data."
          rowKey={(r, i) => String(r.ventilator_model ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Alarm + leak failure breakdown</h2>
        <DataTable
          rows={alarmRows}
          columns={alarmCols}
          emptyMessage="No alarm or leak data."
          rowKey={(r, i) => String((r.alarm_test_result ?? '') + '|' + (r.leak_verdict ?? '') + '|' + i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Open CAPA queue (p0 first, SLA-sorted)</h2>
        <DataTable
          rows={openCapaRows}
          columns={openCapaCols}
          emptyMessage="No open CAPA items. ICU fleet is calibrated."
          rowKey={(r, i) => String(r.capa_id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">CAPA category leaderboard</h2>
        <DataTable
          rows={capaLeaderRows}
          columns={capaLeaderCols}
          emptyMessage="No CAPA categories logged."
          rowKey={(r, i) => String(r.capa_category ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">CDSCO reportable + patient-safety events</h2>
        <DataTable
          rows={cdscoRows}
          columns={cdscoCols}
          emptyMessage="No CDSCO reportables — clean fleet."
          rowKey={(r, i) => String(r.asset_tag ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Next-due calibration schedule</h2>
        <DataTable
          rows={nextDueRows}
          columns={nextDueCols}
          emptyMessage="No upcoming calibrations scheduled."
          rowKey={(r, i) => String(r.asset_tag ?? i)}
        />
      </section>
    </main>
  );
}
