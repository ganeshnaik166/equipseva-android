import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlySelfReviewPage() {
  const sb = await getSupabaseServerClient();

  const [reviewsRes, recentReviewsRes, recentActionsRes] = await Promise.all([
    sb.rpc('r1998_list_reviews'),
    sb.rpc('r1998_recent_reviews'),
    sb.rpc('r1998_recent_actions'),
  ]);

  const reviews: any[] = Array.isArray(reviewsRes.data) ? reviewsRes.data : [];
  const recentReviews: any[] = Array.isArray(recentReviewsRes.data) ? recentReviewsRes.data : [];
  const recentActions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const totalReviews = reviews.length;
  const publishedCount = reviews.filter((r) => r.status === 'published').length;
  const draftCount = reviews.filter((r) => r.status === 'draft').length;
  const archivedCount = reviews.filter((r) => r.status === 'archived').length;
  const totalActions = recentActions.length;

  const reviewColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'year', header: 'Year', render: (r: any) => String(r.year ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    {
      key: 'recorded_at',
      header: 'Recorded',
      render: (r: any) => (r.recorded_at ? new Date(r.recorded_at).toLocaleString() : 'pending'),
    },
    {
      key: 'finalized_at',
      header: 'Finalized',
      render: (r: any) => (r.finalized_at ? new Date(r.finalized_at).toLocaleString() : 'not yet'),
    },
  ];

  const recentReviewColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'year', header: 'Year', render: (r: any) => String(r.year ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    {
      key: 'what_changed_md',
      header: 'What Changed',
      render: (r: any) => {
        const text = String(r.what_changed_md ?? '');
        return text.length > 80 ? text.slice(0, 80) + 'and more' : text || 'empty';
      },
    },
    {
      key: 'recorded_at',
      header: 'Recorded',
      render: (r: any) => (r.recorded_at ? new Date(r.recorded_at).toLocaleString() : 'pending'),
    },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? 'unknown') },
    {
      key: 'taken_at',
      header: 'Taken',
      render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : 'pending'),
    },
    {
      key: 'notes_md',
      header: 'Notes',
      render: (r: any) => {
        const text = String(r.notes_md ?? '');
        return text.length > 60 ? text.slice(0, 60) + 'and more' : text || 'none';
      },
    },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Founder Quarterly Self-Review
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Quarterly self-review log. Capture what changed, what to change, what to keep, and the key
        blocker. Track downstream actions taken on each review.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total reviews</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalReviews}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Published</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#16a34a' }}>{publishedCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Draft</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#f59e0b' }}>{draftCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Archived</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#6b7280' }}>{archivedCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Action log entries</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalActions}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Reviews</h2>
        <DataTable
          rows={reviews}
          columns={reviewColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Reviews</h2>
        <DataTable
          rows={recentReviews}
          columns={recentReviewColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Action Log</h2>
        <DataTable
          rows={recentActions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
