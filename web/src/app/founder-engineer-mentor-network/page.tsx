import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Pairing = {
  id: string;
  mentor_user_id: string | null;
  mentor_email: string | null;
  mentee_user_id: string | null;
  mentee_email: string | null;
  paired_at: string | null;
  focus_area: string | null;
  status: string | null;
  last_check_in_at: string | null;
  checkin_count: number | null;
};

type NeedingCheckin = {
  id: string;
  mentor_email: string | null;
  mentee_email: string | null;
  focus_area: string | null;
  paired_at: string | null;
  last_check_in_at: string | null;
  days_since_checkin: number | null;
};

type RecentCheckin = {
  id: string;
  pairing_id: string | null;
  mentor_email: string | null;
  mentee_email: string | null;
  focus_area: string | null;
  checkin_at: string | null;
  outcome: string | null;
  topic_md: string | null;
  by_email: string | null;
};

function fmt(ts: string | null | undefined): string {
  if (!ts) return 'never';
  try {
    return new Date(ts).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  } catch {
    return String(ts);
  }
}

function statusBadge(status: string | null): string {
  if (!status) return 'unknown';
  return status;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [pairingsRes, needingRes, recentRes] = await Promise.all([
    sb.rpc('list_pairings_r1924'),
    sb.rpc('pairings_needing_checkin_r1924'),
    sb.rpc('recent_checkins_r1924'),
  ]);

  const pairings: Pairing[] = (pairingsRes.data as Pairing[] | null) ?? [];
  const needing: NeedingCheckin[] = (needingRes.data as NeedingCheckin[] | null) ?? [];
  const recent: RecentCheckin[] = (recentRes.data as RecentCheckin[] | null) ?? [];

  const activeCount = pairings.filter((p) => p.status === 'active').length;
  const pausedCount = pairings.filter((p) => p.status === 'paused').length;
  const completedCount = pairings.filter((p) => p.status === 'completed').length;
  const totalCheckins = recent.length;

  const pairingCols: Column<Pairing>[] = [
    { key: 'mentor', header: 'Mentor', render: (r: any) => r.mentor_email ?? 'unknown' },
    { key: 'mentee', header: 'Mentee', render: (r: any) => r.mentee_email ?? 'unknown' },
    { key: 'focus', header: 'Focus Area', render: (r: any) => r.focus_area ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => statusBadge(r.status) },
    { key: 'paired', header: 'Paired At', render: (r: any) => fmt(r.paired_at) },
    { key: 'last', header: 'Last Check-in', render: (r: any) => fmt(r.last_check_in_at) },
    { key: 'count', header: 'Check-ins', render: (r: any) => String(r.checkin_count ?? 0) },
  ];

  const needingCols: Column<NeedingCheckin>[] = [
    { key: 'mentor', header: 'Mentor', render: (r: any) => r.mentor_email ?? 'unknown' },
    { key: 'mentee', header: 'Mentee', render: (r: any) => r.mentee_email ?? 'unknown' },
    { key: 'focus', header: 'Focus', render: (r: any) => r.focus_area ?? '-' },
    { key: 'paired', header: 'Paired', render: (r: any) => fmt(r.paired_at) },
    { key: 'last', header: 'Last Check-in', render: (r: any) => fmt(r.last_check_in_at) },
    { key: 'days', header: 'Days Stale', render: (r: any) => String(r.days_since_checkin ?? 0) },
  ];

  const recentCols: Column<RecentCheckin>[] = [
    { key: 'when', header: 'When', render: (r: any) => fmt(r.checkin_at) },
    { key: 'mentor', header: 'Mentor', render: (r: any) => r.mentor_email ?? 'unknown' },
    { key: 'mentee', header: 'Mentee', render: (r: any) => r.mentee_email ?? 'unknown' },
    { key: 'focus', header: 'Focus', render: (r: any) => r.focus_area ?? '-' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '-' },
    { key: 'topic', header: 'Topic', render: (r: any) => (r.topic_md ?? '').slice(0, 120) },
    { key: 'by', header: 'By', render: (r: any) => r.by_email ?? '-' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer Mentor Network</h1>
        <p className="text-sm text-gray-600">
          Mentor and mentee pairings plus check-in cadence across the engineer corps.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Active</div>
          <div className="mt-1 text-2xl font-semibold">{activeCount}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Paused</div>
          <div className="mt-1 text-2xl font-semibold">{pausedCount}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Completed</div>
          <div className="mt-1 text-2xl font-semibold">{completedCount}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs uppercase text-gray-500">Recent Check-ins</div>
          <div className="mt-1 text-2xl font-semibold">{totalCheckins}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Pairings Needing Check-in (stale by more than 14 days)</h2>
        <p className="text-xs text-gray-500">
          Active pairings where the last check-in is older than 14 days, or no check-in yet since pairing.
        </p>
        <DataTable
          rows={needing}
          columns={needingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All Pairings</h2>
        <DataTable
          rows={pairings}
          columns={pairingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent Check-ins</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
