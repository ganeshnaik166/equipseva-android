import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderDecisionFrameworksLibraryPage() {
  const sb = await getSupabaseServerClient();

  const [frameworksRes, mostUsedRes, recentAppsRes] = await Promise.all([
    sb.rpc('list_frameworks_r2090'),
    sb.rpc('most_used_r2090'),
    sb.rpc('recent_applications_r2090'),
  ]);

  const frameworks: any[] = Array.isArray(frameworksRes.data) ? frameworksRes.data : [];
  const mostUsed: any[] = Array.isArray(mostUsedRes.data) ? mostUsedRes.data : [];
  const recentApps: any[] = Array.isArray(recentAppsRes.data) ? recentAppsRes.data : [];

  const frameworkCols: Column<any>[] = [
    { key: 'framework_label', header: 'Label', render: (r: any) => String(r.framework_label ?? '') },
    { key: 'framework_type', header: 'Type', render: (r: any) => String(r.framework_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const mostUsedCols: Column<any>[] = [
    { key: 'framework_label', header: 'Framework', render: (r: any) => String(r.framework_label ?? '') },
    { key: 'framework_type', header: 'Type', render: (r: any) => String(r.framework_type ?? '') },
    { key: 'application_count', header: 'Applications', render: (r: any) => String(r.application_count ?? 0) },
  ];

  const recentAppCols: Column<any>[] = [
    { key: 'framework_label', header: 'Framework', render: (r: any) => String(r.framework_label ?? '') },
    { key: 'decision_context_md', header: 'Context', render: (r: any) => String(r.decision_context_md ?? '').slice(0, 80) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'applied_at', header: 'Applied', render: (r: any) => r.applied_at ? new Date(r.applied_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Founder Decision-Making Frameworks Library
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Library of decision frameworks plus application log. Round 2090.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          All Frameworks
        </h2>
        <DataTable rows={frameworks} columns={frameworkCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          Most Used Frameworks
        </h2>
        <DataTable rows={mostUsed} columns={mostUsedCols} rowKey={(r, i) => String(r.framework_id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          Recent Applications
        </h2>
        <DataTable rows={recentApps} columns={recentAppCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
