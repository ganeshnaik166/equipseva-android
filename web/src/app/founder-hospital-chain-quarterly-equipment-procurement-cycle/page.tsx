import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_cycles: number;
  awarded_cycles: number;
  active_cycles: number;
  total_budget_lakh: number;
  committed_lakh: number;
  equipseva_share_lakh: number;
  win_rate_pct: number;
};

type Cycle = {
  id: string;
  chain_name: string;
  chain_tier: string;
  quarter_label: string;
  cycle_status: string;
  budget_total_lakh: number;
  budget_committed_lakh: number;
  budget_remaining_lakh: number;
  hospitals_in_scope: number;
  equipseva_share_lakh: number;
  award_decided_at: string | null;
};

type Bidder = {
  id: string;
  chain_name: string;
  quarter_label: string;
  bidder_name: string;
  bidder_type: string;
  bid_amount_lakh: number;
  bid_status: string;
  technical_score: number | null;
  commercial_score: number | null;
  amc_bundled: boolean;
  equipseva_referred: boolean;
};

type Tier = {
  chain_tier: string;
  cycle_count: number;
  total_budget_lakh: number;
  committed_lakh: number;
  equipseva_share_lakh: number;
};

type Winner = {
  chain_name: string;
  quarter_label: string;
  bidder_name: string;
  bid_amount_lakh: number;
  amc_bundled: boolean;
  equipseva_referred: boolean;
  technical_score: number | null;
  commercial_score: number | null;
};

type Lesson = {
  chain_name: string;
  quarter_label: string;
  cycle_status: string;
  lessons_learned: string;
};

type Attach = {
  chain_name: string;
  cycles_total: number;
  cycles_referred: number;
  total_bid_value_lakh: number;
  referred_bid_value_lakh: number;
  attach_rate_pct: number;
};

type Pipeline = {
  quarter_label: string;
  active_count: number;
  awarded_count: number;
  cancelled_count: number;
  pipeline_lakh: number;
  awarded_lakh: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, cyclesRes, biddersRes, tiersRes, winnersRes, lessonsRes, attachRes, pipelineRes] = await Promise.all([
    supabase.rpc('r2719_kpi_snapshot'),
    supabase.rpc('r2719_cycles_list'),
    supabase.rpc('r2719_bidders_list'),
    supabase.rpc('r2719_tier_breakdown'),
    supabase.rpc('r2719_winners_list'),
    supabase.rpc('r2719_lessons_digest'),
    supabase.rpc('r2719_equipseva_attach'),
    supabase.rpc('r2719_quarter_pipeline'),
  ]);

  const kpi: Kpi | null = (kpiRes.data?.[0] as Kpi) ?? null;
  const cycles: Cycle[] = (cyclesRes.data as Cycle[]) ?? [];
  const bidders: Bidder[] = (biddersRes.data as Bidder[]) ?? [];
  const tiers: Tier[] = (tiersRes.data as Tier[]) ?? [];
  const winners: Winner[] = (winnersRes.data as Winner[]) ?? [];
  const lessons: Lesson[] = (lessonsRes.data as Lesson[]) ?? [];
  const attach: Attach[] = (attachRes.data as Attach[]) ?? [];
  const pipeline: Pipeline[] = (pipelineRes.data as Pipeline[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Equipment Procurement Cycle</h1>
        <p className="text-sm text-gray-600 mt-1">
          Chain × quarter × budget × bidders × winner & lessons learned. Round r2719.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Cycles" value={kpi?.total_cycles ?? 0} />
        <KpiCard label="Awarded" value={kpi?.awarded_cycles ?? 0} />
        <KpiCard label="Active Pipeline" value={kpi?.active_cycles ?? 0} />
        <KpiCard label="Win Rate %" value={`${kpi?.win_rate_pct ?? 0}%`} />
        <KpiCard label="Total Budget" value={`Rs.${kpi?.total_budget_lakh ?? 0}L`} />
        <KpiCard label="Committed" value={`Rs.${kpi?.committed_lakh ?? 0}L`} />
        <KpiCard label="Equipseva Share" value={`Rs.${kpi?.equipseva_share_lakh ?? 0}L`} />
        <KpiCard label="Hospitals (chain-wide)" value={cycles.reduce((s, c) => s + c.hospitals_in_scope, 0)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Quarter Pipeline</h2>
        <DataTable
          rows={pipeline}
          columns={[
            { key: 'quarter_label', header: 'Quarter', render: (r: Pipeline) => r.quarter_label },
            { key: 'active_count', header: 'Active', render: (r: Pipeline) => r.active_count },
            { key: 'awarded_count', header: 'Awarded', render: (r: Pipeline) => r.awarded_count },
            { key: 'cancelled_count', header: 'Cancelled', render: (r: Pipeline) => r.cancelled_count },
            { key: 'pipeline_lakh', header: 'Pipeline (Lakh)', render: (r: Pipeline) => `Rs.${r.pipeline_lakh}` },
            { key: 'awarded_lakh', header: 'Awarded (Lakh)', render: (r: Pipeline) => `Rs.${r.awarded_lakh}` },
          ]}
          emptyMessage="No pipeline data"
          rowKey={(r: Pipeline, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Procurement Cycles</h2>
        <DataTable
          rows={cycles}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Cycle) => r.chain_name },
            { key: 'chain_tier', header: 'Tier', render: (r: Cycle) => r.chain_tier },
            { key: 'quarter_label', header: 'Quarter', render: (r: Cycle) => r.quarter_label },
            { key: 'cycle_status', header: 'Status', render: (r: Cycle) => r.cycle_status },
            { key: 'budget_total_lakh', header: 'Budget (L)', render: (r: Cycle) => `Rs.${r.budget_total_lakh}` },
            { key: 'budget_committed_lakh', header: 'Committed (L)', render: (r: Cycle) => `Rs.${r.budget_committed_lakh}` },
            { key: 'budget_remaining_lakh', header: 'Remaining (L)', render: (r: Cycle) => `Rs.${r.budget_remaining_lakh}` },
            { key: 'hospitals_in_scope', header: 'Hospitals', render: (r: Cycle) => r.hospitals_in_scope },
            { key: 'equipseva_share_lakh', header: 'Equipseva Share', render: (r: Cycle) => `Rs.${r.equipseva_share_lakh}L` },
            { key: 'award_decided_at', header: 'Awarded On', render: (r: Cycle) => r.award_decided_at ?? '—' },
          ]}
          emptyMessage="No cycles"
          rowKey={(r: Cycle, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Bidders</h2>
        <DataTable
          rows={bidders}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Bidder) => r.chain_name },
            { key: 'quarter_label', header: 'Quarter', render: (r: Bidder) => r.quarter_label },
            { key: 'bidder_name', header: 'Bidder', render: (r: Bidder) => r.bidder_name },
            { key: 'bidder_type', header: 'Type', render: (r: Bidder) => r.bidder_type },
            { key: 'bid_amount_lakh', header: 'Bid (L)', render: (r: Bidder) => `Rs.${r.bid_amount_lakh}` },
            { key: 'bid_status', header: 'Status', render: (r: Bidder) => r.bid_status },
            { key: 'technical_score', header: 'Tech', render: (r: Bidder) => r.technical_score ?? '—' },
            { key: 'commercial_score', header: 'Comm', render: (r: Bidder) => r.commercial_score ?? '—' },
            { key: 'amc_bundled', header: 'AMC?', render: (r: Bidder) => (r.amc_bundled ? 'Yes' : 'No') },
            { key: 'equipseva_referred', header: 'Referred?', render: (r: Bidder) => (r.equipseva_referred ? 'Yes' : 'No') },
          ]}
          emptyMessage="No bidders"
          rowKey={(r: Bidder, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Winners</h2>
        <DataTable
          rows={winners}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Winner) => r.chain_name },
            { key: 'quarter_label', header: 'Quarter', render: (r: Winner) => r.quarter_label },
            { key: 'bidder_name', header: 'Winner', render: (r: Winner) => r.bidder_name },
            { key: 'bid_amount_lakh', header: 'Awarded (L)', render: (r: Winner) => `Rs.${r.bid_amount_lakh}` },
            { key: 'amc_bundled', header: 'AMC Bundled', render: (r: Winner) => (r.amc_bundled ? 'Yes' : 'No') },
            { key: 'equipseva_referred', header: 'Equipseva Referred', render: (r: Winner) => (r.equipseva_referred ? 'Yes' : 'No') },
            { key: 'technical_score', header: 'Tech Score', render: (r: Winner) => r.technical_score ?? '—' },
            { key: 'commercial_score', header: 'Comm Score', render: (r: Winner) => r.commercial_score ?? '—' },
          ]}
          emptyMessage="No winners yet"
          rowKey={(r: Winner, i: number) => `${r.chain_name}-${r.quarter_label}-${i}`}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Tier Breakdown</h2>
        <DataTable
          rows={tiers}
          columns={[
            { key: 'chain_tier', header: 'Tier', render: (r: Tier) => r.chain_tier },
            { key: 'cycle_count', header: 'Cycles', render: (r: Tier) => r.cycle_count },
            { key: 'total_budget_lakh', header: 'Total Budget (L)', render: (r: Tier) => `Rs.${r.total_budget_lakh}` },
            { key: 'committed_lakh', header: 'Committed (L)', render: (r: Tier) => `Rs.${r.committed_lakh}` },
            { key: 'equipseva_share_lakh', header: 'Equipseva Share (L)', render: (r: Tier) => `Rs.${r.equipseva_share_lakh}` },
          ]}
          emptyMessage="No tier data"
          rowKey={(r: Tier, i: number) => String(r.chain_tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Equipseva Attach</h2>
        <DataTable
          rows={attach}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Attach) => r.chain_name },
            { key: 'cycles_total', header: 'Cycles', render: (r: Attach) => r.cycles_total },
            { key: 'cycles_referred', header: 'Referred', render: (r: Attach) => r.cycles_referred },
            { key: 'total_bid_value_lakh', header: 'Total Bid Value (L)', render: (r: Attach) => `Rs.${r.total_bid_value_lakh}` },
            { key: 'referred_bid_value_lakh', header: 'Referred Value (L)', render: (r: Attach) => `Rs.${r.referred_bid_value_lakh}` },
            { key: 'attach_rate_pct', header: 'Attach %', render: (r: Attach) => `${r.attach_rate_pct}%` },
          ]}
          emptyMessage="No attach data"
          rowKey={(r: Attach, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Lessons Learned</h2>
        <DataTable
          rows={lessons}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Lesson) => r.chain_name },
            { key: 'quarter_label', header: 'Quarter', render: (r: Lesson) => r.quarter_label },
            { key: 'cycle_status', header: 'Status', render: (r: Lesson) => r.cycle_status },
            { key: 'lessons_learned', header: 'Lessons', render: (r: Lesson) => r.lessons_learned },
          ]}
          emptyMessage="No lessons captured"
          rowKey={(r: Lesson, i: number) => `${r.chain_name}-${r.quarter_label}-${i}`}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="border rounded-lg p-4 bg-white shadow-sm">
      <div className="text-xs uppercase text-gray-500 tracking-wide">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
    </div>
  );
}