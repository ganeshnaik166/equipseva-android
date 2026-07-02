import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_requests: number;
  active_deployments: number;
  on_time_rate: number | null;
  avg_satisfaction: number | null;
  avg_duration_days: number | null;
  total_billed_rupees: number;
  cancelled_count: number;
  escalated_count: number;
};

type RequestRow = {
  request_code: string;
  customer_org: string;
  equipment_kind: string;
  request_reason: string;
  promised_delivery_at: string;
  actual_delivered_at: string | null;
  duration_days: number | null;
  satisfaction_score: number | null;
  outcome: string;
  total_billed_rupees: number;
};

type KindRow = {
  equipment_kind: string;
  request_count: number;
  avg_duration: number | null;
  avg_satisfaction: number | null;
  total_revenue: number;
};

type ReasonRow = {
  request_reason: string;
  request_count: number;
  ontime_count: number;
  late_count: number;
  avg_satisfaction: number | null;
};

type InventoryRow = {
  asset_tag: string;
  equipment_kind: string;
  status: string;
  total_deployments: number;
  total_revenue_rupees: number;
  last_serviced_at: string | null;
};

type OutcomeRow = {
  outcome: string;
  count: number;
  pct: number | null;
  revenue_rupees: number;
};

type CustomerRow = {
  customer_org: string;
  request_count: number;
  avg_satisfaction: number | null;
  total_billed: number;
};

type PromiseRow = {
  request_code: string;
  customer_org: string;
  promised_delivery_at: string;
  actual_delivered_at: string | null;
  delay_minutes: number | null;
  outcome: string;
};

function fmtRupees(n: number | null | undefined) {
  if (n == null) return '-';
  return '₹' + n.toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s;
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpis, requests, byKind, byReason, inventory, outcomes, customers, promises] = await Promise.all([
    supabase.rpc('founder_loaner_kpis_r2720'),
    supabase.rpc('founder_loaner_requests_list_r2720'),
    supabase.rpc('founder_loaner_by_kind_r2720'),
    supabase.rpc('founder_loaner_by_reason_r2720'),
    supabase.rpc('founder_loaner_inventory_status_r2720'),
    supabase.rpc('founder_loaner_outcome_breakdown_r2720'),
    supabase.rpc('founder_loaner_satisfaction_by_customer_r2720'),
    supabase.rpc('founder_loaner_delivery_promise_r2720'),
  ]);

  const k: Kpis | null = (kpis.data && kpis.data[0]) || null;
  const requestRows: RequestRow[] = requests.data || [];
  const kindRows: KindRow[] = byKind.data || [];
  const reasonRows: ReasonRow[] = byReason.data || [];
  const inventoryRows: InventoryRow[] = inventory.data || [];
  const outcomeRows: OutcomeRow[] = outcomes.data || [];
  const customerRows: CustomerRow[] = customers.data || [];
  const promiseRows: PromiseRow[] = promises.data || [];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Customer Monthly Replacement &amp; Loaner Fulfillment</h1>
        <p className="text-sm text-gray-600">
          Round r2720 — request × kind × promised × delivered × duration × satisfaction × outcome.
          Tracks loaner dispatches when customer equipment sits in long repair or warranty swap. SLA target: delivered_ontime rate &gt;= 85%.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Requests" value={String(k?.total_requests ?? 0)} />
        <KpiCard label="Active Deployments" value={String(k?.active_deployments ?? 0)} />
        <KpiCard label="On-time Rate" value={(k?.on_time_rate ?? 0) + '%'} />
        <KpiCard label="Avg Satisfaction" value={String(k?.avg_satisfaction ?? '-') + ' / 10'} />
        <KpiCard label="Avg Duration" value={String(k?.avg_duration_days ?? '-') + ' days'} />
        <KpiCard label="Total Billed" value={fmtRupees(k?.total_billed_rupees ?? 0)} />
        <KpiCard label="Cancelled" value={String(k?.cancelled_count ?? 0)} />
        <KpiCard label="Escalated" value={String(k?.escalated_count ?? 0)} />
      </section>

      <Section title="All Loaner Requests" subtitle="Promised vs delivered vs returned timeline.">
        <DataTable
          rows={requestRows}
          rowKey={(r, i) => String(r.request_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'request_code', header: 'Code', render: (r: RequestRow) => <span className="font-mono text-xs">{r.request_code}</span> },
            { key: 'customer_org', header: 'Customer', render: (r: RequestRow) => <span>{r.customer_org}</span> },
            { key: 'equipment_kind', header: 'Kind', render: (r: RequestRow) => <span>{r.equipment_kind}</span> },
            { key: 'request_reason', header: 'Reason', render: (r: RequestRow) => <span>{r.request_reason}</span> },
            { key: 'promised_delivery_at', header: 'Promised', render: (r: RequestRow) => <span>{fmtDate(r.promised_delivery_at)}</span> },
            { key: 'actual_delivered_at', header: 'Delivered', render: (r: RequestRow) => <span>{fmtDate(r.actual_delivered_at)}</span> },
            { key: 'duration_days', header: 'Days', render: (r: RequestRow) => <span>{r.duration_days ?? '-'}</span> },
            { key: 'satisfaction_score', header: 'CSAT', render: (r: RequestRow) => <span>{r.satisfaction_score ?? '-'}</span> },
            { key: 'outcome', header: 'Outcome', render: (r: RequestRow) => <OutcomeBadge outcome={r.outcome} /> },
            { key: 'total_billed_rupees', header: 'Billed', render: (r: RequestRow) => <span>{fmtRupees(r.total_billed_rupees)}</span> },
          ]}
        />
      </Section>

      <Section title="Delivery Promise Audit" subtitle="Minutes early (negative) or late (positive) vs promise.">
        <DataTable
          rows={promiseRows}
          rowKey={(r, i) => String(r.request_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'request_code', header: 'Code', render: (r: PromiseRow) => <span className="font-mono text-xs">{r.request_code}</span> },
            { key: 'customer_org', header: 'Customer', render: (r: PromiseRow) => <span>{r.customer_org}</span> },
            { key: 'promised_delivery_at', header: 'Promised', render: (r: PromiseRow) => <span>{fmtDate(r.promised_delivery_at)}</span> },
            { key: 'actual_delivered_at', header: 'Delivered', render: (r: PromiseRow) => <span>{fmtDate(r.actual_delivered_at)}</span> },
            { key: 'delay_minutes', header: 'Delay (min)', render: (r: PromiseRow) => <span className={r.delay_minutes != null && r.delay_minutes > 30 ? 'text-red-600' : 'text-emerald-600'}>{r.delay_minutes ?? '-'}</span> },
            { key: 'outcome', header: 'Outcome', render: (r: PromiseRow) => <OutcomeBadge outcome={r.outcome} /> },
          ]}
        />
      </Section>

      <div className="grid md:grid-cols-2 gap-6">
        <Section title="By Equipment Kind" subtitle="Demand mix & revenue per category.">
          <DataTable
            rows={kindRows}
            rowKey={(r, i) => String(r.equipment_kind ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'equipment_kind', header: 'Kind', render: (r: KindRow) => <span>{r.equipment_kind}</span> },
              { key: 'request_count', header: 'Requests', render: (r: KindRow) => <span>{r.request_count}</span> },
              { key: 'avg_duration', header: 'Avg days', render: (r: KindRow) => <span>{r.avg_duration ?? '-'}</span> },
              { key: 'avg_satisfaction', header: 'CSAT', render: (r: KindRow) => <span>{r.avg_satisfaction ?? '-'}</span> },
              { key: 'total_revenue', header: 'Revenue', render: (r: KindRow) => <span>{fmtRupees(r.total_revenue)}</span> },
            ]}
          />
        </Section>

        <Section title="By Request Reason" subtitle="Why customers needed loaners.">
          <DataTable
            rows={reasonRows}
            rowKey={(r, i) => String(r.request_reason ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'request_reason', header: 'Reason', render: (r: ReasonRow) => <span>{r.request_reason}</span> },
              { key: 'request_count', header: 'Count', render: (r: ReasonRow) => <span>{r.request_count}</span> },
              { key: 'ontime_count', header: 'On-time', render: (r: ReasonRow) => <span className="text-emerald-600">{r.ontime_count}</span> },
              { key: 'late_count', header: 'Late', render: (r: ReasonRow) => <span className="text-red-600">{r.late_count}</span> },
              { key: 'avg_satisfaction', header: 'CSAT', render: (r: ReasonRow) => <span>{r.avg_satisfaction ?? '-'}</span> },
            ]}
          />
        </Section>
      </div>

      <Section title="Loaner Inventory Status" subtitle="Asset utilization & lifetime revenue.">
        <DataTable
          rows={inventoryRows}
          rowKey={(r, i) => String(r.asset_tag ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'asset_tag', header: 'Asset', render: (r: InventoryRow) => <span className="font-mono text-xs">{r.asset_tag}</span> },
            { key: 'equipment_kind', header: 'Kind', render: (r: InventoryRow) => <span>{r.equipment_kind}</span> },
            { key: 'status', header: 'Status', render: (r: InventoryRow) => <StatusBadge status={r.status} /> },
            { key: 'total_deployments', header: 'Deployments', render: (r: InventoryRow) => <span>{r.total_deployments}</span> },
            { key: 'total_revenue_rupees', header: 'Revenue', render: (r: InventoryRow) => <span>{fmtRupees(r.total_revenue_rupees)}</span> },
            { key: 'last_serviced_at', header: 'Last serviced', render: (r: InventoryRow) => <span>{fmtDate(r.last_serviced_at)}</span> },
          ]}
        />
      </Section>

      <div className="grid md:grid-cols-2 gap-6">
        <Section title="Outcome Breakdown" subtitle="Where requests land.">
          <DataTable
            rows={outcomeRows}
            rowKey={(r, i) => String(r.outcome ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => <OutcomeBadge outcome={r.outcome} /> },
              { key: 'count', header: 'Count', render: (r: OutcomeRow) => <span>{r.count}</span> },
              { key: 'pct', header: 'Share', render: (r: OutcomeRow) => <span>{(r.pct ?? 0) + '%'}</span> },
              { key: 'revenue_rupees', header: 'Revenue', render: (r: OutcomeRow) => <span>{fmtRupees(r.revenue_rupees)}</span> },
            ]}
          />
        </Section>

        <Section title="Customer Satisfaction" subtitle="Top customers by CSAT.">
          <DataTable
            rows={customerRows}
            rowKey={(r, i) => String(r.customer_org ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'customer_org', header: 'Customer', render: (r: CustomerRow) => <span>{r.customer_org}</span> },
              { key: 'request_count', header: 'Requests', render: (r: CustomerRow) => <span>{r.request_count}</span> },
              { key: 'avg_satisfaction', header: 'CSAT', render: (r: CustomerRow) => <span>{r.avg_satisfaction ?? '-'}</span> },
              { key: 'total_billed', header: 'Billed', render: (r: CustomerRow) => <span>{fmtRupees(r.total_billed)}</span> },
            ]}
          />
        </Section>
      </div>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value}</div>
    </div>
  );
}

function Section({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <div>
        <h2 className="text-lg font-semibold">{title}</h2>
        {subtitle ? <p className="text-sm text-gray-600">{subtitle}</p> : null}
      </div>
      <div className="overflow-x-auto rounded-lg border bg-white">{children}</div>
    </section>
  );
}

function OutcomeBadge({ outcome }: { outcome: string }) {
  const map: Record<string, string> = {
    delivered_ontime: 'bg-emerald-100 text-emerald-800',
    delivered_late: 'bg-amber-100 text-amber-800',
    pending: 'bg-blue-100 text-blue-800',
    cancelled: 'bg-gray-200 text-gray-700',
    converted_to_sale: 'bg-purple-100 text-purple-800',
    escalated: 'bg-red-100 text-red-800',
  };
  const cls = map[outcome] || 'bg-gray-100 text-gray-700';
  return <span className={'inline-block rounded px-2 py-0.5 text-xs font-medium ' + cls}>{outcome}</span>;
}

function StatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    available: 'bg-emerald-100 text-emerald-800',
    deployed: 'bg-blue-100 text-blue-800',
    maintenance: 'bg-amber-100 text-amber-800',
    retired: 'bg-gray-200 text-gray-700',
    in_transit: 'bg-purple-100 text-purple-800',
  };
  const cls = map[status] || 'bg-gray-100 text-gray-700';
  return <span className={'inline-block rounded px-2 py-0.5 text-xs font-medium ' + cls}>{status}</span>;
}
