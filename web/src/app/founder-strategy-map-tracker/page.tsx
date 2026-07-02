import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderStrategyMapTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [mapsRes, revisionsRes, activeRes] = await Promise.all([
    sb.rpc('list_strategy_maps_r2014'),
    sb.rpc('recent_strategy_map_revisions_r2014', { p_limit: 50 }),
    sb.rpc('current_strategy_map_r2014', { p_type: 'swot' }),
  ]);

  const maps: any[] = Array.isArray(mapsRes.data) ? mapsRes.data : [];
  const revisions: any[] = Array.isArray(revisionsRes.data) ? revisionsRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];

  const mapsCols: Column<any>[] = [
    { key: 'map_label', header: 'Map', render: (r: any) => String(r.map_label ?? '') },
    { key: 'map_type', header: 'Type', render: (r: any) => String(r.map_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'last_reviewed_at', header: 'Last Reviewed', render: (r: any) => r.last_reviewed_at ? new Date(r.last_reviewed_at).toLocaleString() : 'never' },
  ];

  const revisionCols: Column<any>[] = [
    { key: 'map_label', header: 'Map', render: (r: any) => String(r.map_label ?? '') },
    { key: 'map_type', header: 'Type', render: (r: any) => String(r.map_type ?? '') },
    { key: 'reason', header: 'Reason', render: (r: any) => String(r.reason ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'revised_at', header: 'Revised', render: (r: any) => r.revised_at ? new Date(r.revised_at).toLocaleString() : '' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'map_label', header: 'Active Map', render: (r: any) => String(r.map_label ?? '') },
    { key: 'map_type', header: 'Type', render: (r: any) => String(r.map_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const totalMaps = maps.length;
  const activeMaps = maps.filter((m) => m.status === 'active').length;
  const draftMaps = maps.filter((m) => m.status === 'draft').length;
  const supersededMaps = maps.filter((m) => m.status === 'superseded').length;

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Strategy Map Tracker</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Strategic frameworks tracker covering PESTEL, SWOT, Porter Five Forces, Blue Ocean, and Ansoff matrices. Capture maps, log revisions, mark current active versions.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Overview</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>Total Maps</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{totalMaps}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>Active</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{activeMaps}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>Draft</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{draftMaps}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#6b7280' }}>Superseded</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{supersededMaps}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Currently Active SWOT Maps</h2>
        <DataTable
          rows={active}
          columns={activeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Strategy Maps</h2>
        <DataTable
          rows={maps}
          columns={mapsCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Revisions</h2>
        <DataTable
          rows={revisions}
          columns={revisionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
