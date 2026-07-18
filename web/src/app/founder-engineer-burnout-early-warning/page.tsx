import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerBurnoutEarlyWarningPage() {
  const sb = await getSupabaseServerClient();

  const [
    signalsRes,
    interventionsRes,
    topRes,
    severityRes,
    outcomeRes,
    trendRes,
    focusRes,
  ] = await Promise.all([
    sb.rpc('list_signals_r2430'),
    sb.rpc('list_interventions_r2430'),
    sb.rpc('top_burnout_engineers_r2430'),
    sb.rpc('severity_breakdown_r2430'),
    sb.rpc('intervention_outcome_summary_r2430'),
    sb.rpc('weekly_score_trend_r2430'),
    sb.rpc('this_week_focus_r2430'),
  ]);

  const signals: any[] = signalsRes.data ?? [];
  const interventions: any[] = interventionsRes.data ?? [];
  const top: any[] = topRes.data ?? [];
  const severity: any[] = severityRes.data ?? [];
  const outcomes: any[] = outcomeRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const focus: any[] = focusRes.data ?? [];

  const fmtDate = (v: string | null | undefined) =>
    v ? new Date(v).toLocaleString() : '-';
  const fmtDay = (v: string | null | undefined) =>
    v ? new Date(v).toLocaleDateString() : '-';
  const fmtNum = (v: any, d = 1) =>
    v == null ? '-' : Number(v).toFixed(d);

  const severityBadge = (sev: string) => {
    const map: Record<string, string> = {
      critical: '#991b1b',
      high: '#b91c1c',
      medium: '#b45309',
      low: '#15803d',
    };
    return (
      <span style={{ color: map[sev] ?? '#374151', fontWeight: 600, textTransform: 'uppercase' }}>
        {sev}
      </span>
    );
  };

  const statusBadge = (s: string) => {
    const map: Record<string, string> = {
      open: '#b45309',
      in_progress: '#1d4ed8',
      done: '#15803d',
      dropped: '#6b7280',
    };
    return (
      <span style={{ color: map[s] ?? '#374151', fontWeight: 600 }}>{s}</span>
    );
  };

  const outcomeBadge = (o: string) => {
    const map: Record<string, string> = {
      positive: '#15803d',
      neutral: '#6b7280',
      negative: '#b91c1c',
      pending: '#b45309',
    };
    return (
      <span style={{ color: map[o] ?? '#374151', fontWeight: 600 }}>{o}</span>
    );
  };

  const focusCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'signal_score', header: 'Score', render: (r: any) => r.signal_score },
    { key: 'severity', header: 'Severity', render: (r: any) => severityBadge(r.severity) },
    { key: 'top_signal', header: 'Top signal', render: (r: any) => r.top_signal },
    { key: 'hours_worked_7d', header: 'Hrs 7d', render: (r: any) => fmtNum(r.hours_worked_7d) },
    { key: 'days_no_rest', header: 'No-rest days', render: (r: any) => r.days_no_rest },
    { key: 'open_interventions', header: 'Open ints', render: (r: any) => r.open_interventions },
    { key: 'recommended_action', header: 'Recommended action', render: (r: any) => r.recommended_action },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'latest_score', header: 'Latest score', render: (r: any) => r.latest_score },
    { key: 'latest_severity', header: 'Severity', render: (r: any) => severityBadge(r.latest_severity) },
    { key: 'latest_top_signal', header: 'Top signal', render: (r: any) => r.latest_top_signal },
    { key: 'latest_week_start', header: 'Week', render: (r: any) => fmtDay(r.latest_week_start) },
    { key: 'hours_worked_7d', header: 'Hrs 7d', render: (r: any) => fmtNum(r.hours_worked_7d) },
    { key: 'days_no_rest', header: 'No-rest days', render: (r: any) => r.days_no_rest },
  ];

  const signalCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'signal_week_start', header: 'Week start', render: (r: any) => fmtDay(r.signal_week_start) },
    { key: 'hours_worked_7d', header: 'Hrs 7d', render: (r: any) => fmtNum(r.hours_worked_7d) },
    { key: 'days_no_rest', header: 'No-rest', render: (r: any) => r.days_no_rest },
    { key: 'csat_slip_pct', header: 'CSAT slip %', render: (r: any) => fmtNum(r.csat_slip_pct) },
    { key: 'cancellations_count', header: 'Cancels', render: (r: any) => r.cancellations_count },
    { key: 'miss_count', header: 'Misses', render: (r: any) => r.miss_count },
    { key: 'signal_score', header: 'Score', render: (r: any) => r.signal_score },
    { key: 'severity', header: 'Severity', render: (r: any) => severityBadge(r.severity) },
    { key: 'top_signal', header: 'Top signal', render: (r: any) => r.top_signal },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const interventionCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name },
    { key: 'intervention_kind', header: 'Kind', render: (r: any) => r.intervention_kind },
    { key: 'opened_at', header: 'Opened', render: (r: any) => fmtDate(r.opened_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'planned_action', header: 'Planned action', render: (r: any) => r.planned_action },
    { key: 'status', header: 'Status', render: (r: any) => statusBadge(r.status) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => outcomeBadge(r.outcome) },
    { key: 'follow_up_at', header: 'Follow up', render: (r: any) => fmtDate(r.follow_up_at) },
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDate(r.closed_at) },
  ];

  const severityCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => severityBadge(r.severity) },
    { key: 'signal_count', header: 'Signals', render: (r: any) => r.signal_count },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => fmtNum(r.avg_score) },
    { key: 'avg_hours', header: 'Avg hrs/7d', render: (r: any) => fmtNum(r.avg_hours) },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'intervention_kind', header: 'Kind', render: (r: any) => r.intervention_kind },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'in_progress_count', header: 'In progress', render: (r: any) => r.in_progress_count },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => r.dropped_count },
    { key: 'positive_outcomes', header: 'Positive', render: (r: any) => r.positive_outcomes },
    { key: 'negative_outcomes', header: 'Negative', render: (r: any) => r.negative_outcomes },
  ];

  const trendCols: Column<any>[] = [
    { key: 'signal_week_start', header: 'Week', render: (r: any) => fmtDay(r.signal_week_start) },
    { key: 'signals_recorded', header: 'Signals', render: (r: any) => r.signals_recorded },
    { key: 'engineers_tracked', header: 'Engineers', render: (r: any) => r.engineers_tracked },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => fmtNum(r.avg_score) },
    { key: 'max_score', header: 'Max score', render: (r: any) => r.max_score },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'high_count', header: 'High', render: (r: any) => r.high_count },
  ];

  const totalSignals = signals.length;
  const criticalCount = signals.filter((s) => s.severity === 'critical').length;
  const highCount = signals.filter((s) => s.severity === 'high').length;
  const openInts = interventions.filter((i) => i.status === 'open' || i.status === 'in_progress').length;

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Engineer Burnout Early Warning
      </h1>
      <p style={{ color: '#6b7280', marginBottom: 24 }}>
        Rolling 7-day signals: work hours & no-rest days & CSAT slip & cancellations =&gt; early intervention
      </p>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 16,
          marginBottom: 32,
        }}
      >
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Total signals</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalSignals}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fecaca', borderRadius: 8, background: '#fef2f2' }}>
          <div style={{ fontSize: 12, color: '#991b1b' }}>Critical</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#991b1b' }}>{criticalCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fed7aa', borderRadius: 8, background: '#fff7ed' }}>
          <div style={{ fontSize: 12, color: '#b45309' }}>High</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#b45309' }}>{highCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#6b7280' }}>Open interventions</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{openInts}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>This week focus</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No engineers at medium+ risk this week"
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top burnout engineers (latest)</h2>
        <DataTable
          rows={top}
          columns={topCols}
          emptyMessage="No engineer signals tracked"
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Severity breakdown</h2>
        <DataTable
          rows={severity}
          columns={severityCols}
          emptyMessage="No severity data"
          rowKey={(r: any, i: number) => String(r.severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Weekly score trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.signal_week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Intervention outcome summary</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No interventions recorded"
          rowKey={(r: any, i: number) => String(r.intervention_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All burnout signals</h2>
        <DataTable
          rows={signals}
          columns={signalCols}
          emptyMessage="No signals logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All interventions</h2>
        <DataTable
          rows={interventions}
          columns={interventionCols}
          emptyMessage="No interventions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
