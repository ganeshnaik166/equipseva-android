import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMemoLibraryPage() {
  const sb = await getSupabaseServerClient();

  const [memosRes, categoriesRes, recentRes] = await Promise.all([
    sb.rpc('list_memos_r1878'),
    sb.rpc('top_categories_r1878'),
    sb.rpc('recent_published_r1878'),
  ]);

  const memos: any[] = Array.isArray(memosRes.data) ? memosRes.data : [];
  const categories: any[] = Array.isArray(categoriesRes.data) ? categoriesRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalMemos = memos.length;
  const publishedCount = memos.filter((m) => m.status === 'published').length;
  const draftCount = memos.filter((m) => m.status === 'draft').length;
  const underReviewCount = memos.filter((m) => m.status === 'under_review').length;

  const memoCols: Column<any>[] = [
    { key: 'memo_title', header: 'Title', render: (r: any) => <span className="font-medium">{r.memo_title ?? '—'}</span> },
    { key: 'memo_category', header: 'Category', render: (r: any) => <span className="capitalize">{r.memo_category ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="capitalize">{(r.status ?? '—').replace(/_/g, ' ')}</span> },
    { key: 'reading_time_minutes', header: 'Read (min)', render: (r: any) => <span>{r.reading_time_minutes ?? 0}</span> },
    { key: 'drafted_at', header: 'Drafted', render: (r: any) => <span>{r.drafted_at ? new Date(r.drafted_at).toLocaleDateString() : '—'}</span> },
    { key: 'published_at', header: 'Published', render: (r: any) => <span>{r.published_at ? new Date(r.published_at).toLocaleDateString() : '—'}</span> },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'memo_category', header: 'Category', render: (r: any) => <span className="capitalize font-medium">{r.memo_category ?? '—'}</span> },
    { key: 'memo_count', header: 'Total', render: (r: any) => <span>{r.memo_count ?? 0}</span> },
    { key: 'published_count', header: 'Published', render: (r: any) => <span>{r.published_count ?? 0}</span> },
    { key: 'avg_reading_time', header: 'Avg Read (min)', render: (r: any) => <span>{r.avg_reading_time ?? '—'}</span> },
  ];

  const recentCols: Column<any>[] = [
    { key: 'memo_title', header: 'Title', render: (r: any) => <span className="font-medium">{r.memo_title ?? '—'}</span> },
    { key: 'memo_category', header: 'Category', render: (r: any) => <span className="capitalize">{r.memo_category ?? '—'}</span> },
    { key: 'reading_time_minutes', header: 'Read (min)', render: (r: any) => <span>{r.reading_time_minutes ?? 0}</span> },
    { key: 'published_at', header: 'Published At', render: (r: any) => <span>{r.published_at ? new Date(r.published_at).toLocaleString() : '—'}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header className="space-y-2">
        <h1 className="text-3xl font-bold tracking-tight">Founder Memo Library</h1>
        <p className="text-sm text-muted-foreground">
          Bezos-style internal narrative memos — strategy, operations, people, process, customer & financial.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-muted-foreground">Total Memos</div>
          <div className="mt-1 text-2xl font-semibold">{totalMemos}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-muted-foreground">Published</div>
          <div className="mt-1 text-2xl font-semibold">{publishedCount}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-muted-foreground">Under Review</div>
          <div className="mt-1 text-2xl font-semibold">{underReviewCount}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-muted-foreground">Drafts</div>
          <div className="mt-1 text-2xl font-semibold">{draftCount}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">All Memos</h2>
        <p className="text-sm text-muted-foreground">
          Every six-pager in the library. Draft → Under Review → Published.
        </p>
        <DataTable
          rows={memos}
          columns={memoCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Categories Breakdown</h2>
        <p className="text-sm text-muted-foreground">
          Distribution across the six memo categories.
        </p>
        <DataTable
          rows={categories}
          columns={categoryCols}
          rowKey={(r: any, i: number) => String(r.memo_category ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Recently Published</h2>
        <p className="text-sm text-muted-foreground">
          Latest published memos — team-wide reading list.
        </p>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
