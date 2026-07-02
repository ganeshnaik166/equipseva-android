import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [eventsRes, reviewsRes, topRes, aggRes] = await Promise.all([
    sb.rpc('list_activity_events_r2211'),
    sb.rpc('recent_actions_r2211'),
    sb.rpc('top_hospital_r2211'),
    sb.rpc('aggregate_or_search_r2211'),
  ]);

  const events: any[] = Array.isArray(eventsRes.data) ? eventsRes.data : [];
  const reviews: any[] = Array.isArray(reviewsRes.data) ? reviewsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const agg: any[] = Array.isArray(aggRes.data) ? aggRes.data : [];

  const eventCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r: any) => r.occurred_at ? new Date(r.occurred_at).toLocaleString() : '' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '' },
    { key: 'admin_email', header: 'Admin', render: (r: any) => r.admin_email ?? '' },
    { key: 'admin_role', header: 'Role', render: (r: any) => r.admin_role ?? '' },
    { key: 'event_kind', header: 'Event', render: (r: any) => r.event_kind ?? '' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '' },
    { key: 'ip_address', header: 'IP', render: (r: any) => r.ip_address ?? '' },
    { key: 'geo_country', header: 'Country', render: (r: any) => r.geo_country ?? '' },
    { key: 'target_entity', header: 'Target', render: (r: any) => r.target_entity ?? '' },
    { key: 'is_suspicious', header: 'Flag', render: (r: any) => r.is_suspicious ? 'suspicious' : '' },
    { key: 'reviewed_by_founder', header: 'Reviewed', render: (r: any) => r.reviewed_by_founder ? 'yes' : 'no' },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => r.reviewed_at ? new Date(r.reviewed_at).toLocaleString() : '' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '' },
    { key: 'verdict', header: 'Verdict', render: (r: any) => r.verdict ?? '' },
    { key: 'total_events', header: 'Total', render: (r: any) => r.total_events ?? 0 },
    { key: 'suspicious_count', header: 'Suspicious', render: (r: any) => r.suspicious_count ?? 0 },
    { key: 'follow_up_action', header: 'Follow-up', render: (r: any) => r.follow_up_action ?? '' },
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => r.reviewer_email ?? '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '' },
    { key: 'total_events', header: 'Events', render: (r: any) => r.total_events ?? 0 },
    { key: 'suspicious_events', header: 'Suspicious', render: (r: any) => r.suspicious_events ?? 0 },
    { key: 'high_severity_events', header: 'High sev', render: (r: any) => r.high_severity_events ?? 0 },
    { key: 'unique_admins', header: 'Admins', render: (r: any) => r.unique_admins ?? 0 },
    { key: 'last_event_at', header: 'Last event', render: (r: any) => r.last_event_at ? new Date(r.last_event_at).toLocaleString() : '' },
  ];

  const aggCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => r.metric ?? '' },
    { key: 'value_int', header: 'Count', render: (r: any) => r.value_int ?? '' },
    { key: 'value_text', header: 'Value', render: (r: any) => r.value_text ?? '' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital admin activity audit
      </h1>
      <p style={{ color: '#555', marginBottom: '20px', fontSize: '14px' }}>
        Track admin actions across the hospital portal — logins, exports, role changes & settings edits — for periodic security review.
      </p>

      <h2 style={{ fontSize: '18px', fontWeight: 600, marginTop: '16px', marginBottom: '8px' }}>Security KPIs</h2>
      <DataTable columns={aggCols} rows={agg} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 600, marginTop: '24px', marginBottom: '8px' }}>Top hospitals by event volume</h2>
      <DataTable columns={topCols} rows={top} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 600, marginTop: '24px', marginBottom: '8px' }}>Recent admin activity events</h2>
      <DataTable columns={eventCols} rows={events} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 600, marginTop: '24px', marginBottom: '8px' }}>Founder review verdicts</h2>
      <DataTable columns={reviewCols} rows={reviews} rowKey={(_, i) => String(i)} />
    </div>
  );
}
