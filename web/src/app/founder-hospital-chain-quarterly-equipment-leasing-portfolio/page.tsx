import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Rollup = {
  total_leases: number;
  active_leases: number;
  renewal_pending: number;
  returned_leases: number;
  total_units: number;
  gross_asset_value_rupees: number;
  quarterly_lease_run_rate: number;
  residual_at_risk_rupees: number;
};

type ByChain = {
  chain_code: string;
  chain_name: string;
  active_leases: number;
  units: number;
  quarterly_rupees: number;
  avg_residual_percent: number;
};

type ByAsset = {
  asset_category: string;
  leases: number;
  units: number;
  gross_value_rupees: number;
  avg_tenor_quarters: number;
};

type ByStructure = {
  lease_structure: string;
  leases: number;
  avg_quarterly_rupees: number;
  avg_residual_percent: number;
};

type OutcomeMix = {
  outcome_type: string;
  outcomes: number;
  avg_uptime: number;
  avg_utilisation: number;
  avg_net_yield: number;
};

type RenewalFunnel = {
  chain_code: string;
  asset_model: string;
  status: string;
  quarter_ending: string;
  residual_value_rupees: number;
  founder_notes: string | null;
};

type Detail = {
  chain_code: string;
  asset_category: string;
  asset_model: string;
  lease_structure: string;
  tenor_quarters: number;
  quarterly_lease_rupees: number;
  status: string;
  outcome_type: string | null;
  net_yield_percent: number | null;
};

type TopYield = {
  chain_code: string;
  asset_model: string;
  outcome_type: string;
  uptime_percent: number;
  utilisation_percent: number;
  net_yield_percent: number;
  decision_owner: string;
};

function rupees(n: number | null | undefined) {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined) {
  if (n == null) return '-';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [rollupRes, byChainRes, byAssetRes, byStructureRes, outcomeMixRes, renewalRes, detailRes, topYieldRes] = await Promise.all([
    supabase.rpc('founder_chain_lease_portfolio_rollup_r2799'),
    supabase.rpc('founder_chain_lease_by_chain_r2799'),
    supabase.rpc('founder_chain_lease_by_asset_r2799'),
    supabase.rpc('founder_chain_lease_by_structure_r2799'),
    supabase.rpc('founder_chain_lease_outcome_mix_r2799'),
    supabase.rpc('founder_chain_lease_renewal_funnel_r2799'),
    supabase.rpc('founder_chain_lease_detail_r2799'),
    supabase.rpc('founder_chain_lease_top_yield_r2799'),
  ]);

  const rollup = (rollupRes.data?.[0] ?? null) as Rollup | null;
  const byChain = (byChainRes.data ?? []) as ByChain[];
  const byAsset = (byAssetRes.data ?? []) as ByAsset[];
  const byStructure = (byStructureRes.data ?? []) as ByStructure[];
  const outcomeMix = (outcomeMixRes.data ?? []) as OutcomeMix[];
  const renewal = (renewalRes.data ?? []) as RenewalFunnel[];
  const detail = (detailRes.data ?? []) as Detail[];
  const topYield = (topYieldRes.data ?? []) as TopYield[];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Equipment Leasing Portfolio</h1>
        <p className="text-sm text-gray-600">Chain × asset × lease structure × tenor × residual × renew/return × outcome.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total Leases</div>
          <div className="text-xl font-semibold">{rollup?.total_leases ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Active</div>
          <div className="text-xl font-semibold">{rollup?.active_leases ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Renewal Pending</div>
          <div className="text-xl font-semibold">{rollup?.renewal_pending ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Returned</div>
          <div className="text-xl font-semibold">{rollup?.returned_leases ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Units Deployed</div>
          <div className="text-xl font-semibold">{rollup?.total_units ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Gross Asset Value</div>
          <div className="text-xl font-semibold">{rupees(rollup?.gross_asset_value_rupees ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Quarterly Run Rate</div>
          <div className="text-xl font-semibold">{rupees(rollup?.quarterly_lease_run_rate ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Residual At Risk</div>
          <div className="text-xl font-semibold">{rupees(rollup?.residual_at_risk_rupees ?? 0)}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Chain</h2>
        <DataTable
          rows={byChain}
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: ByChain) => r.chain_code },
            { key: 'chain_name', header: 'Name', render: (r: ByChain) => r.chain_name },
            { key: 'active_leases', header: 'Leases', render: (r: ByChain) => String(r.active_leases) },
            { key: 'units', header: 'Units', render: (r: ByChain) => String(r.units) },
            { key: 'quarterly_rupees', header: 'Quarterly', render: (r: ByChain) => rupees(r.quarterly_rupees) },
            { key: 'avg_residual_percent', header: 'Avg Residual', render: (r: ByChain) => pct(r.avg_residual_percent) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByChain, i: number) => String(r.chain_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Asset Category</h2>
        <DataTable
          rows={byAsset}
          columns={[
            { key: 'asset_category', header: 'Category', render: (r: ByAsset) => r.asset_category },
            { key: 'leases', header: 'Leases', render: (r: ByAsset) => String(r.leases) },
            { key: 'units', header: 'Units', render: (r: ByAsset) => String(r.units) },
            { key: 'gross_value_rupees', header: 'Gross Value', render: (r: ByAsset) => rupees(r.gross_value_rupees) },
            { key: 'avg_tenor_quarters', header: 'Avg Tenor (Q)', render: (r: ByAsset) => String(r.avg_tenor_quarters) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByAsset, i: number) => String(r.asset_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Lease Structure</h2>
        <DataTable
          rows={byStructure}
          columns={[
            { key: 'lease_structure', header: 'Structure', render: (r: ByStructure) => r.lease_structure },
            { key: 'leases', header: 'Leases', render: (r: ByStructure) => String(r.leases) },
            { key: 'avg_quarterly_rupees', header: 'Avg Quarterly', render: (r: ByStructure) => rupees(r.avg_quarterly_rupees) },
            { key: 'avg_residual_percent', header: 'Avg Residual', render: (r: ByStructure) => pct(r.avg_residual_percent) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByStructure, i: number) => String(r.lease_structure ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Outcome Mix</h2>
        <DataTable
          rows={outcomeMix}
          columns={[
            { key: 'outcome_type', header: 'Outcome', render: (r: OutcomeMix) => r.outcome_type },
            { key: 'outcomes', header: 'Count', render: (r: OutcomeMix) => String(r.outcomes) },
            { key: 'avg_uptime', header: 'Avg Uptime', render: (r: OutcomeMix) => pct(r.avg_uptime) },
            { key: 'avg_utilisation', header: 'Avg Utilisation', render: (r: OutcomeMix) => pct(r.avg_utilisation) },
            { key: 'avg_net_yield', header: 'Avg Net Yield', render: (r: OutcomeMix) => pct(r.avg_net_yield) },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeMix, i: number) => String(r.outcome_type ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Renewal & Return Funnel</h2>
        <DataTable
          rows={renewal}
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: RenewalFunnel) => r.chain_code },
            { key: 'asset_model', header: 'Asset', render: (r: RenewalFunnel) => r.asset_model },
            { key: 'status', header: 'Status', render: (r: RenewalFunnel) => r.status },
            { key: 'quarter_ending', header: 'Ends', render: (r: RenewalFunnel) => r.quarter_ending },
            { key: 'residual_value_rupees', header: 'Residual', render: (r: RenewalFunnel) => rupees(r.residual_value_rupees) },
            { key: 'founder_notes', header: 'Notes', render: (r: RenewalFunnel) => r.founder_notes ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: RenewalFunnel, i: number) => String(r.chain_code + '-' + r.asset_model + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Lease Detail (Chain × Asset × Outcome)</h2>
        <DataTable
          rows={detail}
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: Detail) => r.chain_code },
            { key: 'asset_category', header: 'Category', render: (r: Detail) => r.asset_category },
            { key: 'asset_model', header: 'Model', render: (r: Detail) => r.asset_model },
            { key: 'lease_structure', header: 'Structure', render: (r: Detail) => r.lease_structure },
            { key: 'tenor_quarters', header: 'Tenor (Q)', render: (r: Detail) => String(r.tenor_quarters) },
            { key: 'quarterly_lease_rupees', header: 'Quarterly', render: (r: Detail) => rupees(r.quarterly_lease_rupees) },
            { key: 'status', header: 'Status', render: (r: Detail) => r.status },
            { key: 'outcome_type', header: 'Outcome', render: (r: Detail) => r.outcome_type ?? '-' },
            { key: 'net_yield_percent', header: 'Net Yield', render: (r: Detail) => pct(r.net_yield_percent ?? undefined) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Detail, i: number) => String(r.chain_code + '-' + r.asset_model + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Yield Performers</h2>
        <DataTable
          rows={topYield}
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: TopYield) => r.chain_code },
            { key: 'asset_model', header: 'Asset', render: (r: TopYield) => r.asset_model },
            { key: 'outcome_type', header: 'Outcome', render: (r: TopYield) => r.outcome_type },
            { key: 'uptime_percent', header: 'Uptime', render: (r: TopYield) => pct(r.uptime_percent) },
            { key: 'utilisation_percent', header: 'Utilisation', render: (r: TopYield) => pct(r.utilisation_percent) },
            { key: 'net_yield_percent', header: 'Net Yield', render: (r: TopYield) => pct(r.net_yield_percent) },
            { key: 'decision_owner', header: 'Owner', render: (r: TopYield) => r.decision_owner },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopYield, i: number) => String(r.chain_code + '-' + r.asset_model + '-' + i)}
        />
      </section>
    </div>
  );
}