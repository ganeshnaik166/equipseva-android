import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInnerCircleTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [circleRes, recentRes, staleRes, checkInsRes] = await Promise.all([
    sb.rpc('fic_list_circle_r1822'),
    sb.rpc('fic_recently_consulted_r1822', { p_days: 14 }),
    sb.rpc('fic_stale_relationships_r1822', { p_threshold_days: 60 }),
    sb.rpc('fic_list_check_ins_r1822', { p_circle_id: null, p_limit: 50 }),
  ]);

  const circle = (circleRes.data as any[]) ?? [];
  const recent = (recentRes.data as any[]) ?? [];
  const stale = (staleRes.data as any[]) ?? [];
  const checkIns = (checkInsRes.data as any[]) ?? [];

  const totalPeople = circle.length;
  const activePeople = circle.filter((c) => c.status === 'active').length;
  const avgTrust = totalPeople > 0
    ? (circle.reduce((s, c) => s + (Number(c.trust_level) || 0), 0) / totalPeople).toFixed(1)
    : '—';
  const helpfulRate = checkIns.length > 0
    ? Math.round((checkIns.filter((c) => c.was_helpful).length / checkIns.length) * 100) + '%'
    : '—';

  const circleColumns: Column<any>[] = [
    { key: 'person_name', header: 'Person', render: (r: any) => <span className="font-medium">{r.person_name}</span> },
    { key: 'person_role', header: 'Role', render: (r: any) => <span className="text-xs uppercase tracking-wide">{r.person_role}</span> },
    { key: 'trust_level', header: 'Trust', render: (r: any) => <span className="font-mono">{r.trust_level}/10</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'share_what_with', header: 'Shares', render: (r: any) => <span className="text-xs text-gray-600">{Array.isArray(r.share_what_with) ? r.share_what_with.join(', ') : ''}</span> },
    { key: 'days_since_consult', header: 'Days since', render: (r: any) => <span className="font-mono">{r.days_since_consult ?? '—'}</span> },
    { key: 'check_in_count', header: 'Check-ins', render: (r: any) => <span className="font-mono">{r.check_in_count ?? 0}</span> },
    { key: 'last_consulted_at', header: 'Last consulted', render: (r: any) => <span className="text-xs">{r.last_consulted_at ? new Date(r.last_consulted_at).toLocaleDateString() : '—'}</span> },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'person_name', header: 'Person', render: (r: any) => <span className="font-medium">{r.person_name}</span> },
    { key: 'person_role', header: 'Role', render: (r: any) => <span className="text-xs">{r.person_role}</span> },
    { key: 'trust_level', header: 'Trust', render: (r: any) => <span className="font-mono">{r.trust_level}/10</span> },
    { key: 'last_consulted_at', header: 'When', render: (r: any) => <span className="text-xs">{r.last_consulted_at ? new Date(r.last_consulted_at).toLocaleString() : '—'}</span> },
    { key: 'days_ago', header: 'Days ago', render: (r: any) => <span className="font-mono">{r.days_ago}</span> },
  ];

  const staleColumns: Column<any>[] = [
    { key: 'person_name', header: 'Person', render: (r: any) => <span className="font-medium">{r.person_name}</span> },
    { key: 'person_role', header: 'Role', render: (r: any) => <span className="text-xs">{r.person_role}</span> },
    { key: 'trust_level', header: 'Trust', render: (r: any) => <span className="font-mono">{r.trust_level}/10</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'last_consulted_at', header: 'Last consulted', render: (r: any) => <span className="text-xs">{r.last_consulted_at ? new Date(r.last_consulted_at).toLocaleDateString() : 'never'}</span> },
    { key: 'days_since', header: 'Days stale', render: (r: any) => <span className="font-mono text-red-600">{r.days_since}</span> },
  ];

  const checkInColumns: Column<any>[] = [
    { key: 'check_in_date', header: 'Date', render: (r: any) => <span className="text-xs">{r.check_in_date ? new Date(r.check_in_date).toLocaleDateString() : '—'}</span> },
    { key: 'person_name', header: 'Person', render: (r: any) => <span className="font-medium">{r.person_name}</span> },
    { key: 'was_helpful', header: 'Helpful', render: (r: any) => <span className="text-xs">{r.was_helpful ? 'yes' : 'no'}</span> },
    { key: 'topic_discussed', header: 'Topic', render: (r: any) => <span className="text-sm">{r.topic_discussed ?? '—'}</span> },
    { key: 'takeaway_md', header: 'Takeaway', render: (r: any) => <span className="text-xs text-gray-600">{r.takeaway_md ? (r.takeaway_md.length > 120 ? r.takeaway_md.slice(0, 117) + '...' : r.takeaway_md) : '—'}</span> },
  ];

  return (
    <div className="max-w-7xl mx-auto p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Inner Circle Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Innermost trusted advisors, family, and friends. Track who you lean on, what you share with them, and whether you're staying in touch.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">People</div>
          <div className="text-2xl font-bold">{totalPeople}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Active</div>
          <div className="text-2xl font-bold">{activePeople}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Avg trust</div>
          <div className="text-2xl font-bold">{avgTrust}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Helpful rate</div>
          <div className="text-2xl font-bold">{helpfulRate}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Inner circle ({circle.length})</h2>
        <p className="text-xs text-gray-500 mb-2">Sorted by trust level. Trust 8–10 = innermost ring.</p>
        <DataTable<any>
          rows={circle}
          columns={circleColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recently consulted (last 14 days)</h2>
        <DataTable<any>
          rows={recent}
          columns={recentColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Stale relationships (&gt; 60 days)</h2>
        <p className="text-xs text-gray-500 mb-2">Active relationships you haven't consulted in over 60 days. Reach out before they go cold.</p>
        <DataTable<any>
          rows={stale}
          columns={staleColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent check-ins ({checkIns.length})</h2>
        <DataTable<any>
          rows={checkIns}
          columns={checkInColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
