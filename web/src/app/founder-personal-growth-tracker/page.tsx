import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPersonalGrowthTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, listRes, monthlyRes, appliedRes, unappliedRes, topicsRes, inProgressRes] = await Promise.all([
    supabase.rpc('fn_growth_summary_r2321'),
    supabase.rpc('fn_growth_list_media_r2321', { p_limit: 100 }),
    supabase.rpc('fn_growth_monthly_rollup_r2321'),
    supabase.rpc('fn_growth_applied_takeaways_r2321'),
    supabase.rpc('fn_growth_unapplied_takeaways_r2321'),
    supabase.rpc('fn_growth_top_topics_r2321'),
    supabase.rpc('fn_growth_in_progress_r2321'),
  ]);

  const summary = summaryRes.data?.[0] ?? null;
  const items = listRes.data ?? [];
  const monthly = monthlyRes.data ?? [];
  const applied = appliedRes.data ?? [];
  const unapplied = unappliedRes.data ?? [];
  const topics = topicsRes.data ?? [];
  const inProgress = inProgressRes.data ?? [];

  const itemCols: Column<any>[] = [
    { key: 'month_consumed', header: 'Month', render: (r) => r.month_consumed ? String(r.month_consumed).slice(0, 7) : '-' },
    { key: 'media_type', header: 'Type', render: (r) => <span className="capitalize">{r.media_type}</span> },
    { key: 'title', header: 'Title', render: (r) => <span className="font-medium">{r.title}</span> },
    { key: 'author_or_host', header: 'Author / Host', render: (r) => r.author_or_host || '-' },
    { key: 'topic', header: 'Topic', render: (r) => r.topic || '-' },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'rating_out_of_5', header: 'Rating', render: (r) => r.rating_out_of_5 ? `${r.rating_out_of_5} / 5` : '-' },
    { key: 'takeaway_count', header: 'Takeaways', render: (r) => `${r.applied_count} applied / ${r.takeaway_count}` },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_consumed', header: 'Month', render: (r) => r.month_consumed ? String(r.month_consumed).slice(0, 7) : '-' },
    { key: 'books_count', header: 'Books', render: (r) => r.books_count },
    { key: 'podcasts_count', header: 'Podcasts', render: (r) => r.podcasts_count },
    { key: 'other_count', header: 'Other', render: (r) => r.other_count },
    { key: 'total_hours', header: 'Hours', render: (r) => Number(r.total_hours || 0).toFixed(1) },
    { key: 'takeaways_logged', header: 'Takeaways', render: (r) => `${r.takeaways_applied} / ${r.takeaways_logged}` },
  ];

  const appliedCols: Column<any>[] = [
    { key: 'media_title', header: 'Source', render: (r) => <span className="font-medium">{r.media_title}</span> },
    { key: 'media_type', header: 'Type', render: (r) => r.media_type },
    { key: 'takeaway_text', header: 'Takeaway', render: (r) => <span className="text-sm">{r.takeaway_text}</span> },
    { key: 'application_note', header: 'How applied', render: (r) => r.application_note || '-' },
    { key: 'impact_rating', header: 'Impact', render: (r) => r.impact_rating ? `${r.impact_rating} / 5` : '-' },
    { key: 'applied_at', header: 'Applied', render: (r) => r.applied_at ? new Date(r.applied_at).toLocaleDateString() : '-' },
  ];

  const unappliedCols: Column<any>[] = [
    { key: 'media_title', header: 'Source', render: (r) => r.media_title },
    { key: 'media_type', header: 'Type', render: (r) => r.media_type },
    { key: 'takeaway_text', header: 'Idea to apply', render: (r) => <span className="text-sm">{r.takeaway_text}</span> },
    { key: 'age_days', header: 'Age (days)', render: (r) => r.age_days },
  ];

  const topicsCols: Column<any>[] = [
    { key: 'topic', header: 'Topic', render: (r) => <span className="font-medium">{r.topic}</span> },
    { key: 'items_count', header: 'Items', render: (r) => r.items_count },
    { key: 'avg_rating', header: 'Avg rating', render: (r) => Number(r.avg_rating || 0).toFixed(2) },
    { key: 'total_hours', header: 'Hours', render: (r) => Number(r.total_hours || 0).toFixed(1) },
  ];

  const inProgressCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r) => <span className="font-medium">{r.title}</span> },
    { key: 'media_type', header: 'Type', render: (r) => r.media_type },
    { key: 'author_or_host', header: 'Author / Host', render: (r) => r.author_or_host || '-' },
    { key: 'started_month', header: 'Started', render: (r) => r.started_month ? String(r.started_month).slice(0, 7) : '-' },
    { key: 'days_in_progress', header: 'Days open', render: (r) => r.days_in_progress },
  ];

  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Personal Growth Tracker</h1>
        <p className="text-gray-600">
          Books, podcasts, essays the founder consumed each month — with key takeaways and whether they were
          applied to the business. Reading without action is just entertainment.
        </p>
      </div>

      {summary && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-white p-4 rounded-lg border border-gray-200">
            <div className="text-sm text-gray-500">Books done</div>
            <div className="text-2xl font-bold">{summary.books_completed}</div>
          </div>
          <div className="bg-white p-4 rounded-lg border border-gray-200">
            <div className="text-sm text-gray-500">Podcasts done</div>
            <div className="text-2xl font-bold">{summary.podcasts_completed}</div>
          </div>
          <div className="bg-white p-4 rounded-lg border border-gray-200">
            <div className="text-sm text-gray-500">In progress</div>
            <div className="text-2xl font-bold">{summary.in_progress_count}</div>
          </div>
          <div className="bg-white p-4 rounded-lg border border-gray-200">
            <div className="text-sm text-gray-500">Application rate</div>
            <div className="text-2xl font-bold">{summary.application_rate}%</div>
            <div className="text-xs text-gray-500 mt-1">
              {summary.applied_takeaways} of {summary.total_takeaways} takeaways applied
            </div>
          </div>
        </div>
      )}

      <section className="mb-10">
        <h2 className="text-xl font-semibold mb-3">Library — all items</h2>
        <DataTable
          rows={items}
          columns={itemCols}
          rowKey={(r: any) => r.id}
          emptyMessage="No items logged yet."
        />
      </section>

      <section className="mb-10">
        <h2 className="text-xl font-semibold mb-3">Monthly consumption rollup</h2>
        <DataTable
          rows={monthly}
          columns={monthlyCols}
          rowKey={(r: any) => String(r.month_consumed)}
          emptyMessage="No monthly data."
        />
      </section>

      <section className="mb-10">
        <h2 className="text-xl font-semibold mb-3">Takeaways applied to the business</h2>
        <p className="text-sm text-gray-600 mb-3">
          Ideas that actually changed how Equipseva operates — the only takeaways that matter.
        </p>
        <DataTable
          rows={applied}
          columns={appliedCols}
          rowKey={(r: any) => r.takeaway_id}
          emptyMessage="No takeaways applied yet."
        />
      </section>

      <section className="mb-10">
        <h2 className="text-xl font-semibold mb-3">Idea backlog — not applied yet</h2>
        <p className="text-sm text-gray-600 mb-3">
          Takeaways logged but not yet acted on. Older than 30 days =&gt; either apply or drop.
        </p>
        <DataTable
          rows={unapplied}
          columns={unappliedCols}
          rowKey={(r: any) => r.takeaway_id}
          emptyMessage="No pending ideas."
        />
      </section>

      <section className="mb-10">
        <h2 className="text-xl font-semibold mb-3">Top topics studied</h2>
        <DataTable
          rows={topics}
          columns={topicsCols}
          rowKey={(r: any) => r.topic}
          emptyMessage="No topics tracked."
        />
      </section>

      <section className="mb-10">
        <h2 className="text-xl font-semibold mb-3">Currently in progress</h2>
        <DataTable
          rows={inProgress}
          columns={inProgressCols}
          rowKey={(r: any) => r.id}
          emptyMessage="Nothing in progress."
        />
      </section>
    </div>
  );
}
