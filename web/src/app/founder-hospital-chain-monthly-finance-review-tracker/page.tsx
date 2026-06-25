import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Review = {
  id: string;
  chain_name: string;
  chain_tier: string;
  review_month: string;
  invoiced_rupees: number;
  collected_rupees: number;
  ar_outstanding_rupees: number;
  ar_days_avg: number;
  dispute_count: number;
  dispute_amount_rupees: number;
  health_score: number;
  status: string;
  reviewed_at: string | null;
};

type Kpis = {
  total_chains: number;
  total_invoiced: number;
  total_collected: number;
  total_ar: number;
  avg_ar_days: number;
  total_dispute_amount: number;
  collection_rate_pct: number;
  escalated_count: number;
};

type TierRow = {
  chain_tier: string;
  chain_count: number;
  ar_total: number;
  ar_days_avg: number;
  dispute_amount_total: number;
};

type RiskRow = {
  id: string;
  chain_name: string;
  ar_outstanding_rupees: number;
  ar_days_avg: number;
  health_score: number;
  status: string;
};

type ActionRow = {
  id: string;
  chain_name: string;
  action_type: string;
  action_summary: string;
  assigned_to: string;
  due_date: string;
  outcome: string;
  recovered_rupees: number;
  closed_at: string | null;
};

type OutcomeRow = {
  outcome: string;
  action_count: number;
  recovered_total: number;
};

type PendingRow = {
  pending_count: number;
  in_progress_count: number;
  overdue_count: number;
  recovered_amount_total: number;
};

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [reviewsRes, kpisRes, tierRes, riskRes, actionsRes, outcomeRes, pendingRes] = await Promise.all([
    supabase.rpc('founder_chain_finance_reviews_list_r2675'),
    supabase.rpc('founder_chain_finance_kpis_r2675'),
    supabase.rpc('founder_chain_finance_by_tier_r2675'),
    supabase.rpc('founder_chain_finance_top_risk_r2675'),
    supabase.rpc('founder_chain_finance_actions_list_r2675'),
    supabase.rpc('founder_chain_finance_action_outcomes_r2675'),
    supabase.rpc('founder_chain_finance_pending_actions_r2675'),
  ]);

  const reviews = (reviewsRes.data ?? []) as Review[];
  const kpis = ((kpisRes.data ?? [])[0] ?? null) as Kpis | null;
  const tiers = (tierRes.data ?? []) as TierRow[];
  const risks = (riskRes.data ?? []) as RiskRow[];
  const actions = (actionsRes.data ?? []) as ActionRow[];
  const outcomes = (outcomeRes.data ?? []) as OutcomeRow[];
  const pending = ((pendingRes.data ?? [])[0] ?? null) as PendingRow | null;

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Chain Monthly Finance Review Tracker</h1>
        <p className="text-sm text-gray-600">
          Chain × review month × AR days × dispute amount × fix action =&gt; outcome
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Chains reviewed</div>
          <div className="text-2xl font-semibold">{kpis?.total_chains ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Invoiced</div>
          <div className="text-2xl font-semibold">{rupees(kpis?.total_invoiced)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Collected</div>
          <div className="text-2xl font-semibold">{rupees(kpis?.total_collected)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Outstanding AR</div>
          <div className="text-2xl font-semibold">{rupees(kpis?.total_ar)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Avg AR days</div>
          <div className="text-2xl font-semibold">{Number(kpis?.avg_ar_days ?? 0).toFixed(1)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Dispute amount</div>
          <div className="text-2xl font-semibold">{rupees(kpis?.total_dispute_amount)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Collection rate</div>
          <div className="text-2xl font-semibold">{Number(kpis?.collection_rate_pct ?? 0).toFixed(1)}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Escalated</div>
          <div className="text-2xl font-semibold">{kpis?.escalated_count ?? 0}</div>
        </div>
      </section>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4 bg-amber-50">
          <div className="text-xs text-gray-500">Pending actions</div>
          <div className="text-2xl font-semibold">{pending?.pending_count ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4 bg-blue-50">
          <div className="text-xs text-gray-500">In progress</div>
          <div className="text-2xl font-semibold">{pending?.in_progress_count ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4 bg-red-50">
          <div className="text-xs text-gray-500">Overdue</div>
          <div className="text-2xl font-semibold">{pending?.overdue_count ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4 bg-emerald-50">
          <div className="text-xs text-gray-500">Recovered</div>
          <div className="text-2xl font-semibold">{rupees(pending?.recovered_amount_total)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Monthly chain reviews</h2>
        <DataTable
          rows={reviews}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: Review) => r.chain_name },
            { key: 'chain_tier', header: 'Tier', render: (r: Review) => r.chain_tier },
            { key: 'review_month', header: 'Month', render: (r: Review) => String(r.review_month).slice(0, 7) },
            { key: 'invoiced_rupees', header: 'Invoiced', render: (r: Review) => rupees(r.invoiced_rupees) },
            { key: 'collected_rupees', header: 'Collected', render: (r: Review) => rupees(r.collected_rupees) },
            { key: 'ar_outstanding_rupees', header: 'AR open', render: (r: Review) => rupees(r.ar_outstanding_rupees) },
            { key: 'ar_days_avg', header: 'AR days', render: (r: Review) => Number(r.ar_days_avg).toFixed(1) },
            { key: 'dispute_amount_rupees', header: 'Disputes', render: (r: Review) => rupees(r.dispute_amount_rupees) },
            { key: 'health_score', header: 'Health', render: (r: Review) => String(r.health_score) },
            { key: 'status', header: 'Status', render: (r: Review) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: Review, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">By tier breakdown</h2>
        <DataTable
          rows={tiers}
          columns={[
            { key: 'chain_tier', header: 'Tier', render: (r: TierRow) => r.chain_tier },
            { key: 'chain_count', header: 'Chains', render: (r: TierRow) => String(r.chain_count) },
            { key: 'ar_total', header: 'AR total', render: (r: TierRow) => rupees(r.ar_total) },
            { key: 'ar_days_avg', header: 'AR days avg', render: (r: TierRow) => Number(r.ar_days_avg).toFixed(1) },
            { key: 'dispute_amount_total', header: 'Disputes', render: (r: TierRow) => rupees(r.dispute_amount_total) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRow, i: number) => String(r.chain_tier ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top risk chains (health &lt; 70 or AR &gt; 40 days)</h2>
        <DataTable
          rows={risks}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: RiskRow) => r.chain_name },
            { key: 'ar_outstanding_rupees', header: 'AR open', render: (r: RiskRow) => rupees(r.ar_outstanding_rupees) },
            { key: 'ar_days_avg', header: 'AR days', render: (r: RiskRow) => Number(r.ar_days_avg).toFixed(1) },
            { key: 'health_score', header: 'Health', render: (r: RiskRow) => String(r.health_score) },
            { key: 'status', header: 'Status', render: (r: RiskRow) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: RiskRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Fix actions =&gt; outcomes</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ActionRow) => r.chain_name },
            { key: 'action_type', header: 'Type', render: (r: ActionRow) => r.action_type },
            { key: 'action_summary', header: 'Summary', render: (r: ActionRow) => r.action_summary },
            { key: 'assigned_to', header: 'Owner', render: (r: ActionRow) => r.assigned_to },
            { key: 'due_date', header: 'Due', render: (r: ActionRow) => String(r.due_date) },
            { key: 'outcome', header: 'Outcome', render: (r: ActionRow) => r.outcome },
            { key: 'recovered_rupees', header: 'Recovered', render: (r: ActionRow) => rupees(r.recovered_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Outcome summary</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
            { key: 'action_count', header: 'Count', render: (r: OutcomeRow) => String(r.action_count) },
            { key: 'recovered_total', header: 'Recovered', render: (r: OutcomeRow) => rupees(r.recovered_total) },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
        />
      </section>
    </main>
  );
}
