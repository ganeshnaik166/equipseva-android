import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderSleepEnergyTrackerPage() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? '';
  const isFounder = email === 'marketingtools@getphyllo.com';

  if (!isFounder) {
    return (
      <main style={{ padding: 24, fontFamily: 'system-ui' }}>
        <h1>Forbidden</h1>
        <p>Founder access only.</p>
      </main>
    );
  }

  const [recent, weekly, correlation, alerts, active, history, kpis] = await Promise.all([
    supabase.rpc('founder_sleep_energy_recent_r2341'),
    supabase.rpc('founder_sleep_energy_weekly_avg_r2341'),
    supabase.rpc('founder_sleep_output_correlation_r2341'),
    supabase.rpc('founder_energy_decline_alerts_r2341'),
    supabase.rpc('founder_sleep_active_interventions_r2341'),
    supabase.rpc('founder_sleep_intervention_history_r2341'),
    supabase.rpc('founder_sleep_energy_kpis_r2341'),
  ]);

  const recentRows = (recent.data ?? []) as any[];
  const weeklyRows = (weekly.data ?? []) as any[];
  const corrRows = (correlation.data ?? []) as any[];
  const alertRows = (alerts.data ?? []) as any[];
  const activeRows = (active.data ?? []) as any[];
  const historyRows = (history.data ?? []) as any[];
  const kpi = (kpis.data?.[0] ?? {}) as any;

  const recentCols: Column<any>[] = [
    { key: 'log_date', header: 'Date', render: (r) => String(r.log_date ?? '') },
    { key: 'sleep_hours', header: 'Sleep (h)', render: (r) => String(r.sleep_hours ?? '') },
    { key: 'sleep_quality', header: 'Sleep Q', render: (r) => String(r.sleep_quality ?? '') },
    { key: 'energy_morning', header: 'AM Energy', render: (r) => String(r.energy_morning ?? '') },
    { key: 'energy_afternoon', header: 'PM Energy', render: (r) => String(r.energy_afternoon ?? '-') },
    { key: 'energy_evening', header: 'Eve Energy', render: (r) => String(r.energy_evening ?? '-') },
    { key: 'output_quality', header: 'Output Q', render: (r) => String(r.output_quality ?? '') },
    { key: 'ships_count', header: 'Ships', render: (r) => String(r.ships_count ?? '') },
    { key: 'bugs_introduced', header: 'Bugs', render: (r) => String(r.bugs_introduced ?? '') },
    { key: 'mood_note', header: 'Mood', render: (r) => String(r.mood_note ?? '') },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r) => String(r.metric ?? '') },
    { key: 'value_7d', header: '7d Avg', render: (r) => String(r.value_7d ?? '') },
    { key: 'value_30d', header: '30d Avg', render: (r) => String(r.value_30d ?? '') },
    { key: 'trend', header: 'Trend', render: (r) => String(r.trend ?? '') },
  ];

  const corrCols: Column<any>[] = [
    { key: 'sleep_bucket', header: 'Sleep Bucket', render: (r) => String(r.sleep_bucket ?? '') },
    { key: 'log_count', header: 'Days', render: (r) => String(r.log_count ?? '') },
    { key: 'avg_output_quality', header: 'Avg Output Q', render: (r) => String(r.avg_output_quality ?? '') },
    { key: 'avg_ships', header: 'Avg Ships', render: (r) => String(r.avg_ships ?? '') },
    { key: 'avg_bugs', header: 'Avg Bugs', render: (r) => String(r.avg_bugs ?? '') },
  ];

  const alertCols: Column<any>[] = [
    { key: 'log_date', header: 'Date', render: (r) => String(r.log_date ?? '') },
    { key: 'morning_energy', header: 'AM Energy', render: (r) => String(r.morning_energy ?? '') },
    { key: 'sleep_hours', header: 'Sleep (h)', render: (r) => String(r.sleep_hours ?? '') },
    { key: 'consecutive_low_days', header: 'Low 3d Streak', render: (r) => String(r.consecutive_low_days ?? '') },
    { key: 'flag', header: 'Flag', render: (r) => String(r.flag ?? '') },
  ];

  const activeCols: Column<any>[] = [
    { key: 'started_on', header: 'Started', render: (r) => String(r.started_on ?? '') },
    { key: 'days_running', header: 'Days', render: (r) => String(r.days_running ?? '') },
    { key: 'intervention_type', header: 'Type', render: (r) => String(r.intervention_type ?? '') },
    { key: 'description', header: 'Description', render: (r) => String(r.description ?? '') },
    { key: 'hypothesis', header: 'Hypothesis', render: (r) => String(r.hypothesis ?? '') },
    { key: 'baseline_energy', header: 'Baseline E', render: (r) => String(r.baseline_energy ?? '-') },
    { key: 'current_energy_7d', header: 'Current 7d E', render: (r) => String(r.current_energy_7d ?? '') },
    { key: 'delta', header: 'Delta', render: (r) => String(r.delta ?? '') },
  ];

  const historyCols: Column<any>[] = [
    { key: 'started_on', header: 'Started', render: (r) => String(r.started_on ?? '') },
    { key: 'ended_on', header: 'Ended', render: (r) => String(r.ended_on ?? '') },
    { key: 'intervention_type', header: 'Type', render: (r) => String(r.intervention_type ?? '') },
    { key: 'description', header: 'Description', render: (r) => String(r.description ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r) => String(r.outcome ?? '') },
    { key: 'baseline_energy', header: 'Baseline E', render: (r) => String(r.baseline_energy ?? '-') },
    { key: 'post_energy', header: 'Post E', render: (r) => String(r.post_energy ?? '-') },
    { key: 'delta', header: 'Delta', render: (r) => String(r.delta ?? '') },
    { key: 'notes', header: 'Notes', render: (r) => String(r.notes ?? '') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ marginBottom: 8 }}>Founder Sleep + Energy Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Daily sleep hours, energy 1–10, output-quality correlation, intervention log.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        <KpiCard label="Logs (30d)" value={kpi.logs_30d ?? 0} />
        <KpiCard label="Avg Sleep (30d)" value={`${kpi.avg_sleep_30d ?? 0} h`} />
        <KpiCard label="Avg Energy (30d)" value={`${kpi.avg_energy_30d ?? 0} / 10`} />
        <KpiCard label="Avg Output Q (30d)" value={`${kpi.avg_output_30d ?? 0} / 10`} />
        <KpiCard label="Low-Energy Days (7d)" value={kpi.low_energy_days_7d ?? 0} />
        <KpiCard label="Active Interventions" value={kpi.active_interventions ?? 0} />
        <KpiCard label="Positive Interventions" value={kpi.positive_interventions_lifetime ?? 0} />
        <KpiCard label="Best Sleep Bucket" value={String(kpi.best_sleep_bucket ?? 'no_data')} />
      </section>

      <h2 style={{ marginTop: 24 }}>7d vs 30d Trend</h2>
      <DataTable
        rows={weeklyRows}
        emptyMessage="No data yet."
        rowKey={(r: any) => String(r.metric)}
        columns={weeklyCols}
      />

      <h2 style={{ marginTop: 32 }}>Energy Decline Alerts</h2>
      <DataTable
        rows={alertRows}
        emptyMessage="No alerts — energy healthy."
        rowKey={(r: any) => String(r.log_date)}
        columns={alertCols}
      />

      <h2 style={{ marginTop: 32 }}>Sleep =&gt; Output Correlation (90d)</h2>
      <DataTable
        rows={corrRows}
        emptyMessage="Need more logs to compute correlation."
        rowKey={(r: any) => String(r.sleep_bucket)}
        columns={corrCols}
      />

      <h2 style={{ marginTop: 32 }}>Active Interventions</h2>
      <DataTable
        rows={activeRows}
        emptyMessage="No active interventions."
        rowKey={(r: any) => String(r.id)}
        columns={activeCols}
      />

      <h2 style={{ marginTop: 32 }}>Recent Daily Log (30d)</h2>
      <DataTable
        rows={recentRows}
        emptyMessage="No logs in last 30 days."
        rowKey={(r: any) => String(r.log_date)}
        columns={recentCols}
      />

      <h2 style={{ marginTop: 32 }}>Intervention History</h2>
      <DataTable
        rows={historyRows}
        emptyMessage="No completed interventions."
        rowKey={(r: any) => `${r.started_on}-${r.intervention_type}`}
        columns={historyCols}
      />
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 600, marginTop: 6 }}>{value}</div>
    </div>
  );
}
