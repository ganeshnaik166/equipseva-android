import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [voicesRes, topStylesRes, needUpdateRes, recentRes] = await Promise.all([
    sb.rpc('list_voices_r1891'),
    sb.rpc('top_styles_r1891'),
    sb.rpc('hospitals_needing_update_r1891'),
    sb.rpc('recent_changes_r1891'),
  ]);

  const voices: any[] = Array.isArray(voicesRes.data) ? voicesRes.data : [];
  const topStyles: any[] = Array.isArray(topStylesRes.data) ? topStylesRes.data : [];
  const needUpdate: any[] = Array.isArray(needUpdateRes.data) ? needUpdateRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const voiceCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_user_id ?? '') },
    { key: 'voice_style', header: 'Style', render: (r: any) => String(r.voice_style ?? '') },
    { key: 'preferred_topics', header: 'Prefer', render: (r: any) => Array.isArray(r.preferred_topics) ? r.preferred_topics.join(', ') : '' },
    { key: 'avoid_topics', header: 'Avoid', render: (r: any) => Array.isArray(r.avoid_topics) ? r.avoid_topics.join(', ') : '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_updated_at', header: 'Updated', render: (r: any) => r.last_updated_at ? new Date(r.last_updated_at).toLocaleString() : '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'voice_style', header: 'Style', render: (r: any) => String(r.voice_style ?? '') },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => String(r.hospital_count ?? 0) },
  ];

  const needCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_user_id ?? '') },
    { key: 'voice_style', header: 'Style', render: (r: any) => String(r.voice_style ?? '') },
    { key: 'days_stale', header: 'Days stale (>90)', render: (r: any) => String(r.days_stale ?? 0) },
    { key: 'last_updated_at', header: 'Last updated', render: (r: any) => r.last_updated_at ? new Date(r.last_updated_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '') },
    { key: 'old_style', header: 'Old', render: (r: any) => String(r.old_style ?? '') },
    { key: 'new_style', header: 'New', render: (r: any) => String(r.new_style ?? '') },
    { key: 'change_reason', header: 'Reason', render: (r: any) => String(r.change_reason ?? '') },
    { key: 'changed_at', header: 'When', render: (r: any) => r.changed_at ? new Date(r.changed_at).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Brand-Voice Library</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Per-hospital voice &amp; communication style for tailored outreach. Styles: formal &lt;&gt; casual &lt;&gt; medical &lt;&gt; peer &lt;&gt; founder.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top styles in use</h2>
        <DataTable rows={topStyles} columns={topCols} rowKey={(r: any, i: number) => String(r.voice_style ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All voice profiles</h2>
        <DataTable rows={voices} columns={voiceCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Hospitals needing update (stale &gt; 90d)</h2>
        <DataTable rows={needUpdate} columns={needCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent style changes</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
