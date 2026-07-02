import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Memo = {
  id: string;
  milestone_label: string;
  written_at: string;
  summary_md: string;
  key_themes_md: string;
  status_check_md: string;
  founder_pulse_md: string;
  status: string;
};

type Signal = {
  id: string;
  memo_id: string;
  signal_type: string;
  signal_md: string;
  recorded_at: string;
  by_email: string | null;
};

type TopSignal = {
  signal_type: string;
  signal_count: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const memosRes = await sb.rpc('list_memos_r2138');
  const recentRes = await sb.rpc('recent_signals_r2138', { p_limit: 25 });
  const topRes = await sb.rpc('top_signals_r2138');

  const memos: Memo[] = (memosRes.data as Memo[] | null) ?? [];
  const recent: Signal[] = (recentRes.data as Signal[] | null) ?? [];
  const top: TopSignal[] = (topRes.data as TopSignal[] | null) ?? [];

  const memoCols: Column<Memo>[] = [
    { key: 'milestone_label', header: 'Milestone', render: (r: any) => String(r.milestone_label ?? '') },
    { key: 'written_at', header: 'Written', render: (r: any) => new Date(r.written_at).toLocaleString() },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'summary_md', header: 'Summary', render: (r: any) => <span className="line-clamp-2 text-xs">{String(r.summary_md ?? '').slice(0, 240)}</span> },
    { key: 'key_themes_md', header: 'Key themes', render: (r: any) => <span className="line-clamp-2 text-xs">{String(r.key_themes_md ?? '').slice(0, 200)}</span> },
    { key: 'founder_pulse_md', header: 'Founder pulse', render: (r: any) => <span className="line-clamp-2 text-xs">{String(r.founder_pulse_md ?? '').slice(0, 200)}</span> },
  ];

  const signalCols: Column<Signal>[] = [
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => new Date(r.recorded_at).toLocaleString() },
    { key: 'signal_type', header: 'Type', render: (r: any) => String(r.signal_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'signal_md', header: 'Signal', render: (r: any) => <span className="line-clamp-2 text-xs">{String(r.signal_md ?? '').slice(0, 280)}</span> },
    { key: 'memo_id', header: 'Memo', render: (r: any) => <span className="font-mono text-xs">{String(r.memo_id ?? '').slice(0, 8)}</span> },
  ];

  const topCols: Column<TopSignal>[] = [
    { key: 'signal_type', header: 'Signal type', render: (r: any) => String(r.signal_type ?? '') },
    { key: 'signal_count', header: 'Count', render: (r: any) => String(r.signal_count ?? 0) },
  ];

  return (
    <main className="mx-auto max-w-6xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Founder 210-Batch Pulse Memo</h1>
        <p className="text-sm text-gray-600">
          Milestone pulse memo at the 210-batch mark. Captures founder summary, key themes, status check, and
          founder pulse, plus pulse signals from team, customers, investors, and external observers.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Memos</h2>
        <DataTable
          rows={memos}
          columns={memoCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent pulse signals</h2>
        <DataTable
          rows={recent}
          columns={signalCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top signal types</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.signal_type ?? i)}
        />
      </section>
    </main>
  );
}
