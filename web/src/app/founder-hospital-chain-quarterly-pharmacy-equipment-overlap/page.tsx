import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_chains: number;
  total_pharmacy_units: number;
  total_overlap_value_rupees: number;
  total_cost_savings_rupees: number;
  avg_utilization_pct: number;
  active_integrations: number;
};

type ByChain = {
  chain_name: string;
  units_count: number;
  total_overlap_value_rupees: number;
  total_savings_rupees: number;
  avg_utilization_pct: number;
};

type ByCategory = {
  equipment_category: string;
  shared_units_total: number;
  total_units: number;
  overlap_value_rupees: number;
  avg_utilization_pct: number;
};

type ByQuarter = {
  quarter: string;
  rows_count: number;
  overlap_value_rupees: number;
  savings_rupees: number;
};

type TopOverlap = {
  chain_name: string;
  pharmacy_unit: string;
  equipment_category: string;
  quarter: string;
  overlap_value_rupees: number;
  utilization_pct: number;
  cost_savings_rupees: number;
};

type IntegrationOutcome = {
  outcome_status: string;
  count_total: number;
  benefit_realized_rupees: number;
  avg_integration_score: number;
};

type IntegrationRow = {
  id: string;
  chain_name: string;
  pharmacy_unit: string;
  integration_type: string;
  outcome_status: string;
  integration_score: number;
  benefit_realized_rupees: number;
  notes: string | null;
};

type OverlapRow = {
  id: string;
  chain_name: string;
  pharmacy_unit: string;
  quarter: string;
  equipment_category: string;
  shared_units_count: number;
  total_units_count: number;
  overlap_value_rupees: number;
  utilization_pct: number;
  cost_savings_rupees: number;
};

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  return Number(n ?? 0).toFixed(1) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, byChainRes, byCatRes, byQtrRes, topRes, outcomesRes, intRowsRes, ovRowsRes] = await Promise.all([
    supabase.rpc('founder_r2711_kpis'),
    supabase.rpc('founder_r2711_by_chain'),
    supabase.rpc('founder_r2711_by_category'),
    supabase.rpc('founder_r2711_by_quarter'),
    supabase.rpc('founder_r2711_top_overlaps'),
    supabase.rpc('founder_r2711_integration_outcomes'),
    supabase.rpc('founder_r2711_integration_rows'),
    supabase.rpc('founder_r2711_overlap_rows'),
  ]);

  const kpis = (kpisRes.data?.[0] ?? {
    total_chains: 0,
    total_pharmacy_units: 0,
    total_overlap_value_rupees: 0,
    total_cost_savings_rupees: 0,
    avg_utilization_pct: 0,
    active_integrations: 0,
  }) as Kpis;

  const byChain = (byChainRes.data ?? []) as ByChain[];
  const byCategory = (byCatRes.data ?? []) as ByCategory[];
  const byQuarter = (byQtrRes.data ?? []) as ByQuarter[];
  const topOverlaps = (topRes.data ?? []) as TopOverlap[];
  const outcomes = (outcomesRes.data ?? []) as IntegrationOutcome[];
  const integrationRows = (intRowsRes.data ?? []) as IntegrationRow[];
  const overlapRows = (ovRowsRes.data ?? []) as OverlapRow[];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Pharmacy Equipment Overlap</h1>
        <p className="text-sm text-gray-600 mt-1">
          Chain × pharmacy unit × shared equipment overlap value, integration outcomes
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Chains</div>
          <div className="text-xl font-bold">{kpis.total_chains}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Pharmacy Units</div>
          <div className="text-xl font-bold">{kpis.total_pharmacy_units}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Overlap Value</div>
          <div className="text-xl font-bold">{rupees(kpis.total_overlap_value_rupees)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Cost Savings</div>
          <div className="text-xl font-bold">{rupees(kpis.total_cost_savings_rupees)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Avg Utilization</div>
          <div className="text-xl font-bold">{pct(kpis.avg_utilization_pct)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Active Integrations</div>
          <div className="text-xl font-bold">{kpis.active_integrations}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overlap by Chain</h2>
        <DataTable
          rows={byChain}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ByChain) => r.chain_name },
            { key: 'units_count', header: 'Units', render: (r: ByChain) => String(r.units_count) },
            { key: 'total_overlap_value_rupees', header: 'Overlap Value', render: (r: ByChain) => rupees(r.total_overlap_value_rupees) },
            { key: 'total_savings_rupees', header: 'Savings', render: (r: ByChain) => rupees(r.total_savings_rupees) },
            { key: 'avg_utilization_pct', header: 'Avg Util', render: (r: ByChain) => pct(r.avg_utilization_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByChain, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overlap by Equipment Category</h2>
        <DataTable
          rows={byCategory}
          columns={[
            { key: 'equipment_category', header: 'Category', render: (r: ByCategory) => r.equipment_category },
            { key: 'shared_units_total', header: 'Shared Units', render: (r: ByCategory) => String(r.shared_units_total) },
            { key: 'total_units', header: 'Total Units', render: (r: ByCategory) => String(r.total_units) },
            { key: 'overlap_value_rupees', header: 'Overlap Value', render: (r: ByCategory) => rupees(r.overlap_value_rupees) },
            { key: 'avg_utilization_pct', header: 'Avg Util', render: (r: ByCategory) => pct(r.avg_utilization_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByCategory, i: number) => String(r.equipment_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overlap by Quarter</h2>
        <DataTable
          rows={byQuarter}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: ByQuarter) => r.quarter },
            { key: 'rows_count', header: 'Rows', render: (r: ByQuarter) => String(r.rows_count) },
            { key: 'overlap_value_rupees', header: 'Overlap Value', render: (r: ByQuarter) => rupees(r.overlap_value_rupees) },
            { key: 'savings_rupees', header: 'Savings', render: (r: ByQuarter) => rupees(r.savings_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByQuarter, i: number) => String(r.quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Overlaps</h2>
        <DataTable
          rows={topOverlaps}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: TopOverlap) => r.chain_name },
            { key: 'pharmacy_unit', header: 'Pharmacy Unit', render: (r: TopOverlap) => r.pharmacy_unit },
            { key: 'equipment_category', header: 'Category', render: (r: TopOverlap) => r.equipment_category },
            { key: 'quarter', header: 'Quarter', render: (r: TopOverlap) => r.quarter },
            { key: 'overlap_value_rupees', header: 'Overlap', render: (r: TopOverlap) => rupees(r.overlap_value_rupees) },
            { key: 'utilization_pct', header: 'Util', render: (r: TopOverlap) => pct(r.utilization_pct) },
            { key: 'cost_savings_rupees', header: 'Savings', render: (r: TopOverlap) => rupees(r.cost_savings_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopOverlap, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Integration Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome_status', header: 'Status', render: (r: IntegrationOutcome) => r.outcome_status },
            { key: 'count_total', header: 'Count', render: (r: IntegrationOutcome) => String(r.count_total) },
            { key: 'benefit_realized_rupees', header: 'Benefit', render: (r: IntegrationOutcome) => rupees(r.benefit_realized_rupees) },
            { key: 'avg_integration_score', header: 'Avg Score', render: (r: IntegrationOutcome) => Number(r.avg_integration_score ?? 0).toFixed(1) },
          ]}
          emptyMessage="No data"
          rowKey={(r: IntegrationOutcome, i: number) => String(r.outcome_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Integration Rows</h2>
        <DataTable
          rows={integrationRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: IntegrationRow) => r.chain_name },
            { key: 'pharmacy_unit', header: 'Pharmacy Unit', render: (r: IntegrationRow) => r.pharmacy_unit },
            { key: 'integration_type', header: 'Type', render: (r: IntegrationRow) => r.integration_type },
            { key: 'outcome_status', header: 'Status', render: (r: IntegrationRow) => r.outcome_status },
            { key: 'integration_score', header: 'Score', render: (r: IntegrationRow) => Number(r.integration_score ?? 0).toFixed(1) },
            { key: 'benefit_realized_rupees', header: 'Benefit', render: (r: IntegrationRow) => rupees(r.benefit_realized_rupees) },
            { key: 'notes', header: 'Notes', render: (r: IntegrationRow) => r.notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r: IntegrationRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Overlap Rows</h2>
        <DataTable
          rows={overlapRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: OverlapRow) => r.chain_name },
            { key: 'pharmacy_unit', header: 'Unit', render: (r: OverlapRow) => r.pharmacy_unit },
            { key: 'quarter', header: 'Quarter', render: (r: OverlapRow) => r.quarter },
            { key: 'equipment_category', header: 'Category', render: (r: OverlapRow) => r.equipment_category },
            { key: 'shared_units_count', header: 'Shared', render: (r: OverlapRow) => String(r.shared_units_count) + ' / ' + String(r.total_units_count) },
            { key: 'overlap_value_rupees', header: 'Overlap', render: (r: OverlapRow) => rupees(r.overlap_value_rupees) },
            { key: 'utilization_pct', header: 'Util', render: (r: OverlapRow) => pct(r.utilization_pct) },
            { key: 'cost_savings_rupees', header: 'Savings', render: (r: OverlapRow) => rupees(r.cost_savings_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: OverlapRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
