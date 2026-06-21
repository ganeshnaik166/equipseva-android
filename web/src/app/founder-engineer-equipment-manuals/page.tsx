import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [manualsRes, accessRes, mostRes, byLangRes] = await Promise.all([
    sb.rpc('list_manuals_r1816'),
    sb.rpc('list_access_r1816'),
    sb.rpc('most_accessed_manuals_r1816'),
    sb.rpc('manuals_by_language_r1816'),
  ]);

  const manuals: any[] = Array.isArray(manualsRes.data) ? manualsRes.data : [];
  const access: any[] = Array.isArray(accessRes.data) ? accessRes.data : [];
  const most: any[] = Array.isArray(mostRes.data) ? mostRes.data : [];
  const byLang: any[] = Array.isArray(byLangRes.data) ? byLangRes.data : [];

  const totalManuals = manuals.length;
  const currentCount = manuals.filter((m) => m.status === 'current').length;
  const supersededCount = manuals.filter((m) => m.status === 'superseded').length;
  const reviewCount = manuals.filter((m) => m.status === 'under_review').length;
  const totalAccesses = access.length;

  const manualCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'manufacturer', header: 'Manufacturer', render: (r: any) => String(r.manufacturer ?? '') },
    { key: 'model_number', header: 'Model', render: (r: any) => String(r.model_number ?? '') },
    { key: 'version_number', header: 'Version', render: (r: any) => String(r.version_number ?? '') },
    { key: 'language', header: 'Language', render: (r: any) => String(r.language ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_updated_at', header: 'Updated', render: (r: any) => r.last_updated_at ? new Date(r.last_updated_at).toLocaleDateString() : '' },
    { key: 'manual_url', header: 'URL', render: (r: any) => r.manual_url ? <a href={String(r.manual_url)} target="_blank" rel="noreferrer" style={{ color: '#2563eb' }}>open</a> : '' },
  ];

  const accessCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? r.engineer_user_id ?? '') },
    { key: 'accessed_at', header: 'Accessed', render: (r: any) => r.accessed_at ? new Date(r.accessed_at).toLocaleString() : '' },
    { key: 'repair_job_id', header: 'Job', render: (r: any) => r.repair_job_id ? String(r.repair_job_id).slice(0, 8) : '' },
    { key: 'search_query', header: 'Query', render: (r: any) => String(r.search_query ?? '') },
  ];

  const mostCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'manufacturer', header: 'Manufacturer', render: (r: any) => String(r.manufacturer ?? '') },
    { key: 'model_number', header: 'Model', render: (r: any) => String(r.model_number ?? '') },
    { key: 'access_count', header: 'Accesses', render: (r: any) => String(r.access_count ?? 0) },
    { key: 'last_access', header: 'Last Access', render: (r: any) => r.last_access ? new Date(r.last_access).toLocaleString() : '' },
  ];

  const langCols: Column<any>[] = [
    { key: 'language', header: 'Language', render: (r: any) => String(r.language ?? '') },
    { key: 'manual_count', header: 'Total', render: (r: any) => String(r.manual_count ?? 0) },
    { key: 'current_count', header: 'Current', render: (r: any) => String(r.current_count ?? 0) },
    { key: 'superseded_count', header: 'Superseded', render: (r: any) => String(r.superseded_count ?? 0) },
    { key: 'under_review_count', header: 'Under Review', render: (r: any) => String(r.under_review_count ?? 0) },
  ];

  const card: React.CSSProperties = { background: '#fff', border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 };
  const stat: React.CSSProperties = { ...card, textAlign: 'center' };
  const grid: React.CSSProperties = { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 };

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Equipment-Specific Manuals</h1>
      <p style={{ color: '#6b7280', marginBottom: 24 }}>
        Per-equipment service manuals library & version tracking. Round r1816.
      </p>

      <section style={grid}>
        <div style={stat}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total Manuals</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalManuals}</div>
        </div>
        <div style={stat}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Current</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#16a34a' }}>{currentCount}</div>
        </div>
        <div style={stat}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Superseded</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#6b7280' }}>{supersededCount}</div>
        </div>
        <div style={stat}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Under Review</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#f59e0b' }}>{reviewCount}</div>
        </div>
        <div style={stat}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total Accesses</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalAccesses}</div>
        </div>
      </section>

      <section style={{ ...card, marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Manuals Library</h2>
        <DataTable rows={manuals} columns={manualCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ ...card, marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Most Accessed Manuals</h2>
        <DataTable rows={most} columns={mostCols} rowKey={(r: any, i: number) => String(r.manual_id ?? i)} />
      </section>

      <section style={{ ...card, marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>By Language</h2>
        <DataTable rows={byLang} columns={langCols} rowKey={(r: any, i: number) => String(r.language ?? i)} />
      </section>

      <section style={card}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Access Log</h2>
        <DataTable rows={access} columns={accessCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
