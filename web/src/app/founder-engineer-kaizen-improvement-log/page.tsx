import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerKaizenImprovementLogPage() {
  const supabase = await getSupabaseServerClient();

  const [submissionsRes, summaryRes, contributorsRes, categoryRes, rolloutsRes] = await Promise.all([
    supabase.rpc('kaizen_list_submissions_r2366', { p_status_filter: null }),
    supabase.rpc('kaizen_summary_r2366'),
    supabase.rpc('kaizen_top_contributors_r2366'),
    supabase.rpc('kaizen_category_breakdown_r2366'),
    supabase.rpc('kaizen_list_rollouts_r2366'),
  ]);

  const submissions = submissionsRes.data ?? [];
  const summary = (summaryRes.data ?? [])[0] ?? {
    total_submissions: 0,
    pending_review_count: 0,
    approved_scaled_count: 0,
    rejected_count: 0,
    total_estimated_savings_rupees: 0,
    total_rewards_paid_rupees: 0,
    unique_contributors: 0,
    avg_time_saved_minutes: 0,
  };
  const contributors = contributorsRes.data ?? [];
  const categories = categoryRes.data ?? [];
  const rollouts = rolloutsRes.data ?? [];

  const anyError = submissionsRes.error || summaryRes.error || contributorsRes.error || categoryRes.error || rolloutsRes.error;

  const submissionColumns: Column<any>[] = [
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => new Date(r.submitted_at).toLocaleString('en-IN') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'time_saved', header: 'Time saved/job', render: (r: any) => `${r.time_saved_minutes_per_job} min` },
    { key: 'jobs_applied', header: 'Jobs applied', render: (r: any) => r.jobs_applied_count },
    { key: 'savings', header: 'Est. annual savings', render: (r: any) => `₹${Number(r.estimated_annual_savings_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'reward', header: 'Reward paid', render: (r: any) => `₹${Number(r.reward_paid_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'scale_decision', header: 'Scale decision', render: (r: any) => r.scale_decision ?? '—' },
  ];

  const contributorColumns: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'submissions_count', header: 'Submissions', render: (r: any) => r.submissions_count },
    { key: 'approved_count', header: 'Approved', render: (r: any) => r.approved_count },
    { key: 'total_savings_rupees', header: 'Total savings', render: (r: any) => `₹${Number(r.total_savings_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_rewards_rupees', header: 'Rewards paid', render: (r: any) => `₹${Number(r.total_rewards_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const categoryColumns: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'submissions_count', header: 'Submissions', render: (r: any) => r.submissions_count },
    { key: 'approved_count', header: 'Approved', render: (r: any) => r.approved_count },
    { key: 'avg_time_saved_minutes', header: 'Avg time saved', render: (r: any) => `${Number(r.avg_time_saved_minutes ?? 0).toFixed(1)} min` },
    { key: 'total_estimated_savings_rupees', header: 'Total est. savings', render: (r: any) => `₹${Number(r.total_estimated_savings_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const rolloutColumns: Column<any>[] = [
    { key: 'rolled_out_at', header: 'Rolled out', render: (r: any) => new Date(r.rolled_out_at).toLocaleString('en-IN') },
    { key: 'kaizen_title', header: 'Kaizen', render: (r: any) => r.kaizen_title ?? '—' },
    { key: 'target_audience', header: 'Target', render: (r: any) => r.target_audience },
    { key: 'engineers_notified_count', header: 'Notified', render: (r: any) => r.engineers_notified_count },
    { key: 'engineers_adopted_count', header: 'Adopted', render: (r: any) => r.engineers_adopted_count },
    { key: 'adoption_rate_pct', header: 'Adoption %', render: (r: any) => `${Number(r.adoption_rate_pct ?? 0).toFixed(1)}%` },
    { key: 'measured_impact_rupees', header: 'Measured impact', render: (r: any) => `₹${Number(r.measured_impact_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'rollout_status', header: 'Status', render: (r: any) => r.rollout_status },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Kaizen Improvement Log</h1>
        <p className="text-sm text-gray-600 mt-1">
          Small improvements from engineers. Founder reviews & scales good ones across team.
        </p>
      </header>

      {anyError && (
        <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-800">
          Error loading data. Verify is_founder() gate & RPC deployment.
        </div>
      )}

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Total submissions</div>
          <div className="text-2xl font-bold mt-1">{Number(summary.total_submissions ?? 0)}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Pending review</div>
          <div className="text-2xl font-bold mt-1 text-orange-600">{Number(summary.pending_review_count ?? 0)}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Approved & scaled</div>
          <div className="text-2xl font-bold mt-1 text-green-600">{Number(summary.approved_scaled_count ?? 0)}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Unique contributors</div>
          <div className="text-2xl font-bold mt-1">{Number(summary.unique_contributors ?? 0)}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Total est. annual savings</div>
          <div className="text-2xl font-bold mt-1">₹{Number(summary.total_estimated_savings_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Total rewards paid</div>
          <div className="text-2xl font-bold mt-1">₹{Number(summary.total_rewards_paid_rupees ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Rejected</div>
          <div className="text-2xl font-bold mt-1 text-red-600">{Number(summary.rejected_count ?? 0)}</div>
        </div>
        <div className="rounded border bg-white p-4">
          <div className="text-xs text-gray-500">Avg time saved/job</div>
          <div className="text-2xl font-bold mt-1">{Number(summary.avg_time_saved_minutes ?? 0).toFixed(1)} min</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All kaizen submissions</h2>
        <DataTable
          rows={submissions}
          columns={submissionColumns}
          emptyMessage="No kaizen submissions yet. Engineers log small improvements from field jobs."
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top contributing engineers</h2>
        <DataTable
          rows={contributors}
          columns={contributorColumns}
          emptyMessage="No contributors yet."
          rowKey={(r: any) => r.engineer_user_id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Category breakdown</h2>
        <DataTable
          rows={categories}
          columns={categoryColumns}
          emptyMessage="No category data."
          rowKey={(r: any) => r.category}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Scale-out rollouts</h2>
        <p className="text-xs text-gray-500 mb-2">
          When founder approves a kaizen & rolls it out to pod, region, or all engineers. Tracks adoption & measured impact.
        </p>
        <DataTable
          rows={rollouts}
          columns={rolloutColumns}
          emptyMessage="No rollouts yet. Approve a kaizen & create a rollout to scale it."
          rowKey={(r: any) => r.id}
        />
      </section>
    </div>
  );
}
