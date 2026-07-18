import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    clarityRes,
    actionsRes,
    blurryRes,
    statusRes,
    trendRes,
    actionDistRes,
    summaryRes,
  ] = await Promise.all([
    supabase.rpc('list_clarity_r2649'),
    supabase.rpc('list_recovery_actions_r2649'),
    supabase.rpc('top_blurry_focus_r2649'),
    supabase.rpc('status_funnel_r2649'),
    supabase.rpc('monthly_clarity_trend_r2649'),
    supabase.rpc('action_kind_distribution_r2649'),
    supabase.rpc('founder_pulse_summary_r2649'),
  ]);

  const clarity: any[] = clarityRes.data ?? [];
  const actions: any[] = actionsRes.data ?? [];
  const blurry: any[] = blurryRes.data ?? [];
  const statusFunnel: any[] = statusRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const actionDist: any[] = actionDistRes.data ?? [];
  const summary: any = (summaryRes.data ?? [])[0] ?? {};

  const clarityCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'clarity_score', header: 'Clarity', render: (r: any) => `${r.clarity_score}/100` },
    { key: 'north_star_clear', header: 'North Star', render: (r: any) => (r.north_star_clear ? 'clear' : 'blurry') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'top_3_priorities_md', header: 'Top 3 Priorities', render: (r: any) => r.top_3_priorities_md },
    { key: 'top_3_kills_md', header: 'Top 3 Kills', render: (r: any) => r.top_3_kills_md },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const actionCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const blurryCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'clarity_score', header: 'Clarity', render: (r: any) => `${r.clarity_score}/100` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'north_star_clear', header: 'North Star', render: (r: any) => (r.north_star_clear ? 'clear' : 'blurry') },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'pulse_count', header: 'Pulses', render: (r: any) => String(r.pulse_count) },
    { key: 'avg_clarity', header: 'Avg Clarity', render: (r: any) => String(r.avg_clarity) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'clarity_score', header: 'Clarity', render: (r: any) => `${r.clarity_score}/100` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'north_star_clear', header: 'North Star', render: (r: any) => (r.north_star_clear ? 'clear' : 'blurry') },
  ];

  const actionDistCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => r.action_kind },
    { key: 'action_count', header: 'Total', render: (r: any) => String(r.action_count) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => String(r.positive_count) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Founder Monthly Strategic Clarity Pulse
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Monthly self-rated clarity on north-star & top-3 priorities & kills =&gt; track when focus goes blurry & what recovery actions move it back to aligned.
      </p>

      <section style={{ marginBottom: 24, padding: 12, background: '#f6f6f6', borderRadius: 8 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Founder Pulse Summary</h2>
        <ul style={{ lineHeight: 1.7 }}>
          <li>Pulses logged: {String(summary.pulses_logged ?? 0)}</li>
          <li>Avg clarity: {String(summary.avg_clarity ?? 0)}/100</li>
          <li>Blurry months: {String(summary.blurry_months ?? 0)}</li>
          <li>Aligned months: {String(summary.aligned_months ?? 0)}</li>
          <li>Open recovery actions: {String(summary.open_actions ?? 0)}</li>
        </ul>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Clarity Pulses</h2>
        <DataTable
          rows={clarity}
          columns={clarityCols}
          emptyMessage="No clarity pulses logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recovery Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No recovery actions logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Blurry Focus Months</h2>
        <DataTable
          rows={blurry}
          columns={blurryCols}
          emptyMessage="No months ranked."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status Funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Clarity Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action Kind Distribution</h2>
        <DataTable
          rows={actionDist}
          columns={actionDistCols}
          emptyMessage="No actions logged."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>
    </main>
  );
}
