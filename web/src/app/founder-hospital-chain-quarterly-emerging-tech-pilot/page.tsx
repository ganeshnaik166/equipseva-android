import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_pilots: number;
  running_pilots: number;
  complete_pilots: number;
  total_budget_rupees: number;
  avg_budget_rupees: number;
};

type ByChain = {
  chain_name: string;
  pilot_count: number;
  total_budget_rupees: number;
  running: number;
  complete: number;
};

type ByTech = {
  tech_kind: string;
  pilot_count: number;
  total_budget_rupees: number;
};

type GradeRow = {
  outcome_grade: string;
  outcome_count: number;
  pct_of_total: number;
};

type DecisionRow = {
  scale_decision: string;
  decision_count: number;
};

type PilotRow = {
  id: string;
  chain_name: string;
  quarter_label: string;
  tech_kind: string;
  pilot_scope: string;
  start_date: string;
  end_date: string;
  budget_rupees: number;
  status: string;
};

type OutcomeRow = {
  id: string;
  chain_name: string;
  tech_kind: string;
  kpi_label: string;
  target_value: number;
  actual_value: number;
  unit: string;
  outcome_grade: string;
  scale_decision: string;
  decision_notes: string | null;
};

type WinnerRow = {
  chain_name: string;
  tech_kind: string;
  kpi_label: string;
  actual_value: number;
  target_value: number;
  scale_decision: string;
};

function rupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, byChainRes, byTechRes, gradeRes, decisionRes, pilotsRes, outcomesRes, winnersRes] = await Promise.all([
    supabase.rpc('founder_r2747_pilot_overview'),
    supabase.rpc('founder_r2747_pilots_by_chain'),
    supabase.rpc('founder_r2747_pilots_by_tech_kind'),
    supabase.rpc('founder_r2747_outcome_grade_breakdown'),
    supabase.rpc('founder_r2747_scale_decision_breakdown'),
    supabase.rpc('founder_r2747_pilots_list'),
    supabase.rpc('founder_r2747_outcomes_list'),
    supabase.rpc('founder_r2747_scale_winners'),
  ]);

  const overview: Overview = (overviewRes.data?.[0] as Overview) ?? {
    total_pilots: 0,
    running_pilots: 0,
    complete_pilots: 0,
    total_budget_rupees: 0,
    avg_budget_rupees: 0,
  };
  const byChain: ByChain[] = (byChainRes.data as ByChain[]) ?? [];
  const byTech: ByTech[] = (byTechRes.data as ByTech[]) ?? [];
  const grades: GradeRow[] = (gradeRes.data as GradeRow[]) ?? [];
  const decisions: DecisionRow[] = (decisionRes.data as DecisionRow[]) ?? [];
  const pilots: PilotRow[] = (pilotsRes.data as PilotRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomesRes.data as OutcomeRow[]) ?? [];
  const winners: WinnerRow[] = (winnersRes.data as WinnerRow[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Emerging Tech Pilot</h1>
        <p className="text-sm text-gray-600">
          Round r2747 — chain × tech kind × pilot scope × KPI × outcome × scale decision.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Total Pilots</div>
          <div className="text-2xl font-bold">{overview.total_pilots}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Running</div>
          <div className="text-2xl font-bold">{overview.running_pilots}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Complete</div>
          <div className="text-2xl font-bold">{overview.complete_pilots}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Total Budget</div>
          <div className="text-2xl font-bold">{rupees(overview.total_budget_rupees)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Avg Budget</div>
          <div className="text-2xl font-bold">{rupees(Math.round(Number(overview.avg_budget_rupees) || 0))}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pilots by Chain</h2>
        <DataTable
          rows={byChain}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: ByChain) => r.chain_name },
            { key: 'pilot_count', header: 'Pilots', render: (r: ByChain) => r.pilot_count },
            { key: 'running', header: 'Running', render: (r: ByChain) => r.running },
            { key: 'complete', header: 'Complete', render: (r: ByChain) => r.complete },
            { key: 'total_budget_rupees', header: 'Total Budget', render: (r: ByChain) => rupees(r.total_budget_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByChain, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pilots by Tech Kind</h2>
        <DataTable
          rows={byTech}
          columns={[
            { key: 'tech_kind', header: 'Tech Kind', render: (r: ByTech) => r.tech_kind },
            { key: 'pilot_count', header: 'Pilots', render: (r: ByTech) => r.pilot_count },
            { key: 'total_budget_rupees', header: 'Total Budget', render: (r: ByTech) => rupees(r.total_budget_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByTech, i: number) => String(r.tech_kind ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Outcome Grade Breakdown</h2>
          <DataTable
            rows={grades}
            columns={[
              { key: 'outcome_grade', header: 'Grade', render: (r: GradeRow) => r.outcome_grade },
              { key: 'outcome_count', header: 'Count', render: (r: GradeRow) => r.outcome_count },
              { key: 'pct_of_total', header: 'Pct of Total', render: (r: GradeRow) => String(r.pct_of_total) + '%' },
            ]}
            emptyMessage="No data"
            rowKey={(r: GradeRow, i: number) => String(r.outcome_grade ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Scale Decision Breakdown</h2>
          <DataTable
            rows={decisions}
            columns={[
              { key: 'scale_decision', header: 'Decision', render: (r: DecisionRow) => r.scale_decision },
              { key: 'decision_count', header: 'Count', render: (r: DecisionRow) => r.decision_count },
            ]}
            emptyMessage="No data"
            rowKey={(r: DecisionRow, i: number) => String(r.scale_decision ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pilots</h2>
        <DataTable
          rows={pilots}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: PilotRow) => r.chain_name },
            { key: 'quarter_label', header: 'Quarter', render: (r: PilotRow) => r.quarter_label },
            { key: 'tech_kind', header: 'Tech', render: (r: PilotRow) => r.tech_kind },
            { key: 'pilot_scope', header: 'Scope', render: (r: PilotRow) => r.pilot_scope },
            { key: 'start_date', header: 'Start', render: (r: PilotRow) => r.start_date },
            { key: 'end_date', header: 'End', render: (r: PilotRow) => r.end_date },
            { key: 'budget_rupees', header: 'Budget', render: (r: PilotRow) => rupees(r.budget_rupees) },
            { key: 'status', header: 'Status', render: (r: PilotRow) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: PilotRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Outcomes (KPI & Decision)</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: OutcomeRow) => r.chain_name },
            { key: 'tech_kind', header: 'Tech', render: (r: OutcomeRow) => r.tech_kind },
            { key: 'kpi_label', header: 'KPI', render: (r: OutcomeRow) => r.kpi_label },
            { key: 'target_value', header: 'Target', render: (r: OutcomeRow) => String(r.target_value) + ' ' + r.unit },
            { key: 'actual_value', header: 'Actual', render: (r: OutcomeRow) => String(r.actual_value) + ' ' + r.unit },
            { key: 'outcome_grade', header: 'Grade', render: (r: OutcomeRow) => r.outcome_grade },
            { key: 'scale_decision', header: 'Decision', render: (r: OutcomeRow) => r.scale_decision },
            { key: 'decision_notes', header: 'Notes', render: (r: OutcomeRow) => r.decision_notes ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Scale Winners (chain-wide or select-site)</h2>
        <DataTable
          rows={winners}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: WinnerRow) => r.chain_name },
            { key: 'tech_kind', header: 'Tech', render: (r: WinnerRow) => r.tech_kind },
            { key: 'kpi_label', header: 'KPI', render: (r: WinnerRow) => r.kpi_label },
            { key: 'actual_value', header: 'Actual', render: (r: WinnerRow) => r.actual_value },
            { key: 'target_value', header: 'Target', render: (r: WinnerRow) => r.target_value },
            { key: 'scale_decision', header: 'Decision', render: (r: WinnerRow) => r.scale_decision },
          ]}
          emptyMessage="No data"
          rowKey={(r: WinnerRow, i: number) => String(r.chain_name + '-' + r.tech_kind + '-' + i)}
        />
      </section>
    </div>
  );
}
