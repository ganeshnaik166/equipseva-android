import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [overview, byChannel, byHour, byPriority, recent, breaches, agents] = await Promise.all([
    sb.rpc('founder_cs_frt_overview_r2248'),
    sb.rpc('founder_cs_frt_by_channel_r2248'),
    sb.rpc('founder_cs_frt_by_hour_r2248'),
    sb.rpc('founder_cs_frt_by_priority_r2248'),
    sb.rpc('founder_cs_recent_tickets_r2248'),
    sb.rpc('founder_cs_breach_log_r2248'),
    sb.rpc('founder_cs_agent_leaderboard_r2248'),
  ]);

  const ov = (overview.data?.[0] ?? {}) as Record<string, unknown>;

  const channelCols: Column<any>[] = [
    { key: 'channel', header: 'Channel', render: (r) => String(r.channel) },
    { key: 'ticket_count', header: 'Tickets', render: (r) => String(r.ticket_count) },
    { key: 'avg_frt_min', header: 'Avg FRT (min)', render: (r) => String(r.avg_frt_min ?? '-') },
    { key: 'breach_count', header: 'Breaches', render: (r) => String(r.breach_count) },
  ];

  const hourCols: Column<any>[] = [
    { key: 'hour_of_day', header: 'Hour (0-23)', render: (r) => String(r.hour_of_day) },
    { key: 'ticket_count', header: 'Tickets', render: (r) => String(r.ticket_count) },
    { key: 'avg_frt_min', header: 'Avg FRT (min)', render: (r) => String(r.avg_frt_min ?? '-') },
  ];

  const priorityCols: Column<any>[] = [
    { key: 'priority', header: 'Priority', render: (r) => String(r.priority) },
    { key: 'ticket_count', header: 'Tickets', render: (r) => String(r.ticket_count) },
    { key: 'avg_frt_min', header: 'Avg FRT (min)', render: (r) => String(r.avg_frt_min ?? '-') },
    { key: 'breach_count', header: 'Breaches', render: (r) => String(r.breach_count) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'ticket_code', header: 'Ticket', render: (r) => String(r.ticket_code) },
    { key: 'channel', header: 'Channel', render: (r) => String(r.channel) },
    { key: 'subject', header: 'Subject', render: (r) => String(r.subject) },
    { key: 'priority', header: 'Priority', render: (r) => String(r.priority) },
    { key: 'first_response_minutes', header: 'FRT (min)', render: (r) => String(r.first_response_minutes ?? '-') },
    { key: 'sla_breached', header: 'SLA Breached', render: (r) => (r.sla_breached ? 'yes' : 'no') },
    { key: 'agent_email', header: 'Agent', render: (r) => String(r.agent_email ?? '-') },
  ];

  const breachCols: Column<any>[] = [
    { key: 'ticket_code', header: 'Ticket', render: (r) => String(r.ticket_code) },
    { key: 'channel', header: 'Channel', render: (r) => String(r.channel) },
    { key: 'breach_severity', header: 'Severity', render: (r) => String(r.breach_severity) },
    { key: 'minutes_over_target', header: 'Min Over', render: (r) => String(r.minutes_over_target) },
    { key: 'breach_reason', header: 'Reason', render: (r) => String(r.breach_reason) },
    { key: 'remediation', header: 'Remediation', render: (r) => String(r.remediation ?? '-') },
    { key: 'resolved_followup', header: 'Followed Up', render: (r) => (r.resolved_followup ? 'yes' : 'no') },
  ];

  const agentCols: Column<any>[] = [
    { key: 'agent_email', header: 'Agent', render: (r) => String(r.agent_email) },
    { key: 'ticket_count', header: 'Tickets', render: (r) => String(r.ticket_count) },
    { key: 'avg_frt_min', header: 'Avg FRT (min)', render: (r) => String(r.avg_frt_min ?? '-') },
    { key: 'breach_count', header: 'Breaches', render: (r) => String(r.breach_count) },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>Customer Service First-Response Tracker</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        FRT per ticket by channel and hour-of-day. SLA breach log included. Target: urgent &lt; 5m, high &lt; 30m, normal &lt; 15m.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginBottom: 24 }}>
        <Card label="Tickets" value={String(ov.total_tickets ?? '-')} />
        <Card label="Avg FRT (min)" value={String(ov.avg_first_response_min ?? '-')} />
        <Card label="SLA Breaches" value={String(ov.sla_breach_count ?? '-')} />
        <Card label="Breach Rate %" value={String(ov.breach_rate_pct ?? '-')} />
        <Card label="Open Unresolved" value={String(ov.open_unresolved ?? '-')} />
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 16, marginBottom: 8 }}>By Channel</h2>
      <DataTable columns={channelCols} rows={byChannel.data ?? []} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>By Hour of Day</h2>
      <DataTable columns={hourCols} rows={byHour.data ?? []} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>By Priority</h2>
      <DataTable columns={priorityCols} rows={byPriority.data ?? []} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Recent Tickets</h2>
      <DataTable columns={recentCols} rows={recent.data ?? []} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>SLA Breach Log</h2>
      <DataTable columns={breachCols} rows={breaches.data ?? []} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Agent Leaderboard</h2>
      <DataTable columns={agentCols} rows={agents.data ?? []} rowKey={(_, i) => String(i)} />
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 12, color: '#6b7280' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600 }}>{value}</div>
    </div>
  );
}
