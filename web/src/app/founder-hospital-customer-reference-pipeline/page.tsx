import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [pipelineRes, tier1Res, recentRes] = await Promise.all([
    sb.rpc('list_pipeline_r1839'),
    sb.rpc('top_tier_1_r1839'),
    sb.rpc('recent_groomed_r1839'),
  ]);

  const pipeline: any[] = Array.isArray(pipelineRes.data) ? pipelineRes.data : [];
  const tier1: any[] = Array.isArray(tier1Res.data) ? tier1Res.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const pipelineCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_user_id ?? '—') },
    { key: 'reference_potential', header: 'Potential', render: (r: any) => String(r.reference_potential ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'willingness_to_speak', header: 'Will Speak', render: (r: any) => (r.willingness_to_speak ? 'yes' : 'no') },
    { key: 'focus_areas', header: 'Focus Areas', render: (r: any) => Array.isArray(r.focus_areas) ? r.focus_areas.join(', ') : '—' },
    { key: 'last_groomed_at', header: 'Last Groomed', render: (r: any) => r.last_groomed_at ? new Date(r.last_groomed_at).toLocaleDateString() : '—' },
    { key: 'action_count', header: 'Actions', render: (r: any) => String(r.action_count ?? 0) },
  ];

  const tier1Cols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_user_id ?? '—') },
    { key: 'willingness_to_speak', header: 'Will Speak', render: (r: any) => (r.willingness_to_speak ? 'yes' : 'no') },
    { key: 'focus_areas', header: 'Focus Areas', render: (r: any) => Array.isArray(r.focus_areas) ? r.focus_areas.join(', ') : '—' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'last_groomed_at', header: 'Last Groomed', render: (r: any) => r.last_groomed_at ? new Date(r.last_groomed_at).toLocaleDateString() : '—' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_user_id ?? '—') },
    { key: 'reference_potential', header: 'Potential', render: (r: any) => String(r.reference_potential ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '—') },
    { key: 'recent_action_type', header: 'Recent Action', render: (r: any) => String(r.recent_action_type ?? '—') },
    { key: 'last_groomed_at', header: 'Last Groomed', render: (r: any) => r.last_groomed_at ? new Date(r.last_groomed_at).toLocaleString() : '—' },
  ];

  const tier1Count = pipeline.filter((p: any) => p.reference_potential === 'tier_1').length;
  const tier2Count = pipeline.filter((p: any) => p.reference_potential === 'tier_2').length;
  const warmCount = pipeline.filter((p: any) => p.status === 'warm').length;
  const willingCount = pipeline.filter((p: any) => p.willingness_to_speak).length;

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Reference Pipeline</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Cultivate hospitals into reference customers for pre-investor diligence. Tier-1 & tier-2 references unlock VC calls & case studies.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Snapshot</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <Stat label="Tier-1 hospitals" value={String(tier1Count)} />
          <Stat label="Tier-2 hospitals" value={String(tier2Count)} />
          <Stat label="Warm status" value={String(warmCount)} />
          <Stat label="Willing to speak" value={String(willingCount)} />
          <Stat label="Total in pipeline" value={String(pipeline.length)} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Tier-1 references (warm & warming)</h2>
        <DataTable rows={tier1} columns={tier1Cols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Full pipeline (sorted by potential)</h2>
        <DataTable rows={pipeline} columns={pipelineCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recently groomed</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
