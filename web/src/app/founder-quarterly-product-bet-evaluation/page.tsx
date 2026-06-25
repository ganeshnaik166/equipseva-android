import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Bet = {
  id: string;
  quarter: string;
  bet_name: string;
  hypothesis: string;
  success_metric: string;
  target_value: number;
  actual_value: number | null;
  attainment_pct: number | null;
  cost_rupees: number;
  bet_tier: string;
  status: string;
  owner: string;
  started_at: string;
  evaluated_at: string | null;
};

type Summary = {
  total_bets: number;
  running_bets: number;
  succeeded_bets: number;
  failed_bets: number;
  partial_bets: number;
  total_cost_rupees: number;
  win_rate_pct: number;
  avg_attainment_pct: number;
};

type TierRow = { bet_tier: string; bet_count: number; total_cost: number; win_count: number };
type QuarterRow = { quarter: string; bet_count: number; total_cost: number; succeeded: number; failed: number };
type Learning = { id: string; bet_name: string; learning_text: string; decision: string; rationale: string; confidence_pct: number; recorded_at: string };
type Kill = { bet_name: string; attainment_pct: number | null; cost_rupees: number; decision: string; rationale: string };
type Win = { bet_name: string; attainment_pct: number | null; cost_rupees: number; learning_text: string; confidence_pct: number };
type Owner = { owner: string; total_cost: number; win_count: number; avg_attainment: number | null };

function fmtRupees(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}
function fmtPct(n: number | null | undefined) {
  if (n === null || n === undefined) return '-';
  return `${n}%`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [bets, summary, tiers, quarters, learnings, kills, wins, owners] = await Promise.all([
    supabase.rpc('founder_list_product_bets_r2681'),
    supabase.rpc('founder_bet_summary_r2681'),
    supabase.rpc('founder_bets_by_tier_r2681'),
    supabase.rpc('founder_bets_by_quarter_r2681'),
    supabase.rpc('founder_list_learnings_r2681'),
    supabase.rpc('founder_kill_candidates_r2681'),
    supabase.rpc('founder_double_down_winners_r2681'),
    supabase.rpc('founder_capital_efficiency_r2681'),
  ]);

  const betRows: Bet[] = (bets.data as Bet[]) ?? [];
  const sum: Summary | null = ((summary.data as Summary[]) ?? [])[0] ?? null;
  const tierRows: TierRow[] = (tiers.data as TierRow[]) ?? [];
  const quarterRows: QuarterRow[] = (quarters.data as QuarterRow[]) ?? [];
  const learningRows: Learning[] = (learnings.data as Learning[]) ?? [];
  const killRows: Kill[] = (kills.data as Kill[]) ?? [];
  const winRows: Win[] = (wins.data as Win[]) ?? [];
  const ownerRows: Owner[] = (owners.data as Owner[]) ?? [];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Quarterly Product Bet Evaluation</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Bet, hypothesis, cost, actual outcome, learning, continue or kill decision per quarter.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total Bets" value={sum?.total_bets ?? 0} />
        <KpiCard label="Running" value={sum?.running_bets ?? 0} />
        <KpiCard label="Succeeded" value={sum?.succeeded_bets ?? 0} />
        <KpiCard label="Failed" value={sum?.failed_bets ?? 0} />
        <KpiCard label="Win Rate" value={fmtPct(sum?.win_rate_pct)} />
        <KpiCard label="Capital Deployed" value={fmtRupees(sum?.total_cost_rupees)} />
        <KpiCard label="Avg Attainment" value={fmtPct(sum?.avg_attainment_pct)} />
      </div>

      <Section title="All Bets">
        <DataTable
          rows={betRows}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: Bet) => r.quarter },
            { key: 'bet_name', header: 'Bet', render: (r: Bet) => r.bet_name },
            { key: 'hypothesis', header: 'Hypothesis', render: (r: Bet) => r.hypothesis },
            { key: 'success_metric', header: 'Metric', render: (r: Bet) => r.success_metric },
            { key: 'target_value', header: 'Target', render: (r: Bet) => String(r.target_value) },
            { key: 'actual_value', header: 'Actual', render: (r: Bet) => r.actual_value === null ? '-' : String(r.actual_value) },
            { key: 'attainment_pct', header: 'Attainment', render: (r: Bet) => fmtPct(r.attainment_pct) },
            { key: 'cost_rupees', header: 'Cost', render: (r: Bet) => fmtRupees(r.cost_rupees) },
            { key: 'bet_tier', header: 'Tier', render: (r: Bet) => r.bet_tier },
            { key: 'status', header: 'Status', render: (r: Bet) => r.status },
            { key: 'owner', header: 'Owner', render: (r: Bet) => r.owner },
          ]}
          emptyMessage="No data"
          rowKey={(r: Bet, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="By Tier">
        <DataTable
          rows={tierRows}
          columns={[
            { key: 'bet_tier', header: 'Tier', render: (r: TierRow) => r.bet_tier },
            { key: 'bet_count', header: 'Count', render: (r: TierRow) => String(r.bet_count) },
            { key: 'total_cost', header: 'Total Cost', render: (r: TierRow) => fmtRupees(r.total_cost) },
            { key: 'win_count', header: 'Wins', render: (r: TierRow) => String(r.win_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRow, i: number) => String(r.bet_tier ?? i)}
        />
      </Section>

      <Section title="By Quarter">
        <DataTable
          rows={quarterRows}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: QuarterRow) => r.quarter },
            { key: 'bet_count', header: 'Bets', render: (r: QuarterRow) => String(r.bet_count) },
            { key: 'total_cost', header: 'Total Cost', render: (r: QuarterRow) => fmtRupees(r.total_cost) },
            { key: 'succeeded', header: 'Succeeded', render: (r: QuarterRow) => String(r.succeeded) },
            { key: 'failed', header: 'Failed', render: (r: QuarterRow) => String(r.failed) },
          ]}
          emptyMessage="No data"
          rowKey={(r: QuarterRow, i: number) => String(r.quarter ?? i)}
        />
      </Section>

      <Section title="Double-Down Winners">
        <DataTable
          rows={winRows}
          columns={[
            { key: 'bet_name', header: 'Bet', render: (r: Win) => r.bet_name },
            { key: 'attainment_pct', header: 'Attainment', render: (r: Win) => fmtPct(r.attainment_pct) },
            { key: 'cost_rupees', header: 'Cost', render: (r: Win) => fmtRupees(r.cost_rupees) },
            { key: 'learning_text', header: 'Learning', render: (r: Win) => r.learning_text },
            { key: 'confidence_pct', header: 'Confidence', render: (r: Win) => fmtPct(r.confidence_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Win, i: number) => String(r.bet_name ?? i)}
        />
      </Section>

      <Section title="Kill or Pivot Candidates">
        <DataTable
          rows={killRows}
          columns={[
            { key: 'bet_name', header: 'Bet', render: (r: Kill) => r.bet_name },
            { key: 'attainment_pct', header: 'Attainment', render: (r: Kill) => fmtPct(r.attainment_pct) },
            { key: 'cost_rupees', header: 'Cost', render: (r: Kill) => fmtRupees(r.cost_rupees) },
            { key: 'decision', header: 'Decision', render: (r: Kill) => r.decision },
            { key: 'rationale', header: 'Rationale', render: (r: Kill) => r.rationale },
          ]}
          emptyMessage="No data"
          rowKey={(r: Kill, i: number) => String(r.bet_name ?? i)}
        />
      </Section>

      <Section title="Learnings Log">
        <DataTable
          rows={learningRows}
          columns={[
            { key: 'bet_name', header: 'Bet', render: (r: Learning) => r.bet_name },
            { key: 'learning_text', header: 'Learning', render: (r: Learning) => r.learning_text },
            { key: 'decision', header: 'Decision', render: (r: Learning) => r.decision },
            { key: 'rationale', header: 'Rationale', render: (r: Learning) => r.rationale },
            { key: 'confidence_pct', header: 'Confidence', render: (r: Learning) => fmtPct(r.confidence_pct) },
            { key: 'recorded_at', header: 'Recorded', render: (r: Learning) => new Date(r.recorded_at).toLocaleDateString() },
          ]}
          emptyMessage="No data"
          rowKey={(r: Learning, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Capital Efficiency by Owner">
        <DataTable
          rows={ownerRows}
          columns={[
            { key: 'owner', header: 'Owner', render: (r: Owner) => r.owner },
            { key: 'total_cost', header: 'Capital', render: (r: Owner) => fmtRupees(r.total_cost) },
            { key: 'win_count', header: 'Wins', render: (r: Owner) => String(r.win_count) },
            { key: 'avg_attainment', header: 'Avg Attainment', render: (r: Owner) => fmtPct(r.avg_attainment) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Owner, i: number) => String(r.owner ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </div>
  );
}
