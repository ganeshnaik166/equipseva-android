import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWeeklyReflectionLogPage() {
  const sb = await getSupabaseServerClient();

  const [reflectionsRes, threadsRes, recentRes, trendRes] = await Promise.all([
    sb.rpc('list_reflections_r1910'),
    sb.rpc('list_threads_r1910', { p_reflection_id: null }),
    sb.rpc('recent_reflections_r1910'),
    sb.rpc('energy_trend_r1910'),
  ]);

  const reflections: any[] = (reflectionsRes.data as any[]) ?? [];
  const threads: any[] = (threadsRes.data as any[]) ?? [];
  const recent: any[] = (recentRes.data as any[]) ?? [];
  const trend: any[] = (trendRes.data as any[]) ?? [];

  const totalReflections = reflections.length;
  const publishedCount = reflections.filter((r) => r.status === 'published').length;
  const draftCount = reflections.filter((r) => r.status === 'draft').length;
  const avgEnergy =
    trend.length > 0
      ? (trend.reduce((acc, t) => acc + (Number(t.energy_score) || 0), 0) / trend.length).toFixed(1)
      : '0.0';

  const reflectionColumns: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r: any) => String(r.week_start ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'energy_score', header: 'Energy', render: (r: any) => String(r.energy_score ?? '') },
    {
      key: 'what_worked_md',
      header: 'What Worked',
      render: (r: any) => String(r.what_worked_md ?? '').slice(0, 80),
    },
    {
      key: 'what_did_not_md',
      header: 'What Did Not',
      render: (r: any) => String(r.what_did_not_md ?? '').slice(0, 80),
    },
    {
      key: 'key_learning_md',
      header: 'Key Learning',
      render: (r: any) => String(r.key_learning_md ?? '').slice(0, 80),
    },
    { key: 'thread_count', header: 'Threads', render: (r: any) => String(r.thread_count ?? 0) },
    {
      key: 'written_at',
      header: 'Written',
      render: (r: any) => (r.written_at ? new Date(r.written_at).toLocaleDateString() : ''),
    },
    {
      key: 'published_at',
      header: 'Published',
      render: (r: any) => (r.published_at ? new Date(r.published_at).toLocaleDateString() : '—'),
    },
  ];

  const threadColumns: Column<any>[] = [
    { key: 'thread_type', header: 'Type', render: (r: any) => String(r.thread_type ?? '') },
    {
      key: 'thread_md',
      header: 'Thread',
      render: (r: any) => String(r.thread_md ?? '').slice(0, 120),
    },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    {
      key: 'recorded_at',
      header: 'Recorded',
      render: (r: any) => (r.recorded_at ? new Date(r.recorded_at).toLocaleString() : ''),
    },
    {
      key: 'reflection_id',
      header: 'Reflection',
      render: (r: any) => String(r.reflection_id ?? '').slice(0, 8),
    },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'energy_score', header: 'Energy', render: (r: any) => String(r.energy_score ?? '') },
    {
      key: 'written_at',
      header: 'Written',
      render: (r: any) => (r.written_at ? new Date(r.written_at).toLocaleString() : ''),
    },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'energy_score', header: 'Energy', render: (r: any) => String(r.energy_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
          Founder Weekly Reflection Log
        </h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          Weekly founder reflections — what worked, what did not, key learnings & energy
          trend across the last 26 weeks.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: '12px',
          marginBottom: '32px',
        }}
      >
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total Reflections</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalReflections}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Published</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{publishedCount}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Drafts</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{draftCount}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Avg Energy (26w)</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{avgEnergy}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>
          All Reflections
        </h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Up to 100 most recent weekly reflections sorted by week start.
        </p>
        <DataTable
          rows={reflections}
          columns={reflectionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>
          Reflection Threads
        </h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Follow-ups, incidents, decisions & celebrations attached to reflections.
        </p>
        <DataTable
          rows={threads}
          columns={threadColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>
          Recent (last 90 days)
        </h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Reflections written in the last 90 days.
        </p>
        <DataTable
          rows={recent}
          columns={recentColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '8px' }}>
          Energy Trend (26 weeks)
        </h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Founder energy score per week. Useful when energy stays at or above seven for several
          weeks running.
        </p>
        <DataTable
          rows={trend}
          columns={trendColumns}
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>
    </main>
  );
}
