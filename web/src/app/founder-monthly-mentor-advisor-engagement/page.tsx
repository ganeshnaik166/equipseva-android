import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_sessions_month: number | null;
  total_minutes_invested: number | null;
  avg_value_score: number | null;
  open_followups: number | null;
  inner_circle_count: number | null;
};

type Session = {
  id: string;
  mentor_name: string;
  mentor_role: string;
  topic: string;
  session_date: string;
  time_invested_minutes: number;
  value_score: number;
  follow_up_status: string;
};

type Followup = {
  id: string;
  mentor_name: string;
  topic: string;
  follow_up_action: string;
  follow_up_due_date: string | null;
  follow_up_status: string;
  days_until_due: number | null;
};

type Roster = {
  id: string;
  mentor_name: string;
  affiliation: string;
  expertise_area: string;
  relationship_depth: string;
  cadence_target_per_quarter: number;
  last_touch_date: string | null;
  next_touch_planned_date: string | null;
  days_since_touch: number | null;
};

type TopicValue = {
  topic: string;
  session_count: number;
  total_minutes: number;
  avg_value_score: number;
};

type HighValue = {
  id: string;
  mentor_name: string;
  topic: string;
  value_score: number;
  key_insight: string;
  deepen_relationship_action: string;
};

type Health = {
  relationship_depth: string;
  mentor_count: number;
  avg_days_since_touch: number | null;
};

type CadenceRisk = {
  mentor_name: string;
  relationship_depth: string;
  days_since_touch: number | null;
  next_touch_planned_date: string | null;
  risk_label: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpisRes,
    sessionsRes,
    followupsRes,
    rosterRes,
    topicsRes,
    highValueRes,
    healthRes,
    cadenceRes,
  ] = await Promise.all([
    supabase.rpc('founder_mentor_kpis_r2701'),
    supabase.rpc('founder_mentor_sessions_list_r2701'),
    supabase.rpc('founder_mentor_open_followups_r2701'),
    supabase.rpc('founder_mentor_roster_list_r2701'),
    supabase.rpc('founder_mentor_topic_value_r2701'),
    supabase.rpc('founder_mentor_high_value_sessions_r2701'),
    supabase.rpc('founder_mentor_relationship_health_r2701'),
    supabase.rpc('founder_mentor_cadence_risk_r2701'),
  ]);

  const kpis: Kpis = (kpisRes.data?.[0] ?? {}) as Kpis;
  const sessions: Session[] = (sessionsRes.data ?? []) as Session[];
  const followups: Followup[] = (followupsRes.data ?? []) as Followup[];
  const roster: Roster[] = (rosterRes.data ?? []) as Roster[];
  const topics: TopicValue[] = (topicsRes.data ?? []) as TopicValue[];
  const highValue: HighValue[] = (highValueRes.data ?? []) as HighValue[];
  const health: Health[] = (healthRes.data ?? []) as Health[];
  const cadence: CadenceRisk[] = (cadenceRes.data ?? []) as CadenceRisk[];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
          Monthly Mentor & Advisor Engagement
        </h1>
        <p style={{ color: '#6b7280', fontSize: 14 }}>
          Mentor × topic × time invested × value × follow-up × deepen-relationship action.
          Track sessions, surface high-value insight, and protect cadence with inner-circle advisors.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <KpiCard label="Sessions this month" value={String(kpis.total_sessions_month ?? 0)} />
        <KpiCard label="Minutes invested" value={String(kpis.total_minutes_invested ?? 0)} />
        <KpiCard label="Avg value score" value={String(kpis.avg_value_score ?? 0)} suffix=" / 10" />
        <KpiCard label="Open follow-ups" value={String(kpis.open_followups ?? 0)} />
        <KpiCard label="Inner circle" value={String(kpis.inner_circle_count ?? 0)} />
      </section>

      <Section title="Open follow-ups" subtitle="Action commitments still owed back to mentors">
        <DataTable
          rows={followups}
          columns={[
            { key: 'mentor_name', header: 'Mentor', render: (r: Followup) => r.mentor_name },
            { key: 'topic', header: 'Topic', render: (r: Followup) => r.topic },
            { key: 'follow_up_action', header: 'Action', render: (r: Followup) => r.follow_up_action },
            { key: 'follow_up_due_date', header: 'Due', render: (r: Followup) => r.follow_up_due_date ?? '—' },
            { key: 'days_until_due', header: 'Days left', render: (r: Followup) => r.days_until_due ?? '—' },
            { key: 'follow_up_status', header: 'Status', render: (r: Followup) => r.follow_up_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: Followup, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="High-value sessions" subtitle="Value score 8 and above — re-read these insights weekly">
        <DataTable
          rows={highValue}
          columns={[
            { key: 'mentor_name', header: 'Mentor', render: (r: HighValue) => r.mentor_name },
            { key: 'topic', header: 'Topic', render: (r: HighValue) => r.topic },
            { key: 'value_score', header: 'Value', render: (r: HighValue) => `${r.value_score} / 10` },
            { key: 'key_insight', header: 'Key insight', render: (r: HighValue) => r.key_insight },
            { key: 'deepen_relationship_action', header: 'Deepen relationship', render: (r: HighValue) => r.deepen_relationship_action },
          ]}
          emptyMessage="No data"
          rowKey={(r: HighValue, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="All sessions" subtitle="Reverse chronological session log">
        <DataTable
          rows={sessions}
          columns={[
            { key: 'session_date', header: 'Date', render: (r: Session) => r.session_date },
            { key: 'mentor_name', header: 'Mentor', render: (r: Session) => r.mentor_name },
            { key: 'mentor_role', header: 'Role', render: (r: Session) => r.mentor_role },
            { key: 'topic', header: 'Topic', render: (r: Session) => r.topic },
            { key: 'time_invested_minutes', header: 'Minutes', render: (r: Session) => r.time_invested_minutes },
            { key: 'value_score', header: 'Value', render: (r: Session) => `${r.value_score} / 10` },
            { key: 'follow_up_status', header: 'Follow-up', render: (r: Session) => r.follow_up_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: Session, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Mentor roster" subtitle="Relationship depth and planned cadence">
        <DataTable
          rows={roster}
          columns={[
            { key: 'mentor_name', header: 'Mentor', render: (r: Roster) => r.mentor_name },
            { key: 'affiliation', header: 'Affiliation', render: (r: Roster) => r.affiliation },
            { key: 'expertise_area', header: 'Expertise', render: (r: Roster) => r.expertise_area },
            { key: 'relationship_depth', header: 'Depth', render: (r: Roster) => r.relationship_depth },
            { key: 'cadence_target_per_quarter', header: 'Cadence / Q', render: (r: Roster) => r.cadence_target_per_quarter },
            { key: 'last_touch_date', header: 'Last touch', render: (r: Roster) => r.last_touch_date ?? '—' },
            { key: 'days_since_touch', header: 'Days since', render: (r: Roster) => r.days_since_touch ?? '—' },
            { key: 'next_touch_planned_date', header: 'Next planned', render: (r: Roster) => r.next_touch_planned_date ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Roster, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Topic value mix" subtitle="Where the highest-value conversations are landing">
        <DataTable
          rows={topics}
          columns={[
            { key: 'topic', header: 'Topic', render: (r: TopicValue) => r.topic },
            { key: 'session_count', header: 'Sessions', render: (r: TopicValue) => r.session_count },
            { key: 'total_minutes', header: 'Minutes', render: (r: TopicValue) => r.total_minutes },
            { key: 'avg_value_score', header: 'Avg value', render: (r: TopicValue) => `${r.avg_value_score} / 10` },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopicValue, i: number) => String(r.topic ?? i)}
        />
      </Section>

      <Section title="Relationship health by depth" subtitle="Average days since last touch by relationship tier">
        <DataTable
          rows={health}
          columns={[
            { key: 'relationship_depth', header: 'Depth', render: (r: Health) => r.relationship_depth },
            { key: 'mentor_count', header: 'Mentors', render: (r: Health) => r.mentor_count },
            { key: 'avg_days_since_touch', header: 'Avg days since touch', render: (r: Health) => r.avg_days_since_touch ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Health, i: number) => String(r.relationship_depth ?? i)}
        />
      </Section>

      <Section title="Cadence risk" subtitle="Stale relationships needing a re-warm touch">
        <DataTable
          rows={cadence}
          columns={[
            { key: 'mentor_name', header: 'Mentor', render: (r: CadenceRisk) => r.mentor_name },
            { key: 'relationship_depth', header: 'Depth', render: (r: CadenceRisk) => r.relationship_depth },
            { key: 'days_since_touch', header: 'Days since', render: (r: CadenceRisk) => r.days_since_touch ?? '—' },
            { key: 'next_touch_planned_date', header: 'Next planned', render: (r: CadenceRisk) => r.next_touch_planned_date ?? '—' },
            { key: 'risk_label', header: 'Risk', render: (r: CadenceRisk) => r.risk_label },
          ]}
          emptyMessage="No data"
          rowKey={(r: CadenceRisk, i: number) => String(r.mentor_name ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value, suffix }: { label: string; value: string; suffix?: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 10, padding: 14, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 6 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>
        {value}
        {suffix ? <span style={{ fontSize: 14, color: '#6b7280', fontWeight: 500 }}>{suffix}</span> : null}
      </div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <div style={{ marginBottom: 10 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>{title}</h2>
        <p style={{ fontSize: 13, color: '#6b7280' }}>{subtitle}</p>
      </div>
      {children}
    </section>
  );
}
