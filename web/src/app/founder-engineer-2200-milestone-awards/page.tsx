import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [awards, actions, recentAwards, recentActions] = await Promise.all([
    sb.rpc('list_awards_r2180'),
    sb.rpc('list_actions_r2180'),
    sb.rpc('recent_awards_r2180'),
    sb.rpc('recent_actions_r2180'),
  ]);

  const awardCols: Column<any>[] = [
    { key: 'award_label', header: 'Label', render: (r: any) => String(r.award_label ?? '') },
    { key: 'award_category', header: 'Category', render: (r: any) => String(r.award_category ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'awarded_at', header: 'Awarded', render: (r: any) => r.awarded_at ? new Date(r.awarded_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'award_id', header: 'Award', render: (r: any) => String(r.award_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  const recentAwardCols: Column<any>[] = [
    { key: 'award_label', header: 'Label', render: (r: any) => String(r.award_label ?? '') },
    { key: 'award_category', header: 'Category', render: (r: any) => String(r.award_category ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'awarded_at', header: 'Awarded', render: (r: any) => r.awarded_at ? new Date(r.awarded_at).toLocaleString() : '' },
  ];

  const recentActionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'award_id', header: 'Award', render: (r: any) => String(r.award_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer 2200-Series Milestone Awards</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track milestone awards across the engineer corps — tenure, certification, customer champion and safety leader recognition.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Awards</h2>
        <DataTable rows={awards.data ?? []} columns={awardCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Action Log</h2>
        <DataTable rows={actions.data ?? []} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Awards (90 days)</h2>
        <DataTable rows={recentAwards.data ?? []} columns={recentAwardCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions (90 days)</h2>
        <DataTable rows={recentActions.data ?? []} columns={recentActionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
