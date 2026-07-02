import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderAnnualThemeTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [themesRes, currentRes, recentRes] = await Promise.all([
    sb.rpc('list_themes_r1974'),
    sb.rpc('current_theme_r1974'),
    sb.rpc('recent_progress_r1974'),
  ]);

  const themes: any[] = Array.isArray(themesRes.data) ? themesRes.data : [];
  const current: any[] = Array.isArray(currentRes.data) ? currentRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const themeCols: Column<any>[] = [
    { key: 'year', header: 'Year', render: (r: any) => String(r.year ?? '') },
    { key: 'theme_label', header: 'Theme', render: (r: any) => r.theme_label ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'theme_committed_at', header: 'Committed', render: (r: any) => r.theme_committed_at ? new Date(r.theme_committed_at).toLocaleDateString() : '' },
    { key: 'theme_completed_at', header: 'Completed', render: (r: any) => r.theme_completed_at ? new Date(r.theme_completed_at).toLocaleDateString() : '-' },
    { key: 'theme_md', header: 'Notes', render: (r: any) => (r.theme_md ?? '').slice(0, 80) },
  ];

  const currentCols: Column<any>[] = [
    { key: 'year', header: 'Year', render: (r: any) => String(r.year ?? '') },
    { key: 'theme_label', header: 'Theme', render: (r: any) => r.theme_label ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'theme_committed_at', header: 'Since', render: (r: any) => r.theme_committed_at ? new Date(r.theme_committed_at).toLocaleDateString() : '' },
    { key: 'theme_md', header: 'Description', render: (r: any) => (r.theme_md ?? '').slice(0, 120) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'logged_at', header: 'Logged', render: (r: any) => r.logged_at ? new Date(r.logged_at).toLocaleDateString() : '' },
    { key: 'theme_label', header: 'Theme', render: (r: any) => r.theme_label ?? '' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '' },
    { key: 'progress_score', header: 'Score', render: (r: any) => String(r.progress_score ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'progress_md', header: 'Notes', render: (r: any) => (r.progress_md ?? '').slice(0, 80) },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder Annual Theme Tracker</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Track annual themes (1 to 3 word phrases) that guide the year. Score quarterly progress at least 1 and up to 10.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Current active theme</h2>
        <DataTable
          rows={current}
          columns={currentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All themes</h2>
        <DataTable
          rows={themes}
          columns={themeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent quarterly progress</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
