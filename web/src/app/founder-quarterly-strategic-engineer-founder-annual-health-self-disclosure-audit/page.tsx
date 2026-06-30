import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type RosterRow = { id?: string; disclosure_quarter: string; subject_role: string; subject_name: string; region: string; overall_health_score: number; burnout_risk: string; mental_health_self_report: string; founder_review_status: string };
type BurnoutRow = { id?: string; burnout_risk: string; headcount: number; avg_health_score: number; avg_stress: number; chronic_count: number };
type PendingRow = { id?: string; subject_name: string; subject_role: string; disclosure_quarter: string; burnout_risk: string; mental_health_self_report: string; last_medical_checkup_at: string | null };
type BudgetRow = { id?: string; intervention_type: string; count_total: number; approved_count: number; total_budget: number; avg_outcome_score: number | null };
type TrendRow = { id?: string; disclosure_quarter: string; headcount: number; avg_health_score: number; avg_sleep: number; high_risk_count: number; crisis_count: number };
type CriticalRow = { id?: string; subject_name: string; subject_role: string; region: string; overall_health_score: number; burnout_risk: string; mental_health_self_report: string; chronic_condition_flag: boolean; founder_review_status: string };
type OutcomeRow = { id?: string; subject_name: string; intervention_count: number; approved_count: number; total_spent: number; succeeded_count: number; follow_up_required_count: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [roster, burnout, pending, budget, trend, critical, outcomes] = await Promise.all([
    supabase.rpc('founder_r3069_roster_overview'),
    supabase.rpc('founder_r3069_burnout_risk_breakdown'),
    supabase.rpc('founder_r3069_pending_reviews'),
    supabase.rpc('founder_r3069_intervention_budget_summary'),
    supabase.rpc('founder_r3069_quarter_trend'),
    supabase.rpc('founder_r3069_critical_cases'),
    supabase.rpc('founder_r3069_intervention_outcomes_by_subject'),
  ]);

  const rosterRows: RosterRow[] = (roster.data as RosterRow[]) ?? [];
  const burnoutRows: BurnoutRow[] = (burnout.data as BurnoutRow[]) ?? [];
  const pendingRows: PendingRow[] = (pending.data as PendingRow[]) ?? [];
  const budgetRows: BudgetRow[] = (budget.data as BudgetRow[]) ?? [];
  const trendRows: TrendRow[] = (trend.data as TrendRow[]) ?? [];
  const criticalRows: CriticalRow[] = (critical.data as CriticalRow[]) ?? [];
  const outcomeRows: OutcomeRow[] = (outcomes.data as OutcomeRow[]) ?? [];

  const rosterCols: Column<RosterRow>[] = [
    { header: 'Quarter', accessor: (r) => r.disclosure_quarter },
    { header: 'Role', accessor: (r) => r.subject_role },
    { header: 'Name', accessor: (r) => r.subject_name },
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Score', accessor: (r) => r.overall_health_score },
    { header: 'Burnout', accessor: (r) => r.burnout_risk },
    { header: 'Mental', accessor: (r) => r.mental_health_self_report },
    { header: 'Review', accessor: (r) => r.founder_review_status },
  ];

  const burnoutCols: Column<BurnoutRow>[] = [
    { header: 'Risk', accessor: (r) => r.burnout_risk },
    { header: 'Headcount', accessor: (r) => r.headcount },
    { header: 'Avg Score', accessor: (r) => r.avg_health_score },
    { header: 'Avg Stress', accessor: (r) => r.avg_stress },
    { header: 'Chronic', accessor: (r) => r.chronic_count },
  ];

  const pendingCols: Column<PendingRow>[] = [
    { header: 'Name', accessor: (r) => r.subject_name },
    { header: 'Role', accessor: (r) => r.subject_role },
    { header: 'Quarter', accessor: (r) => r.disclosure_quarter },
    { header: 'Burnout', accessor: (r) => r.burnout_risk },
    { header: 'Mental', accessor: (r) => r.mental_health_self_report },
    { header: 'Last Checkup', accessor: (r) => r.last_medical_checkup_at ?? '—' },
  ];

  const budgetCols: Column<BudgetRow>[] = [
    { header: 'Type', accessor: (r) => r.intervention_type },
    { header: 'Total', accessor: (r) => r.count_total },
    { header: 'Approved', accessor: (r) => r.approved_count },
    { header: 'Budget (Rs)', accessor: (r) => r.total_budget },
    { header: 'Avg Outcome', accessor: (r) => r.avg_outcome_score ?? '—' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { header: 'Quarter', accessor: (r) => r.disclosure_quarter },
    { header: 'Headcount', accessor: (r) => r.headcount },
    { header: 'Avg Score', accessor: (r) => r.avg_health_score },
    { header: 'Avg Sleep', accessor: (r) => r.avg_sleep },
    { header: 'High Risk', accessor: (r) => r.high_risk_count },
    { header: 'Crisis', accessor: (r) => r.crisis_count },
  ];

  const criticalCols: Column<CriticalRow>[] = [
    { header: 'Name', accessor: (r) => r.subject_name },
    { header: 'Role', accessor: (r) => r.subject_role },
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Score', accessor: (r) => r.overall_health_score },
    { header: 'Burnout', accessor: (r) => r.burnout_risk },
    { header: 'Mental', accessor: (r) => r.mental_health_self_report },
    { header: 'Chronic', accessor: (r) => r.chronic_condition_flag ? 'yes' : 'no' },
    { header: 'Review', accessor: (r) => r.founder_review_status },
  ];

  const outcomeCols: Column<OutcomeRow>[] = [
    { header: 'Name', accessor: (r) => r.subject_name },
    { header: 'Count', accessor: (r) => r.intervention_count },
    { header: 'Approved', accessor: (r) => r.approved_count },
    { header: 'Spent (Rs)', accessor: (r) => r.total_spent },
    { header: 'Succeeded', accessor: (r) => r.succeeded_count },
    { header: 'Follow-up', accessor: (r) => r.follow_up_required_count },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Quarterly Strategic Engineer-Founder Annual Health Self-Disclosure Audit</h1>
        <p style={{ color: '#666', marginTop: 4 }}>Round 3069 — founder reviews health &amp; burnout signals across engineering leadership; approves interventions &gt;= Rs.5k.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Roster Overview</h2>
        <DataTable<RosterRow> rows={rosterRows} columns={rosterCols} emptyMessage="No disclosures" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Burnout Risk Breakdown</h2>
        <DataTable<BurnoutRow> rows={burnoutRows} columns={burnoutCols} emptyMessage="No risk data" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending Founder Reviews</h2>
        <DataTable<PendingRow> rows={pendingRows} columns={pendingCols} emptyMessage="None pending" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Intervention Budget Summary</h2>
        <DataTable<BudgetRow> rows={budgetRows} columns={budgetCols} emptyMessage="No interventions" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Quarter Trend</h2>
        <DataTable<TrendRow> rows={trendRows} columns={trendCols} emptyMessage="No trend data" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Critical Cases (burnout high/critical OR mental struggling/crisis)</h2>
        <DataTable<CriticalRow> rows={criticalRows} columns={criticalCols} emptyMessage="No critical cases" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Intervention Outcomes by Subject</h2>
        <DataTable<OutcomeRow> rows={outcomeRows} columns={outcomeCols} emptyMessage="No outcomes" rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
