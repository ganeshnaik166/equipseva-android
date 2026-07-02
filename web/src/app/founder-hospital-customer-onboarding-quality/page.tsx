import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [qualitiesRes, poorRes, actionsRes] = await Promise.all([
    sb.rpc('list_qualities_r2151'),
    sb.rpc('poor_quality_r2151'),
    sb.rpc('recent_actions_r2151'),
  ]);

  const qualities: any[] = Array.isArray(qualitiesRes.data) ? qualitiesRes.data : [];
  const poor: any[] = Array.isArray(poorRes.data) ? poorRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const qualityCols: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'onboarding_score', header: 'Score', render: (r: any) => String(r.onboarding_score ?? '') },
    { key: 'total_blockers', header: 'Blockers', render: (r: any) => String(r.total_blockers ?? 0) },
    { key: 'days_to_full_activation', header: 'Days to activation', render: (r: any) => String(r.days_to_full_activation ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const poorCols: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'onboarding_score', header: 'Score', render: (r: any) => String(r.onboarding_score ?? '') },
    { key: 'total_blockers', header: 'Blockers', render: (r: any) => String(r.total_blockers ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'quality_id', header: 'Quality', render: (r: any) => String(r.quality_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Onboarding Quality</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Track quality of customer onboarding. Score range zero to one hundred. Status buckets excellent, good, needs work, poor, escalated.
      </p>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All onboarding quality records</h2>
        <DataTable rows={qualities} columns={qualityCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Poor and escalated quality</h2>
        <DataTable rows={poor} columns={poorCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
