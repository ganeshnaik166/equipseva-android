import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [photosRes, marketingRes, actionsRes] = await Promise.all([
    sb.rpc('list_photos_r2164'),
    sb.rpc('marketing_approved_r2164'),
    sb.rpc('recent_actions_r2164'),
  ]);

  const photos = (photosRes.data ?? []) as any[];
  const marketing = (marketingRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];

  const photoCols: Column<any>[] = [
    { key: 'visit_date', header: 'Visit Date', render: (r: any) => String(r.visit_date ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'photo_purpose', header: 'Purpose', render: (r: any) => String(r.photo_purpose ?? '').replace(/_/g, ' ') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '').replace(/_/g, ' ') },
    { key: 'photo_url', header: 'URL', render: (r: any) => String(r.photo_url ?? '').slice(0, 40) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const marketingCols: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'photo_purpose', header: 'Purpose', render: (r: any) => String(r.photo_purpose ?? '').replace(/_/g, ' ') },
    { key: 'photo_url', header: 'URL', render: (r: any) => String(r.photo_url ?? '').slice(0, 40) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'photo_id', header: 'Photo', render: (r: any) => String(r.photo_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '').replace(/_/g, ' ') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 60) },
  ];

  return (
    <div style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>Engineer Customer Visit Photo Log</h1>
      <p style={{ color: '#666', marginBottom: '1.5rem' }}>
        Photo log of engineer customer visits. Tracks repair before and after shots, site documentation, team photos, and customer thank-you snaps for marketing review.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>All Photos</h2>
        <p style={{ color: '#888', marginBottom: '0.5rem', fontSize: '0.875rem' }}>Latest 200 captured photos across all engineers and hospitals.</p>
        <DataTable rows={photos} columns={photoCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Marketing Approved</h2>
        <p style={{ color: '#888', marginBottom: '0.5rem', fontSize: '0.875rem' }}>Photos cleared for marketing use, ready for collateral.</p>
        <DataTable rows={marketing} columns={marketingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Recent Actions</h2>
        <p style={{ color: '#888', marginBottom: '0.5rem', fontSize: '0.875rem' }}>Most recent approvals, restrictions, deletions, and escalations.</p>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
