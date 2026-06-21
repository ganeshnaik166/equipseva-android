import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function inr(n: number | null | undefined): string {
  if (n == null) return '-';
  return 'Rs ' + Math.round(Number(n)).toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined): string {
  if (n == null) return '-';
  return Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try { return new Date(s).toLocaleDateString('en-IN'); } catch { return String(s); }
}

export default async function FounderYearEndReviewPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let wins: any[] = [];
  let losses: any[] = [];
  let lessons: any[] = [];
  let archive: any[] = [];
  let metrics: any[] = [];
  let activity: any[] = [];

  try {
    const r = await sb.rpc('rpc_year_end_overview');
    overview = (r.data ?? [])[0] ?? null;
  } catch { overview = null; }

  try {
    const r = await sb.rpc('rpc_year_end_top_wins');
    wins = (r.data ?? []) as any[];
  } catch { wins = []; }

  try {
    const r = await sb.rpc('rpc_year_end_top_losses');
    losses = (r.data ?? []) as any[];
  } catch { losses = []; }

  try {
    const r = await sb.rpc('rpc_year_end_lessons');
    lessons = (r.data ?? []) as any[];
  } catch { lessons = []; }

  try {
    const r = await sb.rpc('rpc_year_end_archive');
    archive = (r.data ?? []) as any[];
  } catch { archive = []; }

  try {
    const r = await sb.rpc('rpc_year_end_auto_metrics');
    metrics = (r.data ?? []) as any[];
  } catch { metrics = []; }

  try {
    const r = await sb.rpc('rpc_year_end_recent_activity');
    activity = (r.data ?? []) as any[];
  } catch { activity = []; }

  const metricMap: Record<string, number> = {};
  for (const m of metrics) { metricMap[String(m.metric_name)] = Number(m.metric_value ?? 0); }

  const kpis: Kpi[] = [
    { label: 'Fiscal Year', value: overview?.fiscal_year != null ? String(overview.fiscal_year) : '-' },
    { label: 'Status', value: String(overview?.status ?? '-') },
    { label: 'Essay Words', value: fmtNum(overview?.word_count) },
    { label: 'Wins Logged', value: fmtNum(overview?.wins_count) },
    { label: 'Losses Logged', value: fmtNum(overview?.losses_count) },
    { label: 'Lessons Logged', value: fmtNum(overview?.lessons_count) },
    { label: 'Total Entries', value: fmtNum(overview?.entries_count) },
    { label: 'Revenue YTD', value: inr(metricMap['revenue']) },
    { label: 'Jobs Closed YTD', value: fmtNum(metricMap['jobs_closed']) },
    { label: 'AMC Contracts YTD', value: fmtNum(metricMap['amc_contracts']) },
    { label: 'Avg Rating', value: metricMap['avg_rating'] ? metricMap['avg_rating'].toFixed(2) : '-' },
    { label: 'NPS (stored)', value: overview?.net_promoter_score != null ? String(overview.net_promoter_score) : '-' },
    { label: 'Published', value: fmtDate(overview?.published_at) },
    { label: 'Archived', value: fmtDate(overview?.archived_at) },
    { label: 'Archived Years', value: fmtNum(archive.length) },
    { label: 'Recent Actions', value: fmtNum(activity.length) },
  ];

  const winCols: Column<any>[] = [
    { key: 'rank', header: 'Rank', render: (r: any) => String(r.rank ?? '-') },
    { key: 'title', header: 'Win', render: (r: any) => String(r.title ?? '-') },
    { key: 'impact_score', header: 'Impact', render: (r: any) => String(r.impact_score ?? '-') },
    { key: 'tags', header: 'Tags', render: (r: any) => Array.isArray(r.tags) ? r.tags.join(', ') : '-' },
    { key: 'created_at', header: 'Logged', render: (r: any) => fmtDate(r.created_at) },
  ];

  const lossCols: Column<any>[] = [
    { key: 'rank', header: 'Rank', render: (r: any) => String(r.rank ?? '-') },
    { key: 'title', header: 'Loss', render: (r: any) => String(r.title ?? '-') },
    { key: 'impact_score', header: 'Impact', render: (r: any) => String(r.impact_score ?? '-') },
    { key: 'tags', header: 'Tags', render: (r: any) => Array.isArray(r.tags) ? r.tags.join(', ') : '-' },
    { key: 'created_at', header: 'Logged', render: (r: any) => fmtDate(r.created_at) },
  ];

  const lessonCols: Column<any>[] = [
    { key: 'rank', header: 'Rank', render: (r: any) => String(r.rank ?? '-') },
    { key: 'title', header: 'Lesson', render: (r: any) => String(r.title ?? '-') },
    { key: 'description', header: 'Detail', render: (r: any) => String(r.description ?? '-') },
    { key: 'impact_score', header: 'Impact', render: (r: any) => String(r.impact_score ?? '-') },
  ];

  const archiveCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'Year', render: (r: any) => String(r.fiscal_year ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'word_count', header: 'Words', render: (r: any) => fmtNum(r.word_count) },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => inr(r.total_revenue_rupees) },
    { key: 'total_jobs_closed', header: 'Jobs', render: (r: any) => fmtNum(r.total_jobs_closed) },
    { key: 'archived_at', header: 'Archived', render: (r: any) => fmtDate(r.archived_at) },
  ];

  const activityCols: Column<any>[] = [
    { key: 'op_name', header: 'Op', render: (r: any) => String(r.op_name ?? '-') },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '-') },
    { key: 'after_value', header: 'Payload', render: (r: any) => r.after_value ? JSON.stringify(r.after_value).slice(0, 80) : '-' },
    { key: 'created_at', header: 'When', render: (r: any) => fmtDate(r.created_at) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Founder Year-End Review</h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>
        Annual reflection: top 10 wins, top 10 losses, biggest lessons, founder essay. Archive for next year.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 28 }}>
        {kpis.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      {overview?.fiscal_year ? (
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, marginBottom: 28, background: '#fafafa' }}>
          <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', marginBottom: 8 }}>
            Founder Reflection — FY {String(overview.fiscal_year)}
          </div>
          <div style={{ fontSize: 13, color: '#374151', whiteSpace: 'pre-wrap' }}>
            {overview?.reflection_essay ? String(overview.reflection_essay) : 'Essay not yet authored.'}
          </div>
        </div>
      ) : null}

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top 10 Wins</h2>
        <DataTable rows={wins} columns={winCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top 10 Losses</h2>
        <DataTable rows={losses} columns={lossCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Biggest Lessons</h2>
        <DataTable rows={lessons} columns={lessonCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Archived Years</h2>
        <DataTable rows={archive} columns={archiveCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent Activity</h2>
        <DataTable rows={activity} columns={activityCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
