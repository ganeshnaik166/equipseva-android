import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_experiments: number;
  active_count: number;
  killed_count: number;
  graduated_count: number;
  paused_count: number;
  total_budget_rupees: number;
  total_spend_rupees: number;
  cap_utilization_pct: number;
  experiments_over_cap: number;
};

type ExperimentRow = {
  experiment_code: string;
  experiment_name: string;
  strategic_bet: string;
  owner: string;
  status: string;
  budget_cap_rupees: number;
  spend_to_date_rupees: number;
  cap_utilization_pct: number;
  target_metric: string;
  target_value: number;
  actual_value: number;
  attainment_pct: number;
  review_on: string;
};

type ScoreboardRow = {
  experiment_code: string;
  experiment_name: string;
  attainment_pct: number;
  cap_utilization_pct: number;
  recommendation: string;
  reason: string;
};

type BetRow = {
  strategic_bet: string;
  experiment_count: number;
  total_budget_rupees: number;
  total_spend_rupees: number;
  avg_attainment_pct: number;
};

type DecisionRow = {
  experiment_code: string;
  decided_on: string;
  decision: string;
  rationale: string;
  cost_cap_hit: boolean;
  outcome_snapshot: string;
  next_milestone: string | null;
  decided_by: string;
};

type BreachRow = {
  experiment_code: string;
  experiment_name: string;
  budget_cap_rupees: number;
  spend_to_date_rupees: number;
  overspend_rupees: number;
  attainment_pct: number;
  status: string;
};

type TallyRow = {
  bucket: string;
  experiment_count: number;
  total_spend_rupees: number;
  experiments: string;
};

type ReviewRow = {
  experiment_code: string;
  experiment_name: string;
  review_on: string;
  days_until: number;
  attainment_pct: number;
  cap_utilization_pct: number;
  status: string;
};

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(1) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, listRes, scoreRes, betRes, decisionRes, breachRes, tallyRes, reviewRes] = await Promise.all([
    supabase.rpc('r2785_portfolio_summary'),
    supabase.rpc('r2785_list_experiments'),
    supabase.rpc('r2785_continue_kill_scoreboard'),
    supabase.rpc('r2785_bet_rollup'),
    supabase.rpc('r2785_decisions_log'),
    supabase.rpc('r2785_cap_breach_watchlist'),
    supabase.rpc('r2785_graduates_and_kills'),
    supabase.rpc('r2785_upcoming_reviews'),
  ]);

  const summary: Summary | null = (summaryRes.data?.[0] as Summary) ?? null;
  const experiments: ExperimentRow[] = (listRes.data as ExperimentRow[]) ?? [];
  const scoreboard: ScoreboardRow[] = (scoreRes.data as ScoreboardRow[]) ?? [];
  const bets: BetRow[] = (betRes.data as BetRow[]) ?? [];
  const decisions: DecisionRow[] = (decisionRes.data as DecisionRow[]) ?? [];
  const breaches: BreachRow[] = (breachRes.data as BreachRow[]) ?? [];
  const tally: TallyRow[] = (tallyRes.data as TallyRow[]) ?? [];
  const reviews: ReviewRow[] = (reviewRes.data as ReviewRow[]) ?? [];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Quarterly Strategic Experiment Cost Cap
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Bet × spend × cap × actual × outcome × continue/kill decision. Caps enforced when spend &gt;= 80% with attainment &lt; 50%.
      </p>

      {/* KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Kpi label="Total Experiments" value={String(summary?.total_experiments ?? 0)} />
        <Kpi label="Active" value={String(summary?.active_count ?? 0)} />
        <Kpi label="Graduated" value={String(summary?.graduated_count ?? 0)} />
        <Kpi label="Killed" value={String(summary?.killed_count ?? 0)} />
        <Kpi label="Paused" value={String(summary?.paused_count ?? 0)} />
        <Kpi label="Total Budget Cap" value={rupees(summary?.total_budget_rupees ?? 0)} />
        <Kpi label="Spend to Date" value={rupees(summary?.total_spend_rupees ?? 0)} />
        <Kpi label="Cap Utilization" value={pct(summary?.cap_utilization_pct ?? 0)} />
        <Kpi label="Over Cap" value={String(summary?.experiments_over_cap ?? 0)} />
      </div>

      <Section title="Experiment Portfolio">
        <DataTable
          rows={experiments}
          columns={[
            { key: 'experiment_code', header: 'Code', render: (r: ExperimentRow) => r.experiment_code },
            { key: 'experiment_name', header: 'Name', render: (r: ExperimentRow) => r.experiment_name },
            { key: 'strategic_bet', header: 'Bet', render: (r: ExperimentRow) => r.strategic_bet },
            { key: 'owner', header: 'Owner', render: (r: ExperimentRow) => r.owner },
            { key: 'status', header: 'Status', render: (r: ExperimentRow) => r.status },
            { key: 'budget_cap_rupees', header: 'Cap', render: (r: ExperimentRow) => rupees(r.budget_cap_rupees) },
            { key: 'spend_to_date_rupees', header: 'Spend', render: (r: ExperimentRow) => rupees(r.spend_to_date_rupees) },
            { key: 'cap_utilization_pct', header: 'Cap Util', render: (r: ExperimentRow) => pct(r.cap_utilization_pct) },
            { key: 'target_metric', header: 'Metric', render: (r: ExperimentRow) => r.target_metric },
            { key: 'target_value', header: 'Target', render: (r: ExperimentRow) => String(r.target_value) },
            { key: 'actual_value', header: 'Actual', render: (r: ExperimentRow) => String(r.actual_value) },
            { key: 'attainment_pct', header: 'Attainment', render: (r: ExperimentRow) => pct(r.attainment_pct) },
            { key: 'review_on', header: 'Review', render: (r: ExperimentRow) => r.review_on },
          ]}
          emptyMessage="No data"
          rowKey={(r: ExperimentRow, i: number) => String(r.experiment_code ?? i)}
        />
      </Section>

      <Section title="Continue / Kill Scoreboard">
        <DataTable
          rows={scoreboard}
          columns={[
            { key: 'experiment_code', header: 'Code', render: (r: ScoreboardRow) => r.experiment_code },
            { key: 'experiment_name', header: 'Name', render: (r: ScoreboardRow) => r.experiment_name },
            { key: 'attainment_pct', header: 'Attainment', render: (r: ScoreboardRow) => pct(r.attainment_pct) },
            { key: 'cap_utilization_pct', header: 'Cap Util', render: (r: ScoreboardRow) => pct(r.cap_utilization_pct) },
            { key: 'recommendation', header: 'Recommend', render: (r: ScoreboardRow) => r.recommendation },
            { key: 'reason', header: 'Reason', render: (r: ScoreboardRow) => r.reason },
          ]}
          emptyMessage="No data"
          rowKey={(r: ScoreboardRow, i: number) => String(r.experiment_code ?? i)}
        />
      </Section>

      <Section title="Strategic Bet Rollup">
        <DataTable
          rows={bets}
          columns={[
            { key: 'strategic_bet', header: 'Bet', render: (r: BetRow) => r.strategic_bet },
            { key: 'experiment_count', header: 'Count', render: (r: BetRow) => String(r.experiment_count) },
            { key: 'total_budget_rupees', header: 'Total Cap', render: (r: BetRow) => rupees(r.total_budget_rupees) },
            { key: 'total_spend_rupees', header: 'Total Spend', render: (r: BetRow) => rupees(r.total_spend_rupees) },
            { key: 'avg_attainment_pct', header: 'Avg Attain', render: (r: BetRow) => pct(r.avg_attainment_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: BetRow, i: number) => String(r.strategic_bet ?? i)}
        />
      </Section>

      <Section title="Cap Breach Watchlist (spend >= 80% of cap)">
        <DataTable
          rows={breaches}
          columns={[
            { key: 'experiment_code', header: 'Code', render: (r: BreachRow) => r.experiment_code },
            { key: 'experiment_name', header: 'Name', render: (r: BreachRow) => r.experiment_name },
            { key: 'budget_cap_rupees', header: 'Cap', render: (r: BreachRow) => rupees(r.budget_cap_rupees) },
            { key: 'spend_to_date_rupees', header: 'Spend', render: (r: BreachRow) => rupees(r.spend_to_date_rupees) },
            { key: 'overspend_rupees', header: 'Overspend', render: (r: BreachRow) => rupees(r.overspend_rupees) },
            { key: 'attainment_pct', header: 'Attainment', render: (r: BreachRow) => pct(r.attainment_pct) },
            { key: 'status', header: 'Status', render: (r: BreachRow) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: BreachRow, i: number) => String(r.experiment_code ?? i)}
        />
      </Section>

      <Section title="Decisions Log">
        <DataTable
          rows={decisions}
          columns={[
            { key: 'experiment_code', header: 'Code', render: (r: DecisionRow) => r.experiment_code },
            { key: 'decided_on', header: 'Date', render: (r: DecisionRow) => r.decided_on },
            { key: 'decision', header: 'Decision', render: (r: DecisionRow) => r.decision },
            { key: 'rationale', header: 'Rationale', render: (r: DecisionRow) => r.rationale },
            { key: 'cost_cap_hit', header: 'Cap Hit', render: (r: DecisionRow) => r.cost_cap_hit ? 'yes' : 'no' },
            { key: 'outcome_snapshot', header: 'Outcome', render: (r: DecisionRow) => r.outcome_snapshot },
            { key: 'next_milestone', header: 'Next Milestone', render: (r: DecisionRow) => r.next_milestone ?? '-' },
            { key: 'decided_by', header: 'By', render: (r: DecisionRow) => r.decided_by },
          ]}
          emptyMessage="No data"
          rowKey={(r: DecisionRow, i: number) => String(r.experiment_code + '-' + r.decided_on) ?? String(i)}
        />
      </Section>

      <Section title="Graduates & Kills Tally">
        <DataTable
          rows={tally}
          columns={[
            { key: 'bucket', header: 'Status', render: (r: TallyRow) => r.bucket },
            { key: 'experiment_count', header: 'Count', render: (r: TallyRow) => String(r.experiment_count) },
            { key: 'total_spend_rupees', header: 'Total Spend', render: (r: TallyRow) => rupees(r.total_spend_rupees) },
            { key: 'experiments', header: 'Experiments', render: (r: TallyRow) => r.experiments },
          ]}
          emptyMessage="No data"
          rowKey={(r: TallyRow, i: number) => String(r.bucket ?? i)}
        />
      </Section>

      <Section title="Upcoming Reviews">
        <DataTable
          rows={reviews}
          columns={[
            { key: 'experiment_code', header: 'Code', render: (r: ReviewRow) => r.experiment_code },
            { key: 'experiment_name', header: 'Name', render: (r: ReviewRow) => r.experiment_name },
            { key: 'review_on', header: 'Review On', render: (r: ReviewRow) => r.review_on },
            { key: 'days_until', header: 'Days Until', render: (r: ReviewRow) => String(r.days_until) },
            { key: 'attainment_pct', header: 'Attainment', render: (r: ReviewRow) => pct(r.attainment_pct) },
            { key: 'cap_utilization_pct', header: 'Cap Util', render: (r: ReviewRow) => pct(r.cap_utilization_pct) },
            { key: 'status', header: 'Status', render: (r: ReviewRow) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: ReviewRow, i: number) => String(r.experiment_code ?? i)}
        />
      </Section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginTop: 32 }}>
      <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </section>
  );
}
