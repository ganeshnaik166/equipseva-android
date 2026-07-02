import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_engineers: number;
  critical_risk_count: number;
  high_risk_count: number;
  zero_backup_count: number;
  avg_backup_count: number;
  total_active_jobs: number;
};

type RiskRow = { bus_factor_risk: string; engineer_count: number; total_jobs: number };
type CityRow = { city: string; engineer_count: number; critical_count: number; avg_backup: number };
type SpecialtyRow = { specialty: string; engineer_count: number; total_hospitals: number; max_risk: string };
type CoverageRow = {
  id: string;
  engineer_name: string;
  specialty: string;
  city: string;
  backup_engineer_count: number;
  active_jobs_30d: number;
  hospitals_served: number;
  bus_factor_risk: string;
  cross_train_action: string;
  action_owner: string;
  target_completion_date: string;
};
type TrainSummary = {
  total_plans: number;
  planned_count: number;
  in_progress_count: number;
  blocked_count: number;
  completed_count: number;
  total_cost_rupees: number;
  hours_planned_sum: number;
  hours_completed_sum: number;
};
type TrainRow = {
  id: string;
  engineer_name: string;
  trainee_engineer_name: string;
  specialty: string;
  city: string;
  training_hours_planned: number;
  training_hours_completed: number;
  certification_target: string;
  plan_status: string;
  expected_completion_date: string;
  cost_rupees: number;
};
type CriticalRow = {
  engineer_name: string;
  specialty: string;
  city: string;
  active_jobs_30d: number;
  hospitals_served: number;
  cross_train_action: string;
  action_owner: string;
  target_completion_date: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, riskRes, cityRes, specRes, listRes, trainSumRes, trainListRes, critRes] = await Promise.all([
    supabase.rpc('r2798_kpi_summary'),
    supabase.rpc('r2798_coverage_by_risk'),
    supabase.rpc('r2798_coverage_by_city'),
    supabase.rpc('r2798_coverage_by_specialty'),
    supabase.rpc('r2798_coverage_list'),
    supabase.rpc('r2798_cross_train_summary'),
    supabase.rpc('r2798_cross_train_list'),
    supabase.rpc('r2798_critical_engineers'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_engineers: 0,
    critical_risk_count: 0,
    high_risk_count: 0,
    zero_backup_count: 0,
    avg_backup_count: 0,
    total_active_jobs: 0,
  };
  const trainSum: TrainSummary = (trainSumRes.data?.[0] as TrainSummary) ?? {
    total_plans: 0,
    planned_count: 0,
    in_progress_count: 0,
    blocked_count: 0,
    completed_count: 0,
    total_cost_rupees: 0,
    hours_planned_sum: 0,
    hours_completed_sum: 0,
  };
  const risks: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];
  const cities: CityRow[] = (cityRes.data as CityRow[]) ?? [];
  const specs: SpecialtyRow[] = (specRes.data as SpecialtyRow[]) ?? [];
  const coverage: CoverageRow[] = (listRes.data as CoverageRow[]) ?? [];
  const trains: TrainRow[] = (trainListRes.data as TrainRow[]) ?? [];
  const crit: CriticalRow[] = (critRes.data as CriticalRow[]) ?? [];

  const fmtINR = (n: number) =>
    new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(n || 0);

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Bus-Factor Coverage</h1>
        <p className="text-sm text-gray-600">
          Engineers with zero or one backup are SLA risks. Track cross-train plans to push backup count &gt;= 2.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <KpiCard label="Engineers" value={String(kpi.total_engineers)} />
        <KpiCard label="Critical risk" value={String(kpi.critical_risk_count)} tone="red" />
        <KpiCard label="High risk" value={String(kpi.high_risk_count)} tone="orange" />
        <KpiCard label="Zero backup" value={String(kpi.zero_backup_count)} tone="red" />
        <KpiCard label="Avg backups" value={String(kpi.avg_backup_count)} />
        <KpiCard label="Active jobs (30d)" value={String(kpi.total_active_jobs)} />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="font-semibold mb-2">Coverage by risk</h2>
          <DataTable
            rows={risks}
            rowKey={(r, i) => String(r.bus_factor_risk ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'bus_factor_risk', header: 'Risk', render: (r: RiskRow) => r.bus_factor_risk },
              { key: 'engineer_count', header: 'Engineers', render: (r: RiskRow) => r.engineer_count },
              { key: 'total_jobs', header: 'Active jobs', render: (r: RiskRow) => r.total_jobs },
            ]}
          />
        </div>
        <div>
          <h2 className="font-semibold mb-2">Coverage by city</h2>
          <DataTable
            rows={cities}
            rowKey={(r, i) => String(r.city ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'city', header: 'City', render: (r: CityRow) => r.city },
              { key: 'engineer_count', header: 'Engineers', render: (r: CityRow) => r.engineer_count },
              { key: 'critical_count', header: 'Critical', render: (r: CityRow) => r.critical_count },
              { key: 'avg_backup', header: 'Avg backup', render: (r: CityRow) => r.avg_backup },
            ]}
          />
        </div>
      </section>

      <section>
        <h2 className="font-semibold mb-2">Coverage by specialty</h2>
        <DataTable
          rows={specs}
          rowKey={(r, i) => String(r.specialty ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'specialty', header: 'Specialty', render: (r: SpecialtyRow) => r.specialty },
            { key: 'engineer_count', header: 'Engineers', render: (r: SpecialtyRow) => r.engineer_count },
            { key: 'total_hospitals', header: 'Hospitals', render: (r: SpecialtyRow) => r.total_hospitals },
            { key: 'max_risk', header: 'Worst risk', render: (r: SpecialtyRow) => r.max_risk },
          ]}
        />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Critical & high-risk engineers</h2>
        <DataTable
          rows={crit}
          rowKey={(r, i) => String(`${r.engineer_name}-${i}`)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: CriticalRow) => r.engineer_name },
            { key: 'specialty', header: 'Specialty', render: (r: CriticalRow) => r.specialty },
            { key: 'city', header: 'City', render: (r: CriticalRow) => r.city },
            { key: 'active_jobs_30d', header: 'Jobs 30d', render: (r: CriticalRow) => r.active_jobs_30d },
            { key: 'hospitals_served', header: 'Hospitals', render: (r: CriticalRow) => r.hospitals_served },
            { key: 'cross_train_action', header: 'Action', render: (r: CriticalRow) => r.cross_train_action },
            { key: 'action_owner', header: 'Owner', render: (r: CriticalRow) => r.action_owner },
            { key: 'target_completion_date', header: 'Target', render: (r: CriticalRow) => r.target_completion_date },
          ]}
        />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Full coverage roster</h2>
        <DataTable
          rows={coverage}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: CoverageRow) => r.engineer_name },
            { key: 'specialty', header: 'Specialty', render: (r: CoverageRow) => r.specialty },
            { key: 'city', header: 'City', render: (r: CoverageRow) => r.city },
            { key: 'backup_engineer_count', header: 'Backups', render: (r: CoverageRow) => r.backup_engineer_count },
            { key: 'active_jobs_30d', header: 'Jobs 30d', render: (r: CoverageRow) => r.active_jobs_30d },
            { key: 'hospitals_served', header: 'Hospitals', render: (r: CoverageRow) => r.hospitals_served },
            { key: 'bus_factor_risk', header: 'Risk', render: (r: CoverageRow) => r.bus_factor_risk },
            { key: 'cross_train_action', header: 'Action', render: (r: CoverageRow) => r.cross_train_action },
            { key: 'action_owner', header: 'Owner', render: (r: CoverageRow) => r.action_owner },
            { key: 'target_completion_date', header: 'Target', render: (r: CoverageRow) => r.target_completion_date },
          ]}
        />
      </section>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        <KpiCard label="Plans" value={String(trainSum.total_plans)} />
        <KpiCard label="Planned" value={String(trainSum.planned_count)} />
        <KpiCard label="In progress" value={String(trainSum.in_progress_count)} />
        <KpiCard label="Blocked" value={String(trainSum.blocked_count)} tone="red" />
        <KpiCard label="Completed" value={String(trainSum.completed_count)} tone="green" />
        <KpiCard label="Cost" value={fmtINR(trainSum.total_cost_rupees)} />
        <KpiCard label="Hrs planned" value={String(trainSum.hours_planned_sum)} />
        <KpiCard label="Hrs done" value={String(trainSum.hours_completed_sum)} />
      </section>

      <section>
        <h2 className="font-semibold mb-2">Cross-train plan</h2>
        <DataTable
          rows={trains}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Mentor', render: (r: TrainRow) => r.engineer_name },
            { key: 'trainee_engineer_name', header: 'Trainee', render: (r: TrainRow) => r.trainee_engineer_name },
            { key: 'specialty', header: 'Specialty', render: (r: TrainRow) => r.specialty },
            { key: 'city', header: 'City', render: (r: TrainRow) => r.city },
            {
              key: 'hours',
              header: 'Hrs (done / plan)',
              render: (r: TrainRow) => `${r.training_hours_completed} / ${r.training_hours_planned}`,
            },
            { key: 'certification_target', header: 'Cert target', render: (r: TrainRow) => r.certification_target },
            { key: 'plan_status', header: 'Status', render: (r: TrainRow) => r.plan_status },
            { key: 'expected_completion_date', header: 'ETA', render: (r: TrainRow) => r.expected_completion_date },
            { key: 'cost_rupees', header: 'Cost', render: (r: TrainRow) => fmtINR(r.cost_rupees) },
          ]}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: string; tone?: 'red' | 'orange' | 'green' }) {
  const toneCls =
    tone === 'red'
      ? 'border-red-300 bg-red-50'
      : tone === 'orange'
      ? 'border-orange-300 bg-orange-50'
      : tone === 'green'
      ? 'border-green-300 bg-green-50'
      : 'border-gray-200 bg-white';
  return (
    <div className={`rounded-lg border p-3 ${toneCls}`}>
      <div className="text-xs text-gray-600">{label}</div>
      <div className="text-lg font-semibold">{value}</div>
    </div>
  );
}
