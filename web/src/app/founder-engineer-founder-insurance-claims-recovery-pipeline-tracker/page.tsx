import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type PipelineRow = {
  stage: string;
  claim_count: number;
  claimed_total_rupees: number;
  approved_total_rupees: number;
  settled_total_rupees: number;
  avg_ageing_days: number;
  outstanding_rupees: number;
};

type InsurerRow = {
  insurer_name: string;
  claim_count: number;
  claimed_total_rupees: number;
  settled_total_rupees: number;
  recovery_pct: number;
  avg_settlement_days: number;
  rejected_count: number;
};

type BrokerRow = {
  broker_name: string;
  claim_count: number;
  claimed_total_rupees: number;
  settled_total_rupees: number;
  recovery_pct: number;
  open_count: number;
};

type AgeingRow = {
  bucket: string;
  claim_count: number;
  outstanding_rupees: number;
  critical_count: number;
};

type CategoryRow = {
  claim_category: string;
  claim_count: number;
  claimed_total_rupees: number;
  settled_total_rupees: number;
  recovery_pct: number;
  avg_deductible_rupees: number;
};

type ActionRow = {
  action_kind: string;
  action_count: number;
  open_count: number;
  amount_at_stake_rupees: number;
  amount_recovered_rupees: number;
};

type WatchRow = {
  claim_reference: string;
  insurer_name: string;
  stage: string;
  priority: string;
  claimed_amount_rupees: number;
  outstanding_rupees: number;
  ageing_days: number;
  recovery_action: string;
};

type RejectionRow = {
  rejection_reason: string;
  claim_count: number;
  claimed_total_rupees: number;
  insurers_affected: number;
};

function inr(v: number | null | undefined): string {
  if (v == null) return '-';
  return '₹' + Number(v).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    pipelineRes,
    insurerRes,
    brokerRes,
    ageingRes,
    categoryRes,
    actionsRes,
    watchRes,
    rejectionRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3107_pipeline_overview'),
    supabase.rpc('founder_r3107_insurer_performance'),
    supabase.rpc('founder_r3107_broker_scorecard'),
    supabase.rpc('founder_r3107_ageing_buckets'),
    supabase.rpc('founder_r3107_category_breakdown'),
    supabase.rpc('founder_r3107_recovery_actions_summary'),
    supabase.rpc('founder_r3107_priority_watchlist'),
    supabase.rpc('founder_r3107_rejection_analysis'),
  ]);

  const pipeline = (pipelineRes.data ?? []) as PipelineRow[];
  const insurers = (insurerRes.data ?? []) as InsurerRow[];
  const brokers = (brokerRes.data ?? []) as BrokerRow[];
  const ageing = (ageingRes.data ?? []) as AgeingRow[];
  const categories = (categoryRes.data ?? []) as CategoryRow[];
  const actions = (actionsRes.data ?? []) as ActionRow[];
  const watch = (watchRes.data ?? []) as WatchRow[];
  const rejections = (rejectionRes.data ?? []) as RejectionRow[];

  const pipelineCols: Column<PipelineRow>[] = [
    { key: 'stage', header: 'Stage' },
    { key: 'claim_count', header: 'Claims' },
    { key: 'claimed_total_rupees', header: 'Claimed', render: (r) => inr(r.claimed_total_rupees) },
    { key: 'approved_total_rupees', header: 'Approved', render: (r) => inr(r.approved_total_rupees) },
    { key: 'settled_total_rupees', header: 'Settled', render: (r) => inr(r.settled_total_rupees) },
    { key: 'avg_ageing_days', header: 'Avg ageing (d)' },
    { key: 'outstanding_rupees', header: 'Outstanding', render: (r) => inr(r.outstanding_rupees) },
  ];

  const insurerCols: Column<InsurerRow>[] = [
    { key: 'insurer_name', header: 'Insurer' },
    { key: 'claim_count', header: 'Claims' },
    { key: 'claimed_total_rupees', header: 'Claimed', render: (r) => inr(r.claimed_total_rupees) },
    { key: 'settled_total_rupees', header: 'Settled', render: (r) => inr(r.settled_total_rupees) },
    { key: 'recovery_pct', header: 'Recovery %' },
    { key: 'avg_settlement_days', header: 'Avg days' },
    { key: 'rejected_count', header: 'Rejected' },
  ];

  const brokerCols: Column<BrokerRow>[] = [
    { key: 'broker_name', header: 'Broker' },
    { key: 'claim_count', header: 'Claims' },
    { key: 'claimed_total_rupees', header: 'Claimed', render: (r) => inr(r.claimed_total_rupees) },
    { key: 'settled_total_rupees', header: 'Settled', render: (r) => inr(r.settled_total_rupees) },
    { key: 'recovery_pct', header: 'Recovery %' },
    { key: 'open_count', header: 'Open' },
  ];

  const ageingCols: Column<AgeingRow>[] = [
    { key: 'bucket', header: 'Ageing bucket' },
    { key: 'claim_count', header: 'Claims' },
    { key: 'outstanding_rupees', header: 'Outstanding', render: (r) => inr(r.outstanding_rupees) },
    { key: 'critical_count', header: 'Critical' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'claim_category', header: 'Category' },
    { key: 'claim_count', header: 'Claims' },
    { key: 'claimed_total_rupees', header: 'Claimed', render: (r) => inr(r.claimed_total_rupees) },
    { key: 'settled_total_rupees', header: 'Settled', render: (r) => inr(r.settled_total_rupees) },
    { key: 'recovery_pct', header: 'Recovery %' },
    { key: 'avg_deductible_rupees', header: 'Avg deductible', render: (r) => inr(r.avg_deductible_rupees) },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'action_kind', header: 'Recovery action' },
    { key: 'action_count', header: 'Total' },
    { key: 'open_count', header: 'Open' },
    { key: 'amount_at_stake_rupees', header: 'At stake', render: (r) => inr(r.amount_at_stake_rupees) },
    { key: 'amount_recovered_rupees', header: 'Recovered', render: (r) => inr(r.amount_recovered_rupees) },
  ];

  const watchCols: Column<WatchRow>[] = [
    { key: 'claim_reference', header: 'Claim ref' },
    { key: 'insurer_name', header: 'Insurer' },
    { key: 'stage', header: 'Stage' },
    { key: 'priority', header: 'Priority' },
    { key: 'claimed_amount_rupees', header: 'Claimed', render: (r) => inr(r.claimed_amount_rupees) },
    { key: 'outstanding_rupees', header: 'Outstanding', render: (r) => inr(r.outstanding_rupees) },
    { key: 'ageing_days', header: 'Ageing (d)' },
    { key: 'recovery_action', header: 'Next action' },
  ];

  const rejectionCols: Column<RejectionRow>[] = [
    { key: 'rejection_reason', header: 'Reason' },
    { key: 'claim_count', header: 'Claims' },
    { key: 'claimed_total_rupees', header: 'Claimed', render: (r) => inr(r.claimed_total_rupees) },
    { key: 'insurers_affected', header: 'Insurers' },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 px-6 py-10">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">
          Quarterly Strategic Engineer-Founder Insurance Claims Recovery Pipeline Tracker
        </h1>
        <p className="text-sm text-neutral-600">
          AMC, accidental damage, and equipment-loss claims pipeline. Tracks claim vs settled,
          ageing, insurer & broker performance, and recovery actions.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Pipeline by stage</h2>
        <DataTable
          rows={pipeline}
          columns={pipelineCols}
          emptyMessage="No claims in pipeline."
          rowKey={(r, i) => String((r as PipelineRow).stage ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Insurer performance</h2>
        <DataTable
          rows={insurers}
          columns={insurerCols}
          emptyMessage="No insurer data."
          rowKey={(r, i) => String((r as InsurerRow).insurer_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Broker scorecard</h2>
        <DataTable
          rows={brokers}
          columns={brokerCols}
          emptyMessage="No broker data."
          rowKey={(r, i) => String((r as BrokerRow).broker_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Ageing buckets (open claims)</h2>
        <DataTable
          rows={ageing}
          columns={ageingCols}
          emptyMessage="No open claims."
          rowKey={(r, i) => String((r as AgeingRow).bucket ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Category breakdown</h2>
        <DataTable
          rows={categories}
          columns={categoryCols}
          emptyMessage="No category data."
          rowKey={(r, i) => String((r as CategoryRow).claim_category ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recovery actions summary</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No recovery actions logged."
          rowKey={(r, i) => String((r as ActionRow).action_kind ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Priority watchlist (high & critical)</h2>
        <DataTable
          rows={watch}
          columns={watchCols}
          emptyMessage="No high-priority claims open."
          rowKey={(r, i) => String((r as WatchRow).claim_reference ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Rejection & partial analysis</h2>
        <DataTable
          rows={rejections}
          columns={rejectionCols}
          emptyMessage="No rejections recorded."
          rowKey={(r, i) => String((r as RejectionRow).rejection_reason ?? i)}
        />
      </section>
    </main>
  );
}
