import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [reviewsRes, upcomingRes, actionsRes] = await Promise.all([
    sb.rpc('list_reviews_r2123'),
    sb.rpc('upcoming_r2123'),
    sb.rpc('recent_actions_r2123'),
  ]);

  const reviews: any[] = Array.isArray(reviewsRes.data) ? reviewsRes.data : [];
  const upcoming: any[] = Array.isArray(upcomingRes.data) ? upcomingRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const reviewCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_id ?? '') },
    { key: 'review_year', header: 'Year', render: (r: any) => String(r.review_year ?? '') },
    { key: 'review_date', header: 'Review Date', render: (r: any) => String(r.review_date ?? '') },
    { key: 'satisfaction_score', header: 'Score', render: (r: any) => r.satisfaction_score == null ? '' : String(r.satisfaction_score) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'key_themes_md', header: 'Themes', render: (r: any) => String(r.key_themes_md ?? '').slice(0, 80) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_id ?? '') },
    { key: 'review_year', header: 'Year', render: (r: any) => String(r.review_year ?? '') },
    { key: 'review_date', header: 'Scheduled', render: (r: any) => String(r.review_date ?? '') },
    { key: 'days_until', header: 'Days Until', render: (r: any) => String(r.days_until ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
    { key: 'review_id', header: 'Review', render: (r: any) => String(r.review_id ?? '').slice(0, 8) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Annual Review Cycle</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Annual review cycle per hospital customer. Track satisfaction score, key themes, scheduled dates and action follow-ups.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Upcoming reviews</h2>
        <DataTable rows={upcoming} columns={upcomingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All review cycles</h2>
        <DataTable rows={reviews} columns={reviewCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
