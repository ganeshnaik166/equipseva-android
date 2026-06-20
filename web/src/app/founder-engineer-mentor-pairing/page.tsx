import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined, total: number): string {
  if (!total || n === null || n === undefined) return '—';
  return `${((Number(n) / total) * 100).toFixed(1)}%`;
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpisRes, pairsRes, staleRes, sessionsRes, mentorsRes] = await Promise.all([
    supabase.rpc('founder_mentor_pairing_kpis'),
    supabase.rpc('founder_mentor_pairs_list'),
    supabase.rpc('founder_mentor_stale_pairs'),
    supabase.rpc('founder_mentor_recent_sessions'),
    supabase.rpc('founder_mentor_top_mentors'),
  ]);

  const k = (kpisRes.data?.[0] ?? {}) as any;
  const pairs = (pairsRes.data ?? []) as any[];
  const stale = (staleRes.data ?? []) as any[];
  const sessions = (sessionsRes.data ?? []) as any[];
  const mentors = (mentorsRes.data ?? []) as any[];

  const kpis: Kpi[] = [
    { label: 'Total Pairs', value: fmtNum(k.total_pairs) },
    { label: 'Active', value: fmtNum(k.active_pairs) },
    { label: 'Paused', value: fmtNum(k.paused_pairs) },
    { label: 'Completed', value: fmtNum(k.completed_pairs) },
    { label: 'Cancelled', value: fmtNum(k.cancelled_pairs) },
    { label: 'Total Sessions', value: fmtNum(k.total_sessions) },
    { label: 'Sessions (30d)', value: fmtNum(k.sessions_last_30d) },
    { label: 'Avg Mentor NPS', value: fmtNum(k.avg_mentor_nps) },
    { label: 'Avg Mentee NPS', value: fmtNum(k.avg_mentee_nps) },
    { label: 'Avg Duration (min)', value: fmtNum(k.avg_duration_minutes) },
    { label: 'Unique Mentors', value: fmtNum(k.unique_mentors) },
    { label: 'Unique Mentees', value: fmtNum(k.unique_mentees) },
    { label: 'Stale Pairs', value: fmtNum(k.stale_pairs) },
    { label: 'Overdue Pairs', value: fmtNum(k.overdue_pairs) },
    { label: 'Avg Cadence (d)', value: fmtNum(k.avg_cadence_days) },
    { label: 'Stale Share', value: fmtPct(k.stale_pairs, k.active_pairs ?? 0) },
  ];

  const pairCols: Column<any>[] = [
    { key: 'mentor', header: 'Mentor', render: (r: any) => r.mentor_name ?? '—' },
    { key: 'mentor_tier', header: 'Tier', render: (r: any) => r.mentor_tier ?? '—' },
    { key: 'mentee', header: 'Mentee', render: (r: any) => r.mentee_name ?? '—' },
    { key: 'mentee_tier', header: 'M.Tier', render: (r: any) => r.mentee_tier ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'cadence', header: 'Cadence (d)', render: (r: any) => fmtNum(r.cadence_days) },
    { key: 'sessions', header: 'Sessions', render: (r: any) => fmtNum(r.sessions_total) },
    { key: 'last', header: 'Last Session', render: (r: any) => r.last_session_on ?? '—' },
    { key: 'days_since', header: 'Days Since', render: (r: any) => fmtNum(r.days_since_last_session) },
    { key: 'stale', header: 'Stale?', render: (r: any) => (r.is_stale ? 'YES' : 'no') },
    { key: 'nps', header: 'Avg NPS', render: (r: any) => fmtNum(r.avg_mentor_nps) },
  ];

  const staleCols: Column<any>[] = [
    { key: 'mentor', header: 'Mentor', render: (r: any) => r.mentor_name ?? '—' },
    { key: 'mentee', header: 'Mentee', render: (r: any) => r.mentee_name ?? '—' },
    { key: 'cadence', header: 'Cadence (d)', render: (r: any) => fmtNum(r.cadence_days) },
    { key: 'last', header: 'Last Session', render: (r: any) => r.last_session_on ?? '—' },
    { key: 'since', header: 'Days Since', render: (r: any) => fmtNum(r.days_since_last) },
    { key: 'overdue', header: 'Days Overdue', render: (r: any) => fmtNum(r.days_overdue) },
  ];

  const sessionCols: Column<any>[] = [
    { key: 'date', header: 'Date', render: (r: any) => r.session_on ?? '—' },
    { key: 'mentor', header: 'Mentor', render: (r: any) => r.mentor_name ?? '—' },
    { key: 'mentee', header: 'Mentee', render: (r: any) => r.mentee_name ?? '—' },
    { key: 'mins', header: 'Mins', render: (r: any) => fmtNum(r.duration_minutes) },
    { key: 'mnps', header: 'M.NPS', render: (r: any) => fmtNum(r.mentor_nps) },
    { key: 'enps', header: 'E.NPS', render: (r: any) => fmtNum(r.mentee_nps) },
    { key: 'skills', header: 'Skills', render: (r: any) => (Array.isArray(r.skills_covered) ? r.skills_covered.join(', ') : '—') },
    { key: 'completed', header: 'Done', render: (r: any) => (r.completed ? 'yes' : 'no') },
  ];

  const mentorCols: Column<any>[] = [
    { key: 'name', header: 'Mentor', render: (r: any) => r.mentor_name ?? '—' },
    { key: 'tier', header: 'Tier', render: (r: any) => r.mentor_tier ?? '—' },
    { key: 'pairs', header: 'Active Pairs', render: (r: any) => fmtNum(r.active_pairs) },
    { key: 'sessions', header: 'Sessions', render: (r: any) => fmtNum(r.total_sessions) },
    { key: 'nps', header: 'Avg NPS', render: (r: any) => fmtNum(r.avg_mentor_nps) },
    { key: 'skills', header: 'Skills Taught', render: (r: any) => fmtNum(r.total_skills_taught) },
  ];

  return (
    <main className="min-h-screen bg-zinc-950 text-zinc-100 p-6">
      <div className="max-w-7xl mx-auto space-y-8">
        <header className="space-y-1">
          <h1 className="text-2xl font-semibold">Engineer Mentor-Pairing Program</h1>
          <p className="text-sm text-zinc-400">
            Senior-junior pairings, session cadence, skills covered, mentor NPS, and stale-no-meeting alerts.
          </p>
        </header>

        <section>
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
            {kpis.map((kpi) => (
              <div key={kpi.label} className="rounded-lg border border-zinc-800 bg-zinc-900 p-3">
                <div className="text-[11px] uppercase tracking-wide text-zinc-500">{kpi.label}</div>
                <div className="text-lg font-semibold text-zinc-100">{kpi.value}</div>
              </div>
            ))}
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold">All Pairs</h2>
          <DataTable<any> rows={pairs} columns={pairCols} rowKey={(r: any) => r.id} />
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold">Stale Pairs (no meeting beyond cadence)</h2>
          <DataTable<any> rows={stale} columns={staleCols} rowKey={(r: any) => r.pair_id} />
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold">Recent Sessions</h2>
          <DataTable<any> rows={sessions} columns={sessionCols} rowKey={(r: any) => r.session_id} />
        </section>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold">Top Mentors</h2>
          <DataTable<any> rows={mentors} columns={mentorCols} rowKey={(r: any) => r.mentor_engineer_id} />
        </section>
      </div>
    </main>
  );
}
