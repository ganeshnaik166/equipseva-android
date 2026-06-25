import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CallbackRow = {
  id: string;
  month_key: string;
  customer_name: string;
  customer_tier: string;
  engineer_name: string;
  engineer_tier: string;
  total_visits: number;
  callbacks: number;
  callback_rate: number;
  recurring_pattern: string;
  primary_cause: string;
  severity: string;
  margin_drag_rupees: number;
  eliminate_action: string;
  status: string;
  detected_on: string;
};

type KpiRow = {
  total_rows: number;
  avg_callback_rate: number;
  total_margin_drag_rupees: number;
  open_rows: number;
  eliminated_rows: number;
  recurrence_rows: number;
};

type PatternRow = {
  recurring_pattern: string;
  n: number;
  avg_rate: number;
  margin_drag: number;
};

type CauseRow = {
  primary_cause: string;
  n: number;
  avg_rate: number;
  margin_drag: number;
};

type EngineerRow = {
  engineer_name: string;
  engineer_tier: string;
  jobs: number;
  callbacks_sum: number;
  avg_rate: number;
  margin_drag: number;
};

type ActionRow = {
  id: string;
  ref_month: string;
  customer_name: string;
  engineer_name: string;
  action_type: string;
  action_summary: string;
  cost_rupees: number;
  expected_savings_rupees: number;
  roi_ratio: number;
  outcome: string;
  callback_before: number;
  callback_after: number;
  delta_pct: number;
  started_on: string;
  closed_on: string | null;
};

type RoiRow = {
  total_actions: number;
  total_cost_rupees: number;
  total_expected_savings_rupees: number;
  blended_roi: number;
  succeeded: number;
  in_progress: number;
  pending: number;
};

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [topRes, kpiRes, patternRes, causeRes, engRes, actionsRes, roiRes] = await Promise.all([
    supabase.rpc('rpc_r2732_top_recurring_callback'),
    supabase.rpc('rpc_r2732_kpi_summary'),
    supabase.rpc('rpc_r2732_by_pattern'),
    supabase.rpc('rpc_r2732_by_cause'),
    supabase.rpc('rpc_r2732_engineer_rank'),
    supabase.rpc('rpc_r2732_actions_list'),
    supabase.rpc('rpc_r2732_action_roi_summary'),
  ]);

  const top = (topRes.data ?? []) as CallbackRow[];
  const kpi = ((kpiRes.data ?? [])[0] ?? {
    total_rows: 0, avg_callback_rate: 0, total_margin_drag_rupees: 0,
    open_rows: 0, eliminated_rows: 0, recurrence_rows: 0,
  }) as KpiRow;
  const patterns = (patternRes.data ?? []) as PatternRow[];
  const causes = (causeRes.data ?? []) as CauseRow[];
  const engineers = (engRes.data ?? []) as EngineerRow[];
  const actions = (actionsRes.data ?? []) as ActionRow[];
  const roi = ((roiRes.data ?? [])[0] ?? {
    total_actions: 0, total_cost_rupees: 0, total_expected_savings_rupees: 0,
    blended_roi: 0, succeeded: 0, in_progress: 0, pending: 0,
  }) as RoiRow;

  return (
    <main className="mx-auto max-w-7xl px-6 py-10 space-y-8">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight">
          Customer x Engineer Recurring Callback (r2732)
        </h1>
        <p className="text-sm text-neutral-600">
          Monthly recurring-callback rate by customer and engineer with pattern, cause and elimination action. Targets repeated visits within the month that drag margin and signal training, part or process failure.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <KpiCard label="Rows tracked" value={String(kpi.total_rows ?? 0)} />
        <KpiCard label="Avg callback rate" value={(Number(kpi.avg_callback_rate ?? 0)).toFixed(2) + '%'} />
        <KpiCard label="Margin drag" value={rupees(kpi.total_margin_drag_rupees)} />
        <KpiCard label="Open" value={String(kpi.open_rows ?? 0)} />
        <KpiCard label="Eliminated" value={String(kpi.eliminated_rows ?? 0)} />
        <KpiCard label="Recurrences" value={String(kpi.recurrence_rows ?? 0)} />
      </section>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <KpiCard label="Actions in ledger" value={String(roi.total_actions ?? 0)} />
        <KpiCard label="Action spend" value={rupees(roi.total_cost_rupees)} />
        <KpiCard label="Expected savings" value={rupees(roi.total_expected_savings_rupees)} />
        <KpiCard label="Blended ROI" value={String(roi.blended_roi ?? 0) + 'x'} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Top recurring-callback rows</h2>
        <DataTable
          rows={top}
          columns={[
            { key: 'month_key', header: 'Month', render: (r: CallbackRow) => r.month_key },
            { key: 'customer_name', header: 'Customer', render: (r: CallbackRow) => r.customer_name + ' (' + r.customer_tier + ')' },
            { key: 'engineer_name', header: 'Engineer', render: (r: CallbackRow) => r.engineer_name + ' (' + r.engineer_tier + ')' },
            { key: 'total_visits', header: 'Visits', render: (r: CallbackRow) => String(r.total_visits) },
            { key: 'callbacks', header: 'Callbacks', render: (r: CallbackRow) => String(r.callbacks) },
            { key: 'callback_rate', header: 'Rate', render: (r: CallbackRow) => (Number(r.callback_rate)).toFixed(2) + '%' },
            { key: 'recurring_pattern', header: 'Pattern', render: (r: CallbackRow) => r.recurring_pattern },
            { key: 'primary_cause', header: 'Cause', render: (r: CallbackRow) => r.primary_cause },
            { key: 'severity', header: 'Sev', render: (r: CallbackRow) => r.severity },
            { key: 'margin_drag_rupees', header: 'Margin drag', render: (r: CallbackRow) => rupees(r.margin_drag_rupees) },
            { key: 'eliminate_action', header: 'Eliminate action', render: (r: CallbackRow) => r.eliminate_action },
            { key: 'status', header: 'Status', render: (r: CallbackRow) => r.status },
            { key: 'detected_on', header: 'Detected', render: (r: CallbackRow) => r.detected_on },
          ]}
          emptyMessage="No data"
          rowKey={(r: CallbackRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-3">
          <h2 className="text-xl font-semibold">By recurring pattern</h2>
          <DataTable
            rows={patterns}
            columns={[
              { key: 'recurring_pattern', header: 'Pattern', render: (r: PatternRow) => r.recurring_pattern },
              { key: 'n', header: 'Rows', render: (r: PatternRow) => String(r.n) },
              { key: 'avg_rate', header: 'Avg rate', render: (r: PatternRow) => (Number(r.avg_rate)).toFixed(2) + '%' },
              { key: 'margin_drag', header: 'Margin drag', render: (r: PatternRow) => rupees(r.margin_drag) },
            ]}
            emptyMessage="No data"
            rowKey={(r: PatternRow, i: number) => String(r.recurring_pattern ?? i)}
          />
        </div>
        <div className="space-y-3">
          <h2 className="text-xl font-semibold">By primary cause</h2>
          <DataTable
            rows={causes}
            columns={[
              { key: 'primary_cause', header: 'Cause', render: (r: CauseRow) => r.primary_cause },
              { key: 'n', header: 'Rows', render: (r: CauseRow) => String(r.n) },
              { key: 'avg_rate', header: 'Avg rate', render: (r: CauseRow) => (Number(r.avg_rate)).toFixed(2) + '%' },
              { key: 'margin_drag', header: 'Margin drag', render: (r: CauseRow) => rupees(r.margin_drag) },
            ]}
            emptyMessage="No data"
            rowKey={(r: CauseRow, i: number) => String(r.primary_cause ?? i)}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Engineer rank by margin drag</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: EngineerRow) => r.engineer_tier },
            { key: 'jobs', header: 'Jobs', render: (r: EngineerRow) => String(r.jobs) },
            { key: 'callbacks_sum', header: 'Callbacks', render: (r: EngineerRow) => String(r.callbacks_sum) },
            { key: 'avg_rate', header: 'Avg rate', render: (r: EngineerRow) => (Number(r.avg_rate)).toFixed(2) + '%' },
            { key: 'margin_drag', header: 'Margin drag', render: (r: EngineerRow) => rupees(r.margin_drag) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Elimination action ledger</h2>
        <p className="text-sm text-neutral-600">
          Interventions logged against each recurrence. Negative delta means callback rate dropped after the action.
        </p>
        <DataTable
          rows={actions}
          columns={[
            { key: 'ref_month', header: 'Month', render: (r: ActionRow) => r.ref_month },
            { key: 'customer_name', header: 'Customer', render: (r: ActionRow) => r.customer_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: ActionRow) => r.engineer_name },
            { key: 'action_type', header: 'Type', render: (r: ActionRow) => r.action_type },
            { key: 'action_summary', header: 'Action', render: (r: ActionRow) => r.action_summary },
            { key: 'cost_rupees', header: 'Cost', render: (r: ActionRow) => rupees(r.cost_rupees) },
            { key: 'expected_savings_rupees', header: 'Savings', render: (r: ActionRow) => rupees(r.expected_savings_rupees) },
            { key: 'roi_ratio', header: 'ROI', render: (r: ActionRow) => String(r.roi_ratio) + 'x' },
            { key: 'callback_before', header: 'Before', render: (r: ActionRow) => String(r.callback_before) },
            { key: 'callback_after', header: 'After', render: (r: ActionRow) => String(r.callback_after) },
            { key: 'delta_pct', header: 'Delta', render: (r: ActionRow) => (Number(r.delta_pct)).toFixed(2) + '%' },
            { key: 'outcome', header: 'Outcome', render: (r: ActionRow) => r.outcome },
            { key: 'started_on', header: 'Started', render: (r: ActionRow) => r.started_on },
            { key: 'closed_on', header: 'Closed', render: (r: ActionRow) => r.closed_on ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-neutral-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
    </div>
  );
}
