import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Affinity = {
  id: string;
  engineer_user_id: string;
  hospital_user_id: string;
  repeat_assignment_count: number;
  avg_hospital_rating: number | null;
  avg_engineer_rating: number | null;
  total_jobs: number;
  affinity_score: number;
  status: string;
  created_at: string;
  updated_at: string;
};

type TopPair = {
  id: string;
  engineer_user_id: string;
  hospital_user_id: string;
  affinity_score: number;
  total_jobs: number;
  status: string;
};

type BlockedPair = {
  id: string;
  engineer_user_id: string;
  hospital_user_id: string;
  affinity_score: number;
  total_jobs: number;
  updated_at: string;
};

type Action = {
  id: string;
  affinity_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
};

function fmt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return String(n);
}

function fmtRating(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(2);
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  return new Date(s).toLocaleString();
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [affRes, topRes, blockedRes, actionsRes] = await Promise.all([
    sb.rpc('list_affinities_r1896'),
    sb.rpc('top_pairs_r1896'),
    sb.rpc('blocked_pairs_r1896'),
    sb.rpc('recent_actions_r1896'),
  ]);

  const affinities: Affinity[] = (affRes.data as Affinity[]) ?? [];
  const topPairs: TopPair[] = (topRes.data as TopPair[]) ?? [];
  const blockedPairs: BlockedPair[] = (blockedRes.data as BlockedPair[]) ?? [];
  const recentActions: Action[] = (actionsRes.data as Action[]) ?? [];

  const strongCount = affinities.filter((a) => a.status === 'strong').length;
  const blockedCount = affinities.filter((a) => a.status === 'blocked').length;
  const avgScore =
    affinities.length === 0
      ? 0
      : Math.round(affinities.reduce((s, a) => s + (a.affinity_score ?? 0), 0) / affinities.length);

  const affColumns: Column<Affinity>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id).slice(0, 8)}</span> },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => <span className="font-mono text-xs">{String(r.hospital_user_id).slice(0, 8)}</span> },
    { key: 'total_jobs', header: 'Total Jobs', render: (r: any) => <span>{fmt(r.total_jobs)}</span> },
    { key: 'repeat_assignment_count', header: 'Repeats', render: (r: any) => <span>{fmt(r.repeat_assignment_count)}</span> },
    { key: 'avg_hospital_rating', header: 'Avg Hosp Rating', render: (r: any) => <span>{fmtRating(r.avg_hospital_rating)}</span> },
    { key: 'affinity_score', header: 'Score', render: (r: any) => <span className="font-semibold">{fmt(r.affinity_score)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="rounded bg-slate-100 px-2 py-0.5 text-xs">{r.status}</span> },
    { key: 'updated_at', header: 'Updated', render: (r: any) => <span className="text-xs">{fmtDate(r.updated_at)}</span> },
  ];

  const topColumns: Column<TopPair>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id).slice(0, 8)}</span> },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => <span className="font-mono text-xs">{String(r.hospital_user_id).slice(0, 8)}</span> },
    { key: 'affinity_score', header: 'Score', render: (r: any) => <span className="font-semibold">{fmt(r.affinity_score)}</span> },
    { key: 'total_jobs', header: 'Total Jobs', render: (r: any) => <span>{fmt(r.total_jobs)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
  ];

  const blockedColumns: Column<BlockedPair>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id).slice(0, 8)}</span> },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => <span className="font-mono text-xs">{String(r.hospital_user_id).slice(0, 8)}</span> },
    { key: 'affinity_score', header: 'Score', render: (r: any) => <span>{fmt(r.affinity_score)}</span> },
    { key: 'total_jobs', header: 'Total Jobs', render: (r: any) => <span>{fmt(r.total_jobs)}</span> },
    { key: 'updated_at', header: 'Blocked At', render: (r: any) => <span className="text-xs">{fmtDate(r.updated_at)}</span> },
  ];

  const actionColumns: Column<Action>[] = [
    { key: 'affinity_id', header: 'Affinity', render: (r: any) => <span className="font-mono text-xs">{String(r.affinity_id).slice(0, 8)}</span> },
    { key: 'action_type', header: 'Action', render: (r: any) => <span className="rounded bg-slate-100 px-2 py-0.5 text-xs">{r.action_type}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span className="text-xs">{r.by_email ?? '-'}</span> },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => <span className="text-xs">{fmtDate(r.taken_at)}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer Hospital Affinity Index</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Track which engineer-hospital pairs perform best on repeat work. Score range 0–100. Strong &gt;= 70, moderate 40–69, weak &lt; 40, blocked = manual.
        </p>
      </header>

      <section className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">Total Pairs</div>
          <div className="mt-1 text-2xl font-semibold">{affinities.length}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">Strong Pairs</div>
          <div className="mt-1 text-2xl font-semibold">{strongCount}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">Blocked Pairs</div>
          <div className="mt-1 text-2xl font-semibold">{blockedCount}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wide text-[var(--color-muted)]">Avg Score</div>
          <div className="mt-1 text-2xl font-semibold">{avgScore}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Affinity Pairs</h2>
        <DataTable<Affinity>
          rows={affinities}
          columns={affColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No affinity pairs computed yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top Pairs (Strong)</h2>
        <DataTable<TopPair>
          rows={topPairs}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No strong pairs yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Blocked Pairs</h2>
        <DataTable<BlockedPair>
          rows={blockedPairs}
          columns={blockedColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No blocked pairs."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Actions</h2>
        <DataTable<Action>
          rows={recentActions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No actions logged."
        />
      </section>
    </div>
  );
}
