import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_decisions: number;
  validated_count: number;
  invalidated_count: number;
  pending_count: number;
  mixed_count: number;
  avg_surprise: number | null;
  avg_confidence_delta: number | null;
  existential_decisions: number;
};

type Entry = {
  id: string;
  entry_month: string;
  decision_title: string;
  decision_area: string;
  stakes_level: string;
  reversibility: string;
  hypothesis: string;
  outcome_status: string;
  outcome_summary: string | null;
  surprise_score: number | null;
  lesson_learned: string | null;
  pattern_tag: string | null;
  confidence_at_decision: number | null;
  confidence_post_outcome: number | null;
  decided_at: string;
};

type Pattern = {
  id: string;
  reflection_month: string;
  pattern_tag: string;
  pattern_label: string;
  occurrence_count: number;
  validated_count: number;
  invalidated_count: number;
  avg_surprise_score: number | null;
  primary_insight: string;
  corrective_action: string | null;
  monthly_theme: string;
};

type HighSurprise = {
  decision_title: string;
  decision_area: string;
  surprise_score: number;
  outcome_status: string;
  lesson_learned: string | null;
  decided_at: string;
};

type AreaValidation = {
  decision_area: string;
  total: number;
  validated: number;
  invalidated: number;
  validation_rate: number;
};

type Overdue = {
  decision_title: string;
  decision_area: string;
  stakes_level: string;
  evaluation_due_at: string;
  days_overdue: number;
};

type StakesLadder = {
  stakes_level: string;
  total: number;
  avg_surprise: number | null;
  avg_confidence_delta: number | null;
  one_way_count: number;
};

type MonthlyTheme = {
  reflection_month: string;
  monthly_theme: string;
  patterns_count: number;
  total_validated: number;
  total_invalidated: number;
  avg_surprise: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, recentRes, patternsRes, surpriseRes, areaRes, overdueRes, stakesRes, themesRes] = await Promise.all([
    supabase.rpc('rpc_decision_journal_kpis_r2705'),
    supabase.rpc('rpc_decision_journal_recent_r2705', { p_limit: 50 }),
    supabase.rpc('rpc_decision_journal_patterns_r2705'),
    supabase.rpc('rpc_decision_journal_high_surprise_r2705', { p_threshold: 5 }),
    supabase.rpc('rpc_decision_journal_area_validation_r2705'),
    supabase.rpc('rpc_decision_journal_overdue_evaluations_r2705'),
    supabase.rpc('rpc_decision_journal_stakes_ladder_r2705'),
    supabase.rpc('rpc_decision_journal_monthly_themes_r2705'),
  ]);

  const kpis: Kpis | null = Array.isArray(kpisRes.data) ? (kpisRes.data[0] as Kpis) : (kpisRes.data as Kpis | null);
  const recent: Entry[] = (recentRes.data as Entry[]) ?? [];
  const patterns: Pattern[] = (patternsRes.data as Pattern[]) ?? [];
  const surprises: HighSurprise[] = (surpriseRes.data as HighSurprise[]) ?? [];
  const areas: AreaValidation[] = (areaRes.data as AreaValidation[]) ?? [];
  const overdue: Overdue[] = (overdueRes.data as Overdue[]) ?? [];
  const stakes: StakesLadder[] = (stakesRes.data as StakesLadder[]) ?? [];
  const themes: MonthlyTheme[] = (themesRes.data as MonthlyTheme[]) ?? [];

  const kpiCards = [
    { label: 'Total decisions', value: kpis?.total_decisions ?? 0 },
    { label: 'Validated', value: kpis?.validated_count ?? 0 },
    { label: 'Invalidated', value: kpis?.invalidated_count ?? 0 },
    { label: 'Pending', value: kpis?.pending_count ?? 0 },
    { label: 'Mixed', value: kpis?.mixed_count ?? 0 },
    { label: 'Avg surprise', value: kpis?.avg_surprise ?? 0 },
    { label: 'Confidence delta', value: kpis?.avg_confidence_delta ?? 0 },
    { label: 'Existential calls', value: kpis?.existential_decisions ?? 0 },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
          Founder Monthly Self Decision Journal
        </h1>
        <p style={{ color: '#555', fontSize: '14px' }}>
          Decision × stakes × hypothesis × outcome × surprise × lesson × pattern.
          Surface every call &gt;= 5 surprise score and overdue evaluations.
        </p>
      </header>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>KPIs</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px' }}>
          {kpiCards.map((c) => (
            <div key={c.label} style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '14px', background: '#fff' }}>
              <div style={{ fontSize: '12px', color: '#6b7280', marginBottom: '4px' }}>{c.label}</div>
              <div style={{ fontSize: '22px', fontWeight: 700 }}>{String(c.value)}</div>
            </div>
          ))}
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent decisions</h2>
        <DataTable
          rows={recent}
          columns={[
            { key: 'decision_title', header: 'Decision', render: (r: Entry) => r.decision_title },
            { key: 'decision_area', header: 'Area', render: (r: Entry) => r.decision_area },
            { key: 'stakes_level', header: 'Stakes', render: (r: Entry) => r.stakes_level },
            { key: 'reversibility', header: 'Reversibility', render: (r: Entry) => r.reversibility },
            { key: 'outcome_status', header: 'Outcome', render: (r: Entry) => r.outcome_status },
            { key: 'surprise_score', header: 'Surprise', render: (r: Entry) => (r.surprise_score ?? '-') },
            { key: 'pattern_tag', header: 'Pattern', render: (r: Entry) => r.pattern_tag ?? '-' },
            { key: 'decided_at', header: 'Decided', render: (r: Entry) => new Date(r.decided_at).toLocaleDateString() },
          ]}
          emptyMessage="No data"
          rowKey={(r: Entry, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>High-surprise outcomes (score &gt;= 5)</h2>
        <DataTable
          rows={surprises}
          columns={[
            { key: 'decision_title', header: 'Decision', render: (r: HighSurprise) => r.decision_title },
            { key: 'decision_area', header: 'Area', render: (r: HighSurprise) => r.decision_area },
            { key: 'surprise_score', header: 'Surprise', render: (r: HighSurprise) => r.surprise_score },
            { key: 'outcome_status', header: 'Outcome', render: (r: HighSurprise) => r.outcome_status },
            { key: 'lesson_learned', header: 'Lesson', render: (r: HighSurprise) => r.lesson_learned ?? '-' },
            { key: 'decided_at', header: 'Decided', render: (r: HighSurprise) => new Date(r.decided_at).toLocaleDateString() },
          ]}
          emptyMessage="No data"
          rowKey={(r: HighSurprise, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Pattern reflections</h2>
        <DataTable
          rows={patterns}
          columns={[
            { key: 'reflection_month', header: 'Month', render: (r: Pattern) => r.reflection_month },
            { key: 'pattern_label', header: 'Pattern', render: (r: Pattern) => r.pattern_label },
            { key: 'monthly_theme', header: 'Theme', render: (r: Pattern) => r.monthly_theme },
            { key: 'occurrence_count', header: 'Seen', render: (r: Pattern) => r.occurrence_count },
            { key: 'validated_count', header: 'Validated', render: (r: Pattern) => r.validated_count },
            { key: 'invalidated_count', header: 'Invalidated', render: (r: Pattern) => r.invalidated_count },
            { key: 'avg_surprise_score', header: 'Avg surprise', render: (r: Pattern) => r.avg_surprise_score ?? '-' },
            { key: 'primary_insight', header: 'Insight', render: (r: Pattern) => r.primary_insight },
            { key: 'corrective_action', header: 'Action', render: (r: Pattern) => r.corrective_action ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Pattern, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Validation rate by area</h2>
        <DataTable
          rows={areas}
          columns={[
            { key: 'decision_area', header: 'Area', render: (r: AreaValidation) => r.decision_area },
            { key: 'total', header: 'Total', render: (r: AreaValidation) => r.total },
            { key: 'validated', header: 'Validated', render: (r: AreaValidation) => r.validated },
            { key: 'invalidated', header: 'Invalidated', render: (r: AreaValidation) => r.invalidated },
            { key: 'validation_rate', header: 'Validation %', render: (r: AreaValidation) => `${r.validation_rate}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: AreaValidation, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Overdue evaluations</h2>
        <DataTable
          rows={overdue}
          columns={[
            { key: 'decision_title', header: 'Decision', render: (r: Overdue) => r.decision_title },
            { key: 'decision_area', header: 'Area', render: (r: Overdue) => r.decision_area },
            { key: 'stakes_level', header: 'Stakes', render: (r: Overdue) => r.stakes_level },
            { key: 'evaluation_due_at', header: 'Due', render: (r: Overdue) => new Date(r.evaluation_due_at).toLocaleDateString() },
            { key: 'days_overdue', header: 'Days overdue', render: (r: Overdue) => r.days_overdue },
          ]}
          emptyMessage="No data"
          rowKey={(r: Overdue, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Stakes ladder</h2>
        <DataTable
          rows={stakes}
          columns={[
            { key: 'stakes_level', header: 'Stakes', render: (r: StakesLadder) => r.stakes_level },
            { key: 'total', header: 'Total', render: (r: StakesLadder) => r.total },
            { key: 'avg_surprise', header: 'Avg surprise', render: (r: StakesLadder) => r.avg_surprise ?? '-' },
            { key: 'avg_confidence_delta', header: 'Confidence delta', render: (r: StakesLadder) => r.avg_confidence_delta ?? '-' },
            { key: 'one_way_count', header: 'One-way doors', render: (r: StakesLadder) => r.one_way_count },
          ]}
          emptyMessage="No data"
          rowKey={(r: StakesLadder, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Monthly themes</h2>
        <DataTable
          rows={themes}
          columns={[
            { key: 'reflection_month', header: 'Month', render: (r: MonthlyTheme) => r.reflection_month },
            { key: 'monthly_theme', header: 'Theme', render: (r: MonthlyTheme) => r.monthly_theme },
            { key: 'patterns_count', header: 'Patterns', render: (r: MonthlyTheme) => r.patterns_count },
            { key: 'total_validated', header: 'Validated', render: (r: MonthlyTheme) => r.total_validated },
            { key: 'total_invalidated', header: 'Invalidated', render: (r: MonthlyTheme) => r.total_invalidated },
            { key: 'avg_surprise', header: 'Avg surprise', render: (r: MonthlyTheme) => r.avg_surprise ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: MonthlyTheme, i: number) => String(i)}
        />
      </section>
    </main>
  );
}
