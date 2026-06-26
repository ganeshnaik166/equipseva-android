import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overview, list, byAlignment, signals, outcomes, refocus, critical] = await Promise.all([
    supabase.rpc('founder_team_mission_clarity_overview_r2845'),
    supabase.rpc('founder_team_mission_clarity_list_r2845'),
    supabase.rpc('founder_team_mission_clarity_by_alignment_r2845'),
    supabase.rpc('founder_team_mission_clarity_signals_r2845'),
    supabase.rpc('founder_team_mission_clarity_outcomes_r2845'),
    supabase.rpc('founder_team_mission_clarity_refocus_actions_r2845'),
    supabase.rpc('founder_team_mission_clarity_critical_signals_r2845'),
  ]);

  const ov = (overview.data?.[0] ?? {}) as {
    total_members?: number;
    avg_clarity?: number;
    strong_count?: number;
    off_mission_count?: number;
    refocused_count?: number;
  };

  const listRows = (list.data ?? []) as Array<{
    id: string;
    quarter: string;
    team_member: string;
    role: string;
    mission_alignment: string;
    clarity_score: number;
    refocus_action: string;
    outcome: string;
  }>;

  const alignmentRows = (byAlignment.data ?? []) as Array<{
    mission_alignment: string;
    member_count: number;
    avg_clarity: number;
  }>;

  const signalRows = (signals.data ?? []) as Array<{
    team_member: string;
    signal_type: string;
    signal_description: string;
    signal_weight: number;
    observed_at: string;
  }>;

  const outcomeRows = (outcomes.data ?? []) as Array<{
    outcome: string;
    member_count: number;
  }>;

  const refocusRows = (refocus.data ?? []) as Array<{
    team_member: string;
    role: string;
    clarity_score: number;
    refocus_action: string;
    outcome: string;
  }>;

  const criticalRows = (critical.data ?? []) as Array<{
    team_member: string;
    role: string;
    signal_description: string;
    signal_weight: number;
  }>;

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
        Quarterly Team Mission Clarity Check
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Founder review of team member alignment, clarity scores, signals, refocus actions and outcomes.
      </p>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12,
          marginBottom: 24,
        }}
      >
        <Kpi label="Members reviewed" value={String(ov.total_members ?? 0)} />
        <Kpi label="Avg clarity (0-10)" value={String(ov.avg_clarity ?? 0)} />
        <Kpi label="Strong alignment" value={String(ov.strong_count ?? 0)} />
        <Kpi label="Off mission" value={String(ov.off_mission_count ?? 0)} />
        <Kpi label="Refocused" value={String(ov.refocused_count ?? 0)} />
      </section>

      <Section title="Team member clarity checks">
        <DataTable
          rows={listRows}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
            { key: 'team_member', header: 'Team member', render: (r) => r.team_member },
            { key: 'role', header: 'Role', render: (r) => r.role },
            { key: 'mission_alignment', header: 'Alignment', render: (r) => r.mission_alignment },
            { key: 'clarity_score', header: 'Clarity (0-10)', render: (r) => String(r.clarity_score) },
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </Section>

      <Section title="By mission alignment">
        <DataTable
          rows={alignmentRows}
          columns={[
            { key: 'mission_alignment', header: 'Alignment', render: (r) => r.mission_alignment },
            { key: 'member_count', header: 'Members', render: (r) => String(r.member_count) },
            { key: 'avg_clarity', header: 'Avg clarity', render: (r) => String(r.avg_clarity) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Signals (positive, neutral, warning, critical)">
        <DataTable
          rows={signalRows}
          columns={[
            { key: 'team_member', header: 'Team member', render: (r) => r.team_member },
            { key: 'signal_type', header: 'Signal', render: (r) => r.signal_type },
            { key: 'signal_description', header: 'Description', render: (r) => r.signal_description },
            { key: 'signal_weight', header: 'Weight', render: (r) => String(r.signal_weight) },
            {
              key: 'observed_at',
              header: 'Observed at',
              render: (r) => new Date(r.observed_at).toLocaleString('en-IN'),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Outcome distribution">
        <DataTable
          rows={outcomeRows}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
            { key: 'member_count', header: 'Members', render: (r) => String(r.member_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Refocus actions (refocused and transitioning)">
        <DataTable
          rows={refocusRows}
          columns={[
            { key: 'team_member', header: 'Team member', render: (r) => r.team_member },
            { key: 'role', header: 'Role', render: (r) => r.role },
            { key: 'clarity_score', header: 'Clarity', render: (r) => String(r.clarity_score) },
            { key: 'refocus_action', header: 'Refocus action', render: (r) => r.refocus_action },
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </Section>

      <Section title="Critical and warning signals to address">
        <DataTable
          rows={criticalRows}
          columns={[
            { key: 'team_member', header: 'Team member', render: (r) => r.team_member },
            { key: 'role', header: 'Role', render: (r) => r.role },
            { key: 'signal_description', header: 'Signal', render: (r) => r.signal_description },
            { key: 'signal_weight', header: 'Weight', render: (r) => String(r.signal_weight) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </Section>
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        padding: 16,
        background: '#fff',
      }}
    >
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
