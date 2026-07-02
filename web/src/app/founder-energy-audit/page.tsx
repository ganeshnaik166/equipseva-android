import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type AuditRow = {
  id: string;
  week_start: string;
  total_hours: number;
  deep_work_hours: number;
  meetings_hours: number;
  ops_hours: number;
  sales_hours: number;
  recovery_hours: number;
  energy_level: number;
  status: string;
  recorded_at: string;
};

type TrendRow = {
  week_start: string;
  energy_level: number;
  total_hours: number;
  deep_work_hours: number;
  meetings_hours: number;
  recovery_hours: number;
};

type FollowupRow = {
  id: string;
  audit_id: string;
  week_start: string;
  followup_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, trendRes, followupsRes] = await Promise.all([
    sb.rpc('list_audits_r1942'),
    sb.rpc('energy_trend_r1942'),
    sb.rpc('recent_followups_r1942'),
  ]);

  const audits: AuditRow[] = (auditsRes.data as AuditRow[] | null) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];
  const followups: FollowupRow[] = (followupsRes.data as FollowupRow[] | null) ?? [];

  const auditCols: Column<AuditRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'total_hours', header: 'Total hrs', render: (r: any) => String(r.total_hours ?? 0) },
    { key: 'deep_work_hours', header: 'Deep work', render: (r: any) => String(r.deep_work_hours ?? 0) },
    { key: 'meetings_hours', header: 'Meetings', render: (r: any) => String(r.meetings_hours ?? 0) },
    { key: 'ops_hours', header: 'Ops', render: (r: any) => String(r.ops_hours ?? 0) },
    { key: 'sales_hours', header: 'Sales', render: (r: any) => String(r.sales_hours ?? 0) },
    { key: 'recovery_hours', header: 'Recovery', render: (r: any) => String(r.recovery_hours ?? 0) },
    { key: 'energy_level', header: 'Energy (1 to 10)', render: (r: any) => String(r.energy_level ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'energy_level', header: 'Energy', render: (r: any) => String(r.energy_level ?? 0) },
    { key: 'total_hours', header: 'Total hrs', render: (r: any) => String(r.total_hours ?? 0) },
    { key: 'deep_work_hours', header: 'Deep work', render: (r: any) => String(r.deep_work_hours ?? 0) },
    { key: 'meetings_hours', header: 'Meetings', render: (r: any) => String(r.meetings_hours ?? 0) },
    { key: 'recovery_hours', header: 'Recovery', render: (r: any) => String(r.recovery_hours ?? 0) },
  ];

  const followupCols: Column<FollowupRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'followup_type', header: 'Type', render: (r: any) => String(r.followup_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Energy Audit</h1>
        <p className="text-sm text-gray-600">
          Weekly self-audit of where founder energy goes. Energy rating 1 to 10. Track deep work vs meetings vs ops vs sales vs recovery.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly audits</h2>
        <DataTable
          rows={audits}
          columns={auditCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
        {audits.length === 0 && <p className="text-sm text-gray-500 mt-2">No audits logged yet.</p>}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Energy trend (last 26 weeks)</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
        {trend.length === 0 && <p className="text-sm text-gray-500 mt-2">No trend data yet.</p>}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent follow-ups</h2>
        <DataTable
          rows={followups}
          columns={followupCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
        {followups.length === 0 && <p className="text-sm text-gray-500 mt-2">No follow-ups yet.</p>}
      </section>
    </div>
  );
}
