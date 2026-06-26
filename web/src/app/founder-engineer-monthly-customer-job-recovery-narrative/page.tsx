import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_failed_jobs: number;
  total_won_back: number;
  total_churned: number;
  total_winback_revenue: number;
  total_refunds_paid: number;
  avg_pulse_score: number;
  exemplary_engineers: number;
  intervene_engineers: number;
};

type PulseRow = {
  engineer_code: string;
  engineer_name: string;
  engineer_tier: string;
  failed_jobs_count: number;
  won_back_count: number;
  churned_count: number;
  total_winback_revenue_rupees: number;
  pulse_score: number;
  trend_vs_prev_month: string;
  founder_verdict: string;
  founder_note: string;
};

type NarrativeRow = {
  failed_job_code: string;
  engineer_code: string;
  engineer_name: string;
  customer_name: string;
  customer_segment: string;
  failure_root_cause: string;
  failure_severity: string;
  recovery_action: string;
  recovery_outcome: string;
  winback_revenue_rupees: number;
  pulse_score: number;
  founder_verdict: string;
  narrative_summary: string;
};

type RootCauseRow = {
  failure_root_cause: string;
  failures: number;
  won_back: number;
  churned: number;
  winback_revenue_rupees: number;
};

type SegmentRow = {
  customer_segment: string;
  failures: number;
  won_back: number;
  at_risk: number;
  churned: number;
  winback_revenue_rupees: number;
};

type WatchRow = {
  engineer_code: string;
  engineer_name: string;
  engineer_tier: string;
  pulse_score: number;
  failed_jobs_count: number;
  churned_count: number;
  founder_verdict: string;
  founder_note: string;
};

type TopWinRow = {
  failed_job_code: string;
  engineer_name: string;
  customer_name: string;
  recovery_action: string;
  winback_revenue_rupees: number;
  pulse_score: number;
  narrative_summary: string;
};

type VerdictRow = {
  founder_verdict: string;
  engineers: number;
  avg_pulse: number;
  total_winback_revenue: number;
};

function fmtRupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const month = '2026-06-01';

  const [kpiRes, pulseRes, narrRes, rootRes, segRes, watchRes, topRes, verdictRes] = await Promise.all([
    supabase.rpc('founder_r2874_recovery_kpis', { p_month: month }),
    supabase.rpc('founder_r2874_engineer_pulse', { p_month: month }),
    supabase.rpc('founder_r2874_recovery_narratives', { p_month: month }),
    supabase.rpc('founder_r2874_root_cause_mix', { p_month: month }),
    supabase.rpc('founder_r2874_segment_outcomes', { p_month: month }),
    supabase.rpc('founder_r2874_watchlist', { p_month: month }),
    supabase.rpc('founder_r2874_top_winbacks', { p_month: month, p_limit: 5 }),
    supabase.rpc('founder_r2874_verdict_mix', { p_month: month }),
  ]);

  const kpi: KpiRow = (kpiRes.data?.[0] as KpiRow) ?? {
    total_failed_jobs: 0,
    total_won_back: 0,
    total_churned: 0,
    total_winback_revenue: 0,
    total_refunds_paid: 0,
    avg_pulse_score: 0,
    exemplary_engineers: 0,
    intervene_engineers: 0,
  };
  const pulse: PulseRow[] = (pulseRes.data as PulseRow[]) ?? [];
  const narratives: NarrativeRow[] = (narrRes.data as NarrativeRow[]) ?? [];
  const rootCauses: RootCauseRow[] = (rootRes.data as RootCauseRow[]) ?? [];
  const segments: SegmentRow[] = (segRes.data as SegmentRow[]) ?? [];
  const watch: WatchRow[] = (watchRes.data as WatchRow[]) ?? [];
  const topWins: TopWinRow[] = (topRes.data as TopWinRow[]) ?? [];
  const verdicts: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];

  const winRate = kpi.total_failed_jobs > 0
    ? Math.round((kpi.total_won_back / kpi.total_failed_jobs) * 100)
    : 0;

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, margin: 0 }}>
          Engineer Monthly Customer Job Recovery Narrative
        </h1>
        <p style={{ color: '#555', marginTop: '6px' }}>
          Round r2874 · engineer x failed job x recovery story x customer winback x pulse x verdict · month {month}
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <Kpi label="Failed jobs" value={String(kpi.total_failed_jobs)} />
        <Kpi label="Won back" value={String(kpi.total_won_back)} />
        <Kpi label="Churned" value={String(kpi.total_churned)} />
        <Kpi label="Win rate" value={winRate + '%'} />
        <Kpi label="Winback revenue" value={fmtRupees(kpi.total_winback_revenue)} />
        <Kpi label="Refunds paid" value={fmtRupees(kpi.total_refunds_paid)} />
        <Kpi label="Avg pulse" value={String(kpi.avg_pulse_score)} />
        <Kpi label="Exemplary / Intervene" value={kpi.exemplary_engineers + ' / ' + kpi.intervene_engineers} />
      </section>

      <Section title="Engineer pulse (sorted by score)">
        <DataTable
          rows={pulse}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: PulseRow) => r.engineer_code + ' – ' + r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: PulseRow) => r.engineer_tier },
            { key: 'failed_jobs_count', header: 'Failures', render: (r: PulseRow) => r.failed_jobs_count },
            { key: 'won_back_count', header: 'Won back', render: (r: PulseRow) => r.won_back_count },
            { key: 'churned_count', header: 'Churned', render: (r: PulseRow) => r.churned_count },
            { key: 'total_winback_revenue_rupees', header: 'Winback revenue', render: (r: PulseRow) => fmtRupees(r.total_winback_revenue_rupees) },
            { key: 'pulse_score', header: 'Pulse', render: (r: PulseRow) => r.pulse_score },
            { key: 'trend_vs_prev_month', header: 'Trend', render: (r: PulseRow) => r.trend_vs_prev_month },
            { key: 'founder_verdict', header: 'Verdict', render: (r: PulseRow) => r.founder_verdict },
            { key: 'founder_note', header: 'Note', render: (r: PulseRow) => r.founder_note },
          ]}
          emptyMessage="No data"
          rowKey={(r: PulseRow, i: number) => String(r.engineer_code ?? i)}
        />
      </Section>

      <Section title="Recovery narratives">
        <DataTable
          rows={narratives}
          columns={[
            { key: 'failed_job_code', header: 'Job', render: (r: NarrativeRow) => r.failed_job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: NarrativeRow) => r.engineer_code + ' – ' + r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: NarrativeRow) => r.customer_name + ' (' + r.customer_segment + ')' },
            { key: 'failure_root_cause', header: 'Root cause', render: (r: NarrativeRow) => r.failure_root_cause },
            { key: 'failure_severity', header: 'Severity', render: (r: NarrativeRow) => r.failure_severity },
            { key: 'recovery_action', header: 'Action', render: (r: NarrativeRow) => r.recovery_action },
            { key: 'recovery_outcome', header: 'Outcome', render: (r: NarrativeRow) => r.recovery_outcome },
            { key: 'winback_revenue_rupees', header: 'Winback', render: (r: NarrativeRow) => fmtRupees(r.winback_revenue_rupees) },
            { key: 'pulse_score', header: 'Pulse', render: (r: NarrativeRow) => r.pulse_score },
            { key: 'founder_verdict', header: 'Verdict', render: (r: NarrativeRow) => r.founder_verdict },
            { key: 'narrative_summary', header: 'Story', render: (r: NarrativeRow) => r.narrative_summary },
          ]}
          emptyMessage="No data"
          rowKey={(r: NarrativeRow, i: number) => String(r.failed_job_code ?? i)}
        />
      </Section>

      <Section title="Top winbacks">
        <DataTable
          rows={topWins}
          columns={[
            { key: 'failed_job_code', header: 'Job', render: (r: TopWinRow) => r.failed_job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: TopWinRow) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: TopWinRow) => r.customer_name },
            { key: 'recovery_action', header: 'Action', render: (r: TopWinRow) => r.recovery_action },
            { key: 'winback_revenue_rupees', header: 'Winback', render: (r: TopWinRow) => fmtRupees(r.winback_revenue_rupees) },
            { key: 'pulse_score', header: 'Pulse', render: (r: TopWinRow) => r.pulse_score },
            { key: 'narrative_summary', header: 'Story', render: (r: TopWinRow) => r.narrative_summary },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopWinRow, i: number) => String(r.failed_job_code ?? i)}
        />
      </Section>

      <Section title="Root-cause mix">
        <DataTable
          rows={rootCauses}
          columns={[
            { key: 'failure_root_cause', header: 'Root cause', render: (r: RootCauseRow) => r.failure_root_cause },
            { key: 'failures', header: 'Failures', render: (r: RootCauseRow) => r.failures },
            { key: 'won_back', header: 'Won back', render: (r: RootCauseRow) => r.won_back },
            { key: 'churned', header: 'Churned', render: (r: RootCauseRow) => r.churned },
            { key: 'winback_revenue_rupees', header: 'Winback revenue', render: (r: RootCauseRow) => fmtRupees(r.winback_revenue_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: RootCauseRow, i: number) => String(r.failure_root_cause ?? i)}
        />
      </Section>

      <Section title="Customer segment outcomes">
        <DataTable
          rows={segments}
          columns={[
            { key: 'customer_segment', header: 'Segment', render: (r: SegmentRow) => r.customer_segment },
            { key: 'failures', header: 'Failures', render: (r: SegmentRow) => r.failures },
            { key: 'won_back', header: 'Won back', render: (r: SegmentRow) => r.won_back },
            { key: 'at_risk', header: 'At risk', render: (r: SegmentRow) => r.at_risk },
            { key: 'churned', header: 'Churned', render: (r: SegmentRow) => r.churned },
            { key: 'winback_revenue_rupees', header: 'Winback revenue', render: (r: SegmentRow) => fmtRupees(r.winback_revenue_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SegmentRow, i: number) => String(r.customer_segment ?? i)}
        />
      </Section>

      <Section title="Watchlist & intervene engineers">
        <DataTable
          rows={watch}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: WatchRow) => r.engineer_code + ' – ' + r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: WatchRow) => r.engineer_tier },
            { key: 'pulse_score', header: 'Pulse', render: (r: WatchRow) => r.pulse_score },
            { key: 'failed_jobs_count', header: 'Failures', render: (r: WatchRow) => r.failed_jobs_count },
            { key: 'churned_count', header: 'Churned', render: (r: WatchRow) => r.churned_count },
            { key: 'founder_verdict', header: 'Verdict', render: (r: WatchRow) => r.founder_verdict },
            { key: 'founder_note', header: 'Note', render: (r: WatchRow) => r.founder_note },
          ]}
          emptyMessage="No data"
          rowKey={(r: WatchRow, i: number) => String(r.engineer_code ?? i)}
        />
      </Section>

      <Section title="Verdict mix">
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'founder_verdict', header: 'Verdict', render: (r: VerdictRow) => r.founder_verdict },
            { key: 'engineers', header: 'Engineers', render: (r: VerdictRow) => r.engineers },
            { key: 'avg_pulse', header: 'Avg pulse', render: (r: VerdictRow) => r.avg_pulse },
            { key: 'total_winback_revenue', header: 'Total winback', render: (r: VerdictRow) => fmtRupees(r.total_winback_revenue) },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictRow, i: number) => String(r.founder_verdict ?? i)}
        />
      </Section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: '10px', padding: '14px 16px' }}>
      <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</div>
      <div style={{ fontSize: '22px', fontWeight: 700, marginTop: '4px' }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: '28px' }}>
      <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '10px' }}>{title}</h2>
      {children}
    </section>
  );
}
