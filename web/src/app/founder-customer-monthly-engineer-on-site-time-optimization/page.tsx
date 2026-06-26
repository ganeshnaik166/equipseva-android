import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_jobs: number;
  on_track_jobs: number;
  over_run_jobs: number;
  severe_jobs: number;
  avg_deviation_pct: number;
  total_excess_min: number;
};

type JobRow = {
  id: number;
  month_label: string;
  customer_name: string;
  job_code: string;
  job_type: string;
  engineer_name: string;
  scheduled_minutes: number;
  actual_minutes: number;
  deviation_minutes: number;
  deviation_pct: number;
  primary_cause_code: string;
  refine_action: string;
  status: string;
  visit_date: string;
};

type CauseRow = {
  cause_code: string;
  cause_label: string;
  category: string;
  occurrence_count: number;
  avg_excess_minutes: number;
  refine_action: string;
  priority: string;
};

type EngineerRow = {
  engineer_name: string;
  job_count: number;
  avg_deviation_pct: number;
  excess_minutes: number;
};

type CustomerRow = {
  customer_name: string;
  job_count: number;
  avg_deviation_pct: number;
  severe_count: number;
};

type BacklogRow = {
  priority: string;
  cause_code: string;
  cause_label: string;
  refine_action: string;
  owner: string;
  occurrence_count: number;
};

type OutlierRow = {
  job_code: string;
  customer_name: string;
  engineer_name: string;
  scheduled_minutes: number;
  actual_minutes: number;
  deviation_pct: number;
  primary_cause_code: string;
  refine_action: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, jobsRes, causesRes, engRes, custRes, backlogRes, outliersRes] = await Promise.all([
    supabase.rpc('get_customer_monthly_engineer_on_site_time_kpi_r2852'),
    supabase.rpc('list_customer_monthly_engineer_on_site_time_jobs_r2852'),
    supabase.rpc('list_customer_monthly_engineer_on_site_time_causes_r2852'),
    supabase.rpc('engineer_summary_customer_monthly_engineer_on_site_time_r2852'),
    supabase.rpc('customer_summary_customer_monthly_engineer_on_site_time_r2852'),
    supabase.rpc('refine_action_backlog_customer_monthly_engineer_on_site_time_r2852'),
    supabase.rpc('severe_outliers_customer_monthly_engineer_on_site_time_r2852'),
  ]);

  const kpi: Kpi | null = Array.isArray(kpiRes.data) ? (kpiRes.data[0] as Kpi) : null;
  const jobs: JobRow[] = (jobsRes.data as JobRow[]) ?? [];
  const causes: CauseRow[] = (causesRes.data as CauseRow[]) ?? [];
  const engineers: EngineerRow[] = (engRes.data as EngineerRow[]) ?? [];
  const customers: CustomerRow[] = (custRes.data as CustomerRow[]) ?? [];
  const backlog: BacklogRow[] = (backlogRes.data as BacklogRow[]) ?? [];
  const outliers: OutlierRow[] = (outliersRes.data as OutlierRow[]) ?? [];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Engineer On-Site Time Optimization</h1>
        <p className="text-sm text-gray-600">
          Job × scheduled time × actual on-site × deviation × cause × refine action.
          Severe over-run threshold: deviation &gt;= 50%.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-4">
        <KpiCard label="Total Jobs" value={kpi?.total_jobs ?? 0} />
        <KpiCard label="On Track" value={kpi?.on_track_jobs ?? 0} />
        <KpiCard label="Over Run" value={kpi?.over_run_jobs ?? 0} />
        <KpiCard label="Severe" value={kpi?.severe_jobs ?? 0} />
        <KpiCard label="Avg Deviation %" value={kpi?.avg_deviation_pct ?? 0} />
        <KpiCard label="Excess Minutes" value={kpi?.total_excess_min ?? 0} />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Job-level deviation</h2>
        <DataTable
          rows={jobs}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: JobRow) => r.job_code },
            { key: 'customer_name', header: 'Customer', render: (r: JobRow) => r.customer_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: JobRow) => r.engineer_name },
            { key: 'job_type', header: 'Type', render: (r: JobRow) => r.job_type },
            { key: 'scheduled_minutes', header: 'Sched (min)', render: (r: JobRow) => r.scheduled_minutes },
            { key: 'actual_minutes', header: 'Actual (min)', render: (r: JobRow) => r.actual_minutes },
            { key: 'deviation_pct', header: 'Dev %', render: (r: JobRow) => `${r.deviation_pct}%` },
            { key: 'primary_cause_code', header: 'Cause', render: (r: JobRow) => r.primary_cause_code },
            { key: 'refine_action', header: 'Refine Action', render: (r: JobRow) => r.refine_action },
            { key: 'status', header: 'Status', render: (r: JobRow) => r.status },
            { key: 'visit_date', header: 'Visit Date', render: (r: JobRow) => r.visit_date },
          ]}
          emptyMessage="No data"
          rowKey={(r: JobRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Causes & Refine Actions</h2>
        <DataTable
          rows={causes}
          columns={[
            { key: 'cause_code', header: 'Code', render: (r: CauseRow) => r.cause_code },
            { key: 'cause_label', header: 'Label', render: (r: CauseRow) => r.cause_label },
            { key: 'category', header: 'Category', render: (r: CauseRow) => r.category },
            { key: 'occurrence_count', header: 'Occurrences', render: (r: CauseRow) => r.occurrence_count },
            { key: 'avg_excess_minutes', header: 'Avg Excess (min)', render: (r: CauseRow) => r.avg_excess_minutes },
            { key: 'refine_action', header: 'Refine Action', render: (r: CauseRow) => r.refine_action },
            { key: 'priority', header: 'Priority', render: (r: CauseRow) => r.priority },
          ]}
          emptyMessage="No data"
          rowKey={(r: CauseRow, i: number) => String(r.cause_code ?? i)}
        />
      </section>

      <section className="grid md:grid-cols-2 gap-8">
        <div>
          <h2 className="text-xl font-semibold mb-3">Engineer summary</h2>
          <DataTable
            rows={engineers}
            columns={[
              { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
              { key: 'job_count', header: 'Jobs', render: (r: EngineerRow) => r.job_count },
              { key: 'avg_deviation_pct', header: 'Avg Dev %', render: (r: EngineerRow) => `${r.avg_deviation_pct}%` },
              { key: 'excess_minutes', header: 'Excess (min)', render: (r: EngineerRow) => r.excess_minutes },
            ]}
            emptyMessage="No data"
            rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
          />
        </div>
        <div>
          <h2 className="text-xl font-semibold mb-3">Customer summary</h2>
          <DataTable
            rows={customers}
            columns={[
              { key: 'customer_name', header: 'Customer', render: (r: CustomerRow) => r.customer_name },
              { key: 'job_count', header: 'Jobs', render: (r: CustomerRow) => r.job_count },
              { key: 'avg_deviation_pct', header: 'Avg Dev %', render: (r: CustomerRow) => `${r.avg_deviation_pct}%` },
              { key: 'severe_count', header: 'Severe', render: (r: CustomerRow) => r.severe_count },
            ]}
            emptyMessage="No data"
            rowKey={(r: CustomerRow, i: number) => String(r.customer_name ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Refine action backlog</h2>
        <DataTable
          rows={backlog}
          columns={[
            { key: 'priority', header: 'Priority', render: (r: BacklogRow) => r.priority },
            { key: 'cause_code', header: 'Code', render: (r: BacklogRow) => r.cause_code },
            { key: 'cause_label', header: 'Cause', render: (r: BacklogRow) => r.cause_label },
            { key: 'refine_action', header: 'Refine Action', render: (r: BacklogRow) => r.refine_action },
            { key: 'owner', header: 'Owner', render: (r: BacklogRow) => r.owner },
            { key: 'occurrence_count', header: 'Occurrences', render: (r: BacklogRow) => r.occurrence_count },
          ]}
          emptyMessage="No data"
          rowKey={(r: BacklogRow, i: number) => String(r.cause_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Severe outliers (deviation &gt;= 50%)</h2>
        <DataTable
          rows={outliers}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: OutlierRow) => r.job_code },
            { key: 'customer_name', header: 'Customer', render: (r: OutlierRow) => r.customer_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: OutlierRow) => r.engineer_name },
            { key: 'scheduled_minutes', header: 'Sched (min)', render: (r: OutlierRow) => r.scheduled_minutes },
            { key: 'actual_minutes', header: 'Actual (min)', render: (r: OutlierRow) => r.actual_minutes },
            { key: 'deviation_pct', header: 'Dev %', render: (r: OutlierRow) => `${r.deviation_pct}%` },
            { key: 'primary_cause_code', header: 'Cause', render: (r: OutlierRow) => r.primary_cause_code },
            { key: 'refine_action', header: 'Refine Action', render: (r: OutlierRow) => r.refine_action },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutlierRow, i: number) => String(r.job_code ?? i)}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}
