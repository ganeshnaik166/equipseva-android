import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_callbacks: number;
  total_winback_rupees: number;
  renewed_count: number;
  lost_count: number;
  winback_rate_pct: number;
  avg_call_duration: number;
  flagged_for_review: number;
};

type EngineerRow = {
  engineer_name: string;
  engineer_code: string;
  callback_count: number;
  total_winback: number;
  win_rate_pct: number;
  avg_verdict_score: number;
};

type CallbackRow = {
  callback_date: string;
  engineer_name: string;
  customer_org: string;
  customer_segment: string;
  root_cause: string;
  script_code_used: string;
  outcome: string;
  winback_value_rupees: number;
  verdict: string;
  founder_review_flag: boolean;
};

type ScriptRow = {
  script_code: string;
  script_title: string;
  root_cause_target: string;
  expected_rate_pct: number;
  actual_uses: number;
  actual_wins: number;
  actual_winback: number;
  actual_rate_pct: number;
  delta_pct: number;
};

type RootCauseRow = {
  root_cause: string;
  callback_count: number;
  win_count: number;
  loss_count: number;
  total_winback: number;
  recovery_rate_pct: number;
};

type OutcomeRow = {
  outcome: string;
  count_value: number;
  total_value: number;
  pct_of_total: number;
};

type SegmentRow = {
  customer_segment: string;
  callback_count: number;
  total_winback: number;
  avg_winback: number;
  best_engineer: string;
};

type VerdictRow = {
  verdict: string;
  count_value: number;
  total_winback: number;
  flagged_count: number;
};

function formatRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpisRes,
    engineersRes,
    callbacksRes,
    scriptsRes,
    rootCauseRes,
    outcomeRes,
    segmentRes,
    verdictRes,
  ] = await Promise.all([
    supabase.rpc('r2814_callback_kpis'),
    supabase.rpc('r2814_top_engineers'),
    supabase.rpc('r2814_recent_callbacks'),
    supabase.rpc('r2814_script_effectiveness'),
    supabase.rpc('r2814_root_cause_breakdown'),
    supabase.rpc('r2814_outcome_funnel'),
    supabase.rpc('r2814_winback_revenue'),
    supabase.rpc('r2814_verdict_summary'),
  ]);

  const kpi: KpiRow | null = (kpisRes.data?.[0] as KpiRow) ?? null;
  const engineers: EngineerRow[] = (engineersRes.data as EngineerRow[]) ?? [];
  const callbacks: CallbackRow[] = (callbacksRes.data as CallbackRow[]) ?? [];
  const scripts: ScriptRow[] = (scriptsRes.data as ScriptRow[]) ?? [];
  const rootCauses: RootCauseRow[] = (rootCauseRes.data as RootCauseRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[]) ?? [];
  const segments: SegmentRow[] = (segmentRes.data as SegmentRow[]) ?? [];
  const verdicts: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.875rem', fontWeight: 700, marginBottom: '0.5rem' }}>
          Engineer Monthly Customer Callback Recovery Script
        </h1>
        <p style={{ color: '#6b7280' }}>
          Engineer-led callback campaigns to recover churned and at-risk customers. Tracks engineer
          {' '}×{' '}callback{' '}×{' '}root cause{' '}×{' '}script used{' '}×{' '}outcome{' '}×{' '}win-back{' '}×{' '}verdict.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
        <KpiCard label="Total Callbacks" value={kpi?.total_callbacks ?? 0} />
        <KpiCard label="Total Win-back" value={formatRupees(kpi?.total_winback_rupees ?? 0)} />
        <KpiCard label="Renewed" value={kpi?.renewed_count ?? 0} />
        <KpiCard label="Lost" value={kpi?.lost_count ?? 0} />
        <KpiCard label="Win-back Rate" value={(kpi?.winback_rate_pct ?? 0) + '%'} />
        <KpiCard label="Avg Duration (min)" value={kpi?.avg_call_duration ?? 0} />
        <KpiCard label="Flagged for Review" value={kpi?.flagged_for_review ?? 0} accent="#dc2626" />
      </section>

      <Section title="Top Engineers by Win-back">
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'engineer_code', header: 'Code', render: (r: EngineerRow) => r.engineer_code },
            { key: 'callback_count', header: 'Callbacks', render: (r: EngineerRow) => r.callback_count },
            { key: 'total_winback', header: 'Win-back', render: (r: EngineerRow) => formatRupees(r.total_winback) },
            { key: 'win_rate_pct', header: 'Win Rate %', render: (r: EngineerRow) => (r.win_rate_pct ?? 0) + '%' },
            { key: 'avg_verdict_score', header: 'Verdict Score', render: (r: EngineerRow) => r.avg_verdict_score },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_code ?? i)}
        />
      </Section>

      <Section title="Script Effectiveness (Expected vs Actual)">
        <DataTable
          rows={scripts}
          columns={[
            { key: 'script_code', header: 'Script', render: (r: ScriptRow) => r.script_code },
            { key: 'script_title', header: 'Title', render: (r: ScriptRow) => r.script_title },
            { key: 'root_cause_target', header: 'Targets', render: (r: ScriptRow) => r.root_cause_target },
            { key: 'expected_rate_pct', header: 'Expected %', render: (r: ScriptRow) => r.expected_rate_pct + '%' },
            { key: 'actual_uses', header: 'Uses', render: (r: ScriptRow) => r.actual_uses },
            { key: 'actual_wins', header: 'Wins', render: (r: ScriptRow) => r.actual_wins },
            { key: 'actual_rate_pct', header: 'Actual %', render: (r: ScriptRow) => (r.actual_rate_pct ?? 0) + '%' },
            { key: 'delta_pct', header: 'Delta', render: (r: ScriptRow) => {
                const d = r.delta_pct ?? 0;
                const color = d >= 0 ? '#16a34a' : '#dc2626';
                return <span style={{ color, fontWeight: 600 }}>{(d >= 0 ? '+' : '') + d + '%'}</span>;
              } },
            { key: 'actual_winback', header: 'Win-back', render: (r: ScriptRow) => formatRupees(r.actual_winback) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ScriptRow, i: number) => String(r.script_code ?? i)}
        />
      </Section>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(420px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
        <Section title="Root Cause Breakdown">
          <DataTable
            rows={rootCauses}
            columns={[
              { key: 'root_cause', header: 'Root Cause', render: (r: RootCauseRow) => r.root_cause },
              { key: 'callback_count', header: 'Callbacks', render: (r: RootCauseRow) => r.callback_count },
              { key: 'win_count', header: 'Wins', render: (r: RootCauseRow) => r.win_count },
              { key: 'loss_count', header: 'Losses', render: (r: RootCauseRow) => r.loss_count },
              { key: 'recovery_rate_pct', header: 'Recovery %', render: (r: RootCauseRow) => (r.recovery_rate_pct ?? 0) + '%' },
              { key: 'total_winback', header: 'Win-back', render: (r: RootCauseRow) => formatRupees(r.total_winback) },
            ]}
            emptyMessage="No data"
            rowKey={(r: RootCauseRow, i: number) => String(r.root_cause ?? i)}
          />
        </Section>

        <Section title="Outcome Funnel">
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
              { key: 'count_value', header: 'Count', render: (r: OutcomeRow) => r.count_value },
              { key: 'pct_of_total', header: '% of Total', render: (r: OutcomeRow) => (r.pct_of_total ?? 0) + '%' },
              { key: 'total_value', header: 'Value', render: (r: OutcomeRow) => formatRupees(r.total_value) },
            ]}
            emptyMessage="No data"
            rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
          />
        </Section>

        <Section title="Win-back by Segment">
          <DataTable
            rows={segments}
            columns={[
              { key: 'customer_segment', header: 'Segment', render: (r: SegmentRow) => r.customer_segment },
              { key: 'callback_count', header: 'Callbacks', render: (r: SegmentRow) => r.callback_count },
              { key: 'total_winback', header: 'Total', render: (r: SegmentRow) => formatRupees(r.total_winback) },
              { key: 'avg_winback', header: 'Avg', render: (r: SegmentRow) => formatRupees(r.avg_winback) },
              { key: 'best_engineer', header: 'Best Engineer', render: (r: SegmentRow) => r.best_engineer },
            ]}
            emptyMessage="No data"
            rowKey={(r: SegmentRow, i: number) => String(r.customer_segment ?? i)}
          />
        </Section>

        <Section title="Verdict Summary">
          <DataTable
            rows={verdicts}
            columns={[
              { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
              { key: 'count_value', header: 'Count', render: (r: VerdictRow) => r.count_value },
              { key: 'total_winback', header: 'Win-back', render: (r: VerdictRow) => formatRupees(r.total_winback) },
              { key: 'flagged_count', header: 'Flagged', render: (r: VerdictRow) => r.flagged_count },
            ]}
            emptyMessage="No data"
            rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
          />
        </Section>
      </div>

      <Section title="Recent Callback Records">
        <DataTable
          rows={callbacks}
          columns={[
            { key: 'callback_date', header: 'Date', render: (r: CallbackRow) => r.callback_date },
            { key: 'engineer_name', header: 'Engineer', render: (r: CallbackRow) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r: CallbackRow) => r.customer_org },
            { key: 'customer_segment', header: 'Segment', render: (r: CallbackRow) => r.customer_segment },
            { key: 'root_cause', header: 'Root Cause', render: (r: CallbackRow) => r.root_cause },
            { key: 'script_code_used', header: 'Script', render: (r: CallbackRow) => r.script_code_used },
            { key: 'outcome', header: 'Outcome', render: (r: CallbackRow) => r.outcome },
            { key: 'winback_value_rupees', header: 'Win-back', render: (r: CallbackRow) => formatRupees(r.winback_value_rupees) },
            { key: 'verdict', header: 'Verdict', render: (r: CallbackRow) => r.verdict },
            { key: 'founder_review_flag', header: 'Flagged', render: (r: CallbackRow) => r.founder_review_flag ? 'YES' : '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: CallbackRow, i: number) => String(r.callback_date + r.engineer_name + i)}
        />
      </Section>
    </main>
  );
}

function KpiCard({ label, value, accent }: { label: string; value: string | number; accent?: string }) {
  return (
    <div style={{
      background: '#fff',
      border: '1px solid #e5e7eb',
      borderRadius: 12,
      padding: '1rem 1.25rem',
      borderLeft: accent ? '4px solid ' + accent : '1px solid #e5e7eb',
    }}>
      <div style={{ fontSize: '0.75rem', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '0.5rem' }}>
        {label}
      </div>
      <div style={{ fontSize: '1.5rem', fontWeight: 700, color: accent ?? '#111827' }}>
        {value}
      </div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '2rem' }}>
      <h2 style={{ fontSize: '1.125rem', fontWeight: 600, marginBottom: '0.75rem' }}>{title}</h2>
      {children}
    </section>
  );
}
