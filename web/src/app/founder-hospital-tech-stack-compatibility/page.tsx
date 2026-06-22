import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalTechStackCompatibilityPage() {
  const sb = await getSupabaseServerClient();

  const [systemsRes, blockedRes, recentRes] = await Promise.all([
    sb.rpc('list_systems_r1919'),
    sb.rpc('blocked_integrations_r1919'),
    sb.rpc('recent_integrations_r1919'),
  ]);

  const systems: any[] = Array.isArray(systemsRes.data) ? systemsRes.data : [];
  const blocked: any[] = Array.isArray(blockedRes.data) ? blockedRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const systemsColumns: Column<any>[] = [
    { key: 'system_name', header: 'System', render: (r: any) => String(r.system_name ?? '') },
    { key: 'system_category', header: 'Category', render: (r: any) => String(r.system_category ?? '').toUpperCase() },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '-') },
    { key: 'integration_status', header: 'Status', render: (r: any) => String(r.integration_status ?? '') },
    { key: 'compatibility_score', header: 'Score', render: (r: any) => String(r.compatibility_score ?? 0) },
    { key: 'last_assessed_at', header: 'Last Assessed', render: (r: any) => r.last_assessed_at ? new Date(r.last_assessed_at).toLocaleString() : '-' },
  ];

  const blockedColumns: Column<any>[] = [
    { key: 'system_name', header: 'System', render: (r: any) => String(r.system_name ?? '') },
    { key: 'system_category', header: 'Category', render: (r: any) => String(r.system_category ?? '').toUpperCase() },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '-') },
    { key: 'compatibility_score', header: 'Score', render: (r: any) => String(r.compatibility_score ?? 0) },
    { key: 'last_assessed_at', header: 'Last Assessed', render: (r: any) => r.last_assessed_at ? new Date(r.last_assessed_at).toLocaleString() : '-' },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'system_name', header: 'System', render: (r: any) => String(r.system_name ?? '-') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  const liveCount = systems.filter((s: any) => s.integration_status === 'live').length;
  const inProgressCount = systems.filter((s: any) => s.integration_status === 'in_progress').length;
  const blockedCount = blocked.length;

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Tech Stack Compatibility</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track which hospital tech systems we integrate with (HIS, LIS, PACS, EMR, billing, inventory) and where each integration stands.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Overview</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Systems Tracked</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{systems.length}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Live Integrations</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#16a34a' }}>{liveCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>In Progress</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#2563eb' }}>{inProgressCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Blocked</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#dc2626' }}>{blockedCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Tracked Systems</h2>
        <p style={{ color: '#666', fontSize: 14, marginBottom: 8 }}>
          Hospital tech systems and their current integration status. Score is from 0 to 100 and higher is better.
        </p>
        <DataTable rows={systems} columns={systemsColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Blocked Integrations</h2>
        <p style={{ color: '#666', fontSize: 14, marginBottom: 8 }}>
          Integrations currently blocked and needing founder attention.
        </p>
        <DataTable rows={blocked} columns={blockedColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Integration Activity</h2>
        <p style={{ color: '#666', fontSize: 14, marginBottom: 8 }}>
          Latest actions logged across all systems (kickoff, scoped, api test, go live, blocker resolved).
        </p>
        <DataTable rows={recent} columns={recentColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
