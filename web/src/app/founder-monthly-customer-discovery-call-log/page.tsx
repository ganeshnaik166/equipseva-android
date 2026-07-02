import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { total_calls: number; total_followups: number; open_followups: number; p0_open: number; avg_insight: number; avg_duration: number };
type Call = { id: string; call_date: string; customer_name: string; customer_org: string; persona: string; pain_point: string; customer_ask: string; insight: string; insight_score: number; duration_minutes: number; status: string };
type Followup = { id: string; customer_name: string; action_title: string; owner: string; due_date: string; status: string; priority: string; outcome_note: string | null };
type Persona = { persona: string; calls: number; avg_insight: number; open_actions: number };
type Insight = { customer_name: string; persona: string; insight: string; insight_score: number };
type Pain = { pain_point: string; mentions: number; p0_actions: number };
type Health = { status: string; priority: string; count: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, callsRes, followupsRes, personaRes, insightsRes, painRes, healthRes] = await Promise.all([
    supabase.rpc('r2677_kpi_summary'),
    supabase.rpc('r2677_list_calls'),
    supabase.rpc('r2677_list_followups'),
    supabase.rpc('r2677_persona_breakdown'),
    supabase.rpc('r2677_top_insights'),
    supabase.rpc('r2677_pain_themes'),
    supabase.rpc('r2677_followup_health'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? { total_calls: 0, total_followups: 0, open_followups: 0, p0_open: 0, avg_insight: 0, avg_duration: 0 };
  const calls: Call[] = (callsRes.data as Call[]) ?? [];
  const followups: Followup[] = (followupsRes.data as Followup[]) ?? [];
  const personas: Persona[] = (personaRes.data as Persona[]) ?? [];
  const insights: Insight[] = (insightsRes.data as Insight[]) ?? [];
  const pains: Pain[] = (painRes.data as Pain[]) ?? [];
  const health: Health[] = (healthRes.data as Health[]) ?? [];

  const callCols = [
    { key: 'call_date', header: 'Date', render: (r: Call) => r.call_date },
    { key: 'customer_name', header: 'Customer', render: (r: Call) => r.customer_name },
    { key: 'customer_org', header: 'Org', render: (r: Call) => r.customer_org },
    { key: 'persona', header: 'Persona', render: (r: Call) => r.persona },
    { key: 'pain_point', header: 'Pain', render: (r: Call) => r.pain_point },
    { key: 'customer_ask', header: 'Ask', render: (r: Call) => r.customer_ask },
    { key: 'insight', header: 'Insight', render: (r: Call) => r.insight },
    { key: 'insight_score', header: 'Score', render: (r: Call) => `${r.insight_score}/5` },
    { key: 'duration_minutes', header: 'Min', render: (r: Call) => String(r.duration_minutes) },
  ];

  const followupCols = [
    { key: 'customer_name', header: 'Customer', render: (r: Followup) => r.customer_name },
    { key: 'action_title', header: 'Action', render: (r: Followup) => r.action_title },
    { key: 'owner', header: 'Owner', render: (r: Followup) => r.owner },
    { key: 'due_date', header: 'Due', render: (r: Followup) => r.due_date },
    { key: 'priority', header: 'Priority', render: (r: Followup) => r.priority.toUpperCase() },
    { key: 'status', header: 'Status', render: (r: Followup) => r.status },
    { key: 'outcome_note', header: 'Outcome', render: (r: Followup) => r.outcome_note ?? '—' },
  ];

  const personaCols = [
    { key: 'persona', header: 'Persona', render: (r: Persona) => r.persona },
    { key: 'calls', header: 'Calls', render: (r: Persona) => String(r.calls) },
    { key: 'avg_insight', header: 'Avg Insight', render: (r: Persona) => String(r.avg_insight) },
    { key: 'open_actions', header: 'Open Actions', render: (r: Persona) => String(r.open_actions) },
  ];

  const insightCols = [
    { key: 'customer_name', header: 'Customer', render: (r: Insight) => r.customer_name },
    { key: 'persona', header: 'Persona', render: (r: Insight) => r.persona },
    { key: 'insight', header: 'Insight', render: (r: Insight) => r.insight },
    { key: 'insight_score', header: 'Score', render: (r: Insight) => `${r.insight_score}/5` },
  ];

  const painCols = [
    { key: 'pain_point', header: 'Pain Point', render: (r: Pain) => r.pain_point },
    { key: 'mentions', header: 'Mentions', render: (r: Pain) => String(r.mentions) },
    { key: 'p0_actions', header: 'P0 Actions', render: (r: Pain) => String(r.p0_actions) },
  ];

  const healthCols = [
    { key: 'status', header: 'Status', render: (r: Health) => r.status },
    { key: 'priority', header: 'Priority', render: (r: Health) => r.priority.toUpperCase() },
    { key: 'count', header: 'Count', render: (r: Health) => String(r.count) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>Founder Monthly Customer Discovery Call Log</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Call &gt; persona &gt; pain &gt; ask &gt; insight =&gt; follow-up action. Score &gt;= 4 marks high-signal calls.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Kpi label="Total Calls" value={String(kpi.total_calls)} />
        <Kpi label="Total Follow-ups" value={String(kpi.total_followups)} />
        <Kpi label="Open Follow-ups" value={String(kpi.open_followups)} />
        <Kpi label="P0 Open" value={String(kpi.p0_open)} accent="#c00" />
        <Kpi label="Avg Insight Score" value={`${kpi.avg_insight}/5`} />
        <Kpi label="Avg Call Duration" value={`${kpi.avg_duration} min`} />
      </div>

      <Section title="Discovery Calls (this and last month)">
        <DataTable rows={calls} columns={callCols} emptyMessage="No data" rowKey={(r, i) => String(r.id ?? i)} />
      </Section>

      <Section title="Follow-up Actions">
        <DataTable rows={followups} columns={followupCols} emptyMessage="No data" rowKey={(r, i) => String(r.id ?? i)} />
      </Section>

      <Section title="Persona Breakdown">
        <DataTable rows={personas} columns={personaCols} emptyMessage="No data" rowKey={(r, i) => String(r.persona ?? i)} />
      </Section>

      <Section title="Top Insights (score >= 4)">
        <DataTable rows={insights} columns={insightCols} emptyMessage="No data" rowKey={(r, i) => String(i)} />
      </Section>

      <Section title="Pain Themes">
        <DataTable rows={pains} columns={painCols} emptyMessage="No data" rowKey={(r, i) => String(r.pain_point ?? i)} />
      </Section>

      <Section title="Follow-up Health (status x priority)">
        <DataTable rows={health} columns={healthCols} emptyMessage="No data" rowKey={(r, i) => String(i)} />
      </Section>
    </div>
  );
}

function Kpi({ label, value, accent }: { label: string; value: string; accent?: string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 10, padding: 14, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#777', marginBottom: 6 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, color: accent ?? '#111' }}>{value}</div>
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
