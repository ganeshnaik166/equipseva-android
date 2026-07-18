import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyPublicSpeakingImpactPage() {
  const supabase = await getSupabaseServerClient();

  const [
    engagementsRes,
    leadsRes,
    topRes,
    audienceRes,
    trendRes,
    summaryRes,
    funnelRes,
  ] = await Promise.all([
    supabase.rpc('list_engagements_r2621'),
    supabase.rpc('list_lead_attributions_r2621'),
    supabase.rpc('top_lead_engagements_r2621'),
    supabase.rpc('audience_kind_distribution_r2621'),
    supabase.rpc('monthly_speaking_trend_r2621'),
    supabase.rpc('total_lead_value_summary_r2621'),
    supabase.rpc('status_funnel_r2621'),
  ]);

  const engagements = (engagementsRes.data ?? []) as any[];
  const leads = (leadsRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];
  const audience = (audienceRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];

  const fmtRupees = (n: any) =>
    typeof n === 'number' || typeof n === 'string'
      ? `Rs ${Number(n).toLocaleString('en-IN')}`
      : 'Rs 0';

  const engagementCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'event_label', header: 'Event', render: (r: any) => r.event_label },
    { key: 'audience_kind', header: 'Audience', render: (r: any) => r.audience_kind },
    { key: 'audience_size', header: 'Size', render: (r: any) => r.audience_size },
    { key: 'inbound_leads_count', header: 'Inbound', render: (r: any) => r.inbound_leads_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const leadCols: Column<any>[] = [
    { key: 'event_label', header: 'Event', render: (r: any) => r.event_label },
    { key: 'lead_at', header: 'Lead at', render: (r: any) => String(r.lead_at).slice(0, 10) },
    { key: 'lead_kind', header: 'Kind', render: (r: any) => r.lead_kind },
    { key: 'lead_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.lead_value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topCols: Column<any>[] = [
    { key: 'event_label', header: 'Event', render: (r: any) => r.event_label },
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'total_leads', header: 'Leads', render: (r: any) => r.total_leads },
    { key: 'total_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
  ];

  const audienceCols: Column<any>[] = [
    { key: 'audience_kind', header: 'Audience kind', render: (r: any) => r.audience_kind },
    { key: 'engagement_count', header: 'Engagements', render: (r: any) => r.engagement_count },
    { key: 'total_audience', header: 'Total audience', render: (r: any) => r.total_audience },
    { key: 'total_inbound_leads', header: 'Inbound leads', render: (r: any) => r.total_inbound_leads },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'engagement_count', header: 'Engagements', render: (r: any) => r.engagement_count },
    { key: 'total_audience', header: 'Audience', render: (r: any) => r.total_audience },
    { key: 'total_inbound_leads', header: 'Inbound', render: (r: any) => r.total_inbound_leads },
    { key: 'total_lead_value_rupees', header: 'Pipeline value', render: (r: any) => fmtRupees(r.total_lead_value_rupees) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'total_engagements', header: 'Engagements', render: (r: any) => r.total_engagements },
    { key: 'total_leads', header: 'Leads', render: (r: any) => r.total_leads },
    { key: 'total_value_rupees', header: 'Total value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'closed_won_value_rupees', header: 'Closed won', render: (r: any) => fmtRupees(r.closed_won_value_rupees) },
    { key: 'open_pipeline_value_rupees', header: 'Open pipeline', render: (r: any) => fmtRupees(r.open_pipeline_value_rupees) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'lead_kind', header: 'Kind', render: (r: any) => r.lead_kind },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => r.dropped_count },
    { key: 'total_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
  ];

  return (
    <main style={{ maxWidth: 1200, margin: '0 auto', padding: '24px 16px', display: 'flex', flexDirection: 'column', gap: 28 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>
          Founder monthly public speaking impact
        </h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Tracks every speaking slot the founder takes & the downstream pipeline it generates &gt; from MQL to closed_won.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Overall summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No summary yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Monthly trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No monthly data yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Top lead-generating engagements</h2>
        <DataTable
          rows={top}
          columns={topCols}
          emptyMessage="No engagements ranked yet."
          rowKey={(r: any, i: number) => String(r.engagement_id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Audience kind distribution</h2>
        <DataTable
          rows={audience}
          columns={audienceCols}
          emptyMessage="No audience data yet."
          rowKey={(r: any, i: number) => String(r.audience_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Lead status funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No leads yet."
          rowKey={(r: any, i: number) => String(r.lead_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>All speaking engagements</h2>
        <DataTable
          rows={engagements}
          columns={engagementCols}
          emptyMessage="No engagements logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>All lead attributions</h2>
        <DataTable
          rows={leads}
          columns={leadCols}
          emptyMessage="No leads attributed yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
