import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_jobs: number;
  on_time_or_early_pct: number | null;
  avg_buffer_minutes: number | null;
  median_buffer_minutes: number | null;
  complaint_jobs: number;
  avg_csat: number | null;
};

type JobRow = {
  job_code: string;
  customer_name: string;
  engineer_name: string;
  engineer_tier: string;
  device_category: string;
  job_priority: string;
  promised_arrival_at: string;
  actual_arrival_at: string;
  buffer_minutes: number;
  buffer_bucket: string;
  primary_cause: string;
  customer_csat: number;
  customer_complained: boolean;
};

type CauseRow = {
  primary_cause: string;
  job_count: number;
  avg_buffer_minutes: number | null;
  share_pct: number | null;
};

type EngineerRow = {
  engineer_name: string;
  engineer_tier: string;
  jobs: number;
  avg_buffer_minutes: number | null;
  worst_buffer_minutes: number;
  on_time_pct: number | null;
  complaint_count: number;
};

type BucketRow = {
  buffer_bucket: string;
  job_count: number;
  share_pct: number | null;
};

type ActionRow = {
  action_code: string;
  target_cause: string;
  action_title: string;
  action_detail: string;
  owner_role: string;
  status: string;
  expected_buffer_reduction_minutes: number;
  observed_buffer_reduction_minutes: number | null;
  jobs_in_sample: number;
};

type DeviceRow = {
  device_category: string;
  jobs: number;
  avg_buffer_minutes: number | null;
  avg_csat: number | null;
  complaint_count: number;
};

type PriorityRow = {
  job_priority: string;
  jobs: number;
  avg_buffer_minutes: number | null;
  very_late_count: number;
  on_time_pct: number | null;
};

function fmt(n: number | null | undefined, suffix = '') {
  if (n === null || n === undefined) return '—';
  return `${n}${suffix}`;
}

function fmtDateTime(s: string) {
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'short', timeStyle: 'short' });
  } catch {
    return s;
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const month = '2026-06';

  const [kpiRes, jobsRes, causesRes, engineersRes, bucketsRes, actionsRes, devicesRes, prioritiesRes] = await Promise.all([
    supabase.rpc('r2828_kpi_rollup', { p_month: month }),
    supabase.rpc('r2828_list_jobs', { p_month: month }),
    supabase.rpc('r2828_cause_breakdown', { p_month: month }),
    supabase.rpc('r2828_engineer_scorecard', { p_month: month }),
    supabase.rpc('r2828_bucket_distribution', { p_month: month }),
    supabase.rpc('r2828_list_refine_actions', { p_month: month }),
    supabase.rpc('r2828_device_category_drill', { p_month: month }),
    supabase.rpc('r2828_priority_impact', { p_month: month }),
  ]);

  const kpi: KpiRow | null = (kpiRes.data?.[0] as KpiRow) ?? null;
  const jobs: JobRow[] = (jobsRes.data as JobRow[]) ?? [];
  const causes: CauseRow[] = (causesRes.data as CauseRow[]) ?? [];
  const engineers: EngineerRow[] = (engineersRes.data as EngineerRow[]) ?? [];
  const buckets: BucketRow[] = (bucketsRes.data as BucketRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const devices: DeviceRow[] = (devicesRes.data as DeviceRow[]) ?? [];
  const priorities: PriorityRow[] = (prioritiesRes.data as PriorityRow[]) ?? [];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Customer Monthly Engineer Arrival Buffer Time</h1>
        <p className="text-sm text-gray-600">
          Job × promised arrival × actual × buffer × cause × refine action. Month {month}.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <KpiCard label="Total jobs" value={fmt(kpi?.total_jobs ?? 0)} />
        <KpiCard label="On-time / early" value={fmt(kpi?.on_time_or_early_pct, '%')} />
        <KpiCard label="Avg buffer (min)" value={fmt(kpi?.avg_buffer_minutes)} />
        <KpiCard label="Median buffer (min)" value={fmt(kpi?.median_buffer_minutes)} />
        <KpiCard label="Complaint jobs" value={fmt(kpi?.complaint_jobs ?? 0)} />
        <KpiCard label="Avg CSAT" value={fmt(kpi?.avg_csat)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Buffer bucket distribution</h2>
        <p className="text-xs text-gray-500">
          Buckets: early (&lt; 0 min), on_time (0–10 min), slight_late (10–30 min), late (30–60 min), very_late (&gt; 60 min).
        </p>
        <DataTable
          rows={buckets}
          columns={[
            { key: 'buffer_bucket', header: 'Bucket', render: (r: BucketRow) => r.buffer_bucket },
            { key: 'job_count', header: 'Jobs', render: (r: BucketRow) => r.job_count },
            { key: 'share_pct', header: 'Share %', render: (r: BucketRow) => fmt(r.share_pct, '%') },
          ]}
          emptyMessage="No data"
          rowKey={(r: BucketRow, i: number) => String(r.buffer_bucket ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Primary cause breakdown</h2>
        <DataTable
          rows={causes}
          columns={[
            { key: 'primary_cause', header: 'Cause', render: (r: CauseRow) => r.primary_cause },
            { key: 'job_count', header: 'Jobs', render: (r: CauseRow) => r.job_count },
            { key: 'avg_buffer_minutes', header: 'Avg buffer (min)', render: (r: CauseRow) => fmt(r.avg_buffer_minutes) },
            { key: 'share_pct', header: 'Share %', render: (r: CauseRow) => fmt(r.share_pct, '%') },
          ]}
          emptyMessage="No data"
          rowKey={(r: CauseRow, i: number) => String(r.primary_cause ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Engineer scorecard</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: EngineerRow) => r.engineer_tier },
            { key: 'jobs', header: 'Jobs', render: (r: EngineerRow) => r.jobs },
            { key: 'avg_buffer_minutes', header: 'Avg buffer', render: (r: EngineerRow) => fmt(r.avg_buffer_minutes) },
            { key: 'worst_buffer_minutes', header: 'Worst', render: (r: EngineerRow) => r.worst_buffer_minutes },
            { key: 'on_time_pct', header: 'On-time %', render: (r: EngineerRow) => fmt(r.on_time_pct, '%') },
            { key: 'complaint_count', header: 'Complaints', render: (r: EngineerRow) => r.complaint_count },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Device-category drill</h2>
        <DataTable
          rows={devices}
          columns={[
            { key: 'device_category', header: 'Category', render: (r: DeviceRow) => r.device_category },
            { key: 'jobs', header: 'Jobs', render: (r: DeviceRow) => r.jobs },
            { key: 'avg_buffer_minutes', header: 'Avg buffer', render: (r: DeviceRow) => fmt(r.avg_buffer_minutes) },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: DeviceRow) => fmt(r.avg_csat) },
            { key: 'complaint_count', header: 'Complaints', render: (r: DeviceRow) => r.complaint_count },
          ]}
          emptyMessage="No data"
          rowKey={(r: DeviceRow, i: number) => String(r.device_category ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Priority impact</h2>
        <p className="text-xs text-gray-500">
          p0 promises are tightest — any buffer &gt;= 30 min directly hits CSAT.
        </p>
        <DataTable
          rows={priorities}
          columns={[
            { key: 'job_priority', header: 'Priority', render: (r: PriorityRow) => r.job_priority },
            { key: 'jobs', header: 'Jobs', render: (r: PriorityRow) => r.jobs },
            { key: 'avg_buffer_minutes', header: 'Avg buffer', render: (r: PriorityRow) => fmt(r.avg_buffer_minutes) },
            { key: 'very_late_count', header: 'Very late', render: (r: PriorityRow) => r.very_late_count },
            { key: 'on_time_pct', header: 'On-time %', render: (r: PriorityRow) => fmt(r.on_time_pct, '%') },
          ]}
          emptyMessage="No data"
          rowKey={(r: PriorityRow, i: number) => String(r.job_priority ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All jobs (worst buffer first)</h2>
        <DataTable
          rows={jobs}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: JobRow) => r.job_code },
            { key: 'customer_name', header: 'Customer', render: (r: JobRow) => r.customer_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: JobRow) => `${r.engineer_name} (${r.engineer_tier})` },
            { key: 'device_category', header: 'Device', render: (r: JobRow) => r.device_category },
            { key: 'job_priority', header: 'Pri', render: (r: JobRow) => r.job_priority },
            { key: 'promised_arrival_at', header: 'Promised', render: (r: JobRow) => fmtDateTime(r.promised_arrival_at) },
            { key: 'actual_arrival_at', header: 'Actual', render: (r: JobRow) => fmtDateTime(r.actual_arrival_at) },
            { key: 'buffer_minutes', header: 'Buffer (min)', render: (r: JobRow) => r.buffer_minutes },
            { key: 'buffer_bucket', header: 'Bucket', render: (r: JobRow) => r.buffer_bucket },
            { key: 'primary_cause', header: 'Cause', render: (r: JobRow) => r.primary_cause },
            { key: 'customer_csat', header: 'CSAT', render: (r: JobRow) => r.customer_csat },
            { key: 'customer_complained', header: 'Complaint', render: (r: JobRow) => (r.customer_complained ? 'yes' : 'no') },
          ]}
          emptyMessage="No data"
          rowKey={(r: JobRow, i: number) => String(r.job_code ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Refine actions</h2>
        <p className="text-xs text-gray-500">
          Owner-tagged actions targeting top causes. Expected vs observed buffer reduction &gt;= 0 means action is working.
        </p>
        <DataTable
          rows={actions}
          columns={[
            { key: 'action_code', header: 'Code', render: (r: ActionRow) => r.action_code },
            { key: 'target_cause', header: 'Target cause', render: (r: ActionRow) => r.target_cause },
            { key: 'action_title', header: 'Title', render: (r: ActionRow) => r.action_title },
            { key: 'action_detail', header: 'Detail', render: (r: ActionRow) => r.action_detail },
            { key: 'owner_role', header: 'Owner', render: (r: ActionRow) => r.owner_role },
            { key: 'status', header: 'Status', render: (r: ActionRow) => r.status },
            { key: 'expected_buffer_reduction_minutes', header: 'Expected (min)', render: (r: ActionRow) => r.expected_buffer_reduction_minutes },
            { key: 'observed_buffer_reduction_minutes', header: 'Observed (min)', render: (r: ActionRow) => fmt(r.observed_buffer_reduction_minutes) },
            { key: 'jobs_in_sample', header: 'Sample', render: (r: ActionRow) => r.jobs_in_sample },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionRow, i: number) => String(r.action_code ?? i)}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}
