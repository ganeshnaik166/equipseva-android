import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [listRes, movesRes, rollupRes, kanbanRes] = await Promise.all([
    sb.rpc('founder_competitor_list_r2229'),
    sb.rpc('founder_competitor_moves_recent_r2229', { p_limit: 50 }),
    sb.rpc('founder_competitor_threat_rollup_r2229'),
    sb.rpc('founder_competitor_counter_kanban_r2229'),
  ]);

  const competitors: any[] = Array.isArray(listRes.data) ? listRes.data : [];
  const moves: any[] = Array.isArray(movesRes.data) ? movesRes.data : [];
  const rollup: any[] = Array.isArray(rollupRes.data) ? rollupRes.data : [];
  const kanban: any[] = Array.isArray(kanbanRes.data) ? kanbanRes.data : [];

  const compCols: Column<any>[] = [
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => String(r.competitor_name ?? '') },
    { key: 'competitor_type', header: 'Type', render: (r: any) => String(r.competitor_type ?? '') },
    { key: 'hq_country', header: 'HQ', render: (r: any) => String(r.hq_country ?? '') },
    { key: 'threat_level', header: 'Threat', render: (r: any) => String(r.threat_level ?? '') },
    { key: 'estimated_revenue_inr_cr', header: 'Rev (Cr)', render: (r: any) => String(r.estimated_revenue_inr_cr ?? '') },
    { key: 'estimated_hospitals_served', header: 'Hosp.', render: (r: any) => String(r.estimated_hospitals_served ?? '') },
    { key: 'overlap_pct', header: 'Overlap %', render: (r: any) => String(r.overlap_pct ?? '') },
    { key: 'total_moves', header: 'Moves', render: (r: any) => String(r.total_moves ?? 0) },
    { key: 'open_counters', header: 'Open Ctrs', render: (r: any) => String(r.open_counters ?? 0) },
    { key: 'last_headline', header: 'Last Move', render: (r: any) => String(r.last_headline ?? '') },
  ];

  const moveCols: Column<any>[] = [
    { key: 'observed_at', header: 'When', render: (r: any) => String(r.observed_at ?? '').slice(0, 10) },
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => String(r.competitor_name ?? '') },
    { key: 'threat_level', header: 'Threat', render: (r: any) => String(r.threat_level ?? '') },
    { key: 'move_type', header: 'Type', render: (r: any) => String(r.move_type ?? '') },
    { key: 'headline', header: 'Headline', render: (r: any) => String(r.headline ?? '') },
    { key: 'threat_delta', header: 'Delta', render: (r: any) => String(r.threat_delta ?? '') },
    { key: 'counter_move', header: 'Counter', render: (r: any) => String(r.counter_move ?? '') },
    { key: 'counter_move_status', header: 'Status', render: (r: any) => String(r.counter_move_status ?? '') },
    { key: 'counter_move_eta_at', header: 'ETA', render: (r: any) => String(r.counter_move_eta_at ?? '').slice(0, 10) },
  ];

  const rollupCols: Column<any>[] = [
    { key: 'threat_level', header: 'Threat', render: (r: any) => String(r.threat_level ?? '') },
    { key: 'competitor_count', header: 'Competitors', render: (r: any) => String(r.competitor_count ?? 0) },
    { key: 'total_moves_90d', header: 'Moves 90d', render: (r: any) => String(r.total_moves_90d ?? 0) },
    { key: 'open_counters', header: 'Open Counters', render: (r: any) => String(r.open_counters ?? 0) },
    { key: 'shipped_counters_90d', header: 'Shipped 90d', render: (r: any) => String(r.shipped_counters_90d ?? 0) },
  ];

  const kanbanCols: Column<any>[] = [
    { key: 'counter_move_status', header: 'Status', render: (r: any) => String(r.counter_move_status ?? '') },
    { key: 'move_count', header: 'Moves', render: (r: any) => String(r.move_count ?? 0) },
    { key: 'competitor_count', header: 'Competitors', render: (r: any) => String(r.competitor_count ?? 0) },
    { key: 'next_eta_at', header: 'Next ETA', render: (r: any) => String(r.next_eta_at ?? '').slice(0, 10) },
    { key: 'overdue_count', header: 'Overdue', render: (r: any) => String(r.overdue_count ?? 0) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Strategic Competitor Watch</h1>
        <p className="text-sm text-gray-600">
          Track competitors (Trivitron, Wipro GE, etc.), their public moves & our counter-move log.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Threat rollup</h2>
        <DataTable columns={rollupCols} rows={rollup} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Counter-move kanban</h2>
        <DataTable columns={kanbanCols} rows={kanban} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Competitors</h2>
        <DataTable columns={compCols} rows={competitors} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent moves & counters</h2>
        <DataTable columns={moveCols} rows={moves} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
