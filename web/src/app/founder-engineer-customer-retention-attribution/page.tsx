import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCustomerRetentionAttributionPage() {
  const supabase = await getSupabaseServerClient();

  const [
    attributionRes,
    eventsRes,
    topEngineersRes,
    breakdownRes,
    summaryRes,
    trendRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_attribution_r2578'),
    supabase.rpc('list_events_r2578'),
    supabase.rpc('top_save_engineers_r2578'),
    supabase.rpc('attribution_kind_breakdown_r2578'),
    supabase.rpc('total_retention_impact_summary_r2578'),
    supabase.rpc('monthly_attribution_trend_r2578'),
    supabase.rpc('owner_load_r2578'),
  ]);

  const attribution: any[] = attributionRes.data ?? [];
  const events: any[] = eventsRes.data ?? [];
  const topEngineers: any[] = topEngineersRes.data ?? [];
  const breakdown: any[] = breakdownRes.data ?? [];
  const summary: any[] = summaryRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const ownerLoad: any[] = ownerLoadRes.data ?? [];

  const fmtRupees = (n: number | null | undefined) => {
    if (n === null || n === undefined) return '—';
    const v = Number(n);
    if (v === 0) return '₹0';
    return (v < 0 ? '-₹' : '₹') + Math.abs(v).toLocaleString('en-IN');
  };

  const fmtDate = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '—';

  const attributionCols: Column<any>[] = [
    { key: 'attribution_kind', header: 'Kind', render: (r: any) => r.attribution_kind },
    { key: 'observed_at', header: 'Observed', render: (r: any) => fmtDate(r.observed_at) },
    {
      key: 'retention_impact_rupees',
      header: 'Impact',
      render: (r: any) => fmtRupees(r.retention_impact_rupees),
    },
    { key: 'top_factor_md', header: 'Top Factor', render: (r: any) => r.top_factor_md ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const eventCols: Column<any>[] = [
    { key: 'event_at', header: 'Event At', render: (r: any) => fmtDate(r.event_at) },
    { key: 'event_kind', header: 'Kind', render: (r: any) => r.event_kind },
    { key: 'impact_rupees', header: 'Impact', render: (r: any) => fmtRupees(r.impact_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topEngineerCols: Column<any>[] = [
    {
      key: 'engineer_user_id',
      header: 'Engineer',
      render: (r: any) => (r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '—'),
    },
    { key: 'saves', header: 'Saves', render: (r: any) => r.saves },
    {
      key: 'total_saved_rupees',
      header: 'Total Saved',
      render: (r: any) => fmtRupees(r.total_saved_rupees),
    },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'attribution_kind', header: 'Kind', render: (r: any) => r.attribution_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    {
      key: 'total_impact_rupees',
      header: 'Total Impact',
      render: (r: any) => fmtRupees(r.total_impact_rupees),
    },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'total_attributions', header: 'Total', render: (r: any) => r.total_attributions },
    { key: 'total_saves', header: 'Saves', render: (r: any) => r.total_saves },
    { key: 'total_losses', header: 'Losses', render: (r: any) => r.total_losses },
    {
      key: 'total_save_rupees',
      header: 'Save Total',
      render: (r: any) => fmtRupees(r.total_save_rupees),
    },
    {
      key: 'total_loss_rupees',
      header: 'Loss Total',
      render: (r: any) => fmtRupees(r.total_loss_rupees),
    },
    {
      key: 'net_impact_rupees',
      header: 'Net Impact',
      render: (r: any) => fmtRupees(r.net_impact_rupees),
    },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'total', header: 'Attributions', render: (r: any) => r.total },
    {
      key: 'net_impact_rupees',
      header: 'Net Impact',
      render: (r: any) => fmtRupees(r.net_impact_rupees),
    },
  ];

  const ownerLoadCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'open_attributions', header: 'Open Attributions', render: (r: any) => r.open_attributions },
    { key: 'open_events', header: 'Open Events', render: (r: any) => r.open_events },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Engineer Customer Retention Attribution
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track how individual engineers drive retention saves & losses — dollar impact per
        customer relationship, factor analysis &gt; gut feel.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Impact Summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No summary"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Kind Breakdown</h2>
        <DataTable
          rows={breakdown}
          columns={breakdownCols}
          emptyMessage="No breakdown"
          rowKey={(r: any, i: number) => String(r.attribution_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Save Engineers</h2>
        <DataTable
          rows={topEngineers}
          columns={topEngineerCols}
          emptyMessage="No engineer saves recorded"
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No monthly trend"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerLoadCols}
          emptyMessage="No owner load"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Attribution Rows</h2>
        <DataTable
          rows={attribution}
          columns={attributionCols}
          emptyMessage="No attribution rows"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Attribution Events</h2>
        <DataTable
          rows={events}
          columns={eventCols}
          emptyMessage="No events"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
