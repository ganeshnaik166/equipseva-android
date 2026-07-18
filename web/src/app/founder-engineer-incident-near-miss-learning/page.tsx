import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerIncidentNearMissLearningPage() {
  const supabase = await getSupabaseServerClient();

  const [nmRes, updatesRes, sevRes, breakdownRes, rateRes, trendRes, ownerRes] = await Promise.all([
    supabase.rpc('list_near_misses_r2558'),
    supabase.rpc('list_runbook_updates_r2558'),
    supabase.rpc('top_severity_focus_r2558'),
    supabase.rpc('root_cause_breakdown_r2558'),
    supabase.rpc('runbook_incorporation_rate_r2558'),
    supabase.rpc('monthly_near_miss_trend_r2558'),
    supabase.rpc('owner_load_r2558'),
  ]);

  const nearMisses = (nmRes.data ?? []) as any[];
  const updates = (updatesRes.data ?? []) as any[];
  const sevFocus = (sevRes.data ?? []) as any[];
  const breakdown = (breakdownRes.data ?? []) as any[];
  const rate = (rateRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const ownerLoad = (ownerRes.data ?? []) as any[];

  const nmCols: Column<any>[] = [
    { key: 'incident_at', header: 'Incident', render: (r: any) => r.incident_at ? new Date(r.incident_at).toLocaleString() : '-' },
    { key: 'near_miss_kind', header: 'Kind', render: (r: any) => r.near_miss_kind ?? '-' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '-' },
    { key: 'incorporated_into_runbook', header: 'In Runbook?', render: (r: any) => r.incorporated_into_runbook ? 'yes' : 'no' },
    { key: 'follow_up_audit_at', header: 'Follow-up', render: (r: any) => r.follow_up_audit_at ? new Date(r.follow_up_audit_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'root_cause_md', header: 'Root Cause', render: (r: any) => r.root_cause_md ?? '-' },
    { key: 'shared_lessons_md', header: 'Lessons', render: (r: any) => r.shared_lessons_md ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const updatesCols: Column<any>[] = [
    { key: 'update_kind', header: 'Update Kind', render: (r: any) => r.update_kind ?? '-' },
    { key: 'update_summary_md', header: 'Summary', render: (r: any) => r.update_summary_md ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'target_at', header: 'Target', render: (r: any) => r.target_at ? new Date(r.target_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const sevCols: Column<any>[] = [
    { key: 'incident_at', header: 'Incident', render: (r: any) => r.incident_at ? new Date(r.incident_at).toLocaleString() : '-' },
    { key: 'near_miss_kind', header: 'Kind', render: (r: any) => r.near_miss_kind ?? '-' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '-' },
    { key: 'incorporated_into_runbook', header: 'In Runbook?', render: (r: any) => r.incorporated_into_runbook ? 'yes' : 'no' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'near_miss_kind', header: 'Kind', render: (r: any) => r.near_miss_kind ?? '-' },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => r.incident_count ?? 0 },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count ?? 0 },
    { key: 'high_count', header: 'High', render: (r: any) => r.high_count ?? 0 },
    { key: 'incorporated_count', header: 'Incorporated', render: (r: any) => r.incorporated_count ?? 0 },
  ];

  const rateCols: Column<any>[] = [
    { key: 'total_incidents', header: 'Total', render: (r: any) => r.total_incidents ?? 0 },
    { key: 'incorporated_count', header: 'Incorporated', render: (r: any) => r.incorporated_count ?? 0 },
    { key: 'not_incorporated_count', header: 'Not Incorporated', render: (r: any) => r.not_incorporated_count ?? 0 },
    { key: 'incorporation_rate_pct', header: 'Rate %', render: (r: any) => (r.incorporation_rate_pct ?? 0) + '%' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '-' },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => r.incident_count ?? 0 },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count ?? 0 },
    { key: 'high_count', header: 'High', render: (r: any) => r.high_count ?? 0 },
    { key: 'incorporated_count', header: 'Incorporated', render: (r: any) => r.incorporated_count ?? 0 },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'open_updates', header: 'Open', render: (r: any) => r.open_updates ?? 0 },
    { key: 'done_updates', header: 'Done', render: (r: any) => r.done_updates ?? 0 },
    { key: 'dropped_updates', header: 'Dropped', render: (r: any) => r.dropped_updates ?? 0 },
    { key: 'total_updates', header: 'Total', render: (r: any) => r.total_updates ?? 0 },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Incident & Near-Miss Learning</h1>
        <p className="text-sm text-gray-600">
          Incident &gt; near-miss &gt; root cause &gt; shared lessons &gt; runbook update &gt; follow-up audit.
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Runbook Incorporation Rate</h2>
        <DataTable
          rows={rate}
          columns={rateCols}
          emptyMessage="No incidents yet."
          rowKey={(r: any, i: number) => String(r.total_incidents ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Top Severity Focus</h2>
        <DataTable
          rows={sevFocus}
          columns={sevCols}
          emptyMessage="No high-severity items."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Root Cause Breakdown</h2>
        <DataTable
          rows={breakdown}
          columns={breakdownCols}
          emptyMessage="No breakdown data."
          rowKey={(r: any, i: number) => String(r.near_miss_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Monthly Near-Miss Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend yet."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">All Near-Misses</h2>
        <DataTable
          rows={nearMisses}
          columns={nmCols}
          emptyMessage="No near-misses logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Runbook Updates</h2>
        <DataTable
          rows={updates}
          columns={updatesCols}
          emptyMessage="No runbook updates."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
