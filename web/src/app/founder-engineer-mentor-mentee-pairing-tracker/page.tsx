import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [pairings, meetings, active, topLift, mentorLoad, weekly, bonusSummary] = await Promise.all([
    supabase.rpc('list_pairings_r2458'),
    supabase.rpc('list_meetings_r2458'),
    supabase.rpc('active_pairings_r2458'),
    supabase.rpc('top_lift_pairings_r2458'),
    supabase.rpc('mentor_load_r2458'),
    supabase.rpc('weekly_meeting_compliance_r2458'),
    supabase.rpc('mentor_bonus_summary_r2458'),
  ]);

  const pairingCols: Column<any>[] = [
    { key: 'pairing_start', header: 'Start', render: (r: any) => r.pairing_start ? new Date(r.pairing_start).toLocaleDateString() : '—' },
    { key: 'mentor_engineer_user_id', header: 'Mentor', render: (r: any) => String(r.mentor_engineer_user_id ?? '').slice(0, 8) },
    { key: 'mentee_engineer_user_id', header: 'Mentee', render: (r: any) => String(r.mentee_engineer_user_id ?? '').slice(0, 8) },
    { key: 'pairing_weeks', header: 'Weeks', render: (r: any) => String(r.pairing_weeks ?? 0) },
    { key: 'cadence', header: 'Meetings (act/plan)', render: (r: any) => `${r.actual_meetings_count ?? 0} / ${(r.pairing_weeks ?? 0) * (r.planned_meetings_per_week ?? 0)}` },
    { key: 'ramp_score_lift_pct', header: 'Lift %', render: (r: any) => `${Number(r.ramp_score_lift_pct ?? 0).toFixed(1)}%` },
    { key: 'mentor_bonus_rupees', header: 'Bonus', render: (r: any) => `₹${Number(r.mentor_bonus_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
  ];

  const meetingCols: Column<any>[] = [
    { key: 'meeting_at', header: 'When', render: (r: any) => r.meeting_at ? new Date(r.meeting_at).toLocaleString() : '—' },
    { key: 'pairing_id', header: 'Pairing', render: (r: any) => String(r.pairing_id ?? '').slice(0, 8) },
    { key: 'duration_minutes', header: 'Mins', render: (r: any) => String(r.duration_minutes ?? 0) },
    { key: 'completion_score', header: 'Score', render: (r: any) => `${r.completion_score ?? 0}/100` },
    { key: 'agenda', header: 'Agenda', render: (r: any) => String(r.agenda ?? '') },
    { key: 'next_focus', header: 'Next focus', render: (r: any) => String(r.next_focus ?? '') },
  ];

  const activeCols: Column<any>[] = [
    { key: 'mentor_engineer_user_id', header: 'Mentor', render: (r: any) => String(r.mentor_engineer_user_id ?? '').slice(0, 8) },
    { key: 'mentee_engineer_user_id', header: 'Mentee', render: (r: any) => String(r.mentee_engineer_user_id ?? '').slice(0, 8) },
    { key: 'weeks_elapsed', header: 'Wk elapsed', render: (r: any) => `${r.weeks_elapsed ?? 0} / ${r.pairing_weeks ?? 0}` },
    { key: 'cadence_pct', header: 'Cadence %', render: (r: any) => `${Number(r.cadence_pct ?? 0).toFixed(1)}%` },
    { key: 'planned_meetings_total', header: 'Met (act/plan)', render: (r: any) => `${r.actual_meetings_count ?? 0} / ${r.planned_meetings_total ?? 0}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const topLiftCols: Column<any>[] = [
    { key: 'mentor_engineer_user_id', header: 'Mentor', render: (r: any) => String(r.mentor_engineer_user_id ?? '').slice(0, 8) },
    { key: 'mentee_engineer_user_id', header: 'Mentee', render: (r: any) => String(r.mentee_engineer_user_id ?? '').slice(0, 8) },
    { key: 'ramp_score_lift_pct', header: 'Lift %', render: (r: any) => `${Number(r.ramp_score_lift_pct ?? 0).toFixed(1)}%` },
    { key: 'pairing_weeks', header: 'Weeks', render: (r: any) => String(r.pairing_weeks ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
  ];

  const loadCols: Column<any>[] = [
    { key: 'mentor_engineer_user_id', header: 'Mentor', render: (r: any) => String(r.mentor_engineer_user_id ?? '').slice(0, 8) },
    { key: 'total_pairings', header: 'Total', render: (r: any) => String(r.total_pairings ?? 0) },
    { key: 'active_pairings', header: 'Active', render: (r: any) => String(r.active_pairings ?? 0) },
    { key: 'completed_pairings', header: 'Done', render: (r: any) => String(r.completed_pairings ?? 0) },
    { key: 'avg_lift_pct', header: 'Avg lift %', render: (r: any) => `${Number(r.avg_lift_pct ?? 0).toFixed(1)}%` },
    { key: 'total_bonus_rupees', header: 'Total bonus', render: (r: any) => `₹${Number(r.total_bonus_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start ? new Date(r.week_start).toLocaleDateString() : '—' },
    { key: 'meetings_count', header: 'Meetings', render: (r: any) => String(r.meetings_count ?? 0) },
    { key: 'avg_completion', header: 'Avg score', render: (r: any) => `${Number(r.avg_completion ?? 0).toFixed(1)}/100` },
    { key: 'avg_duration_minutes', header: 'Avg mins', render: (r: any) => Number(r.avg_duration_minutes ?? 0).toFixed(1) },
  ];

  const bonusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'pairings_count', header: 'Pairings', render: (r: any) => String(r.pairings_count ?? 0) },
    { key: 'total_bonus_rupees', header: 'Total bonus', render: (r: any) => `₹${Number(r.total_bonus_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'avg_bonus_rupees', header: 'Avg bonus', render: (r: any) => `₹${Number(r.avg_bonus_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'avg_lift_pct', header: 'Avg lift %', render: (r: any) => `${Number(r.avg_lift_pct ?? 0).toFixed(1)}%` },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Mentor & Mentee Pairing Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Senior mentor × junior mentee × pairing weeks × ramp lift × meeting cadence × mentor bonus
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All pairings</h2>
        <DataTable
          rows={pairings.data ?? []}
          columns={pairingCols}
          emptyMessage="No pairings yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Active & at-risk pairings</h2>
        <DataTable
          rows={active.data ?? []}
          columns={activeCols}
          emptyMessage="No active pairings"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top ramp-lift pairings</h2>
        <DataTable
          rows={topLift.data ?? []}
          columns={topLiftCols}
          emptyMessage="No lift data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Mentor load</h2>
        <DataTable
          rows={mentorLoad.data ?? []}
          columns={loadCols}
          emptyMessage="No mentors yet"
          rowKey={(r: any, i: number) => String(r.mentor_engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly meeting compliance</h2>
        <DataTable
          rows={weekly.data ?? []}
          columns={weeklyCols}
          emptyMessage="No meeting data"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Mentor bonus summary</h2>
        <DataTable
          rows={bonusSummary.data ?? []}
          columns={bonusCols}
          emptyMessage="No bonus data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent meetings</h2>
        <DataTable
          rows={meetings.data ?? []}
          columns={meetingCols}
          emptyMessage="No meetings logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
