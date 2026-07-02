import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderFamilyEventCommitmentTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [upcomingRes, statsRes, conflictsRes, categoriesRes, logRes, riskRes] = await Promise.all([
    sb.rpc('r2301_list_upcoming_events', { p_days_ahead: 90 }),
    sb.rpc('r2301_summary_stats'),
    sb.rpc('r2301_conflict_alerts'),
    sb.rpc('r2301_category_breakdown'),
    sb.rpc('r2301_recent_log', { p_limit: 25 }),
    sb.rpc('r2301_high_risk_misses'),
  ]);

  const upcoming: any[] = (upcomingRes.data as any[]) ?? [];
  const stats: any = Array.isArray(statsRes.data) ? statsRes.data[0] : statsRes.data;
  const conflicts: any[] = (conflictsRes.data as any[]) ?? [];
  const categories: any[] = (categoriesRes.data as any[]) ?? [];
  const logRows: any[] = (logRes.data as any[]) ?? [];
  const risk: any[] = (riskRes.data as any[]) ?? [];

  const upcomingCols: Column<any>[] = [
    { key: 'event_title', header: 'Event', render: (r: any) => r.event_title },
    { key: 'event_category', header: 'Category', render: (r: any) => r.event_category },
    { key: 'family_member_name', header: 'Family member', render: (r: any) => r.family_member_name ?? '-' },
    { key: 'relationship', header: 'Relation', render: (r: any) => r.relationship ?? '-' },
    { key: 'event_date', header: 'Date', render: (r: any) => r.event_date },
    { key: 'days_until', header: 'Days', render: (r: any) => String(r.days_until) },
    { key: 'importance_tier', header: 'Tier', render: (r: any) => r.importance_tier },
    { key: 'founder_commitment_status', header: 'Commit', render: (r: any) => r.founder_commitment_status },
    { key: 'conflict_check_status', header: 'Conflict', render: (r: any) => r.conflict_check_status },
    { key: 'spouse_attending', header: 'Spouse', render: (r: any) => r.spouse_attending === null ? '-' : r.spouse_attending ? 'yes' : 'no' },
    { key: 'guilt_score', header: 'Guilt', render: (r: any) => r.guilt_score ?? '-' },
  ];

  const conflictCols: Column<any>[] = [
    { key: 'event_title', header: 'Event', render: (r: any) => r.event_title },
    { key: 'event_date', header: 'Date', render: (r: any) => r.event_date },
    { key: 'days_until', header: 'Days', render: (r: any) => String(r.days_until) },
    { key: 'importance_tier', header: 'Tier', render: (r: any) => r.importance_tier },
    { key: 'conflict_check_status', header: 'Status', render: (r: any) => r.conflict_check_status },
    { key: 'conflicting_meetings', header: 'Conflicts', render: (r: any) => {
        const arr = Array.isArray(r.conflicting_meetings) ? r.conflicting_meetings : [];
        return arr.length === 0 ? '-' : `${arr.length} meeting(s)`;
      } },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'event_category', header: 'Category', render: (r: any) => r.event_category },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total) },
    { key: 'attended', header: 'Attended', render: (r: any) => String(r.attended) },
    { key: 'missed', header: 'Missed', render: (r: any) => String(r.missed) },
    { key: 'upcoming', header: 'Upcoming', render: (r: any) => String(r.upcoming) },
    { key: 'attend_rate_pct', header: 'Attend %', render: (r: any) => `${r.attend_rate_pct}%` },
  ];

  const riskCols: Column<any>[] = [
    { key: 'event_title', header: 'Event', render: (r: any) => r.event_title },
    { key: 'family_member_name', header: 'Family member', render: (r: any) => r.family_member_name ?? '-' },
    { key: 'relationship', header: 'Relation', render: (r: any) => r.relationship ?? '-' },
    { key: 'importance_tier', header: 'Tier', render: (r: any) => r.importance_tier },
    { key: 'consecutive_misses', header: 'Misses', render: (r: any) => String(r.consecutive_misses) },
    { key: 'guilt_score', header: 'Guilt', render: (r: any) => r.guilt_score ?? '-' },
    { key: 'next_event_date', header: 'Next date', render: (r: any) => r.next_event_date },
  ];

  const logCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => new Date(r.created_at).toLocaleString() },
    { key: 'event_title', header: 'Event', render: (r: any) => r.event_title ?? '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'prior_status', header: 'Prior', render: (r: any) => r.prior_status ?? '-' },
    { key: 'new_status', header: 'New', render: (r: any) => r.new_status ?? '-' },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '-' },
    { key: 'reason', header: 'Reason', render: (r: any) => r.reason ?? '-' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Family-event commitment tracker
      </h1>
      <p style={{ color: '#555', marginBottom: 20, fontSize: 14 }}>
        Anniversaries, school events & family milestones — founder commitments, conflict alerts, attendance ratio.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: 12, marginBottom: 24 }}>
        <StatCard label="Total events" value={stats?.total_events ?? 0} />
        <StatCard label="Upcoming 30d" value={stats?.upcoming_30d ?? 0} />
        <StatCard label="Critical upcoming" value={stats?.critical_upcoming ?? 0} tone="warn" />
        <StatCard label="Committed" value={stats?.committed_count ?? 0} tone="good" />
        <StatCard label="Tentative" value={stats?.tentative_count ?? 0} />
        <StatCard label="Declined" value={stats?.declined_count ?? 0} />
        <StatCard label="Missed (90d)" value={stats?.missed_last_90d ?? 0} tone="bad" />
        <StatCard label="Hard conflicts" value={stats?.hard_conflict_count ?? 0} tone="bad" />
        <StatCard label="Attended rate" value={`${stats?.attended_rate_pct ?? 0}%`} tone="good" />
      </div>

      <Section title="Conflict alerts (soft & hard)">
        <DataTable<any>
          columns={conflictCols}
          rows={conflicts}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="High-risk relationships (consecutive misses >= 2 or guilt >= 7)">
        <DataTable<any>
          columns={riskCols}
          rows={risk}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Upcoming family events (next 90 days)">
        <DataTable<any>
          columns={upcomingCols}
          rows={upcoming}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Category breakdown & attendance">
        <DataTable<any>
          columns={categoryCols}
          rows={categories}
          rowKey={(r: any, i: number) => String(r.event_category ?? i)}
        />
      </Section>

      <Section title="Recent commitment log">
        <DataTable<any>
          columns={logCols}
          rows={logRows}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>
    </div>
  );
}

function StatCard({ label, value, tone }: { label: string; value: any; tone?: 'good' | 'warn' | 'bad' }) {
  const color = tone === 'good' ? '#0a7f3f' : tone === 'warn' ? '#a86b00' : tone === 'bad' ? '#b00020' : '#111';
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, color }}>{String(value)}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
