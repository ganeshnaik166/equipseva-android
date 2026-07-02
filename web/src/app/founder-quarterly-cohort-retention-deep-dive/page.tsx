import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CohortRow = {
  id: string;
  cohort_label: string;
  period_month: number;
  retained_count: number;
  churned_count: number;
  retention_pct: number;
  churn_cause_kind: string;
  recovery_cost_rupees: number;
  ltv_impact_rupees: number;
  owner_email: string | null;
  status: string;
};

type ActionRow = {
  id: string;
  cohort_id: string;
  cohort_label: string;
  action_at: string;
  action_kind: string;
  outcome: string;
  recovered_arr_rupees: number;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type LtvRow = {
  cohort_label: string;
  period_month: number;
  ltv_impact_rupees: number;
  churn_cause_kind: string;
  retention_pct: number;
};

type ChurnCauseRow = {
  churn_cause_kind: string;
  cohort_count: number;
  total_churned: number;
  total_ltv_impact: number;
};

type RecoveryCostRow = {
  cohort_label: string;
  total_recovery_cost: number;
  total_recovered_arr: number;
  net_recovery: number;
  action_count: number;
};

type TrendRow = {
  cohort_label: string;
  period_month: number;
  retention_pct: number;
  retained_count: number;
  churned_count: number;
};

type RecoveredArrRow = {
  action_kind: string;
  action_count: number;
  total_recovered_arr: number;
  positive_outcomes: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [cohortsRes, actionsRes, ltvRes, churnRes, recCostRes, trendRes, recArrRes] = await Promise.all([
    sb.rpc('list_cohort_retention_r2593'),
    sb.rpc('list_recovery_actions_r2593'),
    sb.rpc('top_ltv_impact_cohorts_r2593'),
    sb.rpc('churn_cause_distribution_r2593'),
    sb.rpc('recovery_cost_summary_r2593'),
    sb.rpc('quarterly_retention_trend_r2593'),
    sb.rpc('recovered_arr_summary_r2593'),
  ]);

  const cohorts: CohortRow[] = (cohortsRes.data as CohortRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];
  const ltv: LtvRow[] = (ltvRes.data as LtvRow[] | null) ?? [];
  const churn: ChurnCauseRow[] = (churnRes.data as ChurnCauseRow[] | null) ?? [];
  const recCost: RecoveryCostRow[] = (recCostRes.data as RecoveryCostRow[] | null) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];
  const recArr: RecoveredArrRow[] = (recArrRes.data as RecoveredArrRow[] | null) ?? [];

  const cohortCols: Column<any>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r: any) => r.cohort_label },
    { key: 'period_month', header: 'Month', render: (r: any) => r.period_month },
    { key: 'retained_count', header: 'Retained', render: (r: any) => r.retained_count },
    { key: 'churned_count', header: 'Churned', render: (r: any) => r.churned_count },
    { key: 'retention_pct', header: 'Retention %', render: (r: any) => r.retention_pct },
    { key: 'churn_cause_kind', header: 'Cause', render: (r: any) => r.churn_cause_kind },
    { key: 'recovery_cost_rupees', header: 'Rec cost', render: (r: any) => r.recovery_cost_rupees },
    { key: 'ltv_impact_rupees', header: 'LTV impact', render: (r: any) => r.ltv_impact_rupees },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const actionCols: Column<any>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r: any) => r.cohort_label ?? '—' },
    { key: 'action_at', header: 'When', render: (r: any) => r.action_at ?? '—' },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'recovered_arr_rupees', header: 'Recovered ARR', render: (r: any) => r.recovered_arr_rupees },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const ltvCols: Column<any>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r: any) => r.cohort_label },
    { key: 'period_month', header: 'Month', render: (r: any) => r.period_month },
    { key: 'ltv_impact_rupees', header: 'LTV impact', render: (r: any) => r.ltv_impact_rupees },
    { key: 'churn_cause_kind', header: 'Cause', render: (r: any) => r.churn_cause_kind },
    { key: 'retention_pct', header: 'Retention %', render: (r: any) => r.retention_pct },
  ];

  const churnCols: Column<any>[] = [
    { key: 'churn_cause_kind', header: 'Cause', render: (r: any) => r.churn_cause_kind },
    { key: 'cohort_count', header: 'Cohorts', render: (r: any) => r.cohort_count },
    { key: 'total_churned', header: 'Total churned', render: (r: any) => r.total_churned },
    { key: 'total_ltv_impact', header: 'Total LTV impact', render: (r: any) => r.total_ltv_impact },
  ];

  const recCostCols: Column<any>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r: any) => r.cohort_label },
    { key: 'total_recovery_cost', header: 'Rec cost', render: (r: any) => r.total_recovery_cost },
    { key: 'total_recovered_arr', header: 'Recovered ARR', render: (r: any) => r.total_recovered_arr },
    { key: 'net_recovery', header: 'Net', render: (r: any) => r.net_recovery },
    { key: 'action_count', header: 'Actions', render: (r: any) => r.action_count },
  ];

  const trendCols: Column<any>[] = [
    { key: 'cohort_label', header: 'Cohort', render: (r: any) => r.cohort_label },
    { key: 'period_month', header: 'Month', render: (r: any) => r.period_month },
    { key: 'retention_pct', header: 'Retention %', render: (r: any) => r.retention_pct },
    { key: 'retained_count', header: 'Retained', render: (r: any) => r.retained_count },
    { key: 'churned_count', header: 'Churned', render: (r: any) => r.churned_count },
  ];

  const recArrCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'action_count', header: 'Count', render: (r: any) => r.action_count },
    { key: 'total_recovered_arr', header: 'Recovered ARR', render: (r: any) => r.total_recovered_arr },
    { key: 'positive_outcomes', header: 'Positive', render: (r: any) => r.positive_outcomes },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Quarterly Cohort Retention Deep Dive</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Cohort × period month retention with churn cause, recovery cost & LTV impact. Plus per-cohort recovery actions and ARR recovered.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All cohort rows ({cohorts.length})</h2>
        <DataTable
          rows={cohorts}
          columns={cohortCols}
          emptyMessage="No cohort rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top LTV impact cohorts ({ltv.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Cohorts with worst LTV impact (most negative => biggest loss).
        </p>
        <DataTable
          rows={ltv}
          columns={ltvCols}
          emptyMessage="No LTV impact data."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Churn cause distribution ({churn.length})</h2>
        <DataTable
          rows={churn}
          columns={churnCols}
          emptyMessage="No churn cause data."
          rowKey={(r: any, i: number) => String(r.churn_cause_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recovery cost summary ({recCost.length})</h2>
        <DataTable
          rows={recCost}
          columns={recCostCols}
          emptyMessage="No recovery cost data."
          rowKey={(r: any, i: number) => String(r.cohort_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Quarterly retention trend ({trend.length})</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recovered ARR by action ({recArr.length})</h2>
        <DataTable
          rows={recArr}
          columns={recArrCols}
          emptyMessage="No recovered ARR data."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recovery actions ({actions.length})</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No recovery actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
