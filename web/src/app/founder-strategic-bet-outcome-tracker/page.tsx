import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [betsRes, winningRes, actionsRes] = await Promise.all([
    sb.rpc('list_bets_r2186'),
    sb.rpc('winning_bets_r2186'),
    sb.rpc('recent_actions_r2186'),
  ]);

  const bets: any[] = Array.isArray(betsRes.data) ? betsRes.data : [];
  const winning: any[] = Array.isArray(winningRes.data) ? winningRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const betCols: Column<any>[] = [
    { key: 'bet_label', header: 'Bet', render: (r: any) => String(r.bet_label ?? '') },
    { key: 'bet_size', header: 'Size', render: (r: any) => String(r.bet_size ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'confidence_at_outcome', header: 'Confidence', render: (r: any) => `${r.confidence_at_outcome ?? 0}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'bet_id', header: 'Bet ID', render: (r: any) => String(r.bet_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Strategic Bet Outcome Tracker</h1>
        <p className="text-sm text-gray-600">Track outcomes of strategic bets across sizes and stages.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Bets</h2>
        <DataTable rows={bets} columns={betCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Winning Active Bets</h2>
        <DataTable rows={winning} columns={betCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
