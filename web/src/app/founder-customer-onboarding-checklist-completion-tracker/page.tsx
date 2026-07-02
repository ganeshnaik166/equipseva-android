import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChecklistRow = {
  id: string;
  customer_id: string;
  customer_email: string;
  started_at: string;
  deadline_at: string;
  completed_at: string | null;
  total_items: number;
  completed_items: number;
  completion_pct: number;
  status: string;
  days_remaining: number;
};

type IncompleteRow = {
  id: string;
  checklist_id: string;
  customer_email: string;
  item_key: string;
  item_label: string;
  item_order: number;
  required: boolean;
  hours_since_started: number;
  deadline_at: string;
};

type AvgTimeRow = {
  item_key: string;
  item_label: string;
  completion_count: number;
  avg_hours: number;
  median_hours: number;
  max_hours: number;
};

type FunnelRow = {
  item_key: string;
  item_label: string;
  total: number;
  completed: number;
  incomplete: number;
  completion_pct: number;
};

type AtRiskRow = {
  id: string;
  customer_email: string;
  started_at: string;
  deadline_at: string;
  total_items: number;
  completed_items: number;
  completion_pct: number;
  days_remaining: number;
};

type CohortRow = {
  status: string;
  customer_count: number;
  avg_completion_pct: number;
  avg_days_to_complete: number | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [checklistsRes, incompleteRes, avgTimeRes, funnelRes, atRiskRes, cohortRes] = await Promise.all([
    sb.rpc('list_checklists_r2396'),
    sb.rpc('incomplete_items_r2396'),
    sb.rpc('avg_time_per_item_r2396'),
    sb.rpc('item_completion_funnel_r2396'),
    sb.rpc('at_risk_checklists_r2396'),
    sb.rpc('cohort_overview_r2396'),
  ]);

  const checklists: ChecklistRow[] = (checklistsRes.data as ChecklistRow[] | null) ?? [];
  const incomplete: IncompleteRow[] = (incompleteRes.data as IncompleteRow[] | null) ?? [];
  const avgTime: AvgTimeRow[] = (avgTimeRes.data as AvgTimeRow[] | null) ?? [];
  const funnel: FunnelRow[] = (funnelRes.data as FunnelRow[] | null) ?? [];
  const atRisk: AtRiskRow[] = (atRiskRes.data as AtRiskRow[] | null) ?? [];
  const cohort: CohortRow[] = (cohortRes.data as CohortRow[] | null) ?? [];

  const checklistCols: Column<ChecklistRow>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: any) => r.customer_email },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleDateString() : '—' },
    { key: 'deadline_at', header: 'Deadline', render: (r: any) => r.deadline_at ? new Date(r.deadline_at).toLocaleDateString() : '—' },
    { key: 'total_items', header: 'Total', render: (r: any) => r.total_items },
    { key: 'completed_items', header: 'Done', render: (r: any) => r.completed_items },
    { key: 'completion_pct', header: '%', render: (r: any) => `${r.completion_pct}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'days_remaining', header: 'Days left', render: (r: any) => r.days_remaining },
  ];

  const incompleteCols: Column<IncompleteRow>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: any) => r.customer_email },
    { key: 'item_label', header: 'Item', render: (r: any) => r.item_label },
    { key: 'item_order', header: 'Order', render: (r: any) => r.item_order },
    { key: 'required', header: 'Required', render: (r: any) => r.required ? 'yes' : 'no' },
    { key: 'hours_since_started', header: 'Hours since start', render: (r: any) => r.hours_since_started },
    { key: 'deadline_at', header: 'Deadline', render: (r: any) => r.deadline_at ? new Date(r.deadline_at).toLocaleDateString() : '—' },
  ];

  const avgTimeCols: Column<AvgTimeRow>[] = [
    { key: 'item_label', header: 'Item', render: (r: any) => r.item_label },
    { key: 'completion_count', header: 'Completions', render: (r: any) => r.completion_count },
    { key: 'avg_hours', header: 'Avg hrs', render: (r: any) => r.avg_hours ?? '—' },
    { key: 'median_hours', header: 'Median hrs', render: (r: any) => r.median_hours ?? '—' },
    { key: 'max_hours', header: 'Max hrs', render: (r: any) => r.max_hours ?? '—' },
  ];

  const funnelCols: Column<FunnelRow>[] = [
    { key: 'item_label', header: 'Item', render: (r: any) => r.item_label },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'completed', header: 'Completed', render: (r: any) => r.completed },
    { key: 'incomplete', header: 'Incomplete', render: (r: any) => r.incomplete },
    { key: 'completion_pct', header: '%', render: (r: any) => `${r.completion_pct}%` },
  ];

  const atRiskCols: Column<AtRiskRow>[] = [
    { key: 'customer_email', header: 'Customer', render: (r: any) => r.customer_email },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleDateString() : '—' },
    { key: 'deadline_at', header: 'Deadline', render: (r: any) => r.deadline_at ? new Date(r.deadline_at).toLocaleDateString() : '—' },
    { key: 'completion_pct', header: '%', render: (r: any) => `${r.completion_pct}%` },
    { key: 'days_remaining', header: 'Days left', render: (r: any) => r.days_remaining },
  ];

  const cohortCols: Column<CohortRow>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'customer_count', header: 'Customers', render: (r: any) => r.customer_count },
    { key: 'avg_completion_pct', header: 'Avg %', render: (r: any) => `${r.avg_completion_pct}%` },
    { key: 'avg_days_to_complete', header: 'Avg days to complete', render: (r: any) => r.avg_days_to_complete ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Customer Onboarding Checklist Completion</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        14-day onboarding checklist tracker. Per-item completion, time-to-complete, incomplete items, and at-risk cohorts.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Cohort overview ({cohort.length})</h2>
        <DataTable
          rows={cohort}
          columns={cohortCols}
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All checklists ({checklists.length})</h2>
        <DataTable
          rows={checklists}
          columns={checklistCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>At-risk checklists ({atRisk.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Deadline within 3 days &amp; completion &lt; 70%.
        </p>
        <DataTable
          rows={atRisk}
          columns={atRiskCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Incomplete items ({incomplete.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Items not yet completed across all in-progress checklists.
        </p>
        <DataTable
          rows={incomplete}
          columns={incompleteCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Item completion funnel ({funnel.length})</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          rowKey={(r: any, i: number) => String(r.item_key ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Average time-to-complete per item ({avgTime.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Across completed items only. Slowest items at top.
        </p>
        <DataTable
          rows={avgTime}
          columns={avgTimeCols}
          rowKey={(r: any, i: number) => String(r.item_key ?? i)}
        />
      </section>
    </div>
  );
}
