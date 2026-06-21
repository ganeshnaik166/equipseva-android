import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [obsRes, pairsRes, topRes, densityRes] = await Promise.all([
    sb.rpc('list_co_investment_observations_r1769'),
    sb.rpc('list_co_investment_pairings_r1769'),
    sb.rpc('top_co_investor_pairs_r1769'),
    sb.rpc('co_investment_network_density_summary_r1769'),
  ]);

  const observations: any[] = Array.isArray(obsRes.data) ? obsRes.data : [];
  const pairings: any[] = Array.isArray(pairsRes.data) ? pairsRes.data : [];
  const topPairs: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const density: any = Array.isArray(densityRes.data) && densityRes.data.length > 0 ? densityRes.data[0] : null;

  const obsColumns: Column<any>[] = [
    { key: 'investor_a_id', header: 'Investor A', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_a_id ?? '').slice(0, 8)}</span> },
    { key: 'investor_b_id', header: 'Investor B', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_b_id ?? '').slice(0, 8)}</span> },
    { key: 'round_label', header: 'Round', render: (r: any) => <span>{r.round_label ?? '—'}</span> },
    { key: 'co_invest_count', header: 'Count', render: (r: any) => <span>{r.co_invest_count ?? 0}</span> },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => <span className="capitalize">{r.relationship_strength ?? '—'}</span> },
    { key: 'last_seen_together_at', header: 'Last Seen', render: (r: any) => <span>{r.last_seen_together_at ? new Date(r.last_seen_together_at).toLocaleDateString() : '—'}</span> },
  ];

  const pairColumns: Column<any>[] = [
    { key: 'investor_a_id', header: 'Investor A', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_a_id ?? '').slice(0, 8)}</span> },
    { key: 'investor_b_id', header: 'Investor B', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_b_id ?? '').slice(0, 8)}</span> },
    { key: 'latest_round', header: 'Latest Round', render: (r: any) => <span>{r.latest_round ?? '—'}</span> },
    { key: 'anchor_investor', header: 'Anchor', render: (r: any) => <span className="font-mono text-xs">{String(r.anchor_investor ?? '').slice(0, 8)}</span> },
    { key: 'created_at', header: 'Discovered', render: (r: any) => <span>{r.created_at ? new Date(r.created_at).toLocaleDateString() : '—'}</span> },
  ];

  const topColumns: Column<any>[] = [
    { key: 'investor_a_id', header: 'Investor A', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_a_id ?? '').slice(0, 8)}</span> },
    { key: 'investor_b_id', header: 'Investor B', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_b_id ?? '').slice(0, 8)}</span> },
    { key: 'total_co_invests', header: 'Total Co-Invests', render: (r: any) => <span className="font-semibold">{r.total_co_invests ?? 0}</span> },
    { key: 'strong_count', header: 'Strong Ties', render: (r: any) => <span>{r.strong_count ?? 0}</span> },
    { key: 'last_seen', header: 'Last Seen', render: (r: any) => <span>{r.last_seen ? new Date(r.last_seen).toLocaleDateString() : '—'}</span> },
  ];

  return (
    <main className="p-6 max-w-7xl mx-auto space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Co-Investment Round Aggregator</h1>
        <p className="text-sm text-gray-600 mt-1">
          Network mapping: which investors typically co-invest together. Strong ties (&gt;=3 rounds) signal anchor relationships worth tapping for intros.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Network Density Summary</h2>
        {density ? (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Total Observations</div>
              <div className="text-2xl font-semibold">{density.total_observations ?? 0}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Pairings</div>
              <div className="text-2xl font-semibold">{density.total_pairings ?? 0}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Unique Investors</div>
              <div className="text-2xl font-semibold">{density.unique_investors ?? 0}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Avg Co-Invests</div>
              <div className="text-2xl font-semibold">{density.avg_co_invests ?? 0}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Strong Ties</div>
              <div className="text-2xl font-semibold text-emerald-700">{density.strong_pairings ?? 0}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Moderate Ties</div>
              <div className="text-2xl font-semibold text-amber-700">{density.moderate_pairings ?? 0}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Weak Ties</div>
              <div className="text-2xl font-semibold text-gray-600">{density.weak_pairings ?? 0}</div>
            </div>
          </div>
        ) : (
          <p className="text-sm text-gray-500">No density data yet.</p>
        )}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Co-Investor Pairs</h2>
        <p className="text-xs text-gray-500 mb-2">Pairs with &gt;=2 shared rounds. Anchor a round by securing one — the other typically follows.</p>
        <DataTable rows={topPairs} columns={topColumns} rowKey={(r: any, i: number) => String(r.investor_a_id ?? '') + '-' + String(r.investor_b_id ?? '') + '-' + i} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Confirmed Pairings</h2>
        <p className="text-xs text-gray-500 mb-2">Refreshed pairings: each unique investor-pair with latest round and anchor designation.</p>
        <DataTable rows={pairings} columns={pairColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Observations</h2>
        <p className="text-xs text-gray-500 mb-2">Raw co-investment log. Strength &gt;= moderate = worth tracking for intro requests.</p>
        <DataTable rows={observations} columns={obsColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
