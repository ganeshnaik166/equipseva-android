import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_jobs: number;
  avg_cleanup_score: number;
  avg_customer_stars: number;
  total_waste_kg: number;
  failed_jobs: number;
  exemplary_jobs: number;
};

type JobLog = {
  id: number;
  job_code: string;
  engineer_name: string;
  customer_org: string;
  device_category: string;
  cleanup_score_pct: number;
  customer_feedback_stars: number;
  status: string;
  customer_quote: string;
};

type Scorecard = {
  engineer_name: string;
  jobs_count: number;
  avg_score: number;
  avg_stars: number;
  total_waste_kg: number;
  worst_status: string;
};

type Category = {
  device_category: string;
  jobs: number;
  avg_score: number;
  avg_space_restored: number;
  avg_stars: number;
};

type Refine = {
  id: number;
  engineer_name: string;
  gap_theme: string;
  refine_action: string;
  owner: string;
  due_in_days: number;
  expected_score_lift_pct: number;
  priority: string;
  status: string;
};

type Waste = {
  device_category: string;
  total_waste_kg: number;
  total_biohazard_bags: number;
  jobs: number;
  kg_per_job: number;
};

type Quote = {
  customer_org: string;
  engineer_name: string;
  customer_feedback_stars: number;
  customer_quote: string;
  status: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, jobsRes, scoreRes, catRes, refineRes, wasteRes, quoteRes] = await Promise.all([
    supabase.rpc('founder_r2804_kpi_summary'),
    supabase.rpc('founder_r2804_list_job_logs'),
    supabase.rpc('founder_r2804_engineer_scorecard'),
    supabase.rpc('founder_r2804_category_breakdown'),
    supabase.rpc('founder_r2804_refine_actions'),
    supabase.rpc('founder_r2804_waste_accounting'),
    supabase.rpc('founder_r2804_top_customer_quotes'),
  ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] as Kpi) ?? null;
  const jobs: JobLog[] = (jobsRes.data as JobLog[]) ?? [];
  const scorecard: Scorecard[] = (scoreRes.data as Scorecard[]) ?? [];
  const categories: Category[] = (catRes.data as Category[]) ?? [];
  const refines: Refine[] = (refineRes.data as Refine[]) ?? [];
  const waste: Waste[] = (wasteRes.data as Waste[]) ?? [];
  const quotes: Quote[] = (quoteRes.data as Quote[]) ?? [];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10">
      <header className="mb-8">
        <h1 className="text-3xl font-semibold tracking-tight">
          Customer Monthly Engineer Cleanup Protocol After Job
        </h1>
        <p className="mt-2 text-sm text-gray-600">
          Job × cleanup score × waste × space × customer feedback × refine action. Track that every
          engineer leaves the bay better than they found it. Score &gt;= 90% targets exemplary, &lt; 60% flags a major gap.
        </p>
      </header>

      <section className="mb-10 grid grid-cols-2 gap-4 md:grid-cols-6">
        <KpiCard label="Total Jobs" value={kpi?.total_jobs ?? 0} />
        <KpiCard label="Avg Cleanup Score" value={`${kpi?.avg_cleanup_score ?? 0}%`} />
        <KpiCard label="Avg Customer Stars" value={`${kpi?.avg_customer_stars ?? 0} / 5`} />
        <KpiCard label="Total Waste" value={`${kpi?.total_waste_kg ?? 0} kg`} />
        <KpiCard label="Exemplary Jobs" value={kpi?.exemplary_jobs ?? 0} />
        <KpiCard label="Failed Jobs" value={kpi?.failed_jobs ?? 0} />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-xl font-semibold">Per-Job Cleanup Logs</h2>
        <DataTable
          rows={jobs}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: JobLog) => r.job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: JobLog) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r: JobLog) => r.customer_org },
            { key: 'device_category', header: 'Category', render: (r: JobLog) => r.device_category },
            { key: 'cleanup_score_pct', header: 'Score %', render: (r: JobLog) => `${r.cleanup_score_pct}%` },
            { key: 'customer_feedback_stars', header: 'Stars', render: (r: JobLog) => `${r.customer_feedback_stars} / 5` },
            { key: 'status', header: 'Status', render: (r: JobLog) => r.status },
            { key: 'customer_quote', header: 'Customer Quote', render: (r: JobLog) => r.customer_quote },
          ]}
          emptyMessage="No data"
          rowKey={(r: JobLog, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-xl font-semibold">Engineer Scorecard</h2>
        <DataTable
          rows={scorecard}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Scorecard) => r.engineer_name },
            { key: 'jobs_count', header: 'Jobs', render: (r: Scorecard) => r.jobs_count },
            { key: 'avg_score', header: 'Avg Score %', render: (r: Scorecard) => `${r.avg_score}%` },
            { key: 'avg_stars', header: 'Avg Stars', render: (r: Scorecard) => `${r.avg_stars} / 5` },
            { key: 'total_waste_kg', header: 'Waste kg', render: (r: Scorecard) => r.total_waste_kg },
            { key: 'worst_status', header: 'Worst Status', render: (r: Scorecard) => r.worst_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: Scorecard, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section className="mb-10 grid gap-6 md:grid-cols-2">
        <div>
          <h2 className="mb-3 text-xl font-semibold">Category Breakdown</h2>
          <DataTable
            rows={categories}
            columns={[
              { key: 'device_category', header: 'Category', render: (r: Category) => r.device_category },
              { key: 'jobs', header: 'Jobs', render: (r: Category) => r.jobs },
              { key: 'avg_score', header: 'Avg Score %', render: (r: Category) => `${r.avg_score}%` },
              { key: 'avg_space_restored', header: 'Space Restored %', render: (r: Category) => `${r.avg_space_restored}%` },
              { key: 'avg_stars', header: 'Avg Stars', render: (r: Category) => `${r.avg_stars} / 5` },
            ]}
            emptyMessage="No data"
            rowKey={(r: Category, i: number) => String(r.device_category ?? i)}
          />
        </div>
        <div>
          <h2 className="mb-3 text-xl font-semibold">Waste Accounting</h2>
          <DataTable
            rows={waste}
            columns={[
              { key: 'device_category', header: 'Category', render: (r: Waste) => r.device_category },
              { key: 'total_waste_kg', header: 'Total kg', render: (r: Waste) => r.total_waste_kg },
              { key: 'total_biohazard_bags', header: 'Biohazard Bags', render: (r: Waste) => r.total_biohazard_bags },
              { key: 'jobs', header: 'Jobs', render: (r: Waste) => r.jobs },
              { key: 'kg_per_job', header: 'kg / Job', render: (r: Waste) => r.kg_per_job },
            ]}
            emptyMessage="No data"
            rowKey={(r: Waste, i: number) => String(r.device_category ?? i)}
          />
        </div>
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-xl font-semibold">Refine Action Backlog</h2>
        <p className="mb-3 text-sm text-gray-600">
          Each gap drives a refine action with an owner and an expected score lift. p0 items target a &gt;= 20% lift within 14 days.
        </p>
        <DataTable
          rows={refines}
          columns={[
            { key: 'priority', header: 'Priority', render: (r: Refine) => r.priority },
            { key: 'engineer_name', header: 'Engineer', render: (r: Refine) => r.engineer_name },
            { key: 'gap_theme', header: 'Gap', render: (r: Refine) => r.gap_theme },
            { key: 'refine_action', header: 'Refine Action', render: (r: Refine) => r.refine_action },
            { key: 'owner', header: 'Owner', render: (r: Refine) => r.owner },
            { key: 'due_in_days', header: 'Due (days)', render: (r: Refine) => r.due_in_days },
            { key: 'expected_score_lift_pct', header: 'Expected Lift %', render: (r: Refine) => `${r.expected_score_lift_pct}%` },
            { key: 'status', header: 'Status', render: (r: Refine) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: Refine, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="mb-10">
        <h2 className="mb-3 text-xl font-semibold">Top Customer Quotes</h2>
        <DataTable
          rows={quotes}
          columns={[
            { key: 'customer_org', header: 'Customer', render: (r: Quote) => r.customer_org },
            { key: 'engineer_name', header: 'Engineer', render: (r: Quote) => r.engineer_name },
            { key: 'customer_feedback_stars', header: 'Stars', render: (r: Quote) => `${r.customer_feedback_stars} / 5` },
            { key: 'customer_quote', header: 'Quote', render: (r: Quote) => r.customer_quote },
            { key: 'status', header: 'Status', render: (r: Quote) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: Quote, i: number) => `${r.customer_org}-${r.engineer_name}-${i}`}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}
