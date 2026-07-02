import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [storiesRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_stories_r2088'),
    sb.rpc('top_stories_r2088'),
    sb.rpc('recent_shares_r2088'),
  ]);

  const stories: any[] = Array.isArray(storiesRes.data) ? storiesRes.data : [];
  const tops: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recents: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const storyCols: Column<any>[] = [
    { key: 'story_title', header: 'Title', render: (r: any) => String(r.story_title ?? '') },
    { key: 'story_type', header: 'Type', render: (r: any) => String(r.story_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleDateString() : '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'story_type', header: 'Type', render: (r: any) => String(r.story_type ?? '') },
    { key: 'story_count', header: 'Stories', render: (r: any) => String(r.story_count ?? 0) },
    { key: 'published_count', header: 'Published', render: (r: any) => String(r.published_count ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'story_id', header: 'Story', render: (r: any) => String(r.story_id ?? '').slice(0, 8) },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Engineer Customer Story Capture</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Capture positive, exceptional, heroic, lifesaving, and award worthy customer stories about engineers.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Story rollup by type</h2>
        <DataTable rows={tops} columns={topCols} rowKey={(r: any, i: number) => String(r.story_type ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Captured stories</h2>
        <DataTable rows={stories} columns={storyCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent share actions</h2>
        <DataTable rows={recents} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
