import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RosterRow = {
  coach_name: string;
  coach_firm: string;
  specialty: string;
  monthly_retainer_rupees: number;
  engagement_status: string;
  total_sessions_held: number;
  founder_rated_value: string;
  continue_next_quarter: boolean;
};

type SpendRow = {
  active_coaches: number;
  paused_coaches: number;
  ended_coaches: number;
  monthly_spend_rupees: number;
  quarterly_spend_rupees: number;
};

type ValueRow = {
  founder_rated_value: string;
  coach_count: number;
  monthly_spend_rupees: number;
};

type TopicRow = {
  topic: string;
  session_count: number;
  avg_rating: number;
  avg_actions_executed: number;
};

type SessionRow = {
  session_date: string;
  coach_name: string;
  topic: string;
  duration_minutes: number;
  actionable_count: number;
  actions_executed: number;
  founder_rating: number;
  followup_required: boolean;
};

type DecisionRow = {
  coach_name: string;
  specialty: string;
  founder_rated_value: string;
  total_sessions_held: number;
  continue_next_quarter: boolean;
  decision_rationale: string;
};

type ActionabilityRow = {
  total_sessions: number;
  total_actionables: number;
  total_executed: number;
  execution_rate_pct: number;
  avg_rating: number;
  followups_open: number;
};

type RoiRow = {
  coach_name: string;
  sessions_held: number;
  avg_rating: number;
  actions_executed: number;
  monthly_retainer_rupees: number;
  cost_per_executed_action_rupees: number;
};

function rupees(paise: number | null | undefined): string {
  if (!paise) return '₹0';
  return '₹' + (paise / 100).toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [roster, spend, value, topics, sessions, decisions, actionability, roi] = await Promise.all([
    supabase.rpc('founder_r2793_coach_roster'),
    supabase.rpc('founder_r2793_spend_summary'),
    supabase.rpc('founder_r2793_value_distribution'),
    supabase.rpc('founder_r2793_topic_frequency'),
    supabase.rpc('founder_r2793_recent_sessions'),
    supabase.rpc('founder_r2793_continue_decisions'),
    supabase.rpc('founder_r2793_actionability_kpis'),
    supabase.rpc('founder_r2793_coach_roi'),
  ]);

  const rosterRows: RosterRow[] = (roster.data as RosterRow[]) ?? [];
  const spendRow: SpendRow = ((spend.data as SpendRow[]) ?? [])[0] ?? {
    active_coaches: 0,
    paused_coaches: 0,
    ended_coaches: 0,
    monthly_spend_rupees: 0,
    quarterly_spend_rupees: 0,
  };
  const valueRows: ValueRow[] = (value.data as ValueRow[]) ?? [];
  const topicRows: TopicRow[] = (topics.data as TopicRow[]) ?? [];
  const sessionRows: SessionRow[] = (sessions.data as SessionRow[]) ?? [];
  const decisionRows: DecisionRow[] = (decisions.data as DecisionRow[]) ?? [];
  const actionabilityRow: ActionabilityRow = ((actionability.data as ActionabilityRow[]) ?? [])[0] ?? {
    total_sessions: 0,
    total_actionables: 0,
    total_executed: 0,
    execution_rate_pct: 0,
    avg_rating: 0,
    followups_open: 0,
  };
  const roiRows: RoiRow[] = (roi.data as RoiRow[]) ?? [];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '4px' }}>
          Quarterly Executive Coach Engagement
        </h1>
        <p style={{ color: '#6b7280', fontSize: '14px' }}>
          Round r2793 — coach × topic × frequency × value × actionable × continue/end
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <KpiCard label="Active Coaches" value={String(spendRow.active_coaches)} />
        <KpiCard label="Paused" value={String(spendRow.paused_coaches)} />
        <KpiCard label="Ended" value={String(spendRow.ended_coaches)} />
        <KpiCard label="Monthly Spend" value={rupees(spendRow.monthly_spend_rupees)} />
        <KpiCard label="Quarterly Spend" value={rupees(spendRow.quarterly_spend_rupees)} />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <KpiCard label="Total Sessions" value={String(actionabilityRow.total_sessions)} />
        <KpiCard label="Actionables Captured" value={String(actionabilityRow.total_actionables)} />
        <KpiCard label="Actions Executed" value={String(actionabilityRow.total_executed)} />
        <KpiCard label="Execution Rate" value={String(actionabilityRow.execution_rate_pct) + '%'} />
        <KpiCard label="Avg Rating" value={String(actionabilityRow.avg_rating) + ' / 5'} />
        <KpiCard label="Open Follow-ups" value={String(actionabilityRow.followups_open)} />
      </section>

      <Section title="Coach Roster">
        <DataTable
          rows={rosterRows}
          columns={[
            { key: 'coach_name', header: 'Coach', render: (r: RosterRow) => r.coach_name },
            { key: 'coach_firm', header: 'Firm', render: (r: RosterRow) => r.coach_firm },
            { key: 'specialty', header: 'Specialty', render: (r: RosterRow) => r.specialty },
            { key: 'monthly_retainer_rupees', header: 'Monthly Retainer', render: (r: RosterRow) => rupees(r.monthly_retainer_rupees) },
            { key: 'engagement_status', header: 'Status', render: (r: RosterRow) => r.engagement_status },
            { key: 'total_sessions_held', header: 'Sessions', render: (r: RosterRow) => String(r.total_sessions_held) },
            { key: 'founder_rated_value', header: 'Value', render: (r: RosterRow) => r.founder_rated_value },
            { key: 'continue_next_quarter', header: 'Continue?', render: (r: RosterRow) => (r.continue_next_quarter ? 'yes' : 'no') },
          ]}
          emptyMessage="No coaches"
          rowKey={(r: RosterRow, i: number) => String(r.coach_name ?? i)}
        />
      </Section>

      <Section title="Value Distribution">
        <DataTable
          rows={valueRows}
          columns={[
            { key: 'founder_rated_value', header: 'Rated Value', render: (r: ValueRow) => r.founder_rated_value },
            { key: 'coach_count', header: 'Coaches', render: (r: ValueRow) => String(r.coach_count) },
            { key: 'monthly_spend_rupees', header: 'Monthly Spend', render: (r: ValueRow) => rupees(r.monthly_spend_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ValueRow, i: number) => String(r.founder_rated_value ?? i)}
        />
      </Section>

      <Section title="Topic Frequency & Outcomes">
        <DataTable
          rows={topicRows}
          columns={[
            { key: 'topic', header: 'Topic', render: (r: TopicRow) => r.topic },
            { key: 'session_count', header: 'Sessions', render: (r: TopicRow) => String(r.session_count) },
            { key: 'avg_rating', header: 'Avg Rating', render: (r: TopicRow) => String(r.avg_rating) },
            { key: 'avg_actions_executed', header: 'Avg Actions Done', render: (r: TopicRow) => String(r.avg_actions_executed) },
          ]}
          emptyMessage="No sessions"
          rowKey={(r: TopicRow, i: number) => String(r.topic ?? i)}
        />
      </Section>

      <Section title="Recent Sessions">
        <DataTable
          rows={sessionRows}
          columns={[
            { key: 'session_date', header: 'Date', render: (r: SessionRow) => r.session_date },
            { key: 'coach_name', header: 'Coach', render: (r: SessionRow) => r.coach_name },
            { key: 'topic', header: 'Topic', render: (r: SessionRow) => r.topic },
            { key: 'duration_minutes', header: 'Minutes', render: (r: SessionRow) => String(r.duration_minutes) },
            { key: 'actionable_count', header: 'Actionables', render: (r: SessionRow) => String(r.actionable_count) },
            { key: 'actions_executed', header: 'Executed', render: (r: SessionRow) => String(r.actions_executed) },
            { key: 'founder_rating', header: 'Rating', render: (r: SessionRow) => String(r.founder_rating) + ' / 5' },
            { key: 'followup_required', header: 'Follow-up?', render: (r: SessionRow) => (r.followup_required ? 'yes' : 'no') },
          ]}
          emptyMessage="No sessions"
          rowKey={(r: SessionRow, i: number) => String(r.session_date + r.coach_name) + String(i)}
        />
      </Section>

      <Section title="Continue vs End Decisions">
        <DataTable
          rows={decisionRows}
          columns={[
            { key: 'coach_name', header: 'Coach', render: (r: DecisionRow) => r.coach_name },
            { key: 'specialty', header: 'Specialty', render: (r: DecisionRow) => r.specialty },
            { key: 'founder_rated_value', header: 'Value', render: (r: DecisionRow) => r.founder_rated_value },
            { key: 'total_sessions_held', header: 'Sessions', render: (r: DecisionRow) => String(r.total_sessions_held) },
            { key: 'continue_next_quarter', header: 'Continue?', render: (r: DecisionRow) => (r.continue_next_quarter ? 'yes' : 'no') },
            { key: 'decision_rationale', header: 'Rationale', render: (r: DecisionRow) => r.decision_rationale },
          ]}
          emptyMessage="No decisions"
          rowKey={(r: DecisionRow, i: number) => String(r.coach_name ?? i)}
        />
      </Section>

      <Section title="ROI per Coach">
        <DataTable
          rows={roiRows}
          columns={[
            { key: 'coach_name', header: 'Coach', render: (r: RoiRow) => r.coach_name },
            { key: 'sessions_held', header: 'Sessions', render: (r: RoiRow) => String(r.sessions_held) },
            { key: 'avg_rating', header: 'Avg Rating', render: (r: RoiRow) => String(r.avg_rating) },
            { key: 'actions_executed', header: 'Actions Done', render: (r: RoiRow) => String(r.actions_executed) },
            { key: 'monthly_retainer_rupees', header: 'Retainer', render: (r: RoiRow) => rupees(r.monthly_retainer_rupees) },
            { key: 'cost_per_executed_action_rupees', header: 'Cost per Action', render: (r: RoiRow) => rupees(r.cost_per_executed_action_rupees) },
          ]}
          emptyMessage="No ROI rows"
          rowKey={(r: RoiRow, i: number) => String(r.coach_name ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ padding: '16px', background: '#f9fafb', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
      <div style={{ fontSize: '12px', color: '#6b7280', marginBottom: '4px' }}>{label}</div>
      <div style={{ fontSize: '20px', fontWeight: 600, color: '#111827' }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '32px' }}>
      <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>{title}</h2>
      {children}
    </section>
  );
}
