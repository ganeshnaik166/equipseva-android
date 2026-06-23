import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TicketRow = {
  id: string;
  customer_id: string;
  customer_email: string | null;
  ticket_subject: string;
  channel: string;
  severity: string;
  status: string;
  current_level: number;
  opened_at: string;
  first_response_minutes: number | null;
  resolution_minutes: number | null;
  step_count: number;
  sla_minutes: number;
  sla_breached: boolean;
};

type TrailRow = {
  step_id: string;
  ticket_id: string;
  ticket_subject: string;
  step_index: number;
  level: number;
  actor_id: string | null;
  actor_email: string | null;
  actor_role: string | null;
  action_type: string;
  note: string | null;
  occurred_at: string;
  minutes_since_open: number | null;
};

type SlaRow = {
  severity: string;
  total_tickets: number;
  resolved_in_sla: number;
  resolved_breached: number;
  open_breached: number;
  median_response_minutes: number | null;
  median_resolution_minutes: number | null;
};

type BreachRow = {
  id: string;
  ticket_subject: string;
  customer_email: string | null;
  severity: string;
  current_level: number;
  opened_at: string;
  minutes_open: number;
  sla_minutes: number;
  minutes_over: number;
  step_count: number;
};

type DepthRow = {
  current_level: number;
  ticket_count: number;
  resolved_count: number;
  open_count: number;
  avg_resolution_minutes: number | null;
};

type RepeatRow = {
  customer_id: string;
  customer_email: string | null;
  ticket_count: number;
  open_count: number;
  breached_count: number;
  avg_csat: number | null;
};

type ChannelRow = {
  channel: string;
  total_tickets: number;
  avg_first_response_minutes: number | null;
  avg_resolution_minutes: number | null;
  breach_rate_pct: number | null;
  avg_csat: number | null;
};

function fmt(n: number | null | undefined, digits = 1): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(digits);
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [ticketsRes, trailRes, slaRes, breachRes, depthRes, repeatRes, channelRes] = await Promise.all([
    sb.rpc('list_escalated_tickets_r2352'),
    sb.rpc('ticket_trail_r2352'),
    sb.rpc('sla_breach_summary_r2352'),
    sb.rpc('open_breaches_r2352'),
    sb.rpc('escalation_depth_distribution_r2352'),
    sb.rpc('top_repeat_escalators_r2352'),
    sb.rpc('channel_performance_r2352'),
  ]);

  const tickets: TicketRow[] = (ticketsRes.data as TicketRow[] | null) ?? [];
  const trail: TrailRow[] = (trailRes.data as TrailRow[] | null) ?? [];
  const sla: SlaRow[] = (slaRes.data as SlaRow[] | null) ?? [];
  const breaches: BreachRow[] = (breachRes.data as BreachRow[] | null) ?? [];
  const depth: DepthRow[] = (depthRes.data as DepthRow[] | null) ?? [];
  const repeats: RepeatRow[] = (repeatRes.data as RepeatRow[] | null) ?? [];
  const channels: ChannelRow[] = (channelRes.data as ChannelRow[] | null) ?? [];

  const ticketCols: Column<TicketRow>[] = [
    { key: 'ticket_subject', header: 'Subject', render: (r: any) => r.ticket_subject },
    { key: 'customer_email', header: 'Customer', render: (r: any) => r.customer_email ?? String(r.customer_id).slice(0, 8) },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel },
    { key: 'severity', header: 'Sev', render: (r: any) => r.severity },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'current_level', header: 'Lvl', render: (r: any) => r.current_level },
    { key: 'first_response_minutes', header: '1st resp (min)', render: (r: any) => fmt(r.first_response_minutes) },
    { key: 'resolution_minutes', header: 'Resolved (min)', render: (r: any) => fmt(r.resolution_minutes) },
    { key: 'sla_minutes', header: 'SLA (min)', render: (r: any) => r.sla_minutes },
    { key: 'sla_breached', header: 'Breached?', render: (r: any) => (r.sla_breached ? 'YES' : 'no') },
    { key: 'step_count', header: 'Steps', render: (r: any) => r.step_count },
  ];

  const trailCols: Column<TrailRow>[] = [
    { key: 'ticket_subject', header: 'Ticket', render: (r: any) => r.ticket_subject },
    { key: 'step_index', header: '#', render: (r: any) => r.step_index },
    { key: 'level', header: 'Lvl', render: (r: any) => r.level },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '—' },
    { key: 'actor_role', header: 'Role', render: (r: any) => r.actor_role ?? '—' },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '—' },
    { key: 'minutes_since_open', header: 'min since open', render: (r: any) => fmt(r.minutes_since_open) },
    { key: 'occurred_at', header: 'At', render: (r: any) => r.occurred_at },
  ];

  const slaCols: Column<SlaRow>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'total_tickets', header: 'Total', render: (r: any) => r.total_tickets },
    { key: 'resolved_in_sla', header: 'In SLA', render: (r: any) => r.resolved_in_sla },
    { key: 'resolved_breached', header: 'Resolved late', render: (r: any) => r.resolved_breached },
    { key: 'open_breached', header: 'Open + late', render: (r: any) => r.open_breached },
    { key: 'median_response_minutes', header: 'p50 resp (min)', render: (r: any) => fmt(r.median_response_minutes) },
    { key: 'median_resolution_minutes', header: 'p50 resolve (min)', render: (r: any) => fmt(r.median_resolution_minutes) },
  ];

  const breachCols: Column<BreachRow>[] = [
    { key: 'ticket_subject', header: 'Subject', render: (r: any) => r.ticket_subject },
    { key: 'customer_email', header: 'Customer', render: (r: any) => r.customer_email ?? '—' },
    { key: 'severity', header: 'Sev', render: (r: any) => r.severity },
    { key: 'current_level', header: 'Lvl', render: (r: any) => r.current_level },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at },
    { key: 'minutes_open', header: 'Open (min)', render: (r: any) => fmt(r.minutes_open) },
    { key: 'sla_minutes', header: 'SLA (min)', render: (r: any) => r.sla_minutes },
    { key: 'minutes_over', header: 'Over by (min)', render: (r: any) => fmt(r.minutes_over) },
    { key: 'step_count', header: 'Steps', render: (r: any) => r.step_count },
  ];

  const depthCols: Column<DepthRow>[] = [
    { key: 'current_level', header: 'Level', render: (r: any) => r.current_level },
    { key: 'ticket_count', header: 'Tickets', render: (r: any) => r.ticket_count },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => r.resolved_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'avg_resolution_minutes', header: 'Avg resolve (min)', render: (r: any) => fmt(r.avg_resolution_minutes) },
  ];

  const repeatCols: Column<RepeatRow>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: any) => r.customer_email ?? String(r.customer_id).slice(0, 8) },
    { key: 'ticket_count', header: 'Tickets', render: (r: any) => r.ticket_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'breached_count', header: 'Breached', render: (r: any) => r.breached_count },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => fmt(r.avg_csat, 2) },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel },
    { key: 'total_tickets', header: 'Tickets', render: (r: any) => r.total_tickets },
    { key: 'avg_first_response_minutes', header: 'Avg 1st resp (min)', render: (r: any) => fmt(r.avg_first_response_minutes) },
    { key: 'avg_resolution_minutes', header: 'Avg resolve (min)', render: (r: any) => fmt(r.avg_resolution_minutes) },
    { key: 'breach_rate_pct', header: 'Breach %', render: (r: any) => fmt(r.breach_rate_pct, 2) },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => fmt(r.avg_csat, 2) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Customer Service Escalation Transparency</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Every escalated ticket exposed with full trail: response time, escalation steps, resolution.
        SLA breaches surface here before customers churn.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All escalated tickets ({tickets.length})</h2>
        <DataTable
          rows={tickets}
          columns={ticketCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Open SLA breaches ({breaches.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Tickets still open AND past their SLA minutes — act now.
        </p>
        <DataTable
          rows={breaches}
          columns={breachCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>SLA performance by severity ({sla.length})</h2>
        <DataTable
          rows={sla}
          columns={slaCols}
          rowKey={(r: any, i: number) => String(r.severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Escalation depth distribution ({depth.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          How many tickets reach each level (1 =&gt; first-line, 5 =&gt; founder).
        </p>
        <DataTable
          rows={depth}
          columns={depthCols}
          rowKey={(r: any, i: number) => String(r.current_level ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Channel performance ({channels.length})</h2>
        <DataTable
          rows={channels}
          columns={channelCols}
          rowKey={(r: any, i: number) => String(r.channel ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top repeat escalators ({repeats.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Customers with &gt;= 2 escalated tickets — churn risk + relationship signal.
        </p>
        <DataTable
          rows={repeats}
          columns={repeatCols}
          rowKey={(r: any, i: number) => String(r.customer_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Full escalation trail ({trail.length} steps)</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Every step recorded against every ticket — ordered newest ticket first, then step #.
        </p>
        <DataTable
          rows={trail}
          columns={trailCols}
          rowKey={(r: any, i: number) => String(r.step_id ?? i)}
        />
      </section>
    </div>
  );
}
