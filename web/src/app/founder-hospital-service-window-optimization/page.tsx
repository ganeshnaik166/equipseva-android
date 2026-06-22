import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type WindowRow = {
  id: string;
  hospital_user_id: string;
  hospital_name: string;
  time_window: string;
  day_of_week: number;
  jobs_count: number;
  avg_response_min: number;
  peak: boolean;
  recorded_at: string;
};

type RuleRow = {
  id: string;
  window_id: string;
  time_window: string;
  day_of_week: number;
  routing_rule: string;
  applied_at: string;
  status: string;
};

type PeakSummaryRow = {
  time_window: string;
  peak_count: number;
  total_jobs: number;
  avg_response_min: number;
};

type TopDemandRow = {
  id: string;
  hospital_user_id: string;
  hospital_name: string;
  time_window: string;
  day_of_week: number;
  jobs_count: number;
  avg_response_min: number;
  peak: boolean;
};

type RuleChangeRow = {
  id: string;
  window_id: string;
  time_window: string;
  day_of_week: number;
  routing_rule: string;
  status: string;
  applied_at: string;
};

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [windowsRes, rulesRes, peakRes, topDemandRes, recentChangesRes] = await Promise.all([
    sb.rpc('list_service_windows_r1883', { p_limit: 200 }),
    sb.rpc('list_service_window_rules_r1883', { p_limit: 200 }),
    sb.rpc('peak_service_windows_summary_r1883'),
    sb.rpc('top_demand_service_windows_r1883', { p_limit: 20 }),
    sb.rpc('recent_service_window_rule_changes_r1883', { p_limit: 50 }),
  ]);

  const windows: WindowRow[] = (windowsRes.data as WindowRow[]) ?? [];
  const rules: RuleRow[] = (rulesRes.data as RuleRow[]) ?? [];
  const peakSummary: PeakSummaryRow[] = (peakRes.data as PeakSummaryRow[]) ?? [];
  const topDemand: TopDemandRow[] = (topDemandRes.data as TopDemandRow[]) ?? [];
  const recentChanges: RuleChangeRow[] = (recentChangesRes.data as RuleChangeRow[]) ?? [];

  const totalWindows = windows.length;
  const peakWindows = windows.filter((w) => w.peak).length;
  const activeRules = rules.filter((r) => r.status === 'active').length;
  const totalJobs = windows.reduce((s, w) => s + (w.jobs_count ?? 0), 0);

  const windowsCols: Column<WindowRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'time_window', header: 'Window', render: (r: any) => r.time_window },
    { key: 'day_of_week', header: 'Day', render: (r: any) => DAY_NAMES[r.day_of_week] ?? String(r.day_of_week) },
    { key: 'jobs_count', header: 'Jobs', render: (r: any) => String(r.jobs_count) },
    { key: 'avg_response_min', header: 'Avg resp (min)', render: (r: any) => String(r.avg_response_min) },
    { key: 'peak', header: 'Peak', render: (r: any) => (r.peak ? 'yes' : 'no') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => new Date(r.recorded_at).toLocaleString() },
  ];

  const peakCols: Column<PeakSummaryRow>[] = [
    { key: 'time_window', header: 'Window', render: (r: any) => r.time_window },
    { key: 'peak_count', header: 'Peak count', render: (r: any) => String(r.peak_count) },
    { key: 'total_jobs', header: 'Total jobs', render: (r: any) => String(r.total_jobs) },
    { key: 'avg_response_min', header: 'Avg resp (min)', render: (r: any) => Number(r.avg_response_min).toFixed(2) },
  ];

  const topDemandCols: Column<TopDemandRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'time_window', header: 'Window', render: (r: any) => r.time_window },
    { key: 'day_of_week', header: 'Day', render: (r: any) => DAY_NAMES[r.day_of_week] ?? String(r.day_of_week) },
    { key: 'jobs_count', header: 'Jobs', render: (r: any) => String(r.jobs_count) },
    { key: 'avg_response_min', header: 'Avg resp (min)', render: (r: any) => String(r.avg_response_min) },
    { key: 'peak', header: 'Peak', render: (r: any) => (r.peak ? 'yes' : 'no') },
  ];

  const rulesCols: Column<RuleRow>[] = [
    { key: 'time_window', header: 'Window', render: (r: any) => r.time_window },
    { key: 'day_of_week', header: 'Day', render: (r: any) => DAY_NAMES[r.day_of_week] ?? String(r.day_of_week) },
    { key: 'routing_rule', header: 'Rule', render: (r: any) => r.routing_rule },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'applied_at', header: 'Applied', render: (r: any) => new Date(r.applied_at).toLocaleString() },
  ];

  const recentChangesCols: Column<RuleChangeRow>[] = [
    { key: 'time_window', header: 'Window', render: (r: any) => r.time_window },
    { key: 'day_of_week', header: 'Day', render: (r: any) => DAY_NAMES[r.day_of_week] ?? String(r.day_of_week) },
    { key: 'routing_rule', header: 'Rule', render: (r: any) => r.routing_rule },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'applied_at', header: 'Applied', render: (r: any) => new Date(r.applied_at).toLocaleString() },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Hospital Service Window Optimization
      </h1>
      <p style={{ color: '#666', marginBottom: 24, fontSize: 14 }}>
        Optimize service windows per hospital across peak & off-peak times. Round r1883.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total windows tracked</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalWindows}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Peak windows</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{peakWindows}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active routing rules</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{activeRules}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total jobs in sample</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalJobs}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Peak windows summary</h2>
        <DataTable
          rows={peakSummary}
          columns={peakCols}
          rowKey={(r: any, i: number) => String(r.time_window ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top demand windows</h2>
        <DataTable
          rows={topDemand}
          columns={topDemandCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All service windows</h2>
        <DataTable
          rows={windows}
          columns={windowsCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Routing rules</h2>
        <DataTable
          rows={rules}
          columns={rulesCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent rule changes</h2>
        <DataTable
          rows={recentChanges}
          columns={recentChangesCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
