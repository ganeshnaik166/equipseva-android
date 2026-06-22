import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpisRes, latestRes, trendRes, byRoleRes, themeRes, recentRes, flagsRes] = await Promise.all([
    sb.rpc('founder_tep_kpis_r2241'),
    sb.rpc('founder_tep_latest_week_r2241'),
    sb.rpc('founder_tep_trend_r2241'),
    sb.rpc('founder_tep_by_role_r2241'),
    sb.rpc('founder_tep_theme_sentiment_r2241'),
    sb.rpc('founder_tep_recent_responses_r2241'),
    sb.rpc('founder_tep_negative_flags_r2241'),
  ]);

  const kpis: any = (kpisRes.data && kpisRes.data[0]) || {};
  const latest: any = (latestRes.data && latestRes.data[0]) || {};
  const trend: any[] = trendRes.data || [];
  const byRole: any[] = byRoleRes.data || [];
  const themes: any[] = themeRes.data || [];
  const recent: any[] = recentRes.data || [];
  const flags: any[] = flagsRes.data || [];

  const trendCols: Column<any>[] = [
    { key: 'week_start_date', header: 'Week', render: (r: any) => String(r.week_start_date ?? '') },
    { key: 'responses', header: 'Responses', render: (r: any) => String(r.responses ?? 0) },
    { key: 'avg_energy', header: 'Avg energy', render: (r: any) => String(r.avg_energy ?? '') },
    { key: 'avg_satisfaction', header: 'Avg satisfaction', render: (r: any) => String(r.avg_satisfaction ?? '') },
  ];

  const roleCols: Column<any>[] = [
    { key: 'respondent_role', header: 'Role', render: (r: any) => String(r.respondent_role ?? '') },
    { key: 'responses', header: 'Responses', render: (r: any) => String(r.responses ?? 0) },
    { key: 'avg_energy', header: 'Avg energy', render: (r: any) => String(r.avg_energy ?? '') },
    { key: 'avg_satisfaction', header: 'Avg satisfaction', render: (r: any) => String(r.avg_satisfaction ?? '') },
    { key: 'avg_workload', header: 'Avg workload', render: (r: any) => String(r.avg_workload ?? '') },
  ];

  const themeCols: Column<any>[] = [
    { key: 'theme', header: 'Theme', render: (r: any) => String(r.theme ?? '') },
    { key: 'total_mentions', header: 'Mentions', render: (r: any) => String(r.total_mentions ?? 0) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => String(r.positive_count ?? 0) },
    { key: 'neutral_count', header: 'Neutral', render: (r: any) => String(r.neutral_count ?? 0) },
    { key: 'negative_count', header: 'Negative', render: (r: any) => String(r.negative_count ?? 0) },
    { key: 'net_score', header: 'Net score', render: (r: any) => String(r.net_score ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => String(r.submitted_at ?? '').slice(0, 16).replace('T', ' ') },
    { key: 'respondent_role', header: 'Role', render: (r: any) => String(r.respondent_role ?? '') },
    { key: 'week_start_date', header: 'Week', render: (r: any) => String(r.week_start_date ?? '') },
    { key: 'energy_score', header: 'Energy', render: (r: any) => String(r.energy_score ?? '') },
    { key: 'satisfaction_score', header: 'Satisfaction', render: (r: any) => String(r.satisfaction_score ?? '') },
    { key: 'is_anonymous', header: 'Anon', render: (r: any) => (r.is_anonymous ? 'yes' : 'no') },
    { key: 'free_text_comment', header: 'Comment', render: (r: any) => String(r.free_text_comment ?? '').slice(0, 80) },
  ];

  const flagCols: Column<any>[] = [
    { key: 'theme', header: 'Theme', render: (r: any) => String(r.theme ?? '') },
    { key: 'recent_negative_count', header: 'Negative (2w)', render: (r: any) => String(r.recent_negative_count ?? 0) },
    { key: 'total_recent_mentions', header: 'Total (2w)', render: (r: any) => String(r.total_recent_mentions ?? 0) },
    { key: 'pct_negative', header: 'Pct negative', render: (r: any) => String(r.pct_negative ?? '') },
    { key: 'latest_note', header: 'Latest note', render: (r: any) => String(r.latest_note ?? '').slice(0, 80) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>Team energy pulse</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Weekly team energy and satisfaction surveys across roles. Tracks workload, recognition, growth and manager themes
        so morale dips surface early — before attrition hits.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total surveys</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{String(kpis.total_surveys ?? 0)}</div>
        </div>
        <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Last 4 weeks</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{String(kpis.surveys_last_4w ?? 0)}</div>
        </div>
        <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Unique respondents</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{String(kpis.unique_respondents ?? 0)}</div>
        </div>
        <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Avg energy 4w</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{String(kpis.avg_energy_4w ?? 0)}</div>
        </div>
        <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Avg satisfaction 4w</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{String(kpis.avg_satisfaction_4w ?? 0)}</div>
        </div>
        <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Pct anonymous</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{String(kpis.pct_anonymous ?? 0)}%</div>
        </div>
        <div style={{ padding: '14px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Themes tracked</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{String(kpis.themes_tracked ?? 0)}</div>
        </div>
      </div>

      <section style={{ marginBottom: '24px', padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px', background: '#f9fafb' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '12px' }}>Latest week snapshot</h2>
        {latest.week_start_date ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '10px' }}>
            <div><div style={{ fontSize: '11px', color: '#666' }}>Week start</div><div style={{ fontWeight: 600 }}>{String(latest.week_start_date)}</div></div>
            <div><div style={{ fontSize: '11px', color: '#666' }}>Responses</div><div style={{ fontWeight: 600 }}>{String(latest.responses ?? 0)}</div></div>
            <div><div style={{ fontSize: '11px', color: '#666' }}>Energy</div><div style={{ fontWeight: 600 }}>{String(latest.avg_energy ?? '')}</div></div>
            <div><div style={{ fontSize: '11px', color: '#666' }}>Satisfaction</div><div style={{ fontWeight: 600 }}>{String(latest.avg_satisfaction ?? '')}</div></div>
            <div><div style={{ fontSize: '11px', color: '#666' }}>Workload</div><div style={{ fontWeight: 600 }}>{String(latest.avg_workload ?? '')}</div></div>
            <div><div style={{ fontSize: '11px', color: '#666' }}>Recognition</div><div style={{ fontWeight: 600 }}>{String(latest.avg_recognition ?? '')}</div></div>
            <div><div style={{ fontSize: '11px', color: '#666' }}>Growth</div><div style={{ fontWeight: 600 }}>{String(latest.avg_growth ?? '')}</div></div>
            <div><div style={{ fontSize: '11px', color: '#666' }}>Manager</div><div style={{ fontWeight: 600 }}>{String(latest.avg_manager ?? '')}</div></div>
          </div>
        ) : (
          <div style={{ color: '#666' }}>No survey data yet.</div>
        )}
      </section>

      <section style={{ marginBottom: '24px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>Negative theme flags (last 2 weeks)</h2>
        <p style={{ fontSize: '12px', color: '#666', marginBottom: '8px' }}>
          Themes with 2 or more negative mentions in the last fortnight. Address before they compound.
        </p>
        <DataTable columns={flagCols} rows={flags} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '24px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>12-week trend</h2>
        <DataTable columns={trendCols} rows={trend} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '24px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>By role (latest week)</h2>
        <DataTable columns={roleCols} rows={byRole} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '24px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>Theme sentiment (last 4 weeks)</h2>
        <DataTable columns={themeCols} rows={themes} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '24px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>Recent responses</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
