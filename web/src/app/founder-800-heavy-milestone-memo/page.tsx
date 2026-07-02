import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MemoRow = {
  id: string;
  milestone_label: string;
  written_at: string;
  summary_md: string | null;
  key_observations_md: string | null;
  founder_pulse_md: string | null;
  status: string;
  reaction_count: number;
};

type RecentReactionRow = {
  reaction_id: string;
  memo_id: string;
  milestone_label: string;
  reactor_email: string;
  reactor_role: string;
  reaction_md: string;
  recorded_at: string;
};

type TopReactionRow = {
  reactor_role: string;
  reaction_count: number;
  last_recorded_at: string;
};

function fmt(ts: string | null): string {
  if (!ts) return '—';
  try {
    return new Date(ts).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return ts;
  }
}

function clip(s: string | null, n = 140): string {
  if (!s) return '';
  return s.length > n ? s.slice(0, n) + '…' : s;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [memosRes, recentRes, topRes] = await Promise.all([
    sb.rpc('r2190_list_memos', { p_limit: 50 }),
    sb.rpc('r2190_recent_reactions', { p_limit: 25 }),
    sb.rpc('r2190_top_reactions', { p_limit: 10 }),
  ]);

  const memos: MemoRow[] = (memosRes.data as MemoRow[] | null) ?? [];
  const recent: RecentReactionRow[] = (recentRes.data as RecentReactionRow[] | null) ?? [];
  const top: TopReactionRow[] = (topRes.data as TopReactionRow[] | null) ?? [];

  const memoCols: Column<MemoRow>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => r.milestone_label },
    { key: 'written_at', header: 'Written', render: (r: any) => fmt(r.written_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'reaction_count', header: 'Reactions', render: (r: any) => String(r.reaction_count ?? 0) },
    { key: 'summary_md', header: 'Summary', render: (r: any) => clip(r.summary_md) },
    { key: 'founder_pulse_md', header: 'Founder pulse', render: (r: any) => clip(r.founder_pulse_md, 100) },
  ];

  const recentCols: Column<RecentReactionRow>[] = [
    { key: 'recorded_at', header: 'When', render: (r: any) => fmt(r.recorded_at) },
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => r.milestone_label },
    { key: 'reactor_role', header: 'Role', render: (r: any) => r.reactor_role },
    { key: 'reactor_email', header: 'From', render: (r: any) => r.reactor_email },
    { key: 'reaction_md', header: 'Reaction', render: (r: any) => clip(r.reaction_md, 180) },
  ];

  const topCols: Column<TopReactionRow>[] = [
    { key: 'reactor_role', header: 'Role', render: (r: any) => r.reactor_role },
    { key: 'reaction_count', header: 'Count', render: (r: any) => String(r.reaction_count ?? 0) },
    { key: 'last_recorded_at', header: 'Last', render: (r: any) => fmt(r.last_recorded_at) },
  ];

  const totalReactions = top.reduce((acc, t) => acc + Number(t.reaction_count ?? 0), 0);
  const publishedCount = memos.filter((m) => m.status === 'published').length;

  return (
    <main className="mx-auto max-w-7xl px-6 py-8 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Founder 800-Heavy Milestone Memo</h1>
        <p className="text-sm text-neutral-600">
          Round 2190 — capture the 800 HEAVY ships moment. Memos, reactions from team & investors,
          and a roll-up of who's talking.
        </p>
        <div className="flex flex-wrap gap-4 text-sm">
          <div className="rounded border px-3 py-2">
            <div className="text-neutral-500">Memos</div>
            <div className="text-lg font-semibold">{memos.length}</div>
          </div>
          <div className="rounded border px-3 py-2">
            <div className="text-neutral-500">Published</div>
            <div className="text-lg font-semibold">{publishedCount}</div>
          </div>
          <div className="rounded border px-3 py-2">
            <div className="text-neutral-500">Reactions (top roles)</div>
            <div className="text-lg font-semibold">{totalReactions}</div>
          </div>
        </div>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Milestone memos</h2>
        <DataTable
          rows={memos}
          columns={memoCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent reactions</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.reaction_id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top reactor roles</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.reactor_role ?? i)}
        />
      </section>
    </main>
  );
}
