import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_opps: number;
  total_pipeline_rupees: number;
  weighted_pipeline_rupees: number;
  won_acv_rupees: number;
  win_count: number;
  loss_count: number;
};

type ByChain = {
  chain_name: string;
  chain_tier: string;
  city: string;
  opps: number;
  total_acv_rupees: number;
  weighted_acv_rupees: number;
};

type SignalMix = {
  signal_type: string;
  opps: number;
  avg_strength: number;
  total_acv_rupees: number;
};

type ProductMatrix = {
  current_product: string;
  candidate_product: string;
  opps: number;
  acv_rupees: number;
};

type Pipeline = {
  pursuit_stage: string;
  count: number;
  acv_rupees: number;
};

type TopOpp = {
  chain_name: string;
  city: string;
  current_product: string;
  candidate_product: string;
  signal_type: string;
  signal_strength: number;
  estimated_acv_rupees: number;
  probability_pct: number;
  pursuit_stage: string | null;
  owner_name: string | null;
  outcome: string | null;
};

type Blocker = {
  chain_name: string;
  pursuit_stage: string;
  blocker: string;
  next_step: string;
  owner_name: string;
  last_touch_at: string;
};

type Outcome = {
  outcome: string;
  count: number;
  realized_acv_rupees: number;
};

function rupees(n: number | null | undefined) {
  if (n == null) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, byChainRes, signalRes, matrixRes, pipelineRes, topRes, blockersRes, outcomesRes] = await Promise.all([
    supabase.rpc('r2691_kpi_summary'),
    supabase.rpc('r2691_by_chain'),
    supabase.rpc('r2691_signal_mix'),
    supabase.rpc('r2691_product_matrix'),
    supabase.rpc('r2691_pursuit_pipeline'),
    supabase.rpc('r2691_top_opportunities'),
    supabase.rpc('r2691_blockers'),
    supabase.rpc('r2691_outcomes'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_opps: 0,
    total_pipeline_rupees: 0,
    weighted_pipeline_rupees: 0,
    won_acv_rupees: 0,
    win_count: 0,
    loss_count: 0,
  };
  const byChain: ByChain[] = (byChainRes.data as ByChain[]) ?? [];
  const signals: SignalMix[] = (signalRes.data as SignalMix[]) ?? [];
  const matrix: ProductMatrix[] = (matrixRes.data as ProductMatrix[]) ?? [];
  const pipeline: Pipeline[] = (pipelineRes.data as Pipeline[]) ?? [];
  const topOpps: TopOpp[] = (topRes.data as TopOpp[]) ?? [];
  const blockers: Blocker[] = (blockersRes.data as Blocker[]) ?? [];
  const outcomes: Outcome[] = (outcomesRes.data as Outcome[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Cross-Sell Opportunity</h1>
        <p className="text-sm text-gray-600">
          Chain × current product × candidate × signal × pursuit × outcome — founder console r2691
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <Kpi label="Total Opps" value={String(kpi.total_opps)} />
        <Kpi label="Pipeline" value={rupees(kpi.total_pipeline_rupees)} />
        <Kpi label="Weighted Pipeline" value={rupees(kpi.weighted_pipeline_rupees)} />
        <Kpi label="Won ACV" value={rupees(kpi.won_acv_rupees)} />
        <Kpi label="Wins" value={String(kpi.win_count)} />
        <Kpi label="Losses" value={String(kpi.loss_count)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Chain</h2>
        <DataTable
          rows={byChain}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ByChain) => r.chain_name },
            { key: 'chain_tier', header: 'Tier', render: (r: ByChain) => r.chain_tier },
            { key: 'city', header: 'City', render: (r: ByChain) => r.city },
            { key: 'opps', header: 'Opps', render: (r: ByChain) => r.opps },
            { key: 'total_acv_rupees', header: 'Total ACV', render: (r: ByChain) => rupees(r.total_acv_rupees) },
            { key: 'weighted_acv_rupees', header: 'Weighted', render: (r: ByChain) => rupees(r.weighted_acv_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByChain, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Signal Mix</h2>
        <DataTable
          rows={signals}
          columns={[
            { key: 'signal_type', header: 'Signal', render: (r: SignalMix) => r.signal_type },
            { key: 'opps', header: 'Opps', render: (r: SignalMix) => r.opps },
            { key: 'avg_strength', header: 'Avg Strength (1-10)', render: (r: SignalMix) => String(r.avg_strength) },
            { key: 'total_acv_rupees', header: 'ACV', render: (r: SignalMix) => rupees(r.total_acv_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SignalMix, i: number) => String(r.signal_type ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Product Transition Matrix</h2>
        <p className="text-xs text-gray-500 mb-2">Current product → candidate cross-sell product</p>
        <DataTable
          rows={matrix}
          columns={[
            { key: 'current_product', header: 'Current', render: (r: ProductMatrix) => r.current_product },
            { key: 'candidate_product', header: 'Candidate', render: (r: ProductMatrix) => r.candidate_product },
            { key: 'opps', header: 'Opps', render: (r: ProductMatrix) => r.opps },
            { key: 'acv_rupees', header: 'ACV', render: (r: ProductMatrix) => rupees(r.acv_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ProductMatrix, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pursuit Pipeline</h2>
        <DataTable
          rows={pipeline}
          columns={[
            { key: 'pursuit_stage', header: 'Stage', render: (r: Pipeline) => r.pursuit_stage },
            { key: 'count', header: 'Count', render: (r: Pipeline) => r.count },
            { key: 'acv_rupees', header: 'ACV', render: (r: Pipeline) => rupees(r.acv_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Pipeline, i: number) => String(r.pursuit_stage ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Opportunities</h2>
        <DataTable
          rows={topOpps}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: TopOpp) => r.chain_name },
            { key: 'city', header: 'City', render: (r: TopOpp) => r.city },
            { key: 'current_product', header: 'Current', render: (r: TopOpp) => r.current_product },
            { key: 'candidate_product', header: 'Candidate', render: (r: TopOpp) => r.candidate_product },
            { key: 'signal_type', header: 'Signal', render: (r: TopOpp) => r.signal_type },
            { key: 'signal_strength', header: 'Strength', render: (r: TopOpp) => r.signal_strength },
            { key: 'estimated_acv_rupees', header: 'Est ACV', render: (r: TopOpp) => rupees(r.estimated_acv_rupees) },
            { key: 'probability_pct', header: 'Prob %', render: (r: TopOpp) => r.probability_pct },
            { key: 'pursuit_stage', header: 'Stage', render: (r: TopOpp) => r.pursuit_stage ?? '—' },
            { key: 'owner_name', header: 'Owner', render: (r: TopOpp) => r.owner_name ?? '—' },
            { key: 'outcome', header: 'Outcome', render: (r: TopOpp) => r.outcome ?? 'pending' },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopOpp, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Blockers</h2>
        <DataTable
          rows={blockers}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Blocker) => r.chain_name },
            { key: 'pursuit_stage', header: 'Stage', render: (r: Blocker) => r.pursuit_stage },
            { key: 'blocker', header: 'Blocker', render: (r: Blocker) => r.blocker },
            { key: 'next_step', header: 'Next step', render: (r: Blocker) => r.next_step },
            { key: 'owner_name', header: 'Owner', render: (r: Blocker) => r.owner_name },
            { key: 'last_touch_at', header: 'Last touch', render: (r: Blocker) => new Date(r.last_touch_at).toLocaleDateString() },
          ]}
          emptyMessage="No data"
          rowKey={(r: Blocker, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: Outcome) => r.outcome },
            { key: 'count', header: 'Count', render: (r: Outcome) => r.count },
            { key: 'realized_acv_rupees', header: 'Realized ACV', render: (r: Outcome) => rupees(r.realized_acv_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Outcome, i: number) => String(r.outcome ?? i)}
        />
      </section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 p-3 bg-white">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-lg font-semibold">{value}</div>
    </div>
  );
}
