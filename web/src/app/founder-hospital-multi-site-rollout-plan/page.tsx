import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [rolloutsRes, behindRes, recentSitesRes] = await Promise.all([
    sb.rpc('list_rollouts_r1927'),
    sb.rpc('rollouts_behind_schedule_r1927'),
    sb.rpc('recent_sites_r1927'),
  ]);

  const rollouts: any[] = Array.isArray(rolloutsRes.data) ? rolloutsRes.data : [];
  const behind: any[] = Array.isArray(behindRes.data) ? behindRes.data : [];
  const recentSites: any[] = Array.isArray(recentSitesRes.data) ? recentSitesRes.data : [];

  const totalRollouts = rollouts.length;
  const liveRollouts = rollouts.filter((r) => r.status === 'live').length;
  const blockedRollouts = rollouts.filter((r) => r.status === 'blocked').length;
  const totalSitesPlanned = rollouts.reduce((a, r) => a + (Number(r.site_count) || 0), 0);
  const totalSitesLive = rollouts.reduce((a, r) => a + (Number(r.sites_live_count) || 0), 0);

  const rolloutCols: Column<any>[] = [
    { key: 'id', header: 'Rollout', render: (r: any) => String(r.id || '').slice(0, 8) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id || '').slice(0, 8) },
    { key: 'site_count', header: 'Sites planned', render: (r: any) => String(r.site_count ?? 0) },
    { key: 'sites_live_count', header: 'Sites live', render: (r: any) => String(r.sites_live_count ?? 0) },
    { key: 'target_completion_date', header: 'Target', render: (r: any) => r.target_completion_date ? String(r.target_completion_date) : '-' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status || '') },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleDateString() : '-' },
  ];

  const behindCols: Column<any>[] = [
    { key: 'id', header: 'Rollout', render: (r: any) => String(r.id || '').slice(0, 8) },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id || '').slice(0, 8) },
    { key: 'site_count', header: 'Planned', render: (r: any) => String(r.site_count ?? 0) },
    { key: 'sites_live_count', header: 'Live', render: (r: any) => String(r.sites_live_count ?? 0) },
    { key: 'target_completion_date', header: 'Target', render: (r: any) => r.target_completion_date ? String(r.target_completion_date) : '-' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status || '') },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => String(r.days_overdue ?? 0) },
  ];

  const siteCols: Column<any>[] = [
    { key: 'id', header: 'Site log', render: (r: any) => String(r.id || '').slice(0, 8) },
    { key: 'rollout_id', header: 'Rollout', render: (r: any) => String(r.rollout_id || '').slice(0, 8) },
    { key: 'site_name', header: 'Site name', render: (r: any) => String(r.site_name || '') },
    { key: 'site_status', header: 'Status', render: (r: any) => String(r.site_status || '') },
    { key: 'went_live_at', header: 'Went live', render: (r: any) => r.went_live_at ? new Date(r.went_live_at).toLocaleString() : '-' },
    { key: 'by_email', header: 'Logged by', render: (r: any) => String(r.by_email || '-') },
    { key: 'created_at', header: 'Logged', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '-' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Hospital Multi-Site Roll-Out Plan
      </h1>
      <p style={{ color: '#666', marginBottom: '1.5rem' }}>
        Track multi-site rollouts at large hospital groups. Monitor sites planned vs live, status, and rollouts behind schedule.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '1rem' }}>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.875rem', color: '#666' }}>Total rollouts</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{totalRollouts}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.875rem', color: '#666' }}>Live rollouts</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{liveRollouts}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.875rem', color: '#666' }}>Blocked</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{blockedRollouts}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.875rem', color: '#666' }}>Sites planned</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{totalSitesPlanned}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.875rem', color: '#666' }}>Sites live</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{totalSitesLive}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>All rollouts</h2>
        <DataTable rows={rollouts} columns={rolloutCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Rollouts behind schedule</h2>
        <p style={{ color: '#666', fontSize: '0.875rem', marginBottom: '0.5rem' }}>
          Target date past, status not live or paused.
        </p>
        <DataTable rows={behind} columns={behindCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Recent site log entries</h2>
        <DataTable rows={recentSites} columns={siteCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
