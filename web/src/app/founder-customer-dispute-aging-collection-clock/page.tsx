import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_open_disputes: number;
  total_disputed_amount_rupees: number;
  total_collected_rupees: number;
  avg_aging_days: number;
  write_off_breach_count: number;
  settled_count: number;
  escalated_legal_count: number;
  collection_recovery_pct: number;
};

type BucketRow = {
  bucket: string;
  dispute_count: number;
  total_amount_rupees: number;
  avg_collected_pct: number;
};

type TopAgedRow = {
  dispute_id: string;
  customer_email: string;
  invoice_number: string;
  invoice_amount_rupees: number;
  amount_disputed_rupees: number;
  amount_collected_rupees: number;
  aging_days: number;
  dispute_status: string;
  dispute_reason: string;
  collection_attempts: number;
  total_effort_minutes: number;
  write_off_breach: boolean;
};

type BreachRow = {
  dispute_id: string;
  customer_email: string;
  invoice_number: string;
  amount_disputed_rupees: number;
  amount_collected_rupees: number;
  write_off_threshold_rupees: number;
  exposure_rupees: number;
  aging_days: number;
  dispute_status: string;
};

type EffortRow = {
  dispute_reason: string;
  dispute_count: number;
  total_effort_minutes: number;
  total_disputed_rupees: number;
  total_collected_rupees: number;
  recovery_pct: number;
  effort_per_dispute_minutes: number;
};

type ActionRow = {
  action_id: string;
  invoice_number: string;
  customer_email: string;
  action_on: string;
  action_type: string;
  effort_minutes: number;
  outcome: string;
  amount_received_rupees: number;
  performed_by_email: string | null;
};

type StatusRow = {
  dispute_status: string;
  dispute_count: number;
  total_amount_rupees: number;
  avg_aging_days: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, bucketsRes, topAgedRes, breachesRes, effortRes, actionsRes, statusRes] = await Promise.all([
    supabase.rpc('dispute_aging_collection_summary_r2400'),
    supabase.rpc('dispute_aging_buckets_r2400'),
    supabase.rpc('dispute_aging_top_aged_r2400'),
    supabase.rpc('dispute_aging_writeoff_breaches_r2400'),
    supabase.rpc('dispute_aging_effort_efficiency_r2400'),
    supabase.rpc('dispute_aging_recent_actions_r2400'),
    supabase.rpc('dispute_aging_status_distribution_r2400'),
  ]);

  const summary: SummaryRow | null = (summaryRes.data?.[0] ?? null) as SummaryRow | null;
  const buckets: BucketRow[] = (bucketsRes.data ?? []) as BucketRow[];
  const topAged: TopAgedRow[] = (topAgedRes.data ?? []) as TopAgedRow[];
  const breaches: BreachRow[] = (breachesRes.data ?? []) as BreachRow[];
  const efforts: EffortRow[] = (effortRes.data ?? []) as EffortRow[];
  const actions: ActionRow[] = (actionsRes.data ?? []) as ActionRow[];
  const statuses: StatusRow[] = (statusRes.data ?? []) as StatusRow[];

  const bucketCols: Column<BucketRow>[] = [
    { key: 'bucket', header: 'Aging Bucket', render: (r) => r.bucket },
    { key: 'count', header: 'Disputes', render: (r) => r.dispute_count },
    { key: 'amt', header: 'Disputed (Rs)', render: (r) => Number(r.total_amount_rupees).toLocaleString('en-IN') },
    { key: 'pct', header: 'Recovery %', render: (r) => `${r.avg_collected_pct}%` },
  ];

  const topAgedCols: Column<TopAgedRow>[] = [
    { key: 'inv', header: 'Invoice', render: (r) => r.invoice_number },
    { key: 'cust', header: 'Customer', render: (r) => r.customer_email },
    { key: 'aging', header: 'Aging (days)', render: (r) => r.aging_days },
    { key: 'disp', header: 'Disputed (Rs)', render: (r) => Number(r.amount_disputed_rupees).toLocaleString('en-IN') },
    { key: 'coll', header: 'Collected (Rs)', render: (r) => Number(r.amount_collected_rupees).toLocaleString('en-IN') },
    { key: 'reason', header: 'Reason', render: (r) => r.dispute_reason },
    { key: 'status', header: 'Status', render: (r) => r.dispute_status },
    { key: 'attempts', header: 'Attempts', render: (r) => r.collection_attempts },
    { key: 'effort', header: 'Effort (min)', render: (r) => r.total_effort_minutes },
    { key: 'breach', header: 'Breach', render: (r) => (r.write_off_breach ? 'YES' : 'no') },
  ];

  const breachCols: Column<BreachRow>[] = [
    { key: 'inv', header: 'Invoice', render: (r) => r.invoice_number },
    { key: 'cust', header: 'Customer', render: (r) => r.customer_email },
    { key: 'disp', header: 'Disputed (Rs)', render: (r) => Number(r.amount_disputed_rupees).toLocaleString('en-IN') },
    { key: 'coll', header: 'Collected (Rs)', render: (r) => Number(r.amount_collected_rupees).toLocaleString('en-IN') },
    { key: 'exp', header: 'Exposure (Rs)', render: (r) => Number(r.exposure_rupees).toLocaleString('en-IN') },
    { key: 'thr', header: 'Threshold (Rs)', render: (r) => Number(r.write_off_threshold_rupees).toLocaleString('en-IN') },
    { key: 'aging', header: 'Aging (d)', render: (r) => r.aging_days },
    { key: 'status', header: 'Status', render: (r) => r.dispute_status },
  ];

  const effortCols: Column<EffortRow>[] = [
    { key: 'reason', header: 'Reason', render: (r) => r.dispute_reason },
    { key: 'count', header: 'Disputes', render: (r) => r.dispute_count },
    { key: 'effort', header: 'Total Effort (min)', render: (r) => r.total_effort_minutes },
    { key: 'per', header: 'Effort/Dispute', render: (r) => r.effort_per_dispute_minutes },
    { key: 'disp', header: 'Disputed (Rs)', render: (r) => Number(r.total_disputed_rupees).toLocaleString('en-IN') },
    { key: 'coll', header: 'Collected (Rs)', render: (r) => Number(r.total_collected_rupees).toLocaleString('en-IN') },
    { key: 'pct', header: 'Recovery %', render: (r) => `${r.recovery_pct}%` },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'date', header: 'Date', render: (r) => r.action_on },
    { key: 'inv', header: 'Invoice', render: (r) => r.invoice_number },
    { key: 'cust', header: 'Customer', render: (r) => r.customer_email },
    { key: 'type', header: 'Action', render: (r) => r.action_type },
    { key: 'min', header: 'Effort (min)', render: (r) => r.effort_minutes },
    { key: 'out', header: 'Outcome', render: (r) => r.outcome },
    { key: 'recv', header: 'Received (Rs)', render: (r) => Number(r.amount_received_rupees).toLocaleString('en-IN') },
    { key: 'by', header: 'By', render: (r) => r.performed_by_email ?? '-' },
  ];

  const statusCols: Column<StatusRow>[] = [
    { key: 'status', header: 'Status', render: (r) => r.dispute_status },
    { key: 'count', header: 'Disputes', render: (r) => r.dispute_count },
    { key: 'amt', header: 'Disputed (Rs)', render: (r) => Number(r.total_amount_rupees).toLocaleString('en-IN') },
    { key: 'aging', header: 'Avg Aging (d)', render: (r) => Number(r.avg_aging_days).toFixed(1) },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer Dispute Aging vs Collection Clock</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Aging days vs collection effort per disputed invoice. Write-off threshold breach alerts when exposure &gt;= threshold.
        </p>
      </header>

      {summary ? (
        <section className="grid grid-cols-2 gap-4 md:grid-cols-4">
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Open Disputes</div>
            <div className="text-2xl font-semibold">{summary.total_open_disputes}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Disputed (Rs)</div>
            <div className="text-2xl font-semibold">{Number(summary.total_disputed_amount_rupees).toLocaleString('en-IN')}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Collected (Rs)</div>
            <div className="text-2xl font-semibold">{Number(summary.total_collected_rupees).toLocaleString('en-IN')}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Recovery %</div>
            <div className="text-2xl font-semibold">{summary.collection_recovery_pct}%</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg Aging (d)</div>
            <div className="text-2xl font-semibold">{Number(summary.avg_aging_days).toFixed(1)}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Write-off Breach</div>
            <div className="text-2xl font-semibold">{summary.write_off_breach_count}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Settled</div>
            <div className="text-2xl font-semibold">{summary.settled_count}</div>
          </div>
          <div className="rounded border border-[var(--color-border)] bg-white p-4">
            <div className="text-xs text-[var(--color-muted)]">Escalated Legal</div>
            <div className="text-2xl font-semibold">{summary.escalated_legal_count}</div>
          </div>
        </section>
      ) : (
        <div className="rounded border border-dashed border-[var(--color-border)] p-6 text-center text-sm text-[var(--color-muted)]">
          No summary data.
        </div>
      )}

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Aging Buckets</h2>
        <DataTable<BucketRow>
          columns={bucketCols}
          rows={buckets}
          emptyMessage="No aging buckets."
          rowKey={(r) => r.bucket}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Write-off Threshold Breaches</h2>
        <DataTable<BreachRow>
          columns={breachCols}
          rows={breaches}
          emptyMessage="No threshold breaches."
          rowKey={(r) => r.dispute_id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Top Aged Disputes (&gt;30d open)</h2>
        <DataTable<TopAgedRow>
          columns={topAgedCols}
          rows={topAged}
          emptyMessage="No aged disputes."
          rowKey={(r) => r.dispute_id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Collection Effort vs Recovery by Reason</h2>
        <DataTable<EffortRow>
          columns={effortCols}
          rows={efforts}
          emptyMessage="No effort data."
          rowKey={(r) => r.dispute_reason}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Status Distribution</h2>
        <DataTable<StatusRow>
          columns={statusCols}
          rows={statuses}
          emptyMessage="No status data."
          rowKey={(r) => r.dispute_status}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Collection Actions</h2>
        <DataTable<ActionRow>
          columns={actionCols}
          rows={actions}
          emptyMessage="No recent actions."
          rowKey={(r) => r.action_id}
        />
      </section>
    </main>
  );
}
