import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [plansRes, summaryRes, offTrackRes] = await Promise.all([
    sb.rpc('list_plans_r1723', { p_status: null }),
    sb.rpc('plan_revenue_summary_r1723'),
    sb.rpc('off_track_plans_r1723'),
  ]);

  const plans: any[] = Array.isArray(plansRes.data) ? plansRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data;
  const offTrack: any[] = Array.isArray(offTrackRes.data) ? offTrackRes.data : [];

  const fmtRupees = (n: any) => {
    const v = Number(n ?? 0);
    return '₹' + v.toLocaleString('en-IN');
  };

  const plansColumns: Column<any>[] = [
    { key: 'plan_label', header: 'Plan', render: (r: any) => <span className="font-medium">{r.plan_label}</span> },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => <span className="text-xs">{r.hospital_email ?? '-'}</span> },
    { key: 'plan_years', header: 'Years', render: (r: any) => <span>{r.plan_years}</span> },
    { key: 'total_committed_rupees', header: 'Committed', render: (r: any) => <span>{fmtRupees(r.total_committed_rupees)}</span> },
    { key: 'plan_start', header: 'Start', render: (r: any) => <span className="text-xs">{r.plan_start ?? '-'}</span> },
    { key: 'plan_end', header: 'End', render: (r: any) => <span className="text-xs">{r.plan_end ?? '-'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => {
      const s = String(r.status ?? '');
      const cls = s === 'active' ? 'bg-green-100 text-green-800'
        : s === 'completed' ? 'bg-blue-100 text-blue-800'
        : s === 'cancelled' ? 'bg-red-100 text-red-800'
        : 'bg-gray-100 text-gray-800';
      return <span className={`px-2 py-0.5 rounded text-xs ${cls}`}>{s}</span>;
    } },
    { key: 'review_count', header: 'Reviews', render: (r: any) => <span>{r.review_count ?? 0}</span> },
  ];

  const offTrackColumns: Column<any>[] = [
    { key: 'plan_label', header: 'Plan', render: (r: any) => <span className="font-medium">{r.plan_label}</span> },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => <span className="text-xs">{r.hospital_email ?? '-'}</span> },
    { key: 'off_track_reviews', header: 'Off-track Reviews', render: (r: any) => <span className="text-red-700 font-semibold">{r.off_track_reviews}</span> },
    { key: 'last_review_date', header: 'Last Review', render: (r: any) => <span className="text-xs">{r.last_review_date ?? '-'}</span> },
    { key: 'total_variance_rupees', header: 'Total Variance', render: (r: any) => {
      const v = Number(r.total_variance_rupees ?? 0);
      const cls = v < 0 ? 'text-red-700' : 'text-green-700';
      return <span className={cls}>{fmtRupees(v)}</span>;
    } },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
  ];

  return (
    <main className="p-6 max-w-7xl mx-auto space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Multi-Year Plan Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track multi-year strategic commitments per hospital chain & quarterly review cadence.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Total Plans</div>
          <div className="text-xl font-bold">{summary?.total_plans ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Active</div>
          <div className="text-xl font-bold text-green-700">{summary?.active_plans ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Completed</div>
          <div className="text-xl font-bold text-blue-700">{summary?.completed_plans ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Draft</div>
          <div className="text-xl font-bold">{summary?.draft_plans ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Cancelled</div>
          <div className="text-xl font-bold text-red-700">{summary?.cancelled_plans ?? 0}</div>
        </div>
      </section>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Total Committed</div>
          <div className="text-lg font-bold">{fmtRupees(summary?.total_committed_rupees)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Expected (reviews)</div>
          <div className="text-lg font-bold">{fmtRupees(summary?.total_expected_rupees)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Actual (reviews)</div>
          <div className="text-lg font-bold">{fmtRupees(summary?.total_actual_rupees)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Overall Variance</div>
          <div className={`text-lg font-bold ${Number(summary?.overall_variance_rupees ?? 0) < 0 ? 'text-red-700' : 'text-green-700'}`}>
            {fmtRupees(summary?.overall_variance_rupees)}
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Plans</h2>
        <DataTable
          rows={plans}
          columns={plansColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
        {plans.length === 0 ? (
          <p className="text-sm text-gray-500 mt-2">No plans recorded yet.</p>
        ) : null}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Off-Track Active Plans</h2>
        <p className="text-xs text-gray-500 mb-2">
          Active plans with at least one quarterly review flagged off-track.
        </p>
        <DataTable
          rows={offTrack}
          columns={offTrackColumns}
          rowKey={(r: any, i: number) => String(r.plan_id ?? i)}
        />
        {offTrack.length === 0 ? (
          <p className="text-sm text-gray-500 mt-2">All active plans are currently on-track.</p>
        ) : null}
      </section>
    </main>
  );
}
