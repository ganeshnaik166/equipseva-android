import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMindMapLibraryPage() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, activeRes, archivedRes] = await Promise.all([
    sb.rpc('mind_map_summary_r1690'),
    sb.rpc('list_mind_maps_r1690', { p_status: 'active' }),
    sb.rpc('list_mind_maps_r1690', { p_status: 'archived' }),
  ]);

  const summary = (summaryRes.data as any[] | null)?.[0] ?? {
    total_maps: 0,
    active_maps: 0,
    archived_maps: 0,
    total_nodes: 0,
    avg_nodes_per_active: 0,
    stale_active_maps: 0,
  };
  const activeMaps = (activeRes.data as any[] | null) ?? [];
  const archivedMaps = (archivedRes.data as any[] | null) ?? [];

  const firstActiveId = activeMaps[0]?.id as string | undefined;
  let firstMapNodes: any[] = [];
  if (firstActiveId) {
    const nodesRes = await sb.rpc('list_mind_map_nodes_r1690', { p_map_id: firstActiveId });
    firstMapNodes = (nodesRes.data as any[] | null) ?? [];
  }

  const mapColumns: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => <span className="font-medium">{r.title ?? '—'}</span> },
    { key: 'summary', header: 'Summary', render: (r: any) => <span className="text-sm text-neutral-600 line-clamp-2">{r.summary_md ?? '—'}</span> },
    { key: 'nodes', header: 'Nodes', render: (r: any) => <span>{r.node_count ?? 0}</span> },
    { key: 'last_edited', header: 'Last Edited', render: (r: any) => <span>{r.last_edited_at ? new Date(r.last_edited_at).toLocaleString() : '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => (
      <span className={`px-2 py-0.5 rounded text-xs ${r.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-neutral-100 text-neutral-700'}`}>
        {r.status ?? '—'}
      </span>
    ) },
  ];

  const nodeColumns: Column<any>[] = [
    { key: 'text', header: 'Node Text', render: (r: any) => <span className="font-medium">{r.node_text ?? '—'}</span> },
    { key: 'parent', header: 'Parent', render: (r: any) => <span className="text-xs font-mono text-neutral-500">{r.parent_node_id ? String(r.parent_node_id).slice(0, 8) : 'root'}</span> },
    { key: 'weight', header: 'Weight', render: (r: any) => (
      <span className={`px-2 py-0.5 rounded text-xs ${(r.weight ?? 1) >= 3 ? 'bg-amber-100 text-amber-800' : 'bg-neutral-100 text-neutral-700'}`}>
        {r.weight ?? 1}
      </span>
    ) },
    { key: 'created_by', header: 'Created By', render: (r: any) => <span className="text-sm">{r.created_by_email ?? '—'}</span> },
    { key: 'created_at', header: 'Created', render: (r: any) => <span>{r.created_at ? new Date(r.created_at).toLocaleDateString() : '—'}</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Founder Mind Map Library</h1>
        <p className="text-sm text-neutral-600 mt-1">Personal mind maps for ideas, strategy, and product thinking.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Library Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
          <div className="rounded border p-3">
            <div className="text-xs text-neutral-500">Total Maps</div>
            <div className="text-xl font-semibold">{summary.total_maps ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-neutral-500">Active</div>
            <div className="text-xl font-semibold text-green-700">{summary.active_maps ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-neutral-500">Archived</div>
            <div className="text-xl font-semibold text-neutral-700">{summary.archived_maps ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-neutral-500">Total Nodes</div>
            <div className="text-xl font-semibold">{summary.total_nodes ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-neutral-500">Avg Nodes/Active</div>
            <div className="text-xl font-semibold">{summary.avg_nodes_per_active ?? 0}</div>
          </div>
          <div className="rounded border p-3">
            <div className="text-xs text-neutral-500">Stale (&gt;14d)</div>
            <div className="text-xl font-semibold text-amber-700">{summary.stale_active_maps ?? 0}</div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Active Maps</h2>
        <DataTable
          rows={activeMaps}
          columns={mapColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">
          Most Recent Map Nodes {firstActiveId ? <span className="text-sm font-normal text-neutral-500">({activeMaps[0]?.title})</span> : null}
        </h2>
        <DataTable
          rows={firstMapNodes}
          columns={nodeColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Archived Maps</h2>
        <DataTable
          rows={archivedMaps}
          columns={mapColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
