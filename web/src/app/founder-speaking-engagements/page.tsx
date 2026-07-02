import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type EventRow = {
  id: string;
  event_name: string;
  event_type: string;
  event_date: string;
  audience_size: number;
  recording_url: string | null;
  status: string;
  lead_count: number;
  converted_count: number;
};

type LeadRow = {
  id: string;
  event_id: string;
  event_name: string;
  lead_name: string;
  lead_org: string | null;
  lead_email: string | null;
  lead_status: string;
  created_at: string;
};

type AudienceRow = {
  event_type: string;
  events_count: number;
  total_audience: number;
  avg_audience: number;
  delivered_count: number;
};

type ConversionRow = {
  event_id: string;
  event_name: string;
  event_date: string;
  audience_size: number;
  total_leads: number;
  qualified_leads: number;
  converted_leads: number;
  conversion_pct: number;
};

export default async function FounderSpeakingEngagementsPage() {
  const sb = await getSupabaseServerClient();

  const [eventsRes, leadsRes, audienceRes, conversionRes] = await Promise.all([
    sb.rpc('list_speaking_events_r1694'),
    sb.rpc('list_speaking_leads_r1694', { p_event_id: null }),
    sb.rpc('speaking_audience_summary_r1694'),
    sb.rpc('speaking_conversion_rate_r1694'),
  ]);

  const events: EventRow[] = (eventsRes.data ?? []) as EventRow[];
  const leads: LeadRow[] = (leadsRes.data ?? []) as LeadRow[];
  const audience: AudienceRow[] = (audienceRes.data ?? []) as AudienceRow[];
  const conversion: ConversionRow[] = (conversionRes.data ?? []) as ConversionRow[];

  const totalEvents = events.length;
  const deliveredEvents = events.filter((e) => e.status === 'delivered').length;
  const totalReach = events.reduce((s, e) => s + (e.audience_size ?? 0), 0);
  const totalLeads = leads.length;
  const convertedLeads = leads.filter((l) => l.lead_status === 'converted').length;
  const overallConv = totalLeads === 0 ? 0 : Math.round((convertedLeads / totalLeads) * 10000) / 100;

  const eventCols: Column<EventRow>[] = [
    { key: 'event_date', header: 'Date', render: (r: any) => String(r.event_date ?? '') },
    { key: 'event_name', header: 'Event', render: (r: any) => String(r.event_name ?? '') },
    { key: 'event_type', header: 'Type', render: (r: any) => String(r.event_type ?? '') },
    { key: 'audience_size', header: 'Audience', render: (r: any) => Number(r.audience_size ?? 0).toLocaleString() },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'lead_count', header: 'Leads', render: (r: any) => String(r.lead_count ?? 0) },
    { key: 'converted_count', header: 'Converted', render: (r: any) => String(r.converted_count ?? 0) },
    {
      key: 'recording_url',
      header: 'Recording',
      render: (r: any) => (r.recording_url ? <a href={String(r.recording_url)} target="_blank" rel="noopener noreferrer">link</a> : '-'),
    },
  ];

  const leadCols: Column<LeadRow>[] = [
    { key: 'created_at', header: 'Added', render: (r: any) => new Date(String(r.created_at)).toLocaleDateString() },
    { key: 'lead_name', header: 'Lead', render: (r: any) => String(r.lead_name ?? '') },
    { key: 'lead_org', header: 'Org', render: (r: any) => String(r.lead_org ?? '-') },
    { key: 'lead_email', header: 'Email', render: (r: any) => String(r.lead_email ?? '-') },
    { key: 'event_name', header: 'Event', render: (r: any) => String(r.event_name ?? '') },
    { key: 'lead_status', header: 'Status', render: (r: any) => String(r.lead_status ?? '') },
  ];

  const audienceCols: Column<AudienceRow>[] = [
    { key: 'event_type', header: 'Type', render: (r: any) => String(r.event_type ?? '') },
    { key: 'events_count', header: 'Events', render: (r: any) => String(r.events_count ?? 0) },
    { key: 'total_audience', header: 'Total Reach', render: (r: any) => Number(r.total_audience ?? 0).toLocaleString() },
    { key: 'avg_audience', header: 'Avg Audience', render: (r: any) => Number(r.avg_audience ?? 0).toLocaleString() },
    { key: 'delivered_count', header: 'Delivered', render: (r: any) => String(r.delivered_count ?? 0) },
  ];

  const convCols: Column<ConversionRow>[] = [
    { key: 'event_date', header: 'Date', render: (r: any) => String(r.event_date ?? '') },
    { key: 'event_name', header: 'Event', render: (r: any) => String(r.event_name ?? '') },
    { key: 'audience_size', header: 'Audience', render: (r: any) => Number(r.audience_size ?? 0).toLocaleString() },
    { key: 'total_leads', header: 'Leads', render: (r: any) => String(r.total_leads ?? 0) },
    { key: 'qualified_leads', header: 'Qualified', render: (r: any) => String(r.qualified_leads ?? 0) },
    { key: 'converted_leads', header: 'Converted', render: (r: any) => String(r.converted_leads ?? 0) },
    {
      key: 'conversion_pct',
      header: 'Conv %',
      render: (r: any) => {
        const pct = Number(r.conversion_pct ?? 0);
        const tag = pct >= 10 ? 'Strong (>=10%)' : pct >= 3 ? 'OK' : 'Low (<3%)';
        return `${pct.toFixed(2)}% — ${tag}`;
      },
    },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Founder Speaking Engagements Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Conferences, panels, keynotes, webinars, podcasts — with lead-gen impact.
      </p>

      <section style={{ marginBottom: 24 }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Events</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{totalEvents}</div>
          </div>
          <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Delivered</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{deliveredEvents}</div>
          </div>
          <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Reach</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{totalReach.toLocaleString()}</div>
          </div>
          <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Leads</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{totalLeads}</div>
          </div>
          <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Converted</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{convertedLeads}</div>
          </div>
          <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Overall Conv %</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{overallConv.toFixed(2)}%</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Speaking Events</h2>
        <DataTable
          rows={events}
          columns={eventCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Audience Summary by Type</h2>
        <DataTable
          rows={audience}
          columns={audienceCols}
          rowKey={(r: any, i: number) => String(r.event_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Conversion Rate per Event</h2>
        <p style={{ fontSize: 12, color: '#666', marginBottom: 8 }}>
          Strong (&gt;=10%), OK, Low (&lt;3%) buckets.
        </p>
        <DataTable
          rows={conversion}
          columns={convCols}
          rowKey={(r: any, i: number) => String(r.event_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Leads</h2>
        <DataTable
          rows={leads}
          columns={leadCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
