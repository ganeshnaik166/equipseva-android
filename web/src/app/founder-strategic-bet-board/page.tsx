import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [betsRes, sizeRes, recentRes] = await Promise.all([
    sb.rpc('list_bets_r1906'),
    sb.rpc('top_bets_by_size_r1906'),
    sb.rpc('recent_assessments_r1906'),
  ]);

  const bets: any[] = Array.isArray(betsRes.data) ? betsRes.data : [];
  const sizes: any[] = Array.isArray(sizeRes.data) ? sizeRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const activeBets = bets.filter((b) => b.status === 'active').length;
  const winningBets = bets.filter((b) => b.status === 'winning' || b.status === 'won').length;
  const companyBets = bets.filter((b) => b.bet_size === 'company_bet').length;

  const betCols: Column<any>[] = [
    { key: 'bet_label', header: 'Bet', render: (r: any) => <span className="font-medium">{r.bet_label}</span> },
    { key: 'bet_size', header: 'Size', render: (r: any) => <span className="uppercase text-xs">{r.bet_size}</span> },
    { key: 'time_horizon_months', header: 'Horizon (mo)', render: (r: any) => r.time_horizon_months },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleDateString() : '—' },
    { key: 'last_assessed_at', header: 'Last assessed', render: (r: any) => r.last_assessed_at ? new Date(r.last_assessed_at).toLocaleDateString() : '—' },
  ];

  const sizeCols: Column<any>[] = [
    { key: 'bet_size', header: 'Size', render: (r: any) => <span className="uppercase text-xs">{r.bet_size}</span> },
    { key: 'total_bets', header: 'Total', render: (r: any) => r.total_bets },
    { key: 'active_count', header: 'Active', render: (r: any) => r.active_count },
    { key: 'winning_count', header: 'Winning/Won', render: (r: any) => r.winning_count },
  ];

  const recentCols: Column<any>[] = [
    { key: 'recorded_at', header: 'When', render: (r: any) => new Date(r.recorded_at).toLocaleString() },
    { key: 'bet_label', header: 'Bet', render: (r: any) => r.bet_label },
    { key: 'assessment_type', header: 'Type', render: (r: any) => <span className="text-xs uppercase">{r.assessment_type}</span> },
    { key: 'confidence_score', header: 'Confidence', render: (r: any) => <span>{r.confidence_score}%</span> },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
  ];

  return (
    <main className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Founder Strategic Bet Board</h1>
        <p className="text-sm text-gray-600">
          Track current strategic bets &amp; their status. Confidence scored 0–100. Bets sized small &lt; medium &lt; large &lt; company_bet.
        </p>
      </header>

      <section className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Active bets</div>
          <div className="text-2xl font-semibold">{activeBets}</div>
          <div className="text-xs text-gray-500 mt-1">status = active</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Winning / won</div>
          <div className="text-2xl font-semibold">{winningBets}</div>
          <div className="text-xs text-gray-500 mt-1">confidence trending &gt;= 60%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Company bets</div>
          <div className="text-2xl font-semibold">{companyBets}</div>
          <div className="text-xs text-gray-500 mt-1">size = company_bet (largest tier)</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All strategic bets</h2>
        <DataTable rows={bets} columns={betCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Portfolio by size</h2>
        <p className="text-sm text-gray-600">Distribution of bets across size tiers. Healthy: most bets small/medium, &lt;= 1–2 company bets at a time.</p>
        <DataTable rows={sizes} columns={sizeCols} rowKey={(r: any, i: number) => String(r.bet_size ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recent assessments</h2>
        <p className="text-sm text-gray-600">Most recent 50 confidence checks across all bets. Score &gt;= 70 = winning signal, &lt; 30 = struggling.</p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
