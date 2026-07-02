import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_assets: number;
  assets_blocked: number;
  total_capex_rupees: number;
  total_disposal_realized_rupees: number;
  avg_age_years: number;
  chains_in_pipeline: number;
};

type ChainRow = {
  chain_name: string;
  asset_count: number;
  blocked_count: number;
  total_capex: number;
  realized_disposal: number;
  avg_age_years: number;
};

type CategoryRow = {
  equipment_category: string;
  asset_count: number;
  avg_age: number;
  avg_utilization: number;
  total_repair_cost: number;
};

type PlanRow = {
  replacement_plan: string;
  asset_count: number;
  total_capex: number;
  total_disposal_value: number;
};

type BlockedRow = {
  asset_tag: string;
  chain_name: string;
  hospital_branch: string;
  equipment_category: string;
  age_years: number;
  replacement_capex_rupees: number;
  blocker_note: string | null;
};

type RollupRow = {
  chain_name: string;
  fiscal_quarter: string;
  fiscal_year: number;
  assets_planned: number;
  assets_completed: number;
  assets_blocked: number;
  net_capex_rupees: number;
  capex_variance_pct: number;
  pipeline_health: string;
  board_review_status: string;
};

type OutcomeRow = {
  decommission_outcome: string;
  asset_count: number;
  share_pct: number;
};

type TopCapexRow = {
  asset_tag: string;
  chain_name: string;
  equipment_category: string;
  age_years: number;
  replacement_capex_rupees: number;
  estimated_disposal_value_rupees: number;
  decommission_outcome: string;
};

function inr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpi, byChain, byCat, planMix, blocked, rollups, outcome, topCapex] = await Promise.all([
    supabase.rpc('r2771_pipeline_kpis'),
    supabase.rpc('r2771_assets_by_chain'),
    supabase.rpc('r2771_assets_by_category'),
    supabase.rpc('r2771_replacement_plan_mix'),
    supabase.rpc('r2771_blocked_assets'),
    supabase.rpc('r2771_quarterly_rollups'),
    supabase.rpc('r2771_outcome_mix'),
    supabase.rpc('r2771_top_capex_assets'),
  ]);

  const k: Kpi = (kpi.data?.[0] as Kpi) ?? {
    total_assets: 0,
    assets_blocked: 0,
    total_capex_rupees: 0,
    total_disposal_realized_rupees: 0,
    avg_age_years: 0,
    chains_in_pipeline: 0,
  };

  const chainRows: ChainRow[] = (byChain.data as ChainRow[]) ?? [];
  const catRows: CategoryRow[] = (byCat.data as CategoryRow[]) ?? [];
  const planRows: PlanRow[] = (planMix.data as PlanRow[]) ?? [];
  const blockedRows: BlockedRow[] = (blocked.data as BlockedRow[]) ?? [];
  const rollupRows: RollupRow[] = (rollups.data as RollupRow[]) ?? [];
  const outcomeRows: OutcomeRow[] = (outcome.data as OutcomeRow[]) ?? [];
  const topRows: TopCapexRow[] = (topCapex.data as TopCapexRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Equipment Decommission Pipeline</h1>
        <p className="text-sm text-gray-600 mt-1">
          Chain × asset × age × replacement plan × disposal value × outcome — quarterly board view across pipeline.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total assets</div>
          <div className="text-xl font-semibold">{k.total_assets}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Chains</div>
          <div className="text-xl font-semibold">{k.chains_in_pipeline}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Blocked</div>
          <div className="text-xl font-semibold">{k.assets_blocked}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Capex planned</div>
          <div className="text-xl font-semibold">{inr(k.total_capex_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Disposal realized</div>
          <div className="text-xl font-semibold">{inr(k.total_disposal_realized_rupees)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Avg age (yrs)</div>
          <div className="text-xl font-semibold">{k.avg_age_years}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By chain</h2>
        <DataTable
          rows={chainRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name },
            { key: 'asset_count', header: 'Assets', render: (r: ChainRow) => r.asset_count },
            { key: 'blocked_count', header: 'Blocked', render: (r: ChainRow) => r.blocked_count },
            { key: 'total_capex', header: 'Capex', render: (r: ChainRow) => inr(r.total_capex) },
            { key: 'realized_disposal', header: 'Disposal realized', render: (r: ChainRow) => inr(r.realized_disposal) },
            { key: 'avg_age_years', header: 'Avg age', render: (r: ChainRow) => r.avg_age_years },
          ]}
          emptyMessage="No data"
          rowKey={(r: ChainRow, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By equipment category</h2>
        <DataTable
          rows={catRows}
          columns={[
            { key: 'equipment_category', header: 'Category', render: (r: CategoryRow) => r.equipment_category },
            { key: 'asset_count', header: 'Assets', render: (r: CategoryRow) => r.asset_count },
            { key: 'avg_age', header: 'Avg age', render: (r: CategoryRow) => r.avg_age },
            { key: 'avg_utilization', header: 'Avg util %', render: (r: CategoryRow) => r.avg_utilization },
            { key: 'total_repair_cost', header: 'YTD repair', render: (r: CategoryRow) => inr(r.total_repair_cost) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CategoryRow, i: number) => String(r.equipment_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Replacement plan mix</h2>
        <DataTable
          rows={planRows}
          columns={[
            { key: 'replacement_plan', header: 'Plan', render: (r: PlanRow) => r.replacement_plan },
            { key: 'asset_count', header: 'Assets', render: (r: PlanRow) => r.asset_count },
            { key: 'total_capex', header: 'Capex', render: (r: PlanRow) => inr(r.total_capex) },
            { key: 'total_disposal_value', header: 'Est disposal', render: (r: PlanRow) => inr(r.total_disposal_value) },
          ]}
          emptyMessage="No data"
          rowKey={(r: PlanRow, i: number) => String(r.replacement_plan ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Outcome mix</h2>
        <DataTable
          rows={outcomeRows}
          columns={[
            { key: 'decommission_outcome', header: 'Outcome', render: (r: OutcomeRow) => r.decommission_outcome },
            { key: 'asset_count', header: 'Count', render: (r: OutcomeRow) => r.asset_count },
            { key: 'share_pct', header: 'Share %', render: (r: OutcomeRow) => r.share_pct },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.decommission_outcome ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly board rollup</h2>
        <DataTable
          rows={rollupRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: RollupRow) => r.chain_name },
            { key: 'fiscal_quarter', header: 'Quarter', render: (r: RollupRow) => r.fiscal_quarter + ' FY' + r.fiscal_year },
            { key: 'assets_planned', header: 'Planned', render: (r: RollupRow) => r.assets_planned },
            { key: 'assets_completed', header: 'Completed', render: (r: RollupRow) => r.assets_completed },
            { key: 'assets_blocked', header: 'Blocked', render: (r: RollupRow) => r.assets_blocked },
            { key: 'net_capex_rupees', header: 'Net capex', render: (r: RollupRow) => inr(r.net_capex_rupees) },
            { key: 'capex_variance_pct', header: 'Variance %', render: (r: RollupRow) => r.capex_variance_pct },
            { key: 'pipeline_health', header: 'Health', render: (r: RollupRow) => r.pipeline_health },
            { key: 'board_review_status', header: 'Board', render: (r: RollupRow) => r.board_review_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: RollupRow, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Blocked assets</h2>
        <DataTable
          rows={blockedRows}
          columns={[
            { key: 'asset_tag', header: 'Asset', render: (r: BlockedRow) => r.asset_tag },
            { key: 'chain_name', header: 'Chain', render: (r: BlockedRow) => r.chain_name },
            { key: 'hospital_branch', header: 'Branch', render: (r: BlockedRow) => r.hospital_branch },
            { key: 'equipment_category', header: 'Category', render: (r: BlockedRow) => r.equipment_category },
            { key: 'age_years', header: 'Age', render: (r: BlockedRow) => r.age_years },
            { key: 'replacement_capex_rupees', header: 'Capex', render: (r: BlockedRow) => inr(r.replacement_capex_rupees) },
            { key: 'blocker_note', header: 'Blocker', render: (r: BlockedRow) => r.blocker_note ?? '-' },
          ]}
          emptyMessage="No blocked assets"
          rowKey={(r: BlockedRow, i: number) => String(r.asset_tag ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top capex assets</h2>
        <DataTable
          rows={topRows}
          columns={[
            { key: 'asset_tag', header: 'Asset', render: (r: TopCapexRow) => r.asset_tag },
            { key: 'chain_name', header: 'Chain', render: (r: TopCapexRow) => r.chain_name },
            { key: 'equipment_category', header: 'Category', render: (r: TopCapexRow) => r.equipment_category },
            { key: 'age_years', header: 'Age', render: (r: TopCapexRow) => r.age_years },
            { key: 'replacement_capex_rupees', header: 'Capex', render: (r: TopCapexRow) => inr(r.replacement_capex_rupees) },
            { key: 'estimated_disposal_value_rupees', header: 'Est disposal', render: (r: TopCapexRow) => inr(r.estimated_disposal_value_rupees) },
            { key: 'decommission_outcome', header: 'Outcome', render: (r: TopCapexRow) => r.decommission_outcome },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopCapexRow, i: number) => String(r.asset_tag ?? i)}
        />
      </section>
    </div>
  );
}
