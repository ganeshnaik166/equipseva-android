import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [pains, critical, resolutions, recent] = await Promise.all([
    sb.rpc('list_pains_r2087'),
    sb.rpc('critical_pains_r2087'),
    sb.rpc('list_resolutions_r2087', { p_pain_id: null }),
    sb.rpc('recent_resolutions_r2087'),
  ]);

  const painRows: any[] = Array.isArray(pains.data) ? pains.data : [];
  const criticalRows: any[] = Array.isArray(critical.data) ? critical.data : [];
  const resolutionRows: any[] = Array.isArray(resolutions.data) ? resolutions.data : [];
  const recentRows: any[] = Array.isArray(recent.data) ? recent.data : [];

  const painCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'pain_label', header: 'Pain', render: (r: any) => String(r.pain_label ?? '') },
    { key: 'pain_category', header: 'Category', render: (r: any) => String(r.pain_category ?? '') },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const criticalCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'pain_label', header: 'Pain', render: (r: any) => String(r.pain_label ?? '') },
    { key: 'pain_category', header: 'Category', render: (r: any) => String(r.pain_category ?? '') },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const resolutionCols: Column<any>[] = [
    { key: 'pain_label', header: 'Pain', render: (r: any) => String(r.pain_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'pain_label', header: 'Pain', render: (r: any) => String(r.pain_label ?? '') },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 600 }}>Hospital Customer Pain Point Catalog</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Track hospital customer pain points across service, pricing, and billing dimensions and log resolution actions.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Critical and major open pains</h2>
        <DataTable rows={criticalRows} columns={criticalCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All pain points</h2>
        <DataTable rows={painRows} columns={painCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Resolution log</h2>
        <DataTable rows={resolutionRows} columns={resolutionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent resolutions (30 days)</h2>
        <DataTable rows={recentRows} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
