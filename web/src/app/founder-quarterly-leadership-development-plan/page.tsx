import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = { total_plans: number; promote_count: number; coach_count: number; exit_count: number; avg_strength: number };
type Plan = { id: string; hire_name: string; role_title: string; hire_date: string; top_strength: string; critical_gap: string; development_plan: string; strength_score: number; gap_severity: string; promotion_decision: string; quarter: string };
type Milestone = { hire_name: string; milestone_title: string; due_date: string; status: string; completion_pct: number; notes: string | null };
type GapRow = { gap_severity: string; plan_count: number; avg_strength: number };
type AtRisk = { hire_name: string; milestone_title: string; status: string; completion_pct: number; due_date: string };
type PromoDist = { promotion_decision: string; hire_count: number };
type CompletionAvg = { hire_name: string; role_title: string; avg_completion: number; milestone_count: number };
type TopStrength = { hire_name: string; role_title: string; top_strength: string; strength_score: number; promotion_decision: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [sumRes, plansRes, milesRes, gapRes, riskRes, promoRes, compRes, topRes] = await Promise.all([
    supabase.rpc('r2693_summary'),
    supabase.rpc('r2693_list_plans'),
    supabase.rpc('r2693_list_milestones'),
    supabase.rpc('r2693_gap_breakdown'),
    supabase.rpc('r2693_at_risk_milestones'),
    supabase.rpc('r2693_promotion_distribution'),
    supabase.rpc('r2693_milestone_completion_avg'),
    supabase.rpc('r2693_top_strength_hires'),
  ]);

  const summary: Summary = (sumRes.data?.[0] as Summary) ?? { total_plans: 0, promote_count: 0, coach_count: 0, exit_count: 0, avg_strength: 0 };
  const plans: Plan[] = (plansRes.data as Plan[]) ?? [];
  const milestones: Milestone[] = (milesRes.data as Milestone[]) ?? [];
  const gaps: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const atRisk: AtRisk[] = (riskRes.data as AtRisk[]) ?? [];
  const promoDist: PromoDist[] = (promoRes.data as PromoDist[]) ?? [];
  const completion: CompletionAvg[] = (compRes.data as CompletionAvg[]) ?? [];
  const top: TopStrength[] = (topRes.data as TopStrength[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Leadership Development Plan</h1>
        <p className="text-sm text-gray-600">Hire {'×'} strength {'×'} gap {'×'} dev plan {'×'} milestone {'×'} promotion decision (strength score &gt;= 8 marks top tier)</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Total plans</div><div className="text-2xl font-semibold">{summary.total_plans}</div></div>
        <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Promote</div><div className="text-2xl font-semibold">{summary.promote_count}</div></div>
        <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Coach</div><div className="text-2xl font-semibold">{summary.coach_count}</div></div>
        <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Exit</div><div className="text-2xl font-semibold">{summary.exit_count}</div></div>
        <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Avg strength</div><div className="text-2xl font-semibold">{summary.avg_strength}</div></div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All development plans</h2>
        <DataTable
          rows={plans}
          columns={[
            { key: 'hire_name', header: 'Hire', render: (r: Plan) => r.hire_name },
            { key: 'role_title', header: 'Role', render: (r: Plan) => r.role_title },
            { key: 'top_strength', header: 'Top strength', render: (r: Plan) => r.top_strength },
            { key: 'critical_gap', header: 'Critical gap', render: (r: Plan) => r.critical_gap },
            { key: 'development_plan', header: 'Dev plan', render: (r: Plan) => r.development_plan },
            { key: 'strength_score', header: 'Strength (1-10)', render: (r: Plan) => String(r.strength_score) },
            { key: 'gap_severity', header: 'Gap severity', render: (r: Plan) => r.gap_severity },
            { key: 'promotion_decision', header: 'Decision', render: (r: Plan) => r.promotion_decision },
            { key: 'quarter', header: 'Quarter', render: (r: Plan) => r.quarter },
          ]}
          emptyMessage="No data"
          rowKey={(r: Plan, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Milestones</h2>
        <DataTable
          rows={milestones}
          columns={[
            { key: 'hire_name', header: 'Hire', render: (r: Milestone) => r.hire_name },
            { key: 'milestone_title', header: 'Milestone', render: (r: Milestone) => r.milestone_title },
            { key: 'due_date', header: 'Due', render: (r: Milestone) => r.due_date },
            { key: 'status', header: 'Status', render: (r: Milestone) => r.status },
            { key: 'completion_pct', header: 'Completion %', render: (r: Milestone) => String(r.completion_pct) },
            { key: 'notes', header: 'Notes', render: (r: Milestone) => r.notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Milestone, i: number) => String(i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Gap severity breakdown</h2>
          <DataTable
            rows={gaps}
            columns={[
              { key: 'gap_severity', header: 'Severity', render: (r: GapRow) => r.gap_severity },
              { key: 'plan_count', header: 'Plans', render: (r: GapRow) => String(r.plan_count) },
              { key: 'avg_strength', header: 'Avg strength', render: (r: GapRow) => String(r.avg_strength) },
            ]}
            emptyMessage="No data"
            rowKey={(r: GapRow, i: number) => String(i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Promotion distribution</h2>
          <DataTable
            rows={promoDist}
            columns={[
              { key: 'promotion_decision', header: 'Decision', render: (r: PromoDist) => r.promotion_decision },
              { key: 'hire_count', header: 'Hires', render: (r: PromoDist) => String(r.hire_count) },
            ]}
            emptyMessage="No data"
            rowKey={(r: PromoDist, i: number) => String(i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">At-risk & blocked milestones</h2>
        <DataTable
          rows={atRisk}
          columns={[
            { key: 'hire_name', header: 'Hire', render: (r: AtRisk) => r.hire_name },
            { key: 'milestone_title', header: 'Milestone', render: (r: AtRisk) => r.milestone_title },
            { key: 'status', header: 'Status', render: (r: AtRisk) => r.status },
            { key: 'completion_pct', header: 'Completion %', render: (r: AtRisk) => String(r.completion_pct) },
            { key: 'due_date', header: 'Due', render: (r: AtRisk) => r.due_date },
          ]}
          emptyMessage="No data"
          rowKey={(r: AtRisk, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Milestone completion average per hire</h2>
        <DataTable
          rows={completion}
          columns={[
            { key: 'hire_name', header: 'Hire', render: (r: CompletionAvg) => r.hire_name },
            { key: 'role_title', header: 'Role', render: (r: CompletionAvg) => r.role_title },
            { key: 'avg_completion', header: 'Avg completion %', render: (r: CompletionAvg) => String(r.avg_completion) },
            { key: 'milestone_count', header: 'Milestones', render: (r: CompletionAvg) => String(r.milestone_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CompletionAvg, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top strength hires (score &gt;= 8)</h2>
        <DataTable
          rows={top}
          columns={[
            { key: 'hire_name', header: 'Hire', render: (r: TopStrength) => r.hire_name },
            { key: 'role_title', header: 'Role', render: (r: TopStrength) => r.role_title },
            { key: 'top_strength', header: 'Strength', render: (r: TopStrength) => r.top_strength },
            { key: 'strength_score', header: 'Score', render: (r: TopStrength) => String(r.strength_score) },
            { key: 'promotion_decision', header: 'Decision', render: (r: TopStrength) => r.promotion_decision },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopStrength, i: number) => String(i)}
        />
      </section>
    </div>
  );
}