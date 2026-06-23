import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';
import { redirect } from 'next/navigation';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_callbacks: number;
  met_count: number;
  missed_count: number;
  recovered_count: number;
  pending_count: number;
  met_pct: number | null;
  recovery_pct: number | null;
  avg_response_minutes: number | null;
};

type LeaderRow = {
  engineer_user_id: string;
  engineer_email: string;
  total_callbacks: number;
  met_count: number;
  missed_count: number;
  met_pct: number | null;
  avg_response_minutes: number | null;
};

type OverdueRow = {
  id: string;
  engineer_email: string;
  customer_name: string;
  customer_phone: string;
  reason: string;
  priority: string;
  promised_at: string;
  callback_due_by: string;
  hours_overdue: number;
};

type RecoveryKpis = {
  total_missed: number;
  total_recovered: number;
  acknowledged_count: number;
  apology_count: number;
  avg_hours_late: number | null;
  avg_satisfaction: number | null;
};

type ReasonRow = {
  reason: string;
  total_count: number;
  met_count: number;
  missed_count: number;
  met_pct: number | null;
};

type OffenderRow = {
  engineer_user_id: string;
  engineer_email: string;
  missed_count: number;
  recovered_count: number;
  total_count: number;
  miss_rate_pct: number | null;
};

type RecoveryEventRow = {
  recovery_id: string;
  engineer_email: string;
  customer_name: string;
  reason: string;
  hours_late: number;
  recovery_channel: string;
  customer_acknowledged: boolean;
  customer_satisfaction: number | null;
  apology_offered: boolean;
  recovered_at: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/login');
  const email = user.email ?? '';
  const FOUNDER = process.env.NEXT_PUBLIC_FOUNDER_EMAIL ?? 'founder@equipseva.com';
  if (email !== FOUNDER) redirect('/');

  const [kpisRes, leaderRes, overdueRes, recRes, reasonRes, offRes, evtRes] = await Promise.all([
    supabase.rpc('r2386_callback_discipline_kpis', { p_days: 30 }),
    supabase.rpc('r2386_engineer_callback_leaderboard', { p_days: 30 }),
    supabase.rpc('r2386_overdue_callbacks'),
    supabase.rpc('r2386_recovery_analytics', { p_days: 30 }),
    supabase.rpc('r2386_callback_breakdown_by_reason', { p_days: 30 }),
    supabase.rpc('r2386_repeat_offenders', { p_days: 30, p_threshold: 3 }),
    supabase.rpc('r2386_recent_recovery_events', { p_limit: 50 }),
  ]);

  const kpis = (kpisRes.data?.[0] ?? null) as Kpis | null;
  const leader = (leaderRes.data ?? []) as LeaderRow[];
  const overdue = (overdueRes.data ?? []) as OverdueRow[];
  const rec = (recRes.data?.[0] ?? null) as RecoveryKpis | null;
  const reasons = (reasonRes.data ?? []) as ReasonRow[];
  const offenders = (offRes.data ?? []) as OffenderRow[];
  const events = (evtRes.data ?? []) as RecoveryEventRow[];

  const leaderCols: Column<LeaderRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: LeaderRow) => r.engineer_email },
    { key: 'total_callbacks', header: 'Total', render: (r: LeaderRow) => String(r.total_callbacks) },
    { key: 'met_count', header: 'Met', render: (r: LeaderRow) => String(r.met_count) },
    { key: 'missed_count', header: 'Missed', render: (r: LeaderRow) => String(r.missed_count) },
    { key: 'met_pct', header: 'Met %', render: (r: LeaderRow) => r.met_pct == null ? '—' : `${r.met_pct}%` },
    { key: 'avg_response_minutes', header: 'Avg resp (min)', render: (r: LeaderRow) => r.avg_response_minutes == null ? '—' : String(r.avg_response_minutes) },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: OverdueRow) => r.engineer_email },
    { key: 'customer_name', header: 'Customer', render: (r: OverdueRow) => r.customer_name },
    { key: 'customer_phone', header: 'Phone', render: (r: OverdueRow) => r.customer_phone },
    { key: 'reason', header: 'Reason', render: (r: OverdueRow) => r.reason },
    { key: 'priority', header: 'Priority', render: (r: OverdueRow) => r.priority },
    { key: 'callback_due_by', header: 'Due', render: (r: OverdueRow) => new Date(r.callback_due_by).toLocaleString() },
    { key: 'hours_overdue', header: 'Hrs overdue', render: (r: OverdueRow) => String(r.hours_overdue) },
  ];

  const reasonCols: Column<ReasonRow>[] = [
    { key: 'reason', header: 'Reason', render: (r: ReasonRow) => r.reason },
    { key: 'total_count', header: 'Total', render: (r: ReasonRow) => String(r.total_count) },
    { key: 'met_count', header: 'Met', render: (r: ReasonRow) => String(r.met_count) },
    { key: 'missed_count', header: 'Missed', render: (r: ReasonRow) => String(r.missed_count) },
    { key: 'met_pct', header: 'Met %', render: (r: ReasonRow) => r.met_pct == null ? '—' : `${r.met_pct}%` },
  ];

  const offenderCols: Column<OffenderRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: OffenderRow) => r.engineer_email },
    { key: 'missed_count', header: 'Missed', render: (r: OffenderRow) => String(r.missed_count) },
    { key: 'recovered_count', header: 'Recovered', render: (r: OffenderRow) => String(r.recovered_count) },
    { key: 'total_count', header: 'Total', render: (r: OffenderRow) => String(r.total_count) },
    { key: 'miss_rate_pct', header: 'Miss rate %', render: (r: OffenderRow) => r.miss_rate_pct == null ? '—' : `${r.miss_rate_pct}%` },
  ];

  const eventCols: Column<RecoveryEventRow>[] = [
    { key: 'recovered_at', header: 'Recovered at', render: (r: RecoveryEventRow) => new Date(r.recovered_at).toLocaleString() },
    { key: 'engineer_email', header: 'Engineer', render: (r: RecoveryEventRow) => r.engineer_email },
    { key: 'customer_name', header: 'Customer', render: (r: RecoveryEventRow) => r.customer_name },
    { key: 'reason', header: 'Reason', render: (r: RecoveryEventRow) => r.reason },
    { key: 'hours_late', header: 'Hrs late', render: (r: RecoveryEventRow) => String(r.hours_late) },
    { key: 'recovery_channel', header: 'Channel', render: (r: RecoveryEventRow) => r.recovery_channel },
    { key: 'customer_acknowledged', header: 'Ack', render: (r: RecoveryEventRow) => r.customer_acknowledged ? 'yes' : 'no' },
    { key: 'customer_satisfaction', header: 'CSAT', render: (r: RecoveryEventRow) => r.customer_satisfaction == null ? '—' : `${r.customer_satisfaction}/5` },
    { key: 'apology_offered', header: 'Apology', render: (r: RecoveryEventRow) => r.apology_offered ? 'yes' : 'no' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>Engineer Customer-Callback Discipline</h1>
      <p style={{ color: '#555', marginBottom: 18 }}>
        Did the engineer call the customer back within the promised time? Track met %, missed callbacks, recovery events, and repeat offenders across the last 30 days.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Total callbacks</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis?.total_callbacks ?? 0}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Met %</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis?.met_pct == null ? '—' : `${kpis.met_pct}%`}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Missed</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis?.missed_count ?? 0}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Recovered</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis?.recovered_count ?? 0}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Recovery %</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis?.recovery_pct == null ? '—' : `${kpis.recovery_pct}%`}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Avg response (min)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis?.avg_response_minutes ?? '—'}</div>
        </div>
        <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#777' }}>Pending</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpis?.pending_count ?? 0}</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Currently overdue</h2>
        <DataTable<OverdueRow>
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No overdue callbacks. Engineers are on top of it."
          rowKey={(r: OverdueRow) => r.id}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Engineer leaderboard (30d)</h2>
        <DataTable<LeaderRow>
          rows={leader}
          columns={leaderCols}
          emptyMessage="No engineer callback data in the last 30 days."
          rowKey={(r: LeaderRow) => r.engineer_user_id}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Repeat offenders (3+ misses, 30d)</h2>
        <DataTable<OffenderRow>
          rows={offenders}
          columns={offenderCols}
          emptyMessage="No repeat offenders in the last 30 days."
          rowKey={(r: OffenderRow) => r.engineer_user_id}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Breakdown by reason (30d)</h2>
        <DataTable<ReasonRow>
          rows={reasons}
          columns={reasonCols}
          emptyMessage="No reason breakdown available."
          rowKey={(r: ReasonRow) => r.reason}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recovery analytics (30d)</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
          <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#777' }}>Total missed</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{rec?.total_missed ?? 0}</div>
          </div>
          <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#777' }}>Total recovered</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{rec?.total_recovered ?? 0}</div>
          </div>
          <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#777' }}>Customer ack'd</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{rec?.acknowledged_count ?? 0}</div>
          </div>
          <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#777' }}>Apology offered</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{rec?.apology_count ?? 0}</div>
          </div>
          <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#777' }}>Avg hours late</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{rec?.avg_hours_late ?? '—'}</div>
          </div>
          <div style={{ padding: 14, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#777' }}>Avg CSAT</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{rec?.avg_satisfaction ?? '—'}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent recovery events</h2>
        <DataTable<RecoveryEventRow>
          rows={events}
          columns={eventCols}
          emptyMessage="No recovery events logged yet."
          rowKey={(r: RecoveryEventRow) => r.recovery_id}
        />
      </section>
    </div>
  );
}
