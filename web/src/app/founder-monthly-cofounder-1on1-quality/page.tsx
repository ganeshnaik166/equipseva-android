import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyCofounder1on1QualityPage() {
  const supabase = await getSupabaseServerClient();

  const [
    meetingsRes,
    actionsRes,
    tensionRes,
    alignmentRes,
    completionRes,
    summaryRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_meetings_r2557'),
    supabase.rpc('list_action_items_r2557'),
    supabase.rpc('tension_focus_r2557'),
    supabase.rpc('alignment_trend_r2557'),
    supabase.rpc('action_completion_rate_r2557'),
    supabase.rpc('monthly_quality_summary_r2557'),
    supabase.rpc('owner_load_r2557'),
  ]);

  const meetings = (meetingsRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const tension = (tensionRes.data ?? []) as any[];
  const alignment = (alignmentRes.data ?? []) as any[];
  const completion = (completionRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];

  const meetingCols: Column<any>[] = [
    { key: 'cofounder_name', header: 'Cofounder', render: (r: any) => r.cofounder_name },
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    {
      key: 'held_at',
      header: 'Held',
      render: (r: any) => (r.held_at ? new Date(r.held_at).toLocaleDateString() : '-'),
    },
    { key: 'duration_minutes', header: 'Dur (min)', render: (r: any) => r.duration_minutes },
    { key: 'agenda_quality_score', header: 'Agenda', render: (r: any) => `${r.agenda_quality_score}/100` },
    { key: 'decisions_made_count', header: 'Decisions', render: (r: any) => r.decisions_made_count },
    { key: 'alignment_score', header: 'Alignment', render: (r: any) => `${r.alignment_score}/100` },
    { key: 'action_items_count', header: 'Actions', render: (r: any) => r.action_items_count },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const actionCols: Column<any>[] = [
    { key: 'cofounder_name', header: 'Cofounder', render: (r: any) => r.cofounder_name },
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    {
      key: 'due_at',
      header: 'Due',
      render: (r: any) => (r.due_at ? new Date(r.due_at).toLocaleDateString() : '-'),
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    {
      key: 'closed_at',
      header: 'Closed',
      render: (r: any) => (r.closed_at ? new Date(r.closed_at).toLocaleDateString() : '-'),
    },
  ];

  const tensionCols: Column<any>[] = [
    { key: 'cofounder_name', header: 'Cofounder', render: (r: any) => r.cofounder_name },
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    {
      key: 'held_at',
      header: 'Held',
      render: (r: any) => (r.held_at ? new Date(r.held_at).toLocaleDateString() : '-'),
    },
    { key: 'alignment_score', header: 'Alignment', render: (r: any) => `${r.alignment_score}/100` },
    { key: 'tension_flags_md', header: 'Tension flags', render: (r: any) => r.tension_flags_md ?? '-' },
  ];

  const alignmentCols: Column<any>[] = [
    { key: 'cofounder_name', header: 'Cofounder', render: (r: any) => r.cofounder_name },
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'meetings_count', header: 'Meetings', render: (r: any) => r.meetings_count },
    { key: 'avg_alignment', header: 'Avg align', render: (r: any) => r.avg_alignment },
    { key: 'avg_agenda_quality', header: 'Avg agenda', render: (r: any) => r.avg_agenda_quality },
  ];

  const completionCols: Column<any>[] = [
    { key: 'cofounder_name', header: 'Cofounder', render: (r: any) => r.cofounder_name },
    { key: 'total_actions', header: 'Total', render: (r: any) => r.total_actions },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'in_progress_count', header: 'In progress', render: (r: any) => r.in_progress_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => r.dropped_count },
    { key: 'completion_rate_pct', header: 'Done %', render: (r: any) => `${r.completion_rate_pct}%` },
    { key: 'positive_outcomes', header: 'Positive', render: (r: any) => r.positive_outcomes },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'meetings_count', header: 'Meetings', render: (r: any) => r.meetings_count },
    { key: 'avg_agenda_quality', header: 'Avg agenda', render: (r: any) => r.avg_agenda_quality },
    { key: 'avg_alignment', header: 'Avg align', render: (r: any) => r.avg_alignment },
    { key: 'total_decisions', header: 'Decisions', render: (r: any) => r.total_decisions },
    { key: 'total_action_items', header: 'Actions', render: (r: any) => r.total_action_items },
    { key: 'tension_flag_count', header: 'Tension flags', render: (r: any) => r.tension_flag_count },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'total_actions', header: 'Total', render: (r: any) => r.total_actions },
    { key: 'open_actions', header: 'Open', render: (r: any) => r.open_actions },
    { key: 'in_progress_actions', header: 'In progress', render: (r: any) => r.in_progress_actions },
    { key: 'done_actions', header: 'Done', render: (r: any) => r.done_actions },
    { key: 'overdue_open', header: 'Overdue', render: (r: any) => r.overdue_open },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Founder > Monthly Cofounder 1:1 Quality
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Cofounder & 1:1 cadence & agenda quality & decisions & alignment & tension flags.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Meetings</h2>
        <DataTable
          rows={meetings}
          columns={meetingCols}
          emptyMessage="No 1:1 meetings logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action items</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No action items captured yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Tension focus</h2>
        <DataTable
          rows={tension}
          columns={tensionCols}
          emptyMessage="No tension flags raised."
          rowKey={(r: any, i: number) => String(r.held_at ?? i) + i}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Alignment trend</h2>
        <DataTable
          rows={alignment}
          columns={alignmentCols}
          emptyMessage="No alignment data."
          rowKey={(r: any, i: number) => `${r.cofounder_name}-${r.month_label}-${i}`}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action completion rate</h2>
        <DataTable
          rows={completion}
          columns={completionCols}
          emptyMessage="No completion data."
          rowKey={(r: any, i: number) => `${r.cofounder_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly quality summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No monthly summary yet."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owner load data."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
