import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PortfolioSummary = {
  total_bets: number;
  total_capital_inr: number;
  total_team_weeks: number;
  wins: number;
  partial_wins: number;
  losses: number;
  kills: number;
  avg_outcome_score: number;
  win_rate_pct: number;
};

type RankedBet = {
  bet_name: string;
  quarter: string;
  outcome: string;
  outcome_score: number;
  capital_deployed_inr: number;
  pattern_tag: string;
  next_bet_implication: string;
};

type CategoryRow = {
  bet_category: string;
  bets: number;
  capital_inr: number;
  avg_score: number;
  wins: number;
};

type PatternRow = {
  pattern_label: string;
  observed_in_bets: number;
  confidence: string;
  capital_to_redirect_inr: number;
  recommended_action: string;
};

type LossRow = {
  bet_name: string;
  outcome: string;
  capital_burned_inr: number;
  why_summary: string;
  lesson: string;
  next_bet_implication: string;
};

type EfficiencyRow = {
  bet_name: string;
  capital_lakh: number;
  outcome_score: number;
  score_per_lakh: number;
};

type ReallocationRow = {
  pattern_label: string;
  recommended_action: string;
  capital_to_redirect_inr: number;
  confidence: string;
};

function inr(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(v);
}

function lakh(n: number | null | undefined): string {
  const v = Number(n ?? 0) / 100000;
  return `${'₹'}${v.toFixed(2)}L`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, rankedRes, categoryRes, patternsRes, lossesRes, efficiencyRes, reallocRes] = await Promise.all([
    supabase.rpc('founder_bet_portfolio_summary_r2841'),
    supabase.rpc('founder_bet_ranked_r2841'),
    supabase.rpc('founder_bet_by_category_r2841'),
    supabase.rpc('founder_bet_top_patterns_r2841'),
    supabase.rpc('founder_bet_losses_lessons_r2841'),
    supabase.rpc('founder_bet_capital_efficiency_r2841'),
    supabase.rpc('founder_bet_next_quarter_reallocation_r2841'),
  ]);

  const summary: PortfolioSummary | null = (summaryRes.data?.[0] as PortfolioSummary) ?? null;
  const ranked: RankedBet[] = (rankedRes.data as RankedBet[]) ?? [];
  const categories: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const patterns: PatternRow[] = (patternsRes.data as PatternRow[]) ?? [];
  const losses: LossRow[] = (lossesRes.data as LossRow[]) ?? [];
  const efficiency: EfficiencyRow[] = (efficiencyRes.data as EfficiencyRow[]) ?? [];
  const realloc: ReallocationRow[] = (reallocRes.data as ReallocationRow[]) ?? [];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700, margin: 0 }}>Quarterly Strategic Bet Postmortem</h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Bet → hypothesis → outcome → why → lesson → pattern → next-bet implication.
          Founder-only review surface for capital reallocation decisions.
        </p>
      </header>

      {summary && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 28 }}>
          <KPI label="Total Bets" value={String(summary.total_bets ?? 0)} />
          <KPI label="Capital Deployed" value={inr(summary.total_capital_inr)} />
          <KPI label="Team Weeks" value={String(summary.total_team_weeks ?? 0)} />
          <KPI label="Wins" value={String(summary.wins ?? 0)} />
          <KPI label="Partial Wins" value={String(summary.partial_wins ?? 0)} />
          <KPI label="Losses" value={String(summary.losses ?? 0)} />
          <KPI label="Kills" value={String(summary.kills ?? 0)} />
          <KPI label="Avg Score" value={String(summary.avg_outcome_score ?? 0)} />
          <KPI label="Win Rate %" value={`${summary.win_rate_pct ?? 0}%`} />
        </section>
      )}

      <Section title="Bets ranked by outcome score">
        <DataTable
          rows={ranked}
          columns={[
            { key: 'bet_name', header: 'Bet', render: (r: RankedBet) => r.bet_name },
            { key: 'quarter', header: 'Quarter', render: (r: RankedBet) => r.quarter },
            { key: 'outcome', header: 'Outcome', render: (r: RankedBet) => r.outcome },
            { key: 'outcome_score', header: 'Score', render: (r: RankedBet) => String(r.outcome_score) },
            { key: 'capital_deployed_inr', header: 'Capital', render: (r: RankedBet) => inr(r.capital_deployed_inr) },
            { key: 'pattern_tag', header: 'Pattern', render: (r: RankedBet) => r.pattern_tag },
            { key: 'next_bet_implication', header: 'Next-bet implication', render: (r: RankedBet) => r.next_bet_implication },
          ]}
          emptyMessage="No data"
          rowKey={(r: RankedBet, i: number) => String((r as { id?: string }).id ?? i)}
        />
      </Section>

      <Section title="Category breakdown">
        <DataTable
          rows={categories}
          columns={[
            { key: 'bet_category', header: 'Category', render: (r: CategoryRow) => r.bet_category },
            { key: 'bets', header: 'Bets', render: (r: CategoryRow) => String(r.bets) },
            { key: 'capital_inr', header: 'Capital', render: (r: CategoryRow) => inr(r.capital_inr) },
            { key: 'avg_score', header: 'Avg score', render: (r: CategoryRow) => String(r.avg_score) },
            { key: 'wins', header: 'Wins', render: (r: CategoryRow) => String(r.wins) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CategoryRow, i: number) => String((r as { id?: string }).id ?? i)}
        />
      </Section>

      <Section title="Top patterns to act on">
        <DataTable
          rows={patterns}
          columns={[
            { key: 'pattern_label', header: 'Pattern', render: (r: PatternRow) => r.pattern_label },
            { key: 'observed_in_bets', header: 'Seen in bets', render: (r: PatternRow) => String(r.observed_in_bets) },
            { key: 'confidence', header: 'Confidence', render: (r: PatternRow) => r.confidence },
            { key: 'capital_to_redirect_inr', header: 'Capital to redirect', render: (r: PatternRow) => inr(r.capital_to_redirect_inr) },
            { key: 'recommended_action', header: 'Recommended action', render: (r: PatternRow) => r.recommended_action },
          ]}
          emptyMessage="No data"
          rowKey={(r: PatternRow, i: number) => String((r as { id?: string }).id ?? i)}
        />
      </Section>

      <Section title="Losses, kills, flats - lessons captured">
        <DataTable
          rows={losses}
          columns={[
            { key: 'bet_name', header: 'Bet', render: (r: LossRow) => r.bet_name },
            { key: 'outcome', header: 'Outcome', render: (r: LossRow) => r.outcome },
            { key: 'capital_burned_inr', header: 'Capital burned', render: (r: LossRow) => inr(r.capital_burned_inr) },
            { key: 'why_summary', header: 'Why', render: (r: LossRow) => r.why_summary },
            { key: 'lesson', header: 'Lesson', render: (r: LossRow) => r.lesson },
            { key: 'next_bet_implication', header: 'Next-bet implication', render: (r: LossRow) => r.next_bet_implication },
          ]}
          emptyMessage="No data"
          rowKey={(r: LossRow, i: number) => String((r as { id?: string }).id ?? i)}
        />
      </Section>

      <Section title="Capital efficiency (score per lakh deployed)">
        <DataTable
          rows={efficiency}
          columns={[
            { key: 'bet_name', header: 'Bet', render: (r: EfficiencyRow) => r.bet_name },
            { key: 'capital_lakh', header: 'Capital', render: (r: EfficiencyRow) => lakh(r.capital_lakh * 100000) },
            { key: 'outcome_score', header: 'Score', render: (r: EfficiencyRow) => String(r.outcome_score) },
            { key: 'score_per_lakh', header: 'Score per lakh', render: (r: EfficiencyRow) => String(r.score_per_lakh) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EfficiencyRow, i: number) => String((r as { id?: string }).id ?? i)}
        />
      </Section>

      <Section title="Next-quarter capital reallocation">
        <DataTable
          rows={realloc}
          columns={[
            { key: 'pattern_label', header: 'Pattern', render: (r: ReallocationRow) => r.pattern_label },
            { key: 'recommended_action', header: 'Recommended action', render: (r: ReallocationRow) => r.recommended_action },
            { key: 'capital_to_redirect_inr', header: 'Capital to redirect', render: (r: ReallocationRow) => inr(r.capital_to_redirect_inr) },
            { key: 'confidence', header: 'Confidence', render: (r: ReallocationRow) => r.confidence },
          ]}
          emptyMessage="No data"
          rowKey={(r: ReallocationRow, i: number) => String((r as { id?: string }).id ?? i)}
        />
      </Section>
    </div>
  );
}

function KPI({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 10, padding: 14, background: '#fff' }}>
      <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '0 0 10px' }}>{title}</h2>
      {children}
    </section>
  );
}
