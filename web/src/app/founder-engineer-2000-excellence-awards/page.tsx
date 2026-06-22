import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [awardsRes, actionsRes, byCatRes] = await Promise.all([
    sb.rpc('r2060_list_awards'),
    sb.rpc('r2060_recent_actions'),
    sb.rpc('r2060_by_category'),
  ]);

  const awards = (awardsRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const byCat = (byCatRes.data ?? []) as any[];

  const awardCols: Column<any>[] = [
    { key: 'award_label', header: 'Award', render: (r: any) => String(r.award_label ?? '') },
    { key: 'award_category', header: 'Category', render: (r: any) => String(r.award_category ?? '') },
    { key: 'award_year', header: 'Year', render: (r: any) => String(r.award_year ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleDateString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  const catCols: Column<any>[] = [
    { key: 'award_category', header: 'Category', render: (r: any) => String(r.award_category ?? '') },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? 0) },
    { key: 'awarded', header: 'Awarded', render: (r: any) => String(r.awarded ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer 2000-Series Excellence Awards</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Annual excellence awards spotlight engineers who set the bar across technical chops, customer love, teamwork, mentorship, innovation, safety, and dedication.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Awards roster</h2>
        <DataTable rows={awards} columns={awardCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Rollup by category</h2>
        <DataTable rows={byCat} columns={catCols} rowKey={(r: any, i: number) => String(r.award_category ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
