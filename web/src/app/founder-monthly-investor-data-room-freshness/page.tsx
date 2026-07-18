import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [sections, actions, staleFocus, kindBreakdown, cadence, trend, accessed] = await Promise.all([
    sb.rpc('list_sections_r2609'),
    sb.rpc('list_refresh_actions_r2609'),
    sb.rpc('stale_focus_r2609'),
    sb.rpc('section_kind_breakdown_r2609'),
    sb.rpc('cadence_compliance_summary_r2609'),
    sb.rpc('monthly_refresh_trend_r2609'),
    sb.rpc('accessed_by_summary_r2609'),
  ]);

  const sectionRows = (sections.data ?? []) as any[];
  const actionRows = (actions.data ?? []) as any[];
  const staleRows = (staleFocus.data ?? []) as any[];
  const kindRows = (kindBreakdown.data ?? []) as any[];
  const cadenceRows = (cadence.data ?? []) as any[];
  const trendRows = (trend.data ?? []) as any[];
  const accessedRows = (accessed.data ?? []) as any[];

  const sectionCols: Column<any>[] = [
    { key: 'section_label', header: 'Section', render: (r: any) => r.section_label },
    { key: 'section_kind', header: 'Kind', render: (r: any) => r.section_kind },
    { key: 'last_refreshed_at', header: 'Last refreshed', render: (r: any) => new Date(r.last_refreshed_at).toLocaleDateString() },
    { key: 'required_cadence_days', header: 'Cadence (days)', render: (r: any) => r.required_cadence_days },
    { key: 'days_until_stale', header: 'Days until stale', render: (r: any) => r.days_until_stale },
    { key: 'stale_flag', header: 'Stale?', render: (r: any) => (r.stale_flag ? 'yes' : 'no') },
    { key: 'accessed_by_count', header: 'Accessed by', render: (r: any) => r.accessed_by_count },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'section_label', header: 'Section', render: (r: any) => r.section_label },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const staleCols: Column<any>[] = [
    { key: 'section_label', header: 'Section', render: (r: any) => r.section_label },
    { key: 'section_kind', header: 'Kind', render: (r: any) => r.section_kind },
    { key: 'days_until_stale', header: 'Days until stale', render: (r: any) => r.days_until_stale },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'section_kind', header: 'Kind', render: (r: any) => r.section_kind },
    { key: 'total_sections', header: 'Total', render: (r: any) => r.total_sections },
    { key: 'stale_sections', header: 'Stale', render: (r: any) => r.stale_sections },
    { key: 'fresh_sections', header: 'Fresh', render: (r: any) => r.fresh_sections },
    { key: 'avg_days_until_stale', header: 'Avg days > stale', render: (r: any) => r.avg_days_until_stale },
  ];

  const cadenceCols: Column<any>[] = [
    { key: 'metric_label', header: 'Metric', render: (r: any) => r.metric_label },
    { key: 'metric_value', header: 'Value', render: (r: any) => r.metric_value },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'refresh_actions', header: 'Actions', render: (r: any) => r.refresh_actions },
    { key: 'done_actions', header: 'Done', render: (r: any) => r.done_actions },
    { key: 'positive_outcomes', header: 'Positive', render: (r: any) => r.positive_outcomes },
  ];

  const accessedCols: Column<any>[] = [
    { key: 'section_label', header: 'Section', render: (r: any) => r.section_label },
    { key: 'section_kind', header: 'Kind', render: (r: any) => r.section_kind },
    { key: 'accessed_by_count', header: 'Accessed by', render: (r: any) => r.accessed_by_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Monthly investor data room freshness — r2609</h1>
        <p style={{ color: '#555' }}>Sections & refresh actions: stale sections &gt; cadence get flagged for founder triage.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Cadence compliance summary</h2>
        <DataTable
          rows={cadenceRows}
          columns={cadenceCols}
          emptyMessage="No cadence metrics yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Stale focus</h2>
        <DataTable
          rows={staleRows}
          columns={staleCols}
          emptyMessage="No stale sections."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Section kind breakdown</h2>
        <DataTable
          rows={kindRows}
          columns={kindCols}
          emptyMessage="No section kinds."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All sections</h2>
        <DataTable
          rows={sectionRows}
          columns={sectionCols}
          emptyMessage="No sections."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Refresh actions log</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly refresh trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No monthly data."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Accessed-by summary</h2>
        <DataTable
          rows={accessedRows}
          columns={accessedCols}
          emptyMessage="No access data."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
