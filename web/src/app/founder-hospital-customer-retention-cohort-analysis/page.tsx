import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Cohort = {
  id: string;
  cohort_label: string;
  cohort_start_month: string;
  customers_started: number;
  customers_remaining_30d: number;
  customers_remaining_90d: number;
  customers_remaining_365d: number;
  status: string;
  captured_at: string;
};

type Declining = {
  id: string;
  cohort_label: string;
  cohort_start_month: string;
  customers_started: number;
  customers_remaining_30d: number;
  customers_remaining_90d: number;
  customers_remaining_365d: number;
  retention_365_pct: number;
  status: string;
};

type Action = {
  id: string;
  cohort_id: string;
  cohort_label: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [cohortsRes, decliningRes, actionsRes] = await Promise.all([
    sb.rpc('list_cohorts_r2175'),
    sb.rpc('declining_cohorts_r2175'),
    sb.rpc('recent_actions_r2175'),
  ]);

  const cohorts: Cohort[] = (cohortsRes.data as Cohort[] | null) ?? [];
  const declining: Declining[] = (decliningRes.data as Declining[] | null) ?? [];
  const actions: Action[] = (actionsRes.data as Action[] | null) ?? [];

  const cohortCols: Column<Cohort>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r: any) => String(r.cohort_label ?? '') },
    { key: 'cohort_start_month', header: 'Start Month', render: (r: any) => String(r.cohort_start_month ?? '') },
    { key: 'customers_started', header: 'Started', render: (r: any) => String(r.customers_started ?? 0) },
    { key: 'customers_remaining_30d', header: 'Day 30', render: (r: any) => String(r.customers_remaining_30d ?? 0) },
    { key: 'customers_remaining_90d', header: 'Day 90', render: (r: any) => String(r.customers_remaining_90d ?? 0) },
    { key: 'customers_remaining_365d', header: 'Day 365', render: (r: any) => String(r.customers_remaining_365d ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleDateString() : '' },
  ];

  const decliningCols: Column<Declining>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r: any) => String(r.cohort_label ?? '') },
    { key: 'cohort_start_month', header: 'Start Month', render: (r: any) => String(r.cohort_start_month ?? '') },
    { key: 'customers_started', header: 'Started', render: (r: any) => String(r.customers_started ?? 0) },
    { key: 'customers_remaining_365d', header: 'Day 365', render: (r: any) => String(r.customers_remaining_365d ?? 0) },
    { key: 'retention_365_pct', header: 'Retention %', render: (r: any) => `${r.retention_365_pct ?? 0}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<Action>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r: any) => String(r.cohort_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Customer Retention Cohort Analysis</h1>
        <p className="text-sm text-gray-600">
          Track cohort retention curves at 30, 90, and 365 days. Flag cohorts where retention drops below 50 percent.
        </p>
      </header>

      <section>
        <h2 className="text-xl font-semibold mb-2">All Cohorts</h2>
        <DataTable
          rows={cohorts}
          columns={cohortCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Declining Cohorts (365-day retention under 50 percent)</h2>
        <DataTable
          rows={declining}
          columns={decliningCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Recent Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
