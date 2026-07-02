import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_jobs: number;
  second_visits_prevented: number;
  second_visits_required: number;
  prevention_rate: number | null;
  total_cost_avoided_rupees: number;
};

type JobRow = {
  job_code: string;
  customer_name: string;
  hospital_name: string;
  city: string;
  equipment: string;
  first_visit_at: string;
  prevention_measure: string;
  second_visit_required: boolean;
  second_visit_cause: string | null;
  prevention_success: boolean;
  cost_avoided_rupees: number;
};

type MeasureRow = {
  prevention_measure: string;
  jobs_applied: number;
  successes: number;
  success_rate: number | null;
  cost_avoided_rupees: number;
};

type CauseRow = {
  second_visit_cause: string | null;
  occurrences: number;
  share_pct: number | null;
};

type CityRow = {
  city: string;
  jobs: number;
  prevented: number;
  prevention_rate: number | null;
  cost_avoided_rupees: number;
};

type CatalogRow = {
  measure_code: string;
  measure_name: string;
  measure_category: string;
  unit_cost_rupees: number;
  baseline_success_rate: number;
  recommended_for: string;
  active: boolean;
};

type EngineerRow = {
  engineer: string;
  jobs: number;
  prevented: number;
  prevention_rate: number | null;
};

type FailedRow = {
  job_code: string;
  hospital_name: string;
  equipment: string;
  first_visit_engineer: string;
  prevention_measure: string;
  second_visit_cause: string | null;
  days_to_second_visit: number | null;
};

function rupees(n: number | null | undefined): string {
  if (!n) return '0';
  return new Intl.NumberFormat('en-IN').format(n);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, jobsRes, measureRes, causeRes, cityRes, catalogRes, engRes, failedRes] = await Promise.all([
    supabase.rpc('rpc_r2820_kpi_summary'),
    supabase.rpc('rpc_r2820_list_jobs'),
    supabase.rpc('rpc_r2820_measure_effectiveness'),
    supabase.rpc('rpc_r2820_cause_breakdown'),
    supabase.rpc('rpc_r2820_city_rollup'),
    supabase.rpc('rpc_r2820_catalog'),
    supabase.rpc('rpc_r2820_engineer_rollup'),
    supabase.rpc('rpc_r2820_failed_prevention'),
  ]);

  const kpi: KpiRow = (kpiRes.data?.[0] as KpiRow) ?? {
    total_jobs: 0,
    second_visits_prevented: 0,
    second_visits_required: 0,
    prevention_rate: 0,
    total_cost_avoided_rupees: 0,
  };
  const jobs: JobRow[] = (jobsRes.data as JobRow[]) ?? [];
  const measures: MeasureRow[] = (measureRes.data as MeasureRow[]) ?? [];
  const causes: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const cities: CityRow[] = (cityRes.data as CityRow[]) ?? [];
  const catalog: CatalogRow[] = (catalogRes.data as CatalogRow[]) ?? [];
  const engineers: EngineerRow[] = (engRes.data as EngineerRow[]) ?? [];
  const failed: FailedRow[] = (failedRes.data as FailedRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Second Visit Prevention — Round 2820</h1>
        <p className="text-sm text-gray-600">
          Job by first visit by prevention measure by second visit by cause by success.
          Tracks where the second visit was avoided and how much cost was saved.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Jobs</div>
          <div className="text-2xl font-bold">{kpi.total_jobs}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Second Visits Prevented</div>
          <div className="text-2xl font-bold text-green-700">{kpi.second_visits_prevented}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Second Visits Required</div>
          <div className="text-2xl font-bold text-red-700">{kpi.second_visits_required}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Prevention Rate</div>
          <div className="text-2xl font-bold">{kpi.prevention_rate ?? 0}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Cost Avoided</div>
          <div className="text-2xl font-bold">₹{rupees(kpi.total_cost_avoided_rupees)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Jobs & Prevention Outcome</h2>
        <DataTable
          rows={jobs}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: JobRow) => r.job_code },
            { key: 'hospital_name', header: 'Hospital', render: (r: JobRow) => r.hospital_name },
            { key: 'city', header: 'City', render: (r: JobRow) => r.city },
            { key: 'equipment', header: 'Equipment', render: (r: JobRow) => r.equipment },
            { key: 'prevention_measure', header: 'Measure', render: (r: JobRow) => r.prevention_measure },
            {
              key: 'second_visit_required',
              header: '2nd Visit?',
              render: (r: JobRow) => (r.second_visit_required ? 'Yes' : 'No'),
            },
            {
              key: 'second_visit_cause',
              header: 'Cause',
              render: (r: JobRow) => r.second_visit_cause ?? '-',
            },
            {
              key: 'prevention_success',
              header: 'Prevented',
              render: (r: JobRow) => (r.prevention_success ? 'Yes' : 'No'),
            },
            {
              key: 'cost_avoided_rupees',
              header: 'Cost Avoided',
              render: (r: JobRow) => `₹${rupees(r.cost_avoided_rupees)}`,
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: JobRow, i: number) => String(r.job_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Prevention Measure Effectiveness</h2>
        <DataTable
          rows={measures}
          columns={[
            { key: 'prevention_measure', header: 'Measure', render: (r: MeasureRow) => r.prevention_measure },
            { key: 'jobs_applied', header: 'Applied', render: (r: MeasureRow) => r.jobs_applied },
            { key: 'successes', header: 'Prevented', render: (r: MeasureRow) => r.successes },
            { key: 'success_rate', header: 'Rate %', render: (r: MeasureRow) => `${r.success_rate ?? 0}%` },
            {
              key: 'cost_avoided_rupees',
              header: 'Cost Avoided',
              render: (r: MeasureRow) => `₹${rupees(r.cost_avoided_rupees)}`,
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: MeasureRow, i: number) => String(r.prevention_measure ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Second Visit Cause Breakdown</h2>
        <DataTable
          rows={causes}
          columns={[
            { key: 'second_visit_cause', header: 'Cause', render: (r: CauseRow) => r.second_visit_cause ?? '-' },
            { key: 'occurrences', header: 'Occurrences', render: (r: CauseRow) => r.occurrences },
            { key: 'share_pct', header: 'Share %', render: (r: CauseRow) => `${r.share_pct ?? 0}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: CauseRow, i: number) => String(r.second_visit_cause ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Rollup</h2>
        <DataTable
          rows={cities}
          columns={[
            { key: 'city', header: 'City', render: (r: CityRow) => r.city },
            { key: 'jobs', header: 'Jobs', render: (r: CityRow) => r.jobs },
            { key: 'prevented', header: 'Prevented', render: (r: CityRow) => r.prevented },
            {
              key: 'prevention_rate',
              header: 'Rate %',
              render: (r: CityRow) => `${r.prevention_rate ?? 0}%`,
            },
            {
              key: 'cost_avoided_rupees',
              header: 'Cost Avoided',
              render: (r: CityRow) => `₹${rupees(r.cost_avoided_rupees)}`,
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: CityRow, i: number) => String(r.city ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Rollup</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer', header: 'Engineer', render: (r: EngineerRow) => r.engineer },
            { key: 'jobs', header: 'Jobs', render: (r: EngineerRow) => r.jobs },
            { key: 'prevented', header: 'Prevented', render: (r: EngineerRow) => r.prevented },
            {
              key: 'prevention_rate',
              header: 'Rate %',
              render: (r: EngineerRow) => `${r.prevention_rate ?? 0}%`,
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Prevention Measure Catalog</h2>
        <DataTable
          rows={catalog}
          columns={[
            { key: 'measure_code', header: 'Code', render: (r: CatalogRow) => r.measure_code },
            { key: 'measure_name', header: 'Name', render: (r: CatalogRow) => r.measure_name },
            { key: 'measure_category', header: 'Category', render: (r: CatalogRow) => r.measure_category },
            {
              key: 'unit_cost_rupees',
              header: 'Unit Cost',
              render: (r: CatalogRow) => `₹${rupees(r.unit_cost_rupees)}`,
            },
            {
              key: 'baseline_success_rate',
              header: 'Baseline %',
              render: (r: CatalogRow) => `${r.baseline_success_rate}%`,
            },
            { key: 'recommended_for', header: 'Recommended For', render: (r: CatalogRow) => r.recommended_for },
            { key: 'active', header: 'Active', render: (r: CatalogRow) => (r.active ? 'Yes' : 'No') },
          ]}
          emptyMessage="No data"
          rowKey={(r: CatalogRow, i: number) => String(r.measure_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failed Prevention Drilldown</h2>
        <DataTable
          rows={failed}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: FailedRow) => r.job_code },
            { key: 'hospital_name', header: 'Hospital', render: (r: FailedRow) => r.hospital_name },
            { key: 'equipment', header: 'Equipment', render: (r: FailedRow) => r.equipment },
            { key: 'first_visit_engineer', header: 'Engineer', render: (r: FailedRow) => r.first_visit_engineer },
            { key: 'prevention_measure', header: 'Measure', render: (r: FailedRow) => r.prevention_measure },
            {
              key: 'second_visit_cause',
              header: 'Cause',
              render: (r: FailedRow) => r.second_visit_cause ?? '-',
            },
            {
              key: 'days_to_second_visit',
              header: 'Days to 2nd Visit',
              render: (r: FailedRow) => r.days_to_second_visit ?? '-',
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: FailedRow, i: number) => String(r.job_code ?? i)}
        />
      </section>
    </div>
  );
}
