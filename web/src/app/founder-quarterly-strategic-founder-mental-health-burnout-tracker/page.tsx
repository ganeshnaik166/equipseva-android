import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TimelineRow = {
  checkin_date: string;
  quarter: string;
  burnout_index: number;
  stress_level: number;
  energy_level: number;
  mood_label: string;
};

type QuarterlyRow = {
  quarter: string;
  checkins_count: number;
  avg_burnout: number;
  avg_sleep: number;
  avg_stress: number;
  avg_energy: number;
  total_focus_min: number;
  total_exercise_min: number;
};

type OpenSignalRow = {
  signal_date: string;
  signal_kind: string;
  severity: string;
  source_system: string;
  description: string;
  trigger_metric: number;
  threshold_metric: number;
  mitigation_owner: string;
  mitigation_status: string;
};

type SeverityRow = {
  severity: string;
  signals_total: number;
  open_count: number;
  resolved_count: number;
  avg_overshoot: number;
};

type SleepBucketRow = {
  sleep_bucket: string;
  checkins: number;
  avg_burnout: number;
  avg_focus_min: number;
  avg_energy: number;
};

type MoodRow = {
  mood_label: string;
  occurrences: number;
  avg_burnout: number;
  avg_stress: number;
  last_seen: string;
};

type RecoveryRow = {
  checkin_date: string;
  mood_label: string;
  burnout_index: number;
  recovery_action: string;
  journal_excerpt: string;
};

type KpiRow = {
  total_checkins: number;
  current_burnout: number;
  avg_burnout_90d: number;
  open_signals: number;
  critical_signals_total: number;
  avg_sleep_90d: number;
  avg_focus_min_90d: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    timeline,
    quarterly,
    openSignals,
    severity,
    sleepBuckets,
    moods,
    recovery,
    kpi,
  ] = await Promise.all([
    supabase.rpc('r2921_burnout_timeline'),
    supabase.rpc('r2921_quarterly_summary'),
    supabase.rpc('r2921_open_signals'),
    supabase.rpc('r2921_signal_severity_rollup'),
    supabase.rpc('r2921_sleep_burnout_buckets'),
    supabase.rpc('r2921_mood_distribution'),
    supabase.rpc('r2921_recovery_log'),
    supabase.rpc('r2921_kpi_summary'),
  ]);

  const timelineRows = (timeline.data ?? []) as TimelineRow[];
  const quarterlyRows = (quarterly.data ?? []) as QuarterlyRow[];
  const openSignalRows = (openSignals.data ?? []) as OpenSignalRow[];
  const severityRows = (severity.data ?? []) as SeverityRow[];
  const sleepBucketRows = (sleepBuckets.data ?? []) as SleepBucketRow[];
  const moodRows = (moods.data ?? []) as MoodRow[];
  const recoveryRows = (recovery.data ?? []) as RecoveryRow[];
  const kpiRow = ((kpi.data ?? [])[0] ?? null) as KpiRow | null;

  const timelineCols: Column<TimelineRow>[] = [
    { key: 'checkin_date', header: 'Date', render: (r) => r.checkin_date },
    { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
    { key: 'burnout_index', header: 'Burnout Index', render: (r) => r.burnout_index?.toFixed(2) },
    { key: 'stress_level', header: 'Stress', render: (r) => String(r.stress_level) },
    { key: 'energy_level', header: 'Energy', render: (r) => String(r.energy_level) },
    { key: 'mood_label', header: 'Mood', render: (r) => r.mood_label },
  ];

  const quarterlyCols: Column<QuarterlyRow>[] = [
    { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
    { key: 'checkins_count', header: 'Check-ins', render: (r) => String(r.checkins_count) },
    { key: 'avg_burnout', header: 'Avg Burnout', render: (r) => r.avg_burnout?.toFixed(2) },
    { key: 'avg_sleep', header: 'Avg Sleep (h)', render: (r) => r.avg_sleep?.toFixed(2) },
    { key: 'avg_stress', header: 'Avg Stress', render: (r) => r.avg_stress?.toFixed(2) },
    { key: 'avg_energy', header: 'Avg Energy', render: (r) => r.avg_energy?.toFixed(2) },
    { key: 'total_focus_min', header: 'Focus Min', render: (r) => String(r.total_focus_min) },
    { key: 'total_exercise_min', header: 'Exercise Min', render: (r) => String(r.total_exercise_min) },
  ];

  const openSignalCols: Column<OpenSignalRow>[] = [
    { key: 'signal_date', header: 'Date', render: (r) => r.signal_date },
    { key: 'signal_kind', header: 'Signal', render: (r) => r.signal_kind },
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'source_system', header: 'Source', render: (r) => r.source_system },
    { key: 'description', header: 'Description', render: (r) => r.description },
    { key: 'trigger_metric', header: 'Trigger', render: (r) => r.trigger_metric?.toFixed(2) },
    { key: 'threshold_metric', header: 'Threshold', render: (r) => r.threshold_metric?.toFixed(2) },
    { key: 'mitigation_owner', header: 'Owner', render: (r) => r.mitigation_owner },
    { key: 'mitigation_status', header: 'Status', render: (r) => r.mitigation_status },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { key: 'severity', header: 'Severity', render: (r) => r.severity },
    { key: 'signals_total', header: 'Total', render: (r) => String(r.signals_total) },
    { key: 'open_count', header: 'Open', render: (r) => String(r.open_count) },
    { key: 'resolved_count', header: 'Resolved', render: (r) => String(r.resolved_count) },
    { key: 'avg_overshoot', header: 'Avg Overshoot', render: (r) => r.avg_overshoot?.toFixed(2) },
  ];

  const sleepBucketCols: Column<SleepBucketRow>[] = [
    { key: 'sleep_bucket', header: 'Sleep Bucket', render: (r) => r.sleep_bucket },
    { key: 'checkins', header: 'Check-ins', render: (r) => String(r.checkins) },
    { key: 'avg_burnout', header: 'Avg Burnout', render: (r) => r.avg_burnout?.toFixed(2) },
    { key: 'avg_focus_min', header: 'Avg Focus Min', render: (r) => r.avg_focus_min?.toFixed(2) },
    { key: 'avg_energy', header: 'Avg Energy', render: (r) => r.avg_energy?.toFixed(2) },
  ];

  const moodCols: Column<MoodRow>[] = [
    { key: 'mood_label', header: 'Mood', render: (r) => r.mood_label },
    { key: 'occurrences', header: 'Occurrences', render: (r) => String(r.occurrences) },
    { key: 'avg_burnout', header: 'Avg Burnout', render: (r) => r.avg_burnout?.toFixed(2) },
    { key: 'avg_stress', header: 'Avg Stress', render: (r) => r.avg_stress?.toFixed(2) },
    { key: 'last_seen', header: 'Last Seen', render: (r) => r.last_seen },
  ];

  const recoveryCols: Column<RecoveryRow>[] = [
    { key: 'checkin_date', header: 'Date', render: (r) => r.checkin_date },
    { key: 'mood_label', header: 'Mood', render: (r) => r.mood_label },
    { key: 'burnout_index', header: 'Burnout', render: (r) => r.burnout_index?.toFixed(2) },
    { key: 'recovery_action', header: 'Recovery Action', render: (r) => r.recovery_action },
    { key: 'journal_excerpt', header: 'Journal', render: (r) => r.journal_excerpt },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>
          Founder Quarterly Strategic Founder-Mental-Health & Burnout Index Tracker
        </h1>
        <p style={{ color: '#666', marginTop: 8 }}>
          Quarterly burnout index, sleep & focus rollups, open risk signals, mood distribution and recovery log — founder-only console for r2921.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        <KpiCard label="Total Check-ins" value={kpiRow ? String(kpiRow.total_checkins) : '—'} />
        <KpiCard label="Current Burnout" value={kpiRow ? kpiRow.current_burnout?.toFixed(2) : '—'} />
        <KpiCard label="Avg Burnout 90d" value={kpiRow ? kpiRow.avg_burnout_90d?.toFixed(2) : '—'} />
        <KpiCard label="Open Signals" value={kpiRow ? String(kpiRow.open_signals) : '—'} />
        <KpiCard label="Critical Signals" value={kpiRow ? String(kpiRow.critical_signals_total) : '—'} />
        <KpiCard label="Avg Sleep 90d (h)" value={kpiRow ? kpiRow.avg_sleep_90d?.toFixed(2) : '—'} />
        <KpiCard label="Avg Focus 90d (min)" value={kpiRow ? kpiRow.avg_focus_min_90d?.toFixed(2) : '—'} />
      </section>

      <Section title="Burnout Timeline">
        <DataTable
          rows={timelineRows}
          columns={timelineCols}
          emptyMessage="No check-ins yet."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </Section>

      <Section title="Quarterly Summary">
        <DataTable
          rows={quarterlyRows}
          columns={quarterlyCols}
          emptyMessage="No quarterly rollup."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </Section>

      <Section title="Open Burnout Risk Signals">
        <DataTable
          rows={openSignalRows}
          columns={openSignalCols}
          emptyMessage="No open signals — clean week."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </Section>

      <Section title="Signal Severity Rollup">
        <DataTable
          rows={severityRows}
          columns={severityCols}
          emptyMessage="No signals tracked yet."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </Section>

      <Section title="Sleep vs Burnout Buckets">
        <DataTable
          rows={sleepBucketRows}
          columns={sleepBucketCols}
          emptyMessage="No sleep data."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </Section>

      <Section title="Mood Distribution">
        <DataTable
          rows={moodRows}
          columns={moodCols}
          emptyMessage="No mood data."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </Section>

      <Section title="Recent Recovery Actions">
        <DataTable
          rows={recoveryRows}
          columns={recoveryCols}
          emptyMessage="No recovery actions logged."
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 12, padding: 16, background: '#fff' }}>
      <div style={{ color: '#666', fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </section>
  );
}
