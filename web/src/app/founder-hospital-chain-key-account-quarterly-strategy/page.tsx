import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [strategies, checkpoints, atRisk, funnel, achievement, trend, ownerLoad] = await Promise.all([
    supabase.rpc('list_strategies_r2547'),
    supabase.rpc('list_checkpoints_r2547'),
    supabase.rpc('top_at_risk_strategies_r2547'),
    supabase.rpc('status_funnel_r2547'),
    supabase.rpc('commitment_achievement_summary_r2547'),
    supabase.rpc('quarterly_strategy_trend_r2547'),
    supabase.rpc('owner_load_r2547'),
  ]);

  const strategyCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'our_owner_email', header: 'Our Owner', render: (r: any) => r.our_owner_email ?? '-' },
    { key: 'their_sponsor_email', header: 'Their Sponsor', render: (r: any) => r.their_sponsor_email ?? '-' },
    { key: 'created_at', header: 'Created', render: (r: any) => new Date(r.created_at).toLocaleDateString() },
  ];

  const checkpointCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'checkpoint_kind', header: 'Kind', render: (r: any) => r.checkpoint_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'commitment_achievement_pct', header: 'Achievement %', render: (r: any) => r.commitment_achievement_pct ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'checkpoint_at', header: 'When', render: (r: any) => new Date(r.checkpoint_at).toLocaleDateString() },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'latest_status', header: 'Latest Status', render: (r: any) => r.latest_status ?? '-' },
    { key: 'latest_achievement_pct', header: 'Latest %', render: (r: any) => r.latest_achievement_pct ?? '-' },
    { key: 'our_owner_email', header: 'Owner', render: (r: any) => r.our_owner_email ?? '-' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'n', header: 'Count', render: (r: any) => r.n },
  ];

  const achievementCols: Column<any>[] = [
    { key: 'checkpoint_kind', header: 'Kind', render: (r: any) => r.checkpoint_kind },
    { key: 'n', header: 'N', render: (r: any) => r.n },
    { key: 'avg_pct', header: 'Avg %', render: (r: any) => r.avg_pct },
    { key: 'green_n', header: 'Green', render: (r: any) => r.green_n },
    { key: 'amber_n', header: 'Amber', render: (r: any) => r.amber_n },
    { key: 'red_n', header: 'Red', render: (r: any) => r.red_n },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'n_strategies', header: 'Total', render: (r: any) => r.n_strategies },
    { key: 'n_draft', header: 'Draft', render: (r: any) => r.n_draft },
    { key: 'n_aligned', header: 'Aligned', render: (r: any) => r.n_aligned },
    { key: 'n_in_execution', header: 'In Execution', render: (r: any) => r.n_in_execution },
    { key: 'n_closed', header: 'Closed', render: (r: any) => r.n_closed },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'our_owner_email', header: 'Owner', render: (r: any) => r.our_owner_email },
    { key: 'n_strategies', header: 'Total', render: (r: any) => r.n_strategies },
    { key: 'n_in_execution', header: 'In Execution', render: (r: any) => r.n_in_execution },
    { key: 'n_closed', header: 'Closed', render: (r: any) => r.n_closed },
  ];

  return (
    <div className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Hospital Chain Key-Account Quarterly Strategy</h1>
        <p className="text-sm text-gray-600 mt-1">
          Chain & KAS quarterly plans — growth, expansion targets, at-risk plans & commitments.
        </p>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Strategies</h2>
        <DataTable
          rows={strategies.data ?? []}
          columns={strategyCols}
          emptyMessage="No strategies yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top At-Risk Strategies</h2>
        <DataTable
          rows={atRisk.data ?? []}
          columns={atRiskCols}
          emptyMessage="No at-risk strategies"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Checkpoints</h2>
        <DataTable
          rows={checkpoints.data ?? []}
          columns={checkpointCols}
          emptyMessage="No checkpoints recorded"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Funnel</h2>
        <DataTable
          rows={funnel.data ?? []}
          columns={funnelCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Commitment Achievement Summary</h2>
        <DataTable
          rows={achievement.data ?? []}
          columns={achievementCols}
          emptyMessage="No checkpoints"
          rowKey={(r: any, i: number) => String(r.checkpoint_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Trend</h2>
        <DataTable
          rows={trend.data ?? []}
          columns={trendCols}
          emptyMessage="No quarters yet"
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={ownerLoad.data ?? []}
          columns={ownerCols}
          emptyMessage="No owners"
          rowKey={(r: any, i: number) => String(r.our_owner_email ?? i)}
        />
      </section>
    </div>
  );
}
