import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type AttendanceRow = {
  id: string;
  chain_name: string;
  event_label: string;
  event_at: string;
  exec_role: string;
  attended: boolean;
  engagement_score: number;
  deal_advancement_kind: string;
  owner_email: string;
  status: string;
};

type FollowUpRow = {
  id: string;
  attendance_id: string;
  chain_name: string;
  event_label: string;
  follow_up_at: string;
  follow_up_kind: string;
  outcome: string;
  owner_email: string;
  status: string;
};

type FocusRow = {
  chain_name: string;
  events_attended: number;
  avg_engagement: number;
  max_engagement: number;
  deal_close_count: number;
};

type RoleRow = {
  exec_role: string;
  total_events: number;
  attended_count: number;
  avg_engagement: number;
};

type FunnelRow = { status: string; event_count: number };

type DealRow = {
  deal_advancement_kind: string;
  event_count: number;
  avg_engagement: number;
  follow_up_count: number;
};

type TrendRow = {
  month_start: string;
  event_count: number;
  attended_count: number;
  avg_engagement: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [attRes, fuRes, focusRes, roleRes, funnelRes, dealRes, trendRes] = await Promise.all([
    sb.rpc('list_attendance_r2635'),
    sb.rpc('list_follow_ups_r2635'),
    sb.rpc('top_engagement_focus_r2635'),
    sb.rpc('exec_role_distribution_r2635'),
    sb.rpc('status_funnel_r2635'),
    sb.rpc('deal_advancement_summary_r2635'),
    sb.rpc('monthly_event_trend_r2635'),
  ]);

  const attendance: AttendanceRow[] = (attRes.data as AttendanceRow[] | null) ?? [];
  const followUps: FollowUpRow[] = (fuRes.data as FollowUpRow[] | null) ?? [];
  const focus: FocusRow[] = (focusRes.data as FocusRow[] | null) ?? [];
  const roles: RoleRow[] = (roleRes.data as RoleRow[] | null) ?? [];
  const funnel: FunnelRow[] = (funnelRes.data as FunnelRow[] | null) ?? [];
  const deals: DealRow[] = (dealRes.data as DealRow[] | null) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];

  const attCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'event_label', header: 'Event', render: (r: any) => r.event_label },
    { key: 'event_at', header: 'When', render: (r: any) => new Date(r.event_at).toLocaleDateString() },
    { key: 'exec_role', header: 'Exec role', render: (r: any) => r.exec_role },
    { key: 'attended', header: 'Attended', render: (r: any) => (r.attended ? 'yes' : 'no') },
    { key: 'engagement_score', header: 'Engagement', render: (r: any) => r.engagement_score },
    { key: 'deal_advancement_kind', header: 'Advancement', render: (r: any) => r.deal_advancement_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const fuCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'event_label', header: 'Event', render: (r: any) => r.event_label },
    { key: 'follow_up_at', header: 'When', render: (r: any) => new Date(r.follow_up_at).toLocaleDateString() },
    { key: 'follow_up_kind', header: 'Kind', render: (r: any) => r.follow_up_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const focusCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'events_attended', header: 'Events attended', render: (r: any) => r.events_attended },
    { key: 'avg_engagement', header: 'Avg engagement', render: (r: any) => r.avg_engagement ?? '—' },
    { key: 'max_engagement', header: 'Max engagement', render: (r: any) => r.max_engagement ?? '—' },
    { key: 'deal_close_count', header: 'Closes', render: (r: any) => r.deal_close_count },
  ];

  const roleCols: Column<any>[] = [
    { key: 'exec_role', header: 'Exec role', render: (r: any) => r.exec_role },
    { key: 'total_events', header: 'Total events', render: (r: any) => r.total_events },
    { key: 'attended_count', header: 'Attended', render: (r: any) => r.attended_count },
    { key: 'avg_engagement', header: 'Avg engagement', render: (r: any) => r.avg_engagement ?? '—' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'event_count', header: 'Events', render: (r: any) => r.event_count },
  ];

  const dealCols: Column<any>[] = [
    { key: 'deal_advancement_kind', header: 'Advancement', render: (r: any) => r.deal_advancement_kind },
    { key: 'event_count', header: 'Events', render: (r: any) => r.event_count },
    { key: 'avg_engagement', header: 'Avg engagement', render: (r: any) => r.avg_engagement ?? '—' },
    { key: 'follow_up_count', header: 'Follow-ups', render: (r: any) => r.follow_up_count },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'event_count', header: 'Events', render: (r: any) => r.event_count },
    { key: 'attended_count', header: 'Attended', render: (r: any) => r.attended_count },
    { key: 'avg_engagement', header: 'Avg engagement', render: (r: any) => r.avg_engagement ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Exec Event Attendance Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track which chain execs (CEO/COO/CFO/CMO/CIO/owner) we met at industry events, engagement
        score, deal advancement kind, and follow-up outcomes. Drives focus list for chain accounts.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All attendance ({attendance.length})</h2>
        <DataTable rows={attendance} columns={attCols} emptyMessage="No events yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Follow-ups ({followUps.length})</h2>
        <DataTable rows={followUps} columns={fuCols} emptyMessage="No follow-ups" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top engagement focus ({focus.length})</h2>
        <DataTable rows={focus} columns={focusCols} emptyMessage="No focus data" rowKey={(r: any, i: number) => String(r.chain_name ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Exec role distribution ({roles.length})</h2>
        <DataTable rows={roles} columns={roleCols} emptyMessage="No role data" rowKey={(r: any, i: number) => String(r.exec_role ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Status funnel ({funnel.length})</h2>
        <DataTable rows={funnel} columns={funnelCols} emptyMessage="No funnel data" rowKey={(r: any, i: number) => String(r.status ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Deal advancement summary ({deals.length})</h2>
        <DataTable rows={deals} columns={dealCols} emptyMessage="No deal data" rowKey={(r: any, i: number) => String(r.deal_advancement_kind ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly event trend ({trend.length})</h2>
        <DataTable rows={trend} columns={trendCols} emptyMessage="No trend data" rowKey={(r: any, i: number) => String(r.month_start ?? i)} />
      </section>
    </div>
  );
}
