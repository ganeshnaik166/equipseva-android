import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [distRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_distributions_r1889'),
    sb.rpc('top_viewed_cims_r1889'),
    sb.rpc('recent_views_r1889'),
  ]);

  const distributions: any[] = Array.isArray(distRes.data) ? distRes.data : [];
  const topViewed: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recentViews: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const distColumns: Column<any>[] = [
    { key: 'cim_version_label', header: 'Version', render: (r: any) => String(r.cim_version_label ?? '') },
    { key: 'investor_email', header: 'Investor', render: (r: any) => String(r.investor_email ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '—' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleString() : '—' },
    { key: 'view_count', header: 'Views', render: (r: any) => String(r.view_count ?? 0) },
    { key: 'watermark_text', header: 'Watermark', render: (r: any) => String(r.watermark_text ?? '—') },
  ];

  const topColumns: Column<any>[] = [
    { key: 'cim_version_label', header: 'Version', render: (r: any) => String(r.cim_version_label ?? '') },
    { key: 'investor_email', header: 'Investor', render: (r: any) => String(r.investor_email ?? '—') },
    { key: 'view_count', header: 'Views', render: (r: any) => String(r.view_count ?? 0) },
    { key: 'total_duration_sec', header: 'Total Duration (s)', render: (r: any) => String(r.total_duration_sec ?? 0) },
    { key: 'last_viewed_at', header: 'Last Viewed', render: (r: any) => r.last_viewed_at ? new Date(r.last_viewed_at).toLocaleString() : '—' },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'viewed_at', header: 'Viewed', render: (r: any) => r.viewed_at ? new Date(r.viewed_at).toLocaleString() : '—' },
    { key: 'cim_version_label', header: 'Version', render: (r: any) => String(r.cim_version_label ?? '') },
    { key: 'investor_email', header: 'Investor', render: (r: any) => String(r.investor_email ?? '—') },
    { key: 'viewer_email', header: 'Viewer', render: (r: any) => String(r.viewer_email ?? '—') },
    { key: 'ip_address', header: 'IP', render: (r: any) => String(r.ip_address ?? '—') },
    { key: 'view_duration_sec', header: 'Duration (s)', render: (r: any) => String(r.view_duration_sec ?? 0) },
  ];

  const totalDist = distributions.length;
  const activeCount = distributions.filter((d: any) => d.status === 'active').length;
  const revokedCount = distributions.filter((d: any) => d.status === 'revoked').length;
  const totalViews = distributions.reduce((acc: number, d: any) => acc + Number(d.view_count ?? 0), 0);

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Investor Confidential Information Memorandum
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track CIMs sent to investors during diligence. Monitor views, durations & revocations.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ color: '#888', fontSize: 12 }}>Total CIMs Sent</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalDist}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ color: '#888', fontSize: 12 }}>Active</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#0a7' }}>{activeCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ color: '#888', fontSize: 12 }}>Revoked</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: '#c33' }}>{revokedCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #ddd', borderRadius: 8 }}>
            <div style={{ color: '#888', fontSize: 12 }}>Total Views</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalViews}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Distributions</h2>
        <DataTable rows={distributions} columns={distColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Viewed CIMs</h2>
        <DataTable rows={topViewed} columns={topColumns} rowKey={(r: any, i: number) => String(r.distribution_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Views</h2>
        <DataTable rows={recentViews} columns={recentColumns} rowKey={(r: any, i: number) => String(r.view_id ?? i)} />
      </section>
    </main>
  );
}
