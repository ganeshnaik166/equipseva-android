import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toLocaleString('en-IN');
}

function fmtHours(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toFixed(1) + ' h';
}

function fmtDate(s: any): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return '—'; }
}

export default async function FounderHospitalEscalationDrilldownPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let digest: any = null;
  let summary: any[] = [];
  let history: any[] = [];
  let clusters: any[] = [];
  let repeat: any[] = [];
  let queue: any[] = [];
  let clusterHospital: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_esc_kpi_digest');
    digest = (r.data && r.data[0]) || null;
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_hospital_esc_summary');
    summary = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_hospital_esc_history');
    history = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_hospital_esc_clusters');
    clusters = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_hospital_esc_repeat');
    repeat = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_esc_action_queue');
    queue = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_esc_cluster_hospital');
    clusterHospital = r.data ?? [];
  } catch {}

  const kpis: Kpi[] = [
    { label: 'Total events', value: fmtNum(digest?.total_events) },
    { label: 'Open events', value: fmtNum(digest?.open_events) },
    { label: 'P0 count', value: fmtNum(digest?.p0_count) },
    { label: 'P1 count', value: fmtNum(digest?.p1_count) },
    { label: 'P2 count', value: fmtNum(digest?.p2_count) },
    { label: 'P3 count', value: fmtNum(digest?.p3_count) },
    { label: 'Events 7d', value: fmtNum(digest?.events_7d) },
    { label: 'Events 30d', value: fmtNum(digest?.events_30d) },
    { label: 'Avg resolution', value: fmtHours(digest?.avg_resolution_hours) },
    { label: 'Queue pending', value: fmtNum(digest?.queue_pending) },
    { label: 'Queue overdue', value: fmtNum(digest?.queue_overdue) },
    { label: 'Affected hospitals', value: fmtNum(digest?.affected_hospitals) },
    { label: 'Hospitals tracked', value: fmtNum(summary.length) },
    { label: 'Repeat-escalators', value: fmtNum(repeat.length) },
    { label: 'Cluster types', value: fmtNum(clusters.length) },
    { label: 'History rows', value: fmtNum(history.length) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'total_escalations', header: 'Total', render: (r: any) => fmtNum(r.total_escalations) },
    { key: 'open_escalations', header: 'Open', render: (r: any) => fmtNum(r.open_escalations) },
    { key: 'p0_p1_count', header: 'P0/P1', render: (r: any) => fmtNum(r.p0_p1_count) },
    { key: 'avg_resolution_hours', header: 'Avg resolution', render: (r: any) => fmtHours(r.avg_resolution_hours) },
    { key: 'last_escalation_at', header: 'Last event', render: (r: any) => fmtDate(r.last_escalation_at) },
    { key: 'repeat_flag', header: 'Repeat?', render: (r: any) => (r.repeat_flag ? 'YES' : 'no') },
  ];

  const historyCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'source_type', header: 'Source', render: (r: any) => r.source_type ?? '—' },
    { key: 'severity', header: 'Sev', render: (r: any) => (r.severity ?? '—').toString().toUpperCase() },
    { key: 'root_cause_cluster', header: 'Cluster', render: (r: any) => r.root_cause_cluster ?? '—' },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary ?? '—' },
    { key: 'opened_at', header: 'Opened', render: (r: any) => fmtDate(r.opened_at) },
    { key: 'resolved_at', header: 'Resolved', render: (r: any) => fmtDate(r.resolved_at) },
    { key: 'resolution_hours', header: 'Resolved in', render: (r: any) => fmtHours(r.resolution_hours) },
  ];

  const clustersCols: Column<any>[] = [
    { key: 'root_cause_cluster', header: 'Cluster', render: (r: any) => r.root_cause_cluster ?? '—' },
    { key: 'event_count', header: 'Events', render: (r: any) => fmtNum(r.event_count) },
    { key: 'affected_hospitals', header: 'Hospitals', render: (r: any) => fmtNum(r.affected_hospitals) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'avg_resolution_hours', header: 'Avg resolution', render: (r: any) => fmtHours(r.avg_resolution_hours) },
  ];

  const repeatCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'escalations_90d', header: 'Events 90d', render: (r: any) => fmtNum(r.escalations_90d) },
    { key: 'p0_p1_90d', header: 'P0/P1 90d', render: (r: any) => fmtNum(r.p0_p1_90d) },
    { key: 'dominant_cluster', header: 'Dominant cluster', render: (r: any) => r.dominant_cluster ?? '—' },
    { key: 'last_escalation_at', header: 'Last event', render: (r: any) => fmtDate(r.last_escalation_at) },
  ];

  const queueCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'priority', header: 'Pri', render: (r: any) => (r.priority ?? '—').toString().toUpperCase() },
    { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
    { key: 'due_at', header: 'Due', render: (r: any) => fmtDate(r.due_at) },
    { key: 'overdue_hours', header: 'Overdue', render: (r: any) => fmtHours(r.overdue_hours) },
    { key: 'action_note', header: 'Note', render: (r: any) => r.action_note ?? '—' },
  ];

  return (
    <main className="p-6 space-y-6">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Hospital escalation drilldown</h1>
          <p className="text-sm text-gray-500">Per-hospital escalation history, root-cause clusters, repeat-escalator flags, founder action queue.</p>
        </div>
        <div className="text-xs text-gray-400">r1587</div>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border border-gray-200 bg-white p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Hospitals by escalation volume</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any) => r.hospital_org_id}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Repeat-escalators (last 90 days)</h2>
        <DataTable
          rows={repeat}
          columns={repeatCols}
          rowKey={(r: any) => r.hospital_org_id}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Root-cause clusters</h2>
        <DataTable
          rows={clusters}
          columns={clustersCols}
          rowKey={(r: any) => r.root_cause_cluster}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Founder action queue</h2>
        <DataTable
          rows={queue}
          columns={queueCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Escalation history</h2>
        <DataTable
          rows={history}
          columns={historyCols}
          rowKey={(r: any) => r.id}
        />
      </section>
    </main>
  );
}
