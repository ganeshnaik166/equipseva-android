import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_sessions: number;
  avg_rating: number;
  on_track: number;
  at_risk: number;
  blocked: number;
  escalate: number;
  exceeded: number;
};

type Session = {
  id: string;
  team_member: string;
  role: string;
  meeting_cadence: string;
  depth_level: string;
  topic: string;
  commitment: string;
  outcome: string;
  verdict: string;
  session_date: string;
  duration_minutes: number;
  next_session_date: string | null;
  founder_rating: number;
};

type Cadence = {
  meeting_cadence: string;
  sessions: number;
  avg_rating: number;
  escalations: number;
};

type CommitmentOverview = {
  total: number;
  completed: number;
  in_progress: number;
  missed: number;
  deferred: number;
  pending: number;
  avg_completion: number;
};

type Commitment = {
  id: string;
  team_member: string;
  commitment_text: string;
  due_date: string;
  status: string;
  impact_area: string;
  completion_percent: number;
  blocker: string | null;
};

type ImpactArea = {
  impact_area: string;
  count: number;
  avg_completion: number;
  missed: number;
};

type Scorecard = {
  team_member: string;
  sessions: number;
  avg_rating: number;
  commitments: number;
  completed: number;
  completion_rate: number;
};

type Upcoming = {
  team_member: string;
  role: string;
  meeting_cadence: string;
  next_session_date: string;
  last_verdict: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    sessionsRes,
    cadenceRes,
    commitmentOverviewRes,
    atRiskRes,
    impactRes,
    scorecardRes,
    upcomingRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2869_session_overview'),
    supabase.rpc('founder_r2869_recent_sessions'),
    supabase.rpc('founder_r2869_cadence_breakdown'),
    supabase.rpc('founder_r2869_commitment_overview'),
    supabase.rpc('founder_r2869_commitments_at_risk'),
    supabase.rpc('founder_r2869_impact_area_breakdown'),
    supabase.rpc('founder_r2869_member_scorecard'),
    supabase.rpc('founder_r2869_upcoming_sessions'),
  ]);

  const overview: Overview | null =
    overviewRes.data && Array.isArray(overviewRes.data) && overviewRes.data.length > 0
      ? (overviewRes.data[0] as Overview)
      : null;
  const sessions: Session[] = (sessionsRes.data ?? []) as Session[];
  const cadence: Cadence[] = (cadenceRes.data ?? []) as Cadence[];
  const commitmentOverview: CommitmentOverview | null =
    commitmentOverviewRes.data && Array.isArray(commitmentOverviewRes.data) && commitmentOverviewRes.data.length > 0
      ? (commitmentOverviewRes.data[0] as CommitmentOverview)
      : null;
  const atRisk: Commitment[] = (atRiskRes.data ?? []) as Commitment[];
  const impact: ImpactArea[] = (impactRes.data ?? []) as ImpactArea[];
  const scorecard: Scorecard[] = (scorecardRes.data ?? []) as Scorecard[];
  const upcoming: Upcoming[] = (upcomingRes.data ?? []) as Upcoming[];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '4px' }}>
          Quarterly Strategic Team 1-on-1 Cadence
        </h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          Founder console r2869 — team member × cadence × depth × commitment × verdict
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <KpiCard label="Total Sessions" value={overview?.total_sessions ?? 0} />
        <KpiCard label="Avg Rating (1-5)" value={overview?.avg_rating ?? 0} />
        <KpiCard label="On Track" value={overview?.on_track ?? 0} tone="green" />
        <KpiCard label="At Risk" value={overview?.at_risk ?? 0} tone="amber" />
        <KpiCard label="Blocked" value={overview?.blocked ?? 0} tone="red" />
        <KpiCard label="Escalate" value={overview?.escalate ?? 0} tone="red" />
        <KpiCard label="Exceeded" value={overview?.exceeded ?? 0} tone="green" />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <KpiCard label="Commitments" value={commitmentOverview?.total ?? 0} />
        <KpiCard label="Completed" value={commitmentOverview?.completed ?? 0} tone="green" />
        <KpiCard label="In Progress" value={commitmentOverview?.in_progress ?? 0} />
        <KpiCard label="Missed" value={commitmentOverview?.missed ?? 0} tone="red" />
        <KpiCard label="Deferred" value={commitmentOverview?.deferred ?? 0} tone="amber" />
        <KpiCard label="Avg Completion %" value={commitmentOverview?.avg_completion ?? 0} />
      </section>

      <Section title="Team Member Scorecard">
        <DataTable
          rows={scorecard}
          columns={[
            { key: 'team_member', header: 'Team Member', render: (r: Scorecard) => r.team_member },
            { key: 'sessions', header: 'Sessions', render: (r: Scorecard) => String(r.sessions) },
            { key: 'avg_rating', header: 'Avg Rating', render: (r: Scorecard) => String(r.avg_rating) },
            { key: 'commitments', header: 'Commitments', render: (r: Scorecard) => String(r.commitments) },
            { key: 'completed', header: 'Completed', render: (r: Scorecard) => String(r.completed) },
            { key: 'completion_rate', header: 'Completion %', render: (r: Scorecard) => `${r.completion_rate}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: Scorecard, i: number) => String(r.team_member ?? i)}
        />
      </Section>

      <Section title="Recent 1-on-1 Sessions">
        <DataTable
          rows={sessions}
          columns={[
            { key: 'session_date', header: 'Date', render: (r: Session) => r.session_date },
            { key: 'team_member', header: 'Team Member', render: (r: Session) => r.team_member },
            { key: 'role', header: 'Role', render: (r: Session) => r.role },
            { key: 'meeting_cadence', header: 'Cadence', render: (r: Session) => r.meeting_cadence },
            { key: 'depth_level', header: 'Depth', render: (r: Session) => r.depth_level },
            { key: 'topic', header: 'Topic', render: (r: Session) => r.topic },
            { key: 'outcome', header: 'Outcome', render: (r: Session) => r.outcome },
            { key: 'verdict', header: 'Verdict', render: (r: Session) => <Pill text={r.verdict} /> },
            { key: 'founder_rating', header: 'Rating', render: (r: Session) => `${r.founder_rating}/5` },
          ]}
          emptyMessage="No data"
          rowKey={(r: Session, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Cadence Breakdown">
        <DataTable
          rows={cadence}
          columns={[
            { key: 'meeting_cadence', header: 'Cadence', render: (r: Cadence) => r.meeting_cadence },
            { key: 'sessions', header: 'Sessions', render: (r: Cadence) => String(r.sessions) },
            { key: 'avg_rating', header: 'Avg Rating', render: (r: Cadence) => String(r.avg_rating) },
            { key: 'escalations', header: 'Escalations', render: (r: Cadence) => String(r.escalations) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Cadence, i: number) => String(r.meeting_cadence ?? i)}
        />
      </Section>

      <Section title="Commitments At Risk (missed / deferred / in progress)">
        <DataTable
          rows={atRisk}
          columns={[
            { key: 'team_member', header: 'Team Member', render: (r: Commitment) => r.team_member },
            { key: 'commitment_text', header: 'Commitment', render: (r: Commitment) => r.commitment_text },
            { key: 'due_date', header: 'Due', render: (r: Commitment) => r.due_date },
            { key: 'status', header: 'Status', render: (r: Commitment) => <Pill text={r.status} /> },
            { key: 'impact_area', header: 'Impact Area', render: (r: Commitment) => r.impact_area },
            { key: 'completion_percent', header: 'Completion', render: (r: Commitment) => `${r.completion_percent}%` },
            { key: 'blocker', header: 'Blocker', render: (r: Commitment) => r.blocker ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Commitment, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Impact Area Breakdown">
        <DataTable
          rows={impact}
          columns={[
            { key: 'impact_area', header: 'Impact Area', render: (r: ImpactArea) => r.impact_area },
            { key: 'count', header: 'Count', render: (r: ImpactArea) => String(r.count) },
            { key: 'avg_completion', header: 'Avg Completion %', render: (r: ImpactArea) => String(r.avg_completion) },
            { key: 'missed', header: 'Missed', render: (r: ImpactArea) => String(r.missed) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ImpactArea, i: number) => String(r.impact_area ?? i)}
        />
      </Section>

      <Section title="Upcoming Sessions">
        <DataTable
          rows={upcoming}
          columns={[
            { key: 'next_session_date', header: 'Next Session', render: (r: Upcoming) => r.next_session_date },
            { key: 'team_member', header: 'Team Member', render: (r: Upcoming) => r.team_member },
            { key: 'role', header: 'Role', render: (r: Upcoming) => r.role },
            { key: 'meeting_cadence', header: 'Cadence', render: (r: Upcoming) => r.meeting_cadence },
            { key: 'last_verdict', header: 'Last Verdict', render: (r: Upcoming) => <Pill text={r.last_verdict} /> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Upcoming, i: number) => String(r.team_member ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: number | string; tone?: 'green' | 'amber' | 'red' }) {
  const bg = tone === 'green' ? '#ecfdf5' : tone === 'amber' ? '#fffbeb' : tone === 'red' ? '#fef2f2' : '#f8fafc';
  const fg = tone === 'green' ? '#065f46' : tone === 'amber' ? '#92400e' : tone === 'red' ? '#991b1b' : '#0f172a';
  return (
    <div style={{ background: bg, border: '1px solid #e5e7eb', borderRadius: '10px', padding: '14px' }}>
      <div style={{ fontSize: '12px', color: '#64748b', marginBottom: '6px' }}>{label}</div>
      <div style={{ fontSize: '22px', fontWeight: 700, color: fg }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '28px' }}>
      <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '10px' }}>{title}</h2>
      <div style={{ overflowX: 'auto' }}>{children}</div>
    </section>
  );
}

function Pill({ text }: { text: string }) {
  const map: Record<string, { bg: string; fg: string }> = {
    on_track:    { bg: '#dcfce7', fg: '#166534' },
    exceeded:    { bg: '#dbeafe', fg: '#1e40af' },
    at_risk:     { bg: '#fef3c7', fg: '#92400e' },
    blocked:     { bg: '#fee2e2', fg: '#991b1b' },
    escalate:    { bg: '#fecaca', fg: '#7f1d1d' },
    completed:   { bg: '#dcfce7', fg: '#166534' },
    in_progress: { bg: '#e0e7ff', fg: '#3730a3' },
    missed:      { bg: '#fee2e2', fg: '#991b1b' },
    deferred:    { bg: '#fef3c7', fg: '#92400e' },
    pending:     { bg: '#f1f5f9', fg: '#475569' },
  };
  const s = map[text] ?? { bg: '#f1f5f9', fg: '#475569' };
  return (
    <span style={{ background: s.bg, color: s.fg, padding: '2px 8px', borderRadius: '999px', fontSize: '12px', fontWeight: 600 }}>
      {text}
    </span>
  );
}
