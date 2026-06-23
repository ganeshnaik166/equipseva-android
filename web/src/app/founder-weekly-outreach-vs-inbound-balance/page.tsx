import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type WeeklyRow = {
  week_start: string;
  outbound_count: number;
  inbound_count: number;
  total_count: number;
  outbound_pct: number;
  inbound_pct: number;
  ratio: number | null;
  outbound_target: number;
  inbound_target: number;
  balance_status: string;
};

type ChannelRow = {
  channel: string;
  outbound_count: number;
  inbound_count: number;
  total_count: number;
  response_rate_pct: number;
};

type CounterpartyRow = {
  counterparty_name: string;
  counterparty_role: string | null;
  outbound_count: number;
  inbound_count: number;
  total_touches: number;
  last_touch_at: string;
};

type EventRow = {
  id: string;
  direction: string;
  channel: string;
  counterparty_name: string;
  counterparty_role: string | null;
  topic: string;
  occurred_at: string;
  response_received: boolean;
  week_start: string;
};

type KpiRow = {
  current_week_outbound: number;
  current_week_inbound: number;
  current_week_ratio: number | null;
  prior_week_outbound: number;
  prior_week_inbound: number;
  prior_week_ratio: number | null;
  outbound_wow_delta_pct: number | null;
  inbound_wow_delta_pct: number | null;
  trailing_4w_outbound: number;
  trailing_4w_inbound: number;
  response_rate_pct: number;
  status: string;
};

export default async function FounderWeeklyOutreachVsInboundBalancePage() {
  const supabase = await getSupabaseServerClient();

  const [weeklyRes, channelRes, counterpartiesRes, eventsRes, kpisRes] = await Promise.all([
    supabase.rpc('founder_r2393_weekly_balance'),
    supabase.rpc('founder_r2393_channel_breakdown'),
    supabase.rpc('founder_r2393_top_counterparties'),
    supabase.rpc('founder_r2393_recent_events'),
    supabase.rpc('founder_r2393_headline_kpis'),
  ]);

  const weekly = (weeklyRes.data ?? []) as WeeklyRow[];
  const channels = (channelRes.data ?? []) as ChannelRow[];
  const counterparties = (counterpartiesRes.data ?? []) as CounterpartyRow[];
  const events = (eventsRes.data ?? []) as EventRow[];
  const kpis = ((kpisRes.data ?? [])[0] ?? null) as KpiRow | null;

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: WeeklyRow) => new Date(r.week_start).toLocaleDateString() },
    { key: 'outbound_count', header: 'Outbound', render: (r: WeeklyRow) => r.outbound_count },
    { key: 'inbound_count', header: 'Inbound', render: (r: WeeklyRow) => r.inbound_count },
    { key: 'total_count', header: 'Total', render: (r: WeeklyRow) => r.total_count },
    { key: 'outbound_pct', header: 'Out %', render: (r: WeeklyRow) => `${r.outbound_pct}%` },
    { key: 'inbound_pct', header: 'In %', render: (r: WeeklyRow) => `${r.inbound_pct}%` },
    { key: 'ratio', header: 'Ratio (out/in)', render: (r: WeeklyRow) => r.ratio ?? '—' },
    { key: 'outbound_target', header: 'Out target', render: (r: WeeklyRow) => r.outbound_target },
    { key: 'inbound_target', header: 'In target', render: (r: WeeklyRow) => r.inbound_target },
    { key: 'balance_status', header: 'Status', render: (r: WeeklyRow) => r.balance_status },
  ];

  const channelCols: Column<any>[] = [
    { key: 'channel', header: 'Channel', render: (r: ChannelRow) => r.channel },
    { key: 'outbound_count', header: 'Outbound', render: (r: ChannelRow) => r.outbound_count },
    { key: 'inbound_count', header: 'Inbound', render: (r: ChannelRow) => r.inbound_count },
    { key: 'total_count', header: 'Total', render: (r: ChannelRow) => r.total_count },
    { key: 'response_rate_pct', header: 'Response rate', render: (r: ChannelRow) => `${r.response_rate_pct}%` },
  ];

  const counterpartyCols: Column<any>[] = [
    { key: 'counterparty_name', header: 'Counterparty', render: (r: CounterpartyRow) => r.counterparty_name },
    { key: 'counterparty_role', header: 'Role', render: (r: CounterpartyRow) => r.counterparty_role ?? '—' },
    { key: 'outbound_count', header: 'Out', render: (r: CounterpartyRow) => r.outbound_count },
    { key: 'inbound_count', header: 'In', render: (r: CounterpartyRow) => r.inbound_count },
    { key: 'total_touches', header: 'Touches', render: (r: CounterpartyRow) => r.total_touches },
    { key: 'last_touch_at', header: 'Last touch', render: (r: CounterpartyRow) => new Date(r.last_touch_at).toLocaleString() },
  ];

  const eventCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r: EventRow) => new Date(r.occurred_at).toLocaleString() },
    { key: 'direction', header: 'Direction', render: (r: EventRow) => r.direction },
    { key: 'channel', header: 'Channel', render: (r: EventRow) => r.channel },
    { key: 'counterparty_name', header: 'Counterparty', render: (r: EventRow) => r.counterparty_name },
    { key: 'counterparty_role', header: 'Role', render: (r: EventRow) => r.counterparty_role ?? '—' },
    { key: 'topic', header: 'Topic', render: (r: EventRow) => r.topic },
    { key: 'response_received', header: 'Replied?', render: (r: EventRow) => (r.response_received ? 'yes' : 'no') },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Weekly outreach vs inbound balance
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Outbound (founder reaching out) vs inbound (people reaching out). Healthy founder pipeline keeps
        ratio in the 1:1 to 2:1 band — pull heavy signals demand, push heavy signals hustle mode.
      </p>

      {kpis && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>This week outbound</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis.current_week_outbound}</div>
            <div style={{ fontSize: 12, color: '#666' }}>
              WoW {kpis.outbound_wow_delta_pct ?? '—'}%
            </div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>This week inbound</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis.current_week_inbound}</div>
            <div style={{ fontSize: 12, color: '#666' }}>
              WoW {kpis.inbound_wow_delta_pct ?? '—'}%
            </div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Ratio (out/in)</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis.current_week_ratio ?? '—'}</div>
            <div style={{ fontSize: 12, color: '#666' }}>prior {kpis.prior_week_ratio ?? '—'}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Trailing 4w</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>
              {kpis.trailing_4w_outbound} / {kpis.trailing_4w_inbound}
            </div>
            <div style={{ fontSize: 12, color: '#666' }}>out / in</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Reply rate (30d)</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis.response_rate_pct}%</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Status</div>
            <div style={{ fontSize: 18, fontWeight: 700 }}>{kpis.status}</div>
          </div>
        </div>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Last 12 weeks</h2>
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          emptyMessage="No weekly data yet — log events to see the trend."
          rowKey={(r: WeeklyRow) => r.week_start}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Channel breakdown (this week)</h2>
        <DataTable
          rows={channels}
          columns={channelCols}
          emptyMessage="No channel activity this week."
          rowKey={(r: ChannelRow) => r.channel}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top counterparties (30 days)</h2>
        <DataTable
          rows={counterparties}
          columns={counterpartyCols}
          emptyMessage="No counterparty activity in last 30 days."
          rowKey={(r: CounterpartyRow) => `${r.counterparty_name}-${r.counterparty_role ?? ''}`}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent events</h2>
        <DataTable
          rows={events}
          columns={eventCols}
          emptyMessage="No recent events logged."
          rowKey={(r: EventRow) => r.id}
        />
      </section>
    </div>
  );
}
