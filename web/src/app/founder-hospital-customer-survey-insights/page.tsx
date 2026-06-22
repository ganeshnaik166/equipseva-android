import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [insightsRes, negativeRes, actionsRes] = await Promise.all([
    sb.rpc('list_insights_r2191', { p_limit: 100 }),
    sb.rpc('negative_insights_r2191', { p_limit: 50 }),
    sb.rpc('recent_actions_r2191', { p_limit: 50 }),
  ]);

  const insights: any[] = (insightsRes.data as any[]) ?? [];
  const negative: any[] = (negativeRes.data as any[]) ?? [];
  const actions: any[] = (actionsRes.data as any[]) ?? [];

  const insightCols: Column<any>[] = [
    { key: 'survey_label', header: 'Survey', render: (r: any) => String(r.survey_label ?? '') },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => String(r.sentiment ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'insight_md', header: 'Insight', render: (r: any) => String(r.insight_md ?? '').slice(0, 140) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const negativeCols: Column<any>[] = [
    { key: 'survey_label', header: 'Survey', render: (r: any) => String(r.survey_label ?? '') },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => String(r.sentiment ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'insight_md', header: 'Insight', render: (r: any) => String(r.insight_md ?? '').slice(0, 200) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 160) },
    { key: 'insight_id', header: 'Insight', render: (r: any) => String(r.insight_id ?? '').slice(0, 8) },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  const totalNeg = negative.length;
  const totalOpen = insights.filter((i: any) => i.status !== 'closed').length;
  const totalActions = actions.length;

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Survey Insights</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Aggregate survey insights across hospitals. Track sentiment, log founder actions, and escalate negative feedback before it churns.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Negative open</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalNeg}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Insights open</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalOpen}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Recent actions</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalActions}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Negative open insights</h2>
        <DataTable rows={negative} columns={negativeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All insights (recent 100)</h2>
        <DataTable rows={insights} columns={insightCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent actions taken</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
