import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type RetentionRow = {
  id?: string;
  cohort_label: string;
  months_since_join: number;
  cohort_size_engineers: number;
  active_engineers: number;
  retention_pct: number;
  promotion_pct: number;
  loop_health: string;
  audit_status: string;
};

type HealthRow = {
  id?: string;
  loop_health: string;
  cohort_count: number;
  total_engineers: number;
  active_engineers: number;
  avg_retention_pct: number;
  avg_promotion_pct: number;
};

type BenchmarkRow = {
  id?: string;
  cohort_label: string;
  months_since_join: number;
  retention_pct: number;
  promotion_pct: number;
  benchmark_status: string;
};

type PendingRow = {
  id?: string;
  cohort_label: string;
  decision_label: string;
  decision_type: string;
  target_tier: string;
  budget_rupees: number;
  priority: string;
  owner_role: string;
  due_date: string | null;
};

type BudgetRow = {
  id?: string;
  decision_type: string;
  decision_count: number;
  executed_count: number;
  total_budget_rupees: number;
  avg_expected_lift_pct: number;
};

type EscalatedRow = {
  id?: string;
  cohort_label: string;
  cohort_start_date: string;
  months_since_join: number;
  loop_health: string;
  audit_status: string;
  founder_notes: string | null;
  open_decisions: number;
};

type WorkloadRow = {
  id?: string;
  owner_role: string;
  open_decisions: number;
  executed_decisions: number;
  total_budget_open_rupees: number;
  avg_expected_lift_pct: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    retention,
    health,
    benchmark,
    pending,
    budget,
    escalated,
    workload,
  ] = await Promise.all([
    supabase.rpc('founder_cohort_retention_rollup_r3013'),
    supabase.rpc('founder_cohort_loop_health_breakdown_r3013'),
    supabase.rpc('founder_cohort_18month_benchmark_r3013'),
    supabase.rpc('founder_cohort_pending_decisions_r3013'),
    supabase.rpc('founder_cohort_decision_budget_summary_r3013'),
    supabase.rpc('founder_cohort_escalated_loops_r3013'),
    supabase.rpc('founder_cohort_owner_workload_r3013'),
  ]);

  const retentionRows: RetentionRow[] = (retention.data as RetentionRow[]) ?? [];
  const healthRows: HealthRow[] = (health.data as HealthRow[]) ?? [];
  const benchmarkRows: BenchmarkRow[] = (benchmark.data as BenchmarkRow[]) ?? [];
  const pendingRows: PendingRow[] = (pending.data as PendingRow[]) ?? [];
  const budgetRows: BudgetRow[] = (budget.data as BudgetRow[]) ?? [];
  const escalatedRows: EscalatedRow[] = (escalated.data as EscalatedRow[]) ?? [];
  const workloadRows: WorkloadRow[] = (workload.data as WorkloadRow[]) ?? [];

  const retentionCols: Column<RetentionRow>[] = [
    { header: 'Cohort', accessor: (r) => r.cohort_label },
    { header: 'Months', accessor: (r) => r.months_since_join },
    { header: 'Size', accessor: (r) => r.cohort_size_engineers },
    { header: 'Active', accessor: (r) => r.active_engineers },
    { header: 'Retention %', accessor: (r) => r.retention_pct },
    { header: 'Promotion %', accessor: (r) => r.promotion_pct },
    { header: 'Loop', accessor: (r) => r.loop_health },
    { header: 'Audit', accessor: (r) => r.audit_status },
  ];

  const healthCols: Column<HealthRow>[] = [
    { header: 'Loop Health', accessor: (r) => r.loop_health },
    { header: 'Cohorts', accessor: (r) => r.cohort_count },
    { header: 'Total Eng', accessor: (r) => r.total_engineers },
    { header: 'Active Eng', accessor: (r) => r.active_engineers },
    { header: 'Avg Retention %', accessor: (r) => r.avg_retention_pct },
    { header: 'Avg Promo %', accessor: (r) => r.avg_promotion_pct },
  ];

  const benchmarkCols: Column<BenchmarkRow>[] = [
    { header: 'Cohort', accessor: (r) => r.cohort_label },
    { header: 'Months', accessor: (r) => r.months_since_join },
    { header: 'Retention %', accessor: (r) => r.retention_pct },
    { header: 'Promotion %', accessor: (r) => r.promotion_pct },
    { header: 'Benchmark', accessor: (r) => r.benchmark_status },
  ];

  const pendingCols: Column<PendingRow>[] = [
    { header: 'Cohort', accessor: (r) => r.cohort_label },
    { header: 'Decision', accessor: (r) => r.decision_label },
    { header: 'Type', accessor: (r) => r.decision_type },
    { header: 'Tier', accessor: (r) => r.target_tier },
    { header: 'Budget', accessor: (r) => r.budget_rupees },
    { header: 'Priority', accessor: (r) => r.priority },
    { header: 'Owner', accessor: (r) => r.owner_role },
    { header: 'Due', accessor: (r) => r.due_date ?? '—' },
  ];

  const budgetCols: Column<BudgetRow>[] = [
    { header: 'Decision Type', accessor: (r) => r.decision_type },
    { header: 'Count', accessor: (r) => r.decision_count },
    { header: 'Executed', accessor: (r) => r.executed_count },
    { header: 'Total Budget', accessor: (r) => r.total_budget_rupees },
    { header: 'Avg Lift %', accessor: (r) => r.avg_expected_lift_pct },
  ];

  const escalatedCols: Column<EscalatedRow>[] = [
    { header: 'Cohort', accessor: (r) => r.cohort_label },
    { header: 'Start', accessor: (r) => r.cohort_start_date },
    { header: 'Months', accessor: (r) => r.months_since_join },
    { header: 'Loop', accessor: (r) => r.loop_health },
    { header: 'Audit', accessor: (r) => r.audit_status },
    { header: 'Notes', accessor: (r) => r.founder_notes ?? '—' },
    { header: 'Open', accessor: (r) => r.open_decisions },
  ];

  const workloadCols: Column<WorkloadRow>[] = [
    { header: 'Owner', accessor: (r) => r.owner_role },
    { header: 'Open', accessor: (r) => r.open_decisions },
    { header: 'Executed', accessor: (r) => r.executed_decisions },
    { header: 'Open Budget', accessor: (r) => r.total_budget_open_rupees },
    { header: 'Avg Lift %', accessor: (r) => r.avg_expected_lift_pct },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Quarterly Strategic Engineer-Cohort 18-Month Retention &amp; Promotion Loop Audit
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Founder console — review every active cohort, benchmark 18m retention &gt;= 80%, and clear open promotion decisions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Cohort retention rollup</h2>
        <DataTable
          rows={retentionRows}
          columns={retentionCols}
          emptyMessage="No cohorts."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Loop-health breakdown</h2>
        <DataTable
          rows={healthRows}
          columns={healthCols}
          emptyMessage="No data."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>18-month benchmark</h2>
        <DataTable
          rows={benchmarkRows}
          columns={benchmarkCols}
          emptyMessage="No cohorts."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending decisions queue</h2>
        <DataTable
          rows={pendingRows}
          columns={pendingCols}
          emptyMessage="No pending decisions."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Decision budget summary</h2>
        <DataTable
          rows={budgetRows}
          columns={budgetCols}
          emptyMessage="No decisions."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Escalated & critical loops</h2>
        <DataTable
          rows={escalatedRows}
          columns={escalatedCols}
          emptyMessage="No escalations."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner workload</h2>
        <DataTable
          rows={workloadRows}
          columns={workloadCols}
          emptyMessage="No workload."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
