import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_calls: number;
  picked_up: number;
  missed: number;
  rejected: number;
  voicemail: number;
  pickup_rate_pct: number | null;
  median_answer_secs: number | null;
  p90_answer_secs: number | null;
  urgent_missed: number;
};

type LeaderRow = {
  engineer_id: string;
  engineer_email: string;
  total_calls: number;
  picked_up: number;
  missed: number;
  pickup_rate_pct: number | null;
  median_answer_secs: number | null;
  urgent_missed: number;
};

type DailyRow = {
  day: string;
  total_calls: number;
  picked_up: number;
  missed: number;
  pickup_rate_pct: number | null;
};

type OpenRow = {
  call_attempt_id: string;
  engineer_email: string;
  rang_at: string;
  outcome: string;
  priority: string;
  job_ref: string | null;
  followup_status: string;
  hours_open: number;
};

type RecentRow = {
  call_id: string;
  engineer_email: string;
  caller_role: string;
  rang_at: string;
  outcome: string;
  priority: string;
  ring_duration_seconds: number | null;
  call_duration_seconds: number | null;
  job_ref: string | null;
};

type FollowupRow = {
  followup_kind: string;
  total_attempts: number;
  resolved_count: number;
  resolution_rate_pct: number | null;
  avg_resolve_hours: number | null;
};

type PriorityRow = {
  priority: string;
  total_calls: number;
  picked_up: number;
  missed: number;
  pickup_rate_pct: number | null;
  median_answer_secs: number | null;
};

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return `${Number(n).toFixed(1)}%`;
}

function fmtSecs(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return `${Number(n).toFixed(1)}s`;
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  return new Date(s).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [ovRes, ldRes, dlRes, opRes, rcRes, fuRes, prRes] = await Promise.all([
    sb.rpc('r2270_pickup_overview', { days: 30 }),
    sb.rpc('r2270_engineer_pickup_leaderboard', { days: 30 }),
    sb.rpc('r2270_daily_pickup_trend', { days: 14 }),
    sb.rpc('r2270_open_missed_calls', { lim: 50 }),
    sb.rpc('r2270_recent_calls', { lim: 50 }),
    sb.rpc('r2270_followup_effectiveness', { days: 30 }),
    sb.rpc('r2270_pickup_by_priority', { days: 30 }),
  ]);

  const ov = (ovRes.data?.[0] ?? null) as Overview | null;
  const leaders = (ldRes.data ?? []) as LeaderRow[];
  const daily = (dlRes.data ?? []) as DailyRow[];
  const open = (opRes.data ?? []) as OpenRow[];
  const recent = (rcRes.data ?? []) as RecentRow[];
  const fu = (fuRes.data ?? []) as FollowupRow[];
  const pr = (prRes.data ?? []) as PriorityRow[];

  const leaderCols: Column<LeaderRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email },
    { key: 'total_calls', header: 'Calls', render: (r) => r.total_calls },
    { key: 'picked_up', header: 'Picked', render: (r) => r.picked_up },
    { key: 'missed', header: 'Missed', render: (r) => r.missed },
    { key: 'pickup_rate_pct', header: 'Pickup %', render: (r) => fmtPct(r.pickup_rate_pct) },
    { key: 'median_answer_secs', header: 'Median answer', render: (r) => fmtSecs(r.median_answer_secs) },
    { key: 'urgent_missed', header: 'Urgent missed', render: (r) => r.urgent_missed },
  ];

  const dailyCols: Column<DailyRow>[] = [
    { key: 'day', header: 'Day (IST)', render: (r) => r.day },
    { key: 'total_calls', header: 'Calls', render: (r) => r.total_calls },
    { key: 'picked_up', header: 'Picked', render: (r) => r.picked_up },
    { key: 'missed', header: 'Missed', render: (r) => r.missed },
    { key: 'pickup_rate_pct', header: 'Pickup %', render: (r) => fmtPct(r.pickup_rate_pct) },
  ];

  const openCols: Column<OpenRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email },
    { key: 'rang_at', header: 'Rang', render: (r) => fmtDate(r.rang_at) },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
    { key: 'priority', header: 'Priority', render: (r) => r.priority },
    { key: 'job_ref', header: 'Job', render: (r) => r.job_ref ?? '—' },
    { key: 'followup_status', header: 'Follow-up', render: (r) => r.followup_status },
    { key: 'hours_open', header: 'Hours open', render: (r) => `${Number(r.hours_open).toFixed(1)}h` },
  ];

  const recentCols: Column<RecentRow>[] = [
    { key: 'rang_at', header: 'Rang', render: (r) => fmtDate(r.rang_at) },
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email },
    { key: 'caller_role', header: 'Caller', render: (r) => r.caller_role },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
    { key: 'priority', header: 'Priority', render: (r) => r.priority },
    { key: 'ring_duration_seconds', header: 'Ring', render: (r) => fmtSecs(r.ring_duration_seconds) },
    { key: 'call_duration_seconds', header: 'Talk', render: (r) => fmtSecs(r.call_duration_seconds) },
    { key: 'job_ref', header: 'Job', render: (r) => r.job_ref ?? '—' },
  ];

  const fuCols: Column<FollowupRow>[] = [
    { key: 'followup_kind', header: 'Kind', render: (r) => r.followup_kind },
    { key: 'total_attempts', header: 'Attempts', render: (r) => r.total_attempts },
    { key: 'resolved_count', header: 'Resolved', render: (r) => r.resolved_count },
    { key: 'resolution_rate_pct', header: 'Resolve %', render: (r) => fmtPct(r.resolution_rate_pct) },
    { key: 'avg_resolve_hours', header: 'Avg resolve hrs', render: (r) => r.avg_resolve_hours === null ? '—' : `${Number(r.avg_resolve_hours).toFixed(1)}h` },
  ];

  const prCols: Column<PriorityRow>[] = [
    { key: 'priority', header: 'Priority', render: (r) => r.priority },
    { key: 'total_calls', header: 'Calls', render: (r) => r.total_calls },
    { key: 'picked_up', header: 'Picked', render: (r) => r.picked_up },
    { key: 'missed', header: 'Missed', render: (r) => r.missed },
    { key: 'pickup_rate_pct', header: 'Pickup %', render: (r) => fmtPct(r.pickup_rate_pct) },
    { key: 'median_answer_secs', header: 'Median answer', render: (r) => fmtSecs(r.median_answer_secs) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>
        Engineer call-center pickup-rate tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>
        When engineer phones ring, are they picked up? Pickup %, time-to-answer, and missed-call follow-up log.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KPI label="Total calls (30d)" value={ov?.total_calls ?? 0} />
        <KPI label="Pickup rate" value={fmtPct(ov?.pickup_rate_pct ?? null)} />
        <KPI label="Picked up" value={ov?.picked_up ?? 0} />
        <KPI label="Missed" value={ov?.missed ?? 0} />
        <KPI label="Rejected" value={ov?.rejected ?? 0} />
        <KPI label="Median answer" value={fmtSecs(ov?.median_answer_secs ?? null)} />
        <KPI label="P90 answer" value={fmtSecs(ov?.p90_answer_secs ?? null)} />
        <KPI label="Urgent missed" value={ov?.urgent_missed ?? 0} tone={(ov?.urgent_missed ?? 0) > 0 ? 'warn' : 'ok'} />
      </section>

      <Section title="Engineer leaderboard (lowest pickup % first, last 30d)">
        <DataTable columns={leaderCols} rows={leaders} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Daily pickup trend (last 14d, IST)">
        <DataTable columns={dailyCols} rows={daily} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Open missed calls (unresolved follow-up)">
        <DataTable columns={openCols} rows={open} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Pickup by priority band (last 30d)">
        <DataTable columns={prCols} rows={pr} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Follow-up effectiveness (last 30d)">
        <DataTable columns={fuCols} rows={fu} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Recent calls (latest 50)">
        <DataTable columns={recentCols} rows={recent} rowKey={(_, i) => String(i)} />
      </Section>
    </main>
  );
}

function KPI({ label, value, tone }: { label: string; value: string | number; tone?: 'ok' | 'warn' }) {
  const bg = tone === 'warn' ? '#fff4e5' : '#f5f7fa';
  const fg = tone === 'warn' ? '#a15c00' : '#222';
  return (
    <div style={{ background: bg, border: '1px solid #e3e6eb', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', color: '#666', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color: fg, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 15, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      {children}
    </section>
  );
}
