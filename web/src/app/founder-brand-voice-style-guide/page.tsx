import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderBrandVoiceStyleGuidePage() {
  const sb = await getSupabaseServerClient();

  const [attrsRes, currentRes, recentRes] = await Promise.all([
    sb.rpc('founder_brand_voice_list_attributes_r2002'),
    sb.rpc('founder_brand_voice_current_voice_r2002'),
    sb.rpc('founder_brand_voice_recent_revisions_r2002', { p_limit: 20 }),
  ]);

  const attrs: any[] = Array.isArray(attrsRes.data) ? attrsRes.data : [];
  const current: any[] = Array.isArray(currentRes.data) ? currentRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const attrCols: Column<any>[] = [
    { key: 'voice_attribute', header: 'Attribute', render: (r: any) => String(r.voice_attribute ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'revision_count', header: 'Revisions', render: (r: any) => String(r.revision_count ?? 0) },
    { key: 'last_revised_at', header: 'Last Revised', render: (r: any) => r.last_revised_at ? new Date(r.last_revised_at).toLocaleString() : '' },
    { key: 'current_definition_md', header: 'Definition', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.current_definition_md ?? '').slice(0, 240)}</span> },
  ];

  const currentCols: Column<any>[] = [
    { key: 'voice_attribute', header: 'Attribute', render: (r: any) => String(r.voice_attribute ?? '') },
    { key: 'current_definition_md', header: 'Active Definition', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap' }}>{String(r.current_definition_md ?? '').slice(0, 320)}</span> },
    { key: 'revision_count', header: 'Revisions', render: (r: any) => String(r.revision_count ?? 0) },
    { key: 'last_revised_at', header: 'Last Revised', render: (r: any) => r.last_revised_at ? new Date(r.last_revised_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'revised_at', header: 'Revised At', render: (r: any) => r.revised_at ? new Date(r.revised_at).toLocaleString() : '' },
    { key: 'voice_attribute', header: 'Attribute', render: (r: any) => String(r.voice_attribute ?? '') },
    { key: 'revision_reason', header: 'Reason', render: (r: any) => String(r.revision_reason ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'revision_id', header: 'Revision ID', render: (r: any) => String(r.revision_id ?? '').slice(0, 8) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder Brand Voice Style Guide</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Maintain founder personal brand voice across tone, diction, topics, cadence, and visuals. Track revisions and the reasons behind them.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Active Voice (Current)</h2>
        <DataTable rows={current} columns={currentCols} rowKey={(r: any, i: number) => String(r.voice_attribute ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Attributes</h2>
        <DataTable rows={attrs} columns={attrCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Revisions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.revision_id ?? i)} />
      </section>
    </main>
  );
}
