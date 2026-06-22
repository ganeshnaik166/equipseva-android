import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerAnnualReviewCyclePage() {
  const sb = await getSupabaseServerClient();

  const [reviewsRes, reviewersRes, actionsRes] = await Promise.all([
    sb.rpc('list_reviews_r1956'),
    sb.rpc('top_reviewers_r1956'),
    sb.rpc('recent_actions_r1956'),
  ]);

  const reviews: any[] = Array.isArray(reviewsRes.data) ? reviewsRes.data : [];
  const reviewers: any[] = Array.isArray(reviewersRes.data) ? reviewersRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const reviewCols: Column<any>[] = [
    { key: 'review_year', header: 'Year', render: (r: any) => String(r.review_year ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'overall_score', header: 'Overall', render: (r: any) => r.overall_score != null ? String(r.overall_score) : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => r.reviewer_email ?? '-' },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleDateString() : '-' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleDateString() : '-' },
  ];

  const reviewerCols: Column<any>[] = [
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => r.reviewer_email ?? '-' },
    { key: 'review_count', header: 'Reviews', render: (r: any) => String(r.review_count ?? 0) },
    { key: 'avg_overall', header: 'Avg Score', render: (r: any) => r.avg_overall != null ? String(r.avg_overall) : '-' },
    { key: 'completed_count', header: 'Completed', render: (r: any) => String(r.completed_count ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '-' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Annual Review Cycle</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track annual performance reviews across technical, customer, teamwork and leadership dimensions. Log actions taken including promotions, raises, training, coaching and exits.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Reviews</h2>
        <DataTable rows={reviews} columns={reviewCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Reviewers</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>Reviewers ranked by review count. Avg score across all assigned reviews.</p>
        <DataTable rows={reviewers} columns={reviewerCols} rowKey={(r: any, i: number) => String(r.reviewer_email ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions Taken</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>Latest review-driven decisions across the engineering org.</p>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
