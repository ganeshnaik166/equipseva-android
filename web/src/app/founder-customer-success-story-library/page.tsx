import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerSuccessStoryLibraryPage() {
  const supabase = await getSupabaseServerClient();

  const [storiesRes, topSalesRes, summaryRes] = await Promise.all([
    supabase.rpc('list_success_stories_r2328'),
    supabase.rpc('top_sales_stories_r2328'),
    supabase.rpc('story_library_summary_r2328'),
  ]);

  const stories = (storiesRes.data ?? []) as any[];
  const topSales = (topSalesRes.data ?? []) as any[];
  const summary = ((summaryRes.data ?? [])[0] ?? {}) as any;

  const storyColumns: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'hero', header: 'Hero', render: (r: any) => (r.is_hero_story ? 'HERO' : '') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'hero_metric', header: 'Hero metric', render: (r: any) => r.hero_metric ?? '' },
    {
      key: 'uptime',
      header: 'Uptime %',
      render: (r: any) => (r.metric_uptime_pct != null ? Number(r.metric_uptime_pct).toFixed(2) : ''),
    },
    {
      key: 'jobs',
      header: 'Jobs done',
      render: (r: any) => (r.metric_jobs_completed != null ? r.metric_jobs_completed : ''),
    },
    {
      key: 'savings',
      header: 'Savings',
      render: (r: any) =>
        r.metric_cost_savings_rupees != null
          ? `Rs ${Number(r.metric_cost_savings_rupees).toLocaleString('en-IN')}`
          : '',
    },
    { key: 'sales_uses', header: 'Sales uses', render: (r: any) => r.used_in_sales_count ?? 0 },
    {
      key: 'last_refresh',
      header: 'Last refresh',
      render: (r: any) =>
        r.last_refreshed_at ? new Date(r.last_refreshed_at).toLocaleString() : '',
    },
    {
      key: 'published',
      header: 'Published at',
      render: (r: any) => (r.published_at ? new Date(r.published_at).toLocaleString() : ''),
    },
  ];

  const topColumns: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'hero', header: 'Hero', render: (r: any) => (r.is_hero_story ? 'HERO' : '') },
    { key: 'sales_uses', header: 'Sales uses', render: (r: any) => r.used_in_sales_count ?? 0 },
    { key: 'refresh_count', header: 'Refreshes', render: (r: any) => Number(r.refresh_count ?? 0) },
    {
      key: 'last_refresh',
      header: 'Last refresh',
      render: (r: any) =>
        r.last_refreshed_at ? new Date(r.last_refreshed_at).toLocaleString() : '',
    },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer success-story library</h1>
        <p className="text-sm text-gray-600">
          Written customer wins, hero story pick, metrics &amp; refresh log =&gt; sales-ready ammo.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <Stat label="Total stories" value={summary.total_stories ?? 0} />
        <Stat label="Published" value={summary.published_stories ?? 0} />
        <Stat label="Drafts" value={summary.draft_stories ?? 0} />
        <Stat label="Hero count" value={summary.hero_count ?? 0} />
        <Stat label="Total sales uses" value={summary.total_sales_uses ?? 0} />
        <Stat label="Total refreshes" value={summary.total_refreshes ?? 0} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Library — all stories</h2>
        <DataTable
          rows={stories}
          columns={storyColumns}
          rowKey={(r: any) => r.id}
          emptyMessage="No success stories drafted yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top sales-used stories</h2>
        <DataTable
          rows={topSales}
          columns={topColumns}
          rowKey={(r: any) => r.story_id}
          emptyMessage="No story sales activity yet."
        />
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded border p-3 bg-white">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-xl font-semibold">{value}</div>
    </div>
  );
}
