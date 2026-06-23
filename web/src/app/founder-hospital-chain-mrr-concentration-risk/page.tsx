import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [chainsRes, totalsRes, actionsRes, riskRes] = await Promise.all([
    supabase.rpc('r2387_list_top_chains', { p_limit: 10 }),
    supabase.rpc('r2387_concentration_totals'),
    supabase.rpc('r2387_list_actions'),
    supabase.rpc('r2387_risk_distribution'),
  ]);

  const chains = (chainsRes.data as any[]) ?? [];
  const totals = ((totalsRes.data as any[]) ?? [])[0] ?? {};
  const actions = (actionsRes.data as any[]) ?? [];
  const risk = (riskRes.data as any[]) ?? [];

  const chainCols: Column<any>[] = [
    { key: 'concentration_rank', header: 'Rank', render: (r) => <span>#{r.concentration_rank}</span> },
    { key: 'chain_name', header: 'Chain', render: (r) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'hospital_count', header: 'Hospitals', render: (r) => <span>{r.hospital_count}</span> },
    { key: 'monthly_recurring_revenue_rupees', header: 'MRR', render: (r) => <span>₹{Number(r.monthly_recurring_revenue_rupees ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'share_of_total_mrr_pct', header: 'Share %', render: (r) => <span>{Number(r.share_of_total_mrr_pct ?? 0).toFixed(2)}%</span> },
    { key: 'dependency_risk_score', header: 'Risk', render: (r) => <span>{r.dependency_risk_score}/100</span> },
    { key: 'risk_tier', header: 'Tier', render: (r) => {
      const tier = r.risk_tier as string;
      const cls = tier === 'critical' ? 'bg-red-100 text-red-800' : tier === 'high' ? 'bg-orange-100 text-orange-800' : tier === 'elevated' ? 'bg-amber-100 text-amber-800' : 'bg-emerald-100 text-emerald-800';
      return <span className={`inline-block px-2 py-0.5 rounded text-xs ${cls}`}>{tier}</span>;
    }},
    { key: 'contract_end_date', header: 'Contract End', render: (r) => <span>{r.contract_end_date ?? '-'}</span> },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'action_type', header: 'Action', render: (r) => <span>{r.action_type}</span> },
    { key: 'target_chain', header: 'Target', render: (r) => <span>{r.target_chain ?? '-'}</span> },
    { key: 'target_mrr_rupees', header: 'Target MRR', render: (r) => <span>₹{Number(r.target_mrr_rupees ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'status', header: 'Status', render: (r) => <span>{r.status}</span> },
    { key: 'owner_email', header: 'Owner', render: (r) => <span>{r.owner_email ?? '-'}</span> },
    { key: 'due_date', header: 'Due', render: (r) => <span>{r.due_date ?? '-'}</span> },
  ];

  const riskCols: Column<any>[] = [
    { key: 'risk_tier', header: 'Tier', render: (r) => <span className="font-medium">{r.risk_tier}</span> },
    { key: 'chain_count', header: 'Chains', render: (r) => <span>{r.chain_count}</span> },
    { key: 'total_mrr_rupees', header: 'MRR', render: (r) => <span>₹{Number(r.total_mrr_rupees ?? 0).toLocaleString('en-IN')}</span> },
    { key: 'avg_share_pct', header: 'Avg Share', render: (r) => <span>{Number(r.avg_share_pct ?? 0).toFixed(2)}%</span> },
  ];

  const top5 = Number(totals.top_5_share_pct ?? 0);
  const top1 = Number(totals.top_1_share_pct ?? 0);
  const concBanner = top5 >= 60 ? 'bg-red-50 border-red-300 text-red-900' : top5 >= 40 ? 'bg-amber-50 border-amber-300 text-amber-900' : 'bg-emerald-50 border-emerald-300 text-emerald-900';

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Hospital Chain MRR Concentration Risk</h1>
        <p className="text-sm text-gray-600 mt-1">Top chains as % of total MRR. Dependency risk & diversification plan.</p>
      </div>

      <div className={`border rounded p-4 ${concBanner}`}>
        <div className="text-xs uppercase tracking-wide">Concentration Snapshot</div>
        <div className="mt-2 grid grid-cols-2 md:grid-cols-5 gap-4">
          <div>
            <div className="text-xs">Top-5 Share</div>
            <div className="text-2xl font-bold">{top5.toFixed(2)}%</div>
          </div>
          <div>
            <div className="text-xs">Top-1 Share</div>
            <div className="text-2xl font-bold">{top1.toFixed(2)}%</div>
          </div>
          <div>
            <div className="text-xs">Critical Chains</div>
            <div className="text-2xl font-bold">{totals.critical_chains ?? 0}</div>
          </div>
          <div>
            <div className="text-xs">High-Risk Chains</div>
            <div className="text-2xl font-bold">{totals.high_risk_chains ?? 0}</div>
          </div>
          <div>
            <div className="text-xs">Tracked MRR</div>
            <div className="text-2xl font-bold">₹{Number(totals.total_tracked_mrr_rupees ?? 0).toLocaleString('en-IN')}</div>
          </div>
        </div>
        <div className="mt-3 text-xs">
          Guard rail: top-5 share &gt;= 60% =&gt; critical concentration. &gt;= 40% =&gt; elevated. &lt; 40% =&gt; healthy diversification.
        </div>
      </div>

      <section>
        <h2 className="text-lg font-medium mb-2">Top Chains by MRR</h2>
        <DataTable
          rows={chains}
          emptyMessage="No chain snapshots yet."
          rowKey={(r: any) => r.id as string}
          columns={chainCols}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Risk Tier Distribution</h2>
        <DataTable
          rows={risk}
          emptyMessage="No risk distribution data."
          rowKey={(r: any) => r.risk_tier as string}
          columns={riskCols}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Diversification Plan</h2>
        <DataTable
          rows={actions}
          emptyMessage="No diversification actions logged."
          rowKey={(r: any) => r.id as string}
          columns={actionCols}
        />
      </section>
    </div>
  );
}
