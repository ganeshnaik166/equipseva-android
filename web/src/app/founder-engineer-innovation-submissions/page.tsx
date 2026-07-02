import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Submission = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  title: string;
  description_md: string;
  category: string;
  submitted_at: string;
  status: string;
  decided_at: string | null;
  reward_rupees: number;
  implemented_at: string | null;
  review_count: number;
};

type Contributor = {
  engineer_user_id: string;
  engineer_email: string | null;
  submissions_count: number;
  accepted_count: number;
  implemented_count: number;
  total_reward_rupees: number;
};

type Summary = {
  total_submissions: number;
  new_count: number;
  reviewing_count: number;
  accepted_count: number;
  rejected_count: number;
  implemented_count: number;
  total_reward_rupees: number;
  implemented_pct: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [submissionsRes, contributorsRes, summaryRes] = await Promise.all([
    sb.rpc('list_submissions_r1708'),
    sb.rpc('top_contributors_r1708'),
    sb.rpc('implementation_summary_r1708'),
  ]);

  const submissions: Submission[] = (submissionsRes.data ?? []) as Submission[];
  const contributors: Contributor[] = (contributorsRes.data ?? []) as Contributor[];
  const summary: Summary = ((summaryRes.data ?? [])[0] ?? {
    total_submissions: 0,
    new_count: 0,
    reviewing_count: 0,
    accepted_count: 0,
    rejected_count: 0,
    implemented_count: 0,
    total_reward_rupees: 0,
    implemented_pct: 0,
  }) as Summary;

  const submissionCols: Column<Submission>[] = [
    { key: 'submitted', header: 'Submitted', render: (r: any) => new Date(r.submitted_at).toLocaleDateString() },
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'reviews', header: 'Reviews', render: (r: any) => String(r.review_count) },
    { key: 'reward', header: 'Reward (Rs)', render: (r: any) => (r.reward_rupees > 0 ? `Rs ${r.reward_rupees}` : '—') },
    { key: 'decided', header: 'Decided', render: (r: any) => (r.decided_at ? new Date(r.decided_at).toLocaleDateString() : '—') },
    { key: 'implemented', header: 'Implemented', render: (r: any) => (r.implemented_at ? new Date(r.implemented_at).toLocaleDateString() : '—') },
  ];

  const contributorCols: Column<Contributor>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'submissions', header: 'Submissions', render: (r: any) => String(r.submissions_count) },
    { key: 'accepted', header: 'Accepted', render: (r: any) => String(r.accepted_count) },
    { key: 'implemented', header: 'Implemented', render: (r: any) => String(r.implemented_count) },
    { key: 'reward', header: 'Total reward (Rs)', render: (r: any) => `Rs ${r.total_reward_rupees}` },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Innovation Submissions</h1>
        <p className="text-sm text-gray-500">r1708 · field engineer ideas to improve product and process</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total submissions</div>
          <div className="text-2xl font-semibold">{summary.total_submissions}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">New</div>
          <div className="text-2xl font-semibold text-blue-600">{summary.new_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Reviewing</div>
          <div className="text-2xl font-semibold">{summary.reviewing_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Implemented</div>
          <div className="text-2xl font-semibold text-green-600">{summary.implemented_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Accepted</div>
          <div className="text-2xl font-semibold">{summary.accepted_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Rejected</div>
          <div className="text-2xl font-semibold text-red-600">{summary.rejected_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Implementation %</div>
          <div className="text-2xl font-semibold">{summary.implemented_pct}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total reward paid</div>
          <div className="text-2xl font-semibold">Rs {summary.total_reward_rupees}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All submissions</h2>
        <DataTable rows={submissions} columns={submissionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top contributors</h2>
        <DataTable rows={contributors} columns={contributorCols} rowKey={(r, i) => String(r.engineer_user_id ?? i)} />
      </section>
    </main>
  );
}
