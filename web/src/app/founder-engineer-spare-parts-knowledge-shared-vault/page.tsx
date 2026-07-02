import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    knowledgeRes,
    eventsRes,
    topPartsRes,
    statusDistRes,
    topContribRes,
    monthlyTrendRes,
    savedHoursRes,
  ] = await Promise.all([
    supabase.rpc('list_knowledge_r2606'),
    supabase.rpc('list_reuse_events_r2606'),
    supabase.rpc('top_reuse_parts_r2606'),
    supabase.rpc('status_distribution_r2606'),
    supabase.rpc('top_contributor_engineers_r2606'),
    supabase.rpc('monthly_reuse_trend_r2606'),
    supabase.rpc('saved_hours_summary_r2606'),
  ]);

  const knowledge = (knowledgeRes.data ?? []) as any[];
  const events = (eventsRes.data ?? []) as any[];
  const topParts = (topPartsRes.data ?? []) as any[];
  const statusDist = (statusDistRes.data ?? []) as any[];
  const topContrib = (topContribRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const savedHours = (savedHoursRes.data ?? []) as any[];

  const knowledgeCols: Column<any>[] = [
    { key: 'part_sku', header: 'SKU', render: (r: any) => r.part_sku ?? '-' },
    { key: 'part_name', header: 'Part', render: (r: any) => r.part_name ?? '-' },
    { key: 'reuse_count', header: 'Reuse #', render: (r: any) => String(r.reuse_count ?? 0) },
    { key: 'last_used_at', header: 'Last Used', render: (r: any) => r.last_used_at ? new Date(r.last_used_at).toLocaleDateString() : '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const eventsCols: Column<any>[] = [
    { key: 'part_sku', header: 'SKU', render: (r: any) => r.part_sku ?? '-' },
    { key: 'observed_at', header: 'When', render: (r: any) => r.observed_at ? new Date(r.observed_at).toLocaleDateString() : '-' },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind ?? '-' },
    { key: 'saved_hours', header: 'Saved hrs', render: (r: any) => String(r.saved_hours ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topPartsCols: Column<any>[] = [
    { key: 'part_sku', header: 'SKU', render: (r: any) => r.part_sku ?? '-' },
    { key: 'part_name', header: 'Part', render: (r: any) => r.part_name ?? '-' },
    { key: 'reuse_count', header: 'Reuse #', render: (r: any) => String(r.reuse_count ?? 0) },
    { key: 'events_logged', header: 'Events', render: (r: any) => String(r.events_logged ?? 0) },
    { key: 'saved_hours', header: 'Saved hrs', render: (r: any) => String(r.saved_hours ?? 0) },
  ];

  const statusDistCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt ?? 0) },
  ];

  const topContribCols: Column<any>[] = [
    { key: 'owner_email', header: 'Engineer', render: (r: any) => r.owner_email ?? '-' },
    { key: 'entries', header: 'Entries', render: (r: any) => String(r.entries ?? 0) },
    { key: 'total_reuse', header: 'Total Reuse', render: (r: any) => String(r.total_reuse ?? 0) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? new Date(r.month_start).toLocaleDateString() : '-' },
    { key: 'events_logged', header: 'Events', render: (r: any) => String(r.events_logged ?? 0) },
    { key: 'saved_hours', header: 'Saved hrs', render: (r: any) => String(r.saved_hours ?? 0) },
  ];

  const savedHoursCols: Column<any>[] = [
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind ?? '-' },
    { key: 'events_cnt', header: 'Events', render: (r: any) => String(r.events_cnt ?? 0) },
    { key: 'saved_hours', header: 'Saved hrs', render: (r: any) => String(r.saved_hours ?? 0) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Spare-Parts Knowledge Shared Vault</h1>
        <p className="text-sm text-gray-600 mt-1">
          Part × engineer × failure modes × fix tips × reuse count. Capture tribal field knowledge so the next engineer fixes faster.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Knowledge Entries</h2>
        <DataTable
          rows={knowledge}
          columns={knowledgeCols}
          emptyMessage="No knowledge entries yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reuse Events</h2>
        <DataTable
          rows={events}
          columns={eventsCols}
          emptyMessage="No reuse events yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Reused Parts</h2>
        <DataTable
          rows={topParts}
          columns={topPartsCols}
          emptyMessage="No top parts"
          rowKey={(r: any, i: number) => String(r.part_sku ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Distribution</h2>
        <DataTable
          rows={statusDist}
          columns={statusDistCols}
          emptyMessage="No status data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Contributor Engineers</h2>
        <DataTable
          rows={topContrib}
          columns={topContribCols}
          emptyMessage="No contributors yet"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Reuse Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Saved Hours Summary</h2>
        <DataTable
          rows={savedHours}
          columns={savedHoursCols}
          emptyMessage="No saved-hours data"
          rowKey={(r: any, i: number) => String(r.outcome_kind ?? i)}
        />
      </section>
    </main>
  );
}
