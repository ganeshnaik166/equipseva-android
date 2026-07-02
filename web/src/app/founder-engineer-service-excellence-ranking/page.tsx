import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerServiceExcellenceRankingPage() {
  const sb = await getSupabaseServerClient();

  const { data: rankings } = await sb.rpc('list_rankings_r2112');
  const { data: top } = await sb.rpc('top_ranked_r2112');
  const { data: recent } = await sb.rpc('recent_actions_r2112');

  const rankingsRows: any[] = Array.isArray(rankings) ? rankings : [];
  const topRows: any[] = Array.isArray(top) ? top : [];
  const recentRows: any[] = Array.isArray(recent) ? recent : [];

  const rankingCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'excellence_score', header: 'Score', render: (r: any) => String(r.excellence_score ?? '') },
    { key: 'percentile', header: 'Percentile', render: (r: any) => String(r.percentile ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'excellence_score', header: 'Score', render: (r: any) => String(r.excellence_score ?? '') },
    { key: 'percentile', header: 'Percentile', render: (r: any) => String(r.percentile ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Service Excellence Ranking</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track engineer excellence scores, percentile rank, and founder actions taken on rising and at-risk performers.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Rankings</h2>
        <DataTable rows={rankingsRows} columns={rankingCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Ranked Engineers</h2>
        <DataTable rows={topRows} columns={topCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Founder Actions</h2>
        <DataTable rows={recentRows} columns={actionCols} rowKey={(r: any, i: number) => String(r?.id ?? i)} />
      </section>
    </div>
  );
}
