import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MemoRow = {
  id: string;
  milestone_label: string;
  written_at: string;
  status: string;
  anniversary_md: string;
  top_3_lessons_md: string;
  what_changed_about_founder_md: string;
  next_chapter_outlook_md: string;
};

type SignalRow = {
  id: string;
  memo_id: string;
  signal_type: string;
  signal_md: string;
  recorded_at: string;
  by_email: string | null;
};

type TopSignalRow = {
  signal_type: string;
  signal_count: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const memosRes = await sb.rpc('list_anniversary_memos_r2098');
  const memos: MemoRow[] = Array.isArray(memosRes.data) ? (memosRes.data as MemoRow[]) : [];

  const recentRes = await sb.rpc('recent_anniversary_signals_r2098', { p_limit: 25 });
  const recentSignals: SignalRow[] = Array.isArray(recentRes.data) ? (recentRes.data as SignalRow[]) : [];

  const topRes = await sb.rpc('top_anniversary_signals_r2098');
  const topSignals: TopSignalRow[] = Array.isArray(topRes.data) ? (topRes.data as TopSignalRow[]) : [];

  const memoColumns: Column<MemoRow>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => String(r.milestone_label ?? '') },
    { key: 'written_at', header: 'Written', render: (r: any) => r.written_at ? new Date(r.written_at).toLocaleString() : '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'anniversary_md', header: 'Anniversary note', render: (r: any) => String(r.anniversary_md ?? '').slice(0, 120) },
    { key: 'top_3_lessons_md', header: 'Top 3 lessons', render: (r: any) => String(r.top_3_lessons_md ?? '').slice(0, 120) },
    { key: 'what_changed_about_founder_md', header: 'Founder change', render: (r: any) => String(r.what_changed_about_founder_md ?? '').slice(0, 120) },
    { key: 'next_chapter_outlook_md', header: 'Next chapter', render: (r: any) => String(r.next_chapter_outlook_md ?? '').slice(0, 120) },
  ];

  const signalColumns: Column<SignalRow>[] = [
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
    { key: 'signal_type', header: 'Type', render: (r: any) => String(r.signal_type ?? '') },
    { key: 'signal_md', header: 'Signal', render: (r: any) => String(r.signal_md ?? '').slice(0, 160) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'memo_id', header: 'Memo', render: (r: any) => String(r.memo_id ?? '').slice(0, 8) },
  ];

  const topColumns: Column<TopSignalRow>[] = [
    { key: 'signal_type', header: 'Signal type', render: (r: any) => String(r.signal_type ?? '') },
    { key: 'signal_count', header: 'Count', render: (r: any) => String(r.signal_count ?? 0) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder 200-Batch Anniversary Memo</h1>
        <p className="text-sm text-gray-600 mt-1">
          Milestone memo capturing the 200-batch anniversary: lessons, founder evolution, and outlook for the next chapter.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Anniversary memos</h2>
        <p className="text-xs text-gray-500">
          Each row is one milestone memo. Use status published or archived to keep the library tidy.
        </p>
        <DataTable
          rows={memos}
          columns={memoColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent anniversary signals</h2>
        <p className="text-xs text-gray-500">
          Signal types: team celebration, investor milestone, customer celebration, founder emotion, external observer.
        </p>
        <DataTable
          rows={recentSignals}
          columns={signalColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top signal types</h2>
        <p className="text-xs text-gray-500">
          Aggregated count per signal type across all anniversary memos.
        </p>
        <DataTable
          rows={topSignals}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.signal_type ?? i)}
        />
      </section>
    </main>
  );
}
