import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    { data: overview },
    { data: topTemplates },
    { data: categoryBreakdown },
    { data: channelBreakdown },
    { data: engineerLeaderboard },
    { data: versionLog },
    { data: lowResponse },
  ] = await Promise.all([
    sb.rpc('r2294_template_overview'),
    sb.rpc('r2294_top_templates'),
    sb.rpc('r2294_category_breakdown'),
    sb.rpc('r2294_channel_breakdown'),
    sb.rpc('r2294_engineer_leaderboard'),
    sb.rpc('r2294_recent_version_log'),
    sb.rpc('r2294_low_response_templates'),
  ]);

  const kpi = (overview as any[])?.[0] ?? {};

  const topCols: Column<any>[] = [
    { key: 'template_title', header: 'Template', render: (r: any) => String(r.template_title ?? '') },
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'channel', header: 'Channel', render: (r: any) => String(r.channel ?? '') },
    { key: 'language', header: 'Lang', render: (r: any) => String(r.language ?? '') },
    { key: 'sends_30d', header: 'Sends 30d', render: (r: any) => String(r.sends_30d ?? '') },
    { key: 'response_rate_pct', header: 'Response %', render: (r: any) => r.response_rate_pct ?? '—' },
    { key: 'avg_response_minutes', header: 'Avg resp (min)', render: (r: any) => r.avg_response_minutes ?? '—' },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'template_count', header: 'Templates', render: (r: any) => String(r.template_count ?? '') },
    { key: 'sends_30d', header: 'Sends 30d', render: (r: any) => String(r.sends_30d ?? '') },
    { key: 'response_rate_pct', header: 'Response %', render: (r: any) => r.response_rate_pct ?? '—' },
  ];

  const chanCols: Column<any>[] = [
    { key: 'channel', header: 'Channel', render: (r: any) => String(r.channel ?? '') },
    { key: 'sends_30d', header: 'Sends 30d', render: (r: any) => String(r.sends_30d ?? '') },
    { key: 'response_rate_pct', header: 'Response %', render: (r: any) => r.response_rate_pct ?? '—' },
    { key: 'avg_response_minutes', header: 'Avg resp (min)', render: (r: any) => r.avg_response_minutes ?? '—' },
  ];

  const engCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'template_count', header: 'Templates', render: (r: any) => String(r.template_count ?? '') },
    { key: 'sends_30d', header: 'Sends 30d', render: (r: any) => String(r.sends_30d ?? '') },
    { key: 'response_rate_pct', header: 'Response %', render: (r: any) => r.response_rate_pct ?? '—' },
    { key: 'edited_rate_pct', header: 'Edited %', render: (r: any) => r.edited_rate_pct ?? '—' },
  ];

  const verCols: Column<any>[] = [
    { key: 'template_title', header: 'Template', render: (r: any) => String(r.template_title ?? '') },
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'current_version', header: 'v', render: (r: any) => String(r.current_version ?? '') },
    { key: 'updated_at', header: 'Updated', render: (r: any) => new Date(r.updated_at).toLocaleString() },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
  ];

  const lowCols: Column<any>[] = [
    { key: 'template_title', header: 'Template', render: (r: any) => String(r.template_title ?? '') },
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'channel', header: 'Channel', render: (r: any) => String(r.channel ?? '') },
    { key: 'sends_30d', header: 'Sends 30d', render: (r: any) => String(r.sends_30d ?? '') },
    { key: 'response_rate_pct', header: 'Response %', render: (r: any) => r.response_rate_pct ?? '—' },
  ];

  return (
    <main style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Comm Template Library</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Templates engineers use to talk to hospitals & clients — usage, response rate, version log.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12, marginBottom: 24 }}>
        <Kpi label="Total templates" value={kpi.total_templates ?? 0} />
        <Kpi label="Active" value={kpi.active_templates ?? 0} />
        <Kpi label="Sends 30d" value={kpi.total_sends_30d ?? 0} />
        <Kpi label="Response %" value={kpi.response_rate_pct ?? '—'} />
        <Kpi label="Avg resp (min)" value={kpi.avg_response_minutes ?? '—'} />
        <Kpi label="Edited before send %" value={kpi.edited_rate_pct ?? '—'} />
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '16px 0 8px' }}>Top templates (30d)</h2>
      <DataTable columns={topCols} rows={(topTemplates as any[]) ?? []} rowKey={(r: any, i: number) => String(r.template_id ?? i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>By category</h2>
      <DataTable columns={catCols} rows={(categoryBreakdown as any[]) ?? []} rowKey={(r: any, i: number) => String(r.category ?? i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>By channel</h2>
      <DataTable columns={chanCols} rows={(channelBreakdown as any[]) ?? []} rowKey={(r: any, i: number) => String(r.channel ?? i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Engineer leaderboard</h2>
      <DataTable columns={engCols} rows={(engineerLeaderboard as any[]) ?? []} rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Recent version log</h2>
      <DataTable columns={verCols} rows={(versionLog as any[]) ?? []} rowKey={(r: any, i: number) => String(r.template_id ?? i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Low-response templates (need rewrite, &gt;= 5 sends)</h2>
      <DataTable columns={lowCols} rows={(lowResponse as any[]) ?? []} rowKey={(r: any, i: number) => String(r.template_id ?? i)} />
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: any }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
