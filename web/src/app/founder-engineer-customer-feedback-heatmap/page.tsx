import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [feedbackRes, topRes, monthRes, actionsRes] = await Promise.all([
    sb.rpc('list_feedback_r2205'),
    sb.rpc('top_engineers_r2205'),
    sb.rpc('aggregate_or_search_r2205'),
    sb.rpc('recent_actions_r2205'),
  ]);

  const feedback: any[] = Array.isArray(feedbackRes.data) ? feedbackRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const months: any[] = Array.isArray(monthRes.data) ? monthRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const totalFeedback = feedback.length;
  const ratingEntries = feedback.filter((f) => f.feedback_type === 'rating' && f.rating_value);
  const avgRating =
    ratingEntries.length > 0
      ? (
          ratingEntries.reduce((s, f) => s + Number(f.rating_value || 0), 0) /
          ratingEntries.length
        ).toFixed(2)
      : '—';
  const complaints = feedback.filter((f) => f.feedback_type === 'complaint').length;
  const compliments = feedback.filter((f) => f.feedback_type === 'compliment').length;
  const coachingFlagged = feedback.filter((f) => f.coaching_flag === true).length;

  const feedbackCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => String(r.engineer_name ?? '') },
    { key: 'engineer_city', header: 'City', render: (r: any) => String(r.engineer_city ?? '—') },
    { key: 'month_bucket', header: 'Month', render: (r: any) => String(r.month_bucket ?? '') },
    { key: 'feedback_type', header: 'Type', render: (r: any) => String(r.feedback_type ?? '') },
    {
      key: 'rating_value',
      header: 'Rating',
      render: (r: any) => (r.rating_value ? String(r.rating_value) + ' / 5' : '—'),
    },
    { key: 'customer_org', header: 'Customer', render: (r: any) => String(r.customer_org ?? '—') },
    { key: 'job_kind', header: 'Job kind', render: (r: any) => String(r.job_kind ?? '—') },
    {
      key: 'feedback_summary',
      header: 'Summary',
      render: (r: any) => String(r.feedback_summary ?? '').slice(0, 80),
    },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? 'normal') },
    {
      key: 'coaching_flag',
      header: 'Coach?',
      render: (r: any) => (r.coaching_flag ? 'yes' : 'no'),
    },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => String(r.engineer_name ?? '') },
    {
      key: 'total_feedback',
      header: 'Total',
      render: (r: any) => String(r.total_feedback ?? 0),
    },
    {
      key: 'avg_rating',
      header: 'Avg rating',
      render: (r: any) => (r.avg_rating != null ? String(r.avg_rating) : '—'),
    },
    {
      key: 'complaint_count',
      header: 'Complaints',
      render: (r: any) => String(r.complaint_count ?? 0),
    },
    {
      key: 'compliment_count',
      header: 'Compliments',
      render: (r: any) => String(r.compliment_count ?? 0),
    },
    {
      key: 'coaching_flagged',
      header: 'Coach flagged',
      render: (r: any) => String(r.coaching_flagged ?? 0),
    },
  ];

  const monthCols: Column<any>[] = [
    { key: 'month_bucket', header: 'Month', render: (r: any) => String(r.month_bucket ?? '') },
    {
      key: 'total_feedback',
      header: 'Total',
      render: (r: any) => String(r.total_feedback ?? 0),
    },
    {
      key: 'avg_rating',
      header: 'Avg rating',
      render: (r: any) => (r.avg_rating != null ? String(r.avg_rating) : '—'),
    },
    { key: 'complaints', header: 'Complaints', render: (r: any) => String(r.complaints ?? 0) },
    { key: 'compliments', header: 'Compliments', render: (r: any) => String(r.compliments ?? 0) },
    {
      key: 'coaching_flagged',
      header: 'Coach flagged',
      render: (r: any) => String(r.coaching_flagged ?? 0),
    },
    {
      key: 'severe_count',
      header: 'Severe',
      render: (r: any) => String(r.severe_count ?? 0),
    },
  ];

  const actionCols: Column<any>[] = [
    { key: 'op_name', header: 'Op', render: (r: any) => String(r.op_name ?? '') },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    {
      key: 'after_value',
      header: 'Payload',
      render: (r: any) => JSON.stringify(r.after_value ?? {}).slice(0, 100),
    },
    { key: 'created_at', header: 'At', render: (r: any) => String(r.created_at ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer customer feedback heatmap
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-engineer aggregated customer ratings & complaints & compliments by month.
        Surface coaching opportunities where rating drops or complaint rate spikes.
      </p>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(4, 1fr)',
          gap: 12,
          marginBottom: 24,
        }}
      >
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total feedback</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalFeedback}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg rating</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{avgRating}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Complaints</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#c00' }}>{complaints}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Coach flagged</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#b86b00' }}>{coachingFlagged}</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Top engineers — complaint & rating leaderboard
        </h2>
        <DataTable columns={topCols} rows={top} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Month-by-month heat — complaints & severe entries
        </h2>
        <DataTable columns={monthCols} rows={months} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Recent feedback (last 200) — {compliments} compliments
        </h2>
        <DataTable columns={feedbackCols} rows={feedback} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent founder actions</h2>
        <DataTable columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
