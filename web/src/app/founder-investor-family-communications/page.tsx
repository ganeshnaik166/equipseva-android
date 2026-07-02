import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorFamilyCommunicationsPage() {
  const sb = await getSupabaseServerClient();

  const [comms, events, top, recent, summary] = await Promise.all([
    sb.rpc('list_investor_family_communications_r1813', { p_limit: 100 }),
    sb.rpc('list_investor_family_events_r1813', { p_limit: 100 }),
    sb.rpc('top_engaged_investor_families_r1813', { p_limit: 10 }),
    sb.rpc('recent_investor_family_communications_r1813', { p_days: 30 }),
    sb.rpc('investor_family_engagement_summary_r1813'),
  ]);

  const commsRows: any[] = Array.isArray(comms.data) ? comms.data : [];
  const eventsRows: any[] = Array.isArray(events.data) ? events.data : [];
  const topRows: any[] = Array.isArray(top.data) ? top.data : [];
  const recentRows: any[] = Array.isArray(recent.data) ? recent.data : [];
  const summaryRow: any = Array.isArray(summary.data) && summary.data.length > 0 ? summary.data[0] : null;

  const commsCols: Column<any>[] = [
    { key: 'family_member_name', header: 'Family Member', render: (r: any) => String(r.family_member_name ?? '') },
    { key: 'family_member_relationship', header: 'Relationship', render: (r: any) => String(r.family_member_relationship ?? '') },
    { key: 'contact_type', header: 'Type', render: (r: any) => String(r.contact_type ?? '') },
    { key: 'contact_at', header: 'When', render: (r: any) => r.contact_at ? new Date(r.contact_at).toLocaleString() : '' },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'summary', header: 'Summary', render: (r: any) => String(r.summary ?? '') },
    { key: 'founder_note', header: 'Founder Note', render: (r: any) => String(r.founder_note ?? '') },
  ];

  const eventsCols: Column<any>[] = [
    { key: 'family_member_name', header: 'Family Member', render: (r: any) => String(r.family_member_name ?? '') },
    { key: 'event_type', header: 'Event Type', render: (r: any) => String(r.event_type ?? '') },
    { key: 'event_at', header: 'When', render: (r: any) => r.event_at ? new Date(r.event_at).toLocaleString() : '' },
    { key: 'attended', header: 'Attended', render: (r: any) => r.attended ? 'Yes' : 'No' },
    { key: 'communication_id', header: 'Comm ID', render: (r: any) => String(r.communication_id ?? '').slice(0, 8) },
  ];

  const topCols: Column<any>[] = [
    { key: 'family_member_name', header: 'Family Member', render: (r: any) => String(r.family_member_name ?? '') },
    { key: 'family_member_relationship', header: 'Relationship', render: (r: any) => String(r.family_member_relationship ?? '') },
    { key: 'touch_count', header: 'Touches', render: (r: any) => String(r.touch_count ?? 0) },
    { key: 'last_contact_at', header: 'Last Contact', render: (r: any) => r.last_contact_at ? new Date(r.last_contact_at).toLocaleString() : '' },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'family_member_name', header: 'Family Member', render: (r: any) => String(r.family_member_name ?? '') },
    { key: 'family_member_relationship', header: 'Relationship', render: (r: any) => String(r.family_member_relationship ?? '') },
    { key: 'contact_type', header: 'Type', render: (r: any) => String(r.contact_type ?? '') },
    { key: 'contact_at', header: 'When', render: (r: any) => r.contact_at ? new Date(r.contact_at).toLocaleString() : '' },
    { key: 'summary', header: 'Summary', render: (r: any) => String(r.summary ?? '') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, marginBottom: 8 }}>Investor Family Communications</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track relationship-building touches with investor spouses & family members.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 12 }}>Engagement Summary</h2>
        {summaryRow ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Total Comms</div>
              <div style={{ fontSize: 22, fontWeight: 600 }}>{summaryRow.total_communications ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Total Events</div>
              <div style={{ fontSize: 22, fontWeight: 600 }}>{summaryRow.total_events ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Events Attended</div>
              <div style={{ fontSize: 22, fontWeight: 600 }}>{summaryRow.events_attended ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Unique Investors</div>
              <div style={{ fontSize: 22, fontWeight: 600 }}>{summaryRow.unique_investors ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Unique Family Members</div>
              <div style={{ fontSize: 22, fontWeight: 600 }}>{summaryRow.unique_family_members ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Calls</div>
              <div style={{ fontSize: 22, fontWeight: 600 }}>{summaryRow.calls_count ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Emails</div>
              <div style={{ fontSize: 22, fontWeight: 600 }}>{summaryRow.emails_count ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Events</div>
              <div style={{ fontSize: 22, fontWeight: 600 }}>{summaryRow.events_count ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
              <div style={{ fontSize: 12, color: '#666' }}>Gifts</div>
              <div style={{ fontSize: 22, fontWeight: 600 }}>{summaryRow.gifts_count ?? 0}</div>
            </div>
          </div>
        ) : (
          <div style={{ color: '#999' }}>No summary available.</div>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 12 }}>Top Engaged Families</h2>
        <DataTable rows={topRows} columns={topCols} rowKey={(r: any, i: number) => String(r.investor_id ?? i) + '_' + String(r.family_member_name ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 12 }}>Recent Communications (last 30 days)</h2>
        <DataTable rows={recentRows} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 12 }}>All Communications</h2>
        <DataTable rows={commsRows} columns={commsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, marginBottom: 12 }}>Engagement Events</h2>
        <DataTable rows={eventsRows} columns={eventsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
