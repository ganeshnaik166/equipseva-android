import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtRupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  if (v >= 10000000) return `Rs ${(v / 10000000).toFixed(2)} Cr`;
  if (v >= 100000) return `Rs ${(v / 100000).toFixed(2)} L`;
  return `Rs ${v.toLocaleString('en-IN')}`;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpis, chains, monthly, recent, lossReasons, learnings, catMix] = await Promise.all([
    sb.rpc('rpc_r2291_kpis'),
    sb.rpc('rpc_r2291_chain_win_rate_summary'),
    sb.rpc('rpc_r2291_monthly_trend'),
    sb.rpc('rpc_r2291_recent_submissions', { p_limit: 50 }),
    sb.rpc('rpc_r2291_loss_reason_breakdown'),
    sb.rpc('rpc_r2291_top_learnings', { p_limit: 20 }),
    sb.rpc('rpc_r2291_category_learning_mix'),
  ]);

  const k = (kpis.data ?? [])[0] ?? {};
  const chainRows: any[] = chains.data ?? [];
  const monthlyRows: any[] = monthly.data ?? [];
  const recentRows: any[] = recent.data ?? [];
  const lossRows: any[] = lossReasons.data ?? [];
  const learningRows: any[] = learnings.data ?? [];
  const catRows: any[] = catMix.data ?? [];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Hospital chain', render: (r) => r.chain_name },
    { key: 'total_submissions', header: 'RFPs', render: (r) => r.total_submissions },
    { key: 'wins', header: 'Wins', render: (r) => r.wins },
    { key: 'losses', header: 'Losses', render: (r) => r.losses },
    { key: 'pending_count', header: 'Pending', render: (r) => r.pending_count },
    { key: 'win_rate_pct', header: 'Win rate %', render: (r) => `${r.win_rate_pct}%` },
    { key: 'total_won_value_rupees', header: 'Won value', render: (r) => fmtRupees(r.total_won_value_rupees) },
    { key: 'total_lost_value_rupees', header: 'Lost value', render: (r) => fmtRupees(r.total_lost_value_rupees) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r) => String(r.month_start).slice(0, 7) },
    { key: 'submissions', header: 'Submissions', render: (r) => r.submissions },
    { key: 'wins', header: 'Wins', render: (r) => r.wins },
    { key: 'losses', header: 'Losses', render: (r) => r.losses },
    { key: 'win_rate_pct', header: 'Win rate %', render: (r) => `${r.win_rate_pct}%` },
  ];

  const recentCols: Column<any>[] = [
    { key: 'submission_date', header: 'Submitted', render: (r) => String(r.submission_date) },
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'rfp_title', header: 'RFP', render: (r) => r.rfp_title },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
    { key: 'contract_value_rupees', header: 'Value', render: (r) => fmtRupees(r.contract_value_rupees) },
    { key: 'competitor_count', header: 'Competitors', render: (r) => r.competitor_count },
    { key: 'winning_competitor', header: 'Winner', render: (r) => r.winning_competitor ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r) => r.owner_email ?? '-' },
  ];

  const lossCols: Column<any>[] = [
    { key: 'loss_reason', header: 'Loss reason', render: (r) => r.loss_reason },
    { key: 'loss_count', header: 'Count', render: (r) => r.loss_count },
    { key: 'total_lost_value_rupees', header: 'Value lost', render: (r) => fmtRupees(r.total_lost_value_rupees) },
  ];

  const learningCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'impact_score', header: 'Impact', render: (r) => `${r.impact_score}/5` },
    { key: 'learning_text', header: 'Learning', render: (r) => r.learning_text },
    { key: 'shared_with_team', header: 'Shared', render: (r) => (r.shared_with_team ? 'yes' : 'no') },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'learning_count', header: 'Count', render: (r) => r.learning_count },
    { key: 'avg_impact', header: 'Avg impact', render: (r) => r.avg_impact },
    { key: 'shared_count', header: 'Shared', render: (r) => r.shared_count },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Hospital chain RFP win-rate tracker</h1>
        <p className="text-sm text-gray-600">
          Track RFP submissions across hospital chains, monitor win rate trends, and share learnings team-wide.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Total RFPs</div>
          <div className="text-xl font-semibold">{k.total_rfps ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Wins / Losses</div>
          <div className="text-xl font-semibold">{k.total_wins ?? 0} / {k.total_losses ?? 0}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Overall win rate</div>
          <div className="text-xl font-semibold">{k.overall_win_rate_pct ?? 0}%</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Pipeline value</div>
          <div className="text-xl font-semibold">{fmtRupees(k.pipeline_value_rupees)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Won value</div>
          <div className="text-xl font-semibold">{fmtRupees(k.won_value_rupees)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Unshared learnings</div>
          <div className="text-xl font-semibold">{k.unshared_learnings ?? 0}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per-chain win rate</h2>
        <DataTable<any> columns={chainCols} rows={chainRows} rowKey={(r) => r.chain_name} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly trend (last 12 months)</h2>
        <DataTable<any> columns={monthlyCols} rows={monthlyRows} rowKey={(r) => String(r.month_start)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent submissions</h2>
        <DataTable<any> columns={recentCols} rows={recentRows} rowKey={(r) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Loss-reason breakdown</h2>
        <DataTable<any> columns={lossCols} rows={lossRows} rowKey={(r) => r.loss_reason} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top learnings to share</h2>
        <DataTable<any> columns={learningCols} rows={learningRows} rowKey={(r) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Learning category mix</h2>
        <DataTable<any> columns={catCols} rows={catRows} rowKey={(r) => r.category} />
      </section>
    </div>
  );
}
