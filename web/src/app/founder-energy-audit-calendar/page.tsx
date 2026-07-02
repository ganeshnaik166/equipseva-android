import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEnergyAuditCalendarPage() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, summariesRes, removableRes, trendRes, offendersRes] = await Promise.all([
    sb.rpc('r1722_list_audits'),
    sb.rpc('r1722_list_summaries'),
    sb.rpc('r1722_removable_recurring_meetings'),
    sb.rpc('r1722_weekly_energy_score_trend'),
    sb.rpc('r1722_monthly_drain_top_offenders'),
  ]);

  const audits = (auditsRes.data ?? []) as any[];
  const summaries = (summariesRes.data ?? []) as any[];
  const removable = (removableRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const offenders = (offendersRes.data ?? []) as any[];

  const auditColumns: Column<any>[] = [
    { key: 'audit_date', header: 'Date', render: (r: any) => r.audit_date ? new Date(r.audit_date).toLocaleDateString() : '—' },
    { key: 'meeting_title', header: 'Meeting', render: (r: any) => r.meeting_title ?? '—' },
    { key: 'meeting_duration_min', header: 'Min', render: (r: any) => String(r.meeting_duration_min ?? 0) },
    { key: 'energy_impact', header: 'Impact', render: (r: any) => {
      const v = String(r.energy_impact ?? '');
      const cls = v === 'charge' ? 'text-green-700 font-semibold' : v === 'drain' ? 'text-red-700 font-semibold' : 'text-gray-600';
      return <span className={cls}>{v.toUpperCase()}</span>;
    }},
    { key: 'importance', header: 'Importance', render: (r: any) => <span className="uppercase">{r.importance ?? '—'}</span> },
    { key: 'was_calendar_or_adhoc', header: 'Source', render: (r: any) => r.was_calendar_or_adhoc ?? '—' },
    { key: 'removable_next_time', header: 'Removable?', render: (r: any) => r.removable_next_time ? 'Yes' : 'No' },
    { key: 'attendee_emails', header: 'Attendees', render: (r: any) => Array.isArray(r.attendee_emails) ? String(r.attendee_emails.length) : '0' },
  ];

  const summaryColumns: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start ? new Date(r.week_start).toLocaleDateString() : '—' },
    { key: 'total_meetings', header: 'Total', render: (r: any) => String(r.total_meetings ?? 0) },
    { key: 'drain_count', header: 'Drain #', render: (r: any) => <span className="text-red-700">{String(r.drain_count ?? 0)}</span> },
    { key: 'charge_count', header: 'Charge #', render: (r: any) => <span className="text-green-700">{String(r.charge_count ?? 0)}</span> },
    { key: 'neutral_count', header: 'Neutral #', render: (r: any) => String(r.neutral_count ?? 0) },
    { key: 'total_drain_min', header: 'Drain Min', render: (r: any) => <span className="text-red-700">{String(r.total_drain_min ?? 0)}</span> },
    { key: 'total_charge_min', header: 'Charge Min', render: (r: any) => <span className="text-green-700">{String(r.total_charge_min ?? 0)}</span> },
    { key: 'score', header: 'Score', render: (r: any) => {
      const s = Number(r.score ?? 0);
      const cls = s > 0 ? 'text-green-700 font-bold' : s < 0 ? 'text-red-700 font-bold' : 'text-gray-700';
      return <span className={cls}>{String(s)}</span>;
    }},
    { key: 'recomputed_at', header: 'Recomputed', render: (r: any) => r.recomputed_at ? new Date(r.recomputed_at).toLocaleString() : '—' },
  ];

  const removableColumns: Column<any>[] = [
    { key: 'meeting_title', header: 'Meeting', render: (r: any) => r.meeting_title ?? '—' },
    { key: 'times_logged', header: 'Times', render: (r: any) => String(r.times_logged ?? 0) },
    { key: 'total_min', header: 'Total Min', render: (r: any) => String(r.total_min ?? 0) },
    { key: 'drain_count', header: 'Drain #', render: (r: any) => <span className="text-red-700">{String(r.drain_count ?? 0)}</span> },
    { key: 'avg_duration_min', header: 'Avg Min', render: (r: any) => String(r.avg_duration_min ?? 0) },
    { key: 'last_audit_date', header: 'Last Seen', render: (r: any) => r.last_audit_date ? new Date(r.last_audit_date).toLocaleDateString() : '—' },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start ? new Date(r.week_start).toLocaleDateString() : '—' },
    { key: 'score', header: 'Score', render: (r: any) => {
      const s = Number(r.score ?? 0);
      const cls = s > 0 ? 'text-green-700 font-bold' : s < 0 ? 'text-red-700 font-bold' : 'text-gray-700';
      return <span className={cls}>{String(s)}</span>;
    }},
    { key: 'total_drain_min', header: 'Drain Min', render: (r: any) => String(r.total_drain_min ?? 0) },
    { key: 'total_charge_min', header: 'Charge Min', render: (r: any) => String(r.total_charge_min ?? 0) },
    { key: 'total_meetings', header: 'Meetings', render: (r: any) => String(r.total_meetings ?? 0) },
  ];

  const offenderColumns: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? new Date(r.month_start).toLocaleDateString() : '—' },
    { key: 'meeting_title', header: 'Meeting', render: (r: any) => r.meeting_title ?? '—' },
    { key: 'drain_count', header: 'Drain #', render: (r: any) => <span className="text-red-700 font-semibold">{String(r.drain_count ?? 0)}</span> },
    { key: 'total_drain_min', header: 'Total Drain Min', render: (r: any) => <span className="text-red-700">{String(r.total_drain_min ?? 0)}</span> },
    { key: 'avg_duration_min', header: 'Avg Min', render: (r: any) => String(r.avg_duration_min ?? 0) },
  ];

  return (
    <div className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Founder Energy Audit Calendar</h1>
        <p className="text-sm text-gray-600 mt-1">
          Log each meeting and task by energy impact — drains, neutral, or charges. Weekly score = charge minutes − drain minutes.
          Score &gt; 0 means a net-positive week; score &lt; 0 means burnout risk. Track removable recurring meetings to reclaim founder time.
        </p>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Energy Score Trend (last 26 weeks)</h2>
        <p className="text-xs text-gray-500 mb-2">
          Trend line of net energy. Sustained negative score &lt;= −300 minutes is the burnout zone — cut drain meetings now.
        </p>
        <DataTable rows={trend} columns={trendColumns} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Summaries</h2>
        <DataTable rows={summaries} columns={summaryColumns} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Removable Recurring Meetings</h2>
        <p className="text-xs text-gray-500 mb-2">
          Meetings flagged removable_next_time = true. Sorted by total minutes — biggest wins first.
        </p>
        <DataTable rows={removable} columns={removableColumns} rowKey={(r: any, i: number) => String(r.meeting_title ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Drain Top Offenders (last 90 days)</h2>
        <p className="text-xs text-gray-500 mb-2">
          Meetings rated drain in the last 90 days, bucketed by month. Top offenders are the first to renegotiate or kill.
        </p>
        <DataTable rows={offenders} columns={offenderColumns} rowKey={(r: any, i: number) => String((r.month_start ?? '') + '-' + (r.meeting_title ?? i))} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Audits (last 500)</h2>
        <DataTable rows={audits} columns={auditColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
