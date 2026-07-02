import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type BankByHospital = {
  hospital_org_id: string;
  hospital_name: string;
  total_filters: number;
  breached: number;
  replacement_due: number;
  watchlist: number;
  in_service: number;
};

type PriorityQueue = {
  priority: string;
  filter_count: number;
  avg_age_months: number;
  oldest_install_date: string;
};

type IsoCompliance = {
  iso_class_target: string;
  total_readings: number;
  pass_count: number;
  marginal_count: number;
  fail_count: number;
  catastrophic_count: number;
  pass_pct: number;
};

type PressureOutlier = {
  ot_room_code: string;
  filter_position: string;
  min_pressure_pa: number;
  max_pressure_pa: number;
  avg_pressure_pa: number;
  last_reading_at: string;
};

type AgeVsLife = {
  ot_room_code: string;
  filter_grade: string;
  manufacturer: string;
  current_age_months: number;
  rated_life_months: number;
  pct_life_used: number;
  filter_status: string;
};

type AtRestDelta = {
  ot_room_code: string;
  at_rest_avg_count: number;
  in_op_avg_count: number;
  delta_multiplier: number;
  reading_pairs: number;
};

type NabhIncident = {
  ot_room_code: string;
  ot_classification: string;
  reading_taken_at: string;
  operational_state: string;
  count_per_m3: number;
  iso_class_observed: string;
  compliance_verdict: string;
};

type ManufacturerScorecard = {
  manufacturer: string;
  filter_count: number;
  avg_age_months: number;
  fail_or_worse_readings: number;
  total_readings: number;
  failure_rate_pct: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    bankRes,
    queueRes,
    isoRes,
    pressureRes,
    ageRes,
    deltaRes,
    nabhRes,
    mfgRes,
  ] = await Promise.all([
    supabase.rpc('r3100_hepa_bank_by_hospital'),
    supabase.rpc('r3100_replacement_priority_queue'),
    supabase.rpc('r3100_iso_class_compliance'),
    supabase.rpc('r3100_pressure_outliers'),
    supabase.rpc('r3100_filter_age_vs_life'),
    supabase.rpc('r3100_at_rest_vs_operation_delta'),
    supabase.rpc('r3100_nabh_reportable_incidents'),
    supabase.rpc('r3100_manufacturer_scorecard'),
  ]);

  const bank = (bankRes.data ?? []) as BankByHospital[];
  const queue = (queueRes.data ?? []) as PriorityQueue[];
  const iso = (isoRes.data ?? []) as IsoCompliance[];
  const pressure = (pressureRes.data ?? []) as PressureOutlier[];
  const age = (ageRes.data ?? []) as AgeVsLife[];
  const delta = (deltaRes.data ?? []) as AtRestDelta[];
  const nabh = (nabhRes.data ?? []) as NabhIncident[];
  const mfg = (mfgRes.data ?? []) as ManufacturerScorecard[];

  const bankCols: Column<BankByHospital>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_filters', header: 'Total filters' },
    { key: 'breached', header: 'Breached' },
    { key: 'replacement_due', header: 'Replacement due' },
    { key: 'watchlist', header: 'Watchlist' },
    { key: 'in_service', header: 'In service' },
  ];

  const queueCols: Column<PriorityQueue>[] = [
    { key: 'priority', header: 'Priority bucket' },
    { key: 'filter_count', header: 'Filters' },
    { key: 'avg_age_months', header: 'Avg age (months)' },
    { key: 'oldest_install_date', header: 'Oldest installed' },
  ];

  const isoCols: Column<IsoCompliance>[] = [
    { key: 'iso_class_target', header: 'ISO target' },
    { key: 'total_readings', header: 'Total readings' },
    { key: 'pass_count', header: 'Pass' },
    { key: 'marginal_count', header: 'Marginal' },
    { key: 'fail_count', header: 'Fail' },
    { key: 'catastrophic_count', header: 'Catastrophic' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const pressureCols: Column<PressureOutlier>[] = [
    { key: 'ot_room_code', header: 'OT room' },
    { key: 'filter_position', header: 'Position' },
    { key: 'min_pressure_pa', header: 'Min Pa' },
    { key: 'max_pressure_pa', header: 'Max Pa' },
    { key: 'avg_pressure_pa', header: 'Avg Pa' },
    { key: 'last_reading_at', header: 'Last reading' },
  ];

  const ageCols: Column<AgeVsLife>[] = [
    { key: 'ot_room_code', header: 'OT room' },
    { key: 'filter_grade', header: 'Grade' },
    { key: 'manufacturer', header: 'Manufacturer' },
    { key: 'current_age_months', header: 'Age (mo)' },
    { key: 'rated_life_months', header: 'Rated (mo)' },
    { key: 'pct_life_used', header: '% life used' },
    { key: 'filter_status', header: 'Status' },
  ];

  const deltaCols: Column<AtRestDelta>[] = [
    { key: 'ot_room_code', header: 'OT room' },
    { key: 'at_rest_avg_count', header: 'At-rest avg' },
    { key: 'in_op_avg_count', header: 'In-op avg' },
    { key: 'delta_multiplier', header: 'Multiplier' },
    { key: 'reading_pairs', header: 'Pairs' },
  ];

  const nabhCols: Column<NabhIncident>[] = [
    { key: 'ot_room_code', header: 'OT room' },
    { key: 'ot_classification', header: 'Class' },
    { key: 'reading_taken_at', header: 'Taken at' },
    { key: 'operational_state', header: 'State' },
    { key: 'count_per_m3', header: 'Count / m3' },
    { key: 'iso_class_observed', header: 'Observed' },
    { key: 'compliance_verdict', header: 'Verdict' },
  ];

  const mfgCols: Column<ManufacturerScorecard>[] = [
    { key: 'manufacturer', header: 'Manufacturer' },
    { key: 'filter_count', header: 'Filters' },
    { key: 'avg_age_months', header: 'Avg age' },
    { key: 'fail_or_worse_readings', header: 'Fail+' },
    { key: 'total_readings', header: 'Total readings' },
    { key: 'failure_rate_pct', header: 'Failure %' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-10 p-6">
      <header>
        <h1 className="text-2xl font-semibold">
          OT HEPA Filter Bank & Particulate Compliance Tracker
        </h1>
        <p className="mt-1 text-sm text-gray-600">
          Round 3100 — tracks at-rest vs in-operation particulate counts,
          ISO Class compliance, filter age vs rated life, differential pressure,
          and replacement priority queue across customer hospital OTs.
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-lg font-medium">Bank summary by hospital</h2>
        <DataTable
          rows={bank}
          columns={bankCols}
          emptyMessage="No HEPA filter banks registered yet."
          rowKey={(r, i) => String(r.hospital_org_id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Replacement priority queue</h2>
        <DataTable
          rows={queue}
          columns={queueCols}
          emptyMessage="Priority queue empty."
          rowKey={(r, i) => String(r.priority ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">ISO class compliance</h2>
        <DataTable
          rows={iso}
          columns={isoCols}
          emptyMessage="No ISO compliance readings."
          rowKey={(r, i) => String(r.iso_class_target ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">
          Differential pressure outliers (&lt;150 Pa or &gt;350 Pa)
        </h2>
        <DataTable
          rows={pressure}
          columns={pressureCols}
          emptyMessage="No pressure outliers detected."
          rowKey={(r, i) => `${r.ot_room_code}-${r.filter_position}-${i}`}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Filter age vs rated life</h2>
        <DataTable
          rows={age}
          columns={ageCols}
          emptyMessage="No filters tracked."
          rowKey={(r, i) => `${r.ot_room_code}-${i}`}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">At-rest vs in-operation delta</h2>
        <DataTable
          rows={delta}
          columns={deltaCols}
          emptyMessage="No paired readings."
          rowKey={(r, i) => String(r.ot_room_code ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">NABH-reportable incidents</h2>
        <DataTable
          rows={nabh}
          columns={nabhCols}
          emptyMessage="No NABH-reportable incidents."
          rowKey={(r, i) => `${r.ot_room_code}-${r.reading_taken_at}-${i}`}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Manufacturer reliability scorecard</h2>
        <DataTable
          rows={mfg}
          columns={mfgCols}
          emptyMessage="No manufacturer data."
          rowKey={(r, i) => String(r.manufacturer ?? i)}
        />
      </section>
    </main>
  );
}
