import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_jobs: number;
  avg_buffer_minutes: number;
  sla_breaches: number;
  actionable_share_pct: number;
  monthly_minutes_savable: number;
  top_cause: string;
};

type AttributionRow = {
  id: string;
  month_label: string;
  job_code: string;
  customer_org: string;
  engineer_name: string;
  scheduled_at: string;
  actual_arrival_at: string;
  buffer_minutes: number;
  delay_cause: string;
  actionability: string;
  prevention_lever: string;
  outcome: string;
  customer_satisfaction: number;
};

type CauseSummary = {
  id: string;
  month_label: string;
  delay_cause: string;
  occurrence_count: number;
  avg_buffer_minutes: number;
  sla_breach_count: number;
  actionable_share_pct: number;
  top_prevention_lever: string;
  est_monthly_minutes_savable: number;
};

type EngineerRow = {
  engineer_name: string;
  jobs: number;
  avg_buffer_minutes: number;
  breaches: number;
  csat_avg: number;
};

type ActionabilityRow = {
  actionability: string;
  jobs: number;
  avg_buffer_minutes: number;
  share_pct: number;
};

type OutcomeRow = {
  outcome: string;
  jobs: number;
  avg_csat: number;
  share_pct: number;
};

type LeverRow = {
  prevention_lever: string;
  occurrence_count: number;
  minutes_savable: number;
};

type BreachRow = {
  job_code: string;
  customer_org: string;
  engineer_name: string;
  buffer_minutes: number;
  delay_cause: string;
  prevention_lever: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, rowsRes, summaryRes, leaderRes, actionRes, outcomeRes, leverRes, breachRes] = await Promise.all([
    supabase.rpc('founder_r2840_kpis'),
    supabase.rpc('founder_r2840_attribution_rows'),
    supabase.rpc('founder_r2840_cause_summary'),
    supabase.rpc('founder_r2840_engineer_leaderboard'),
    supabase.rpc('founder_r2840_actionability_breakdown'),
    supabase.rpc('founder_r2840_outcome_distribution'),
    supabase.rpc('founder_r2840_top_prevention_levers'),
    supabase.rpc('founder_r2840_sla_breach_jobs'),
  ]);

  const kpis: Kpis | null = Array.isArray(kpisRes.data) ? kpisRes.data[0] ?? null : null;
  const rows: AttributionRow[] = (rowsRes.data ?? []) as AttributionRow[];
  const summary: CauseSummary[] = (summaryRes.data ?? []) as CauseSummary[];
  const leaderboard: EngineerRow[] = (leaderRes.data ?? []) as EngineerRow[];
  const actionability: ActionabilityRow[] = (actionRes.data ?? []) as ActionabilityRow[];
  const outcomes: OutcomeRow[] = (outcomeRes.data ?? []) as OutcomeRow[];
  const levers: LeverRow[] = (leverRes.data ?? []) as LeverRow[];
  const breaches: BreachRow[] = (breachRes.data ?? []) as BreachRow[];

  return (
    <div style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Customer Monthly Engineer Arrival Buffer & Cause Attribution
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Round r2840 — job × delay cause × buffer minutes × actionability × prevention × outcome.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total Jobs" value={kpis?.total_jobs ?? 0} />
        <KpiCard label="Avg Buffer (min)" value={kpis?.avg_buffer_minutes ?? 0} />
        <KpiCard label="SLA Breaches" value={kpis?.sla_breaches ?? 0} />
        <KpiCard label="Actionable Share %" value={kpis?.actionable_share_pct ?? 0} />
        <KpiCard label="Minutes Savable / Month" value={kpis?.monthly_minutes_savable ?? 0} />
        <KpiCard label="Top Cause" value={kpis?.top_cause ?? '—'} />
      </div>

      <Section title="Job-level Arrival Buffer Attribution">
        <DataTable
          rows={rows}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: AttributionRow) => r.job_code },
            { key: 'customer_org', header: 'Customer', render: (r: AttributionRow) => r.customer_org },
            { key: 'engineer_name', header: 'Engineer', render: (r: AttributionRow) => r.engineer_name },
            { key: 'buffer_minutes', header: 'Buffer (min)', render: (r: AttributionRow) => r.buffer_minutes },
            { key: 'delay_cause', header: 'Delay Cause', render: (r: AttributionRow) => r.delay_cause },
            { key: 'actionability', header: 'Actionability', render: (r: AttributionRow) => r.actionability },
            { key: 'prevention_lever', header: 'Prevention Lever', render: (r: AttributionRow) => r.prevention_lever },
            { key: 'outcome', header: 'Outcome', render: (r: AttributionRow) => r.outcome },
            { key: 'customer_satisfaction', header: 'CSAT', render: (r: AttributionRow) => r.customer_satisfaction },
          ]}
          emptyMessage="No data"
          rowKey={(r: AttributionRow, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Cause Summary (monthly roll-up)">
        <DataTable
          rows={summary}
          columns={[
            { key: 'delay_cause', header: 'Cause', render: (r: CauseSummary) => r.delay_cause },
            { key: 'occurrence_count', header: 'Occurrences', render: (r: CauseSummary) => r.occurrence_count },
            { key: 'avg_buffer_minutes', header: 'Avg Buffer (min)', render: (r: CauseSummary) => r.avg_buffer_minutes },
            { key: 'sla_breach_count', header: 'SLA Breaches', render: (r: CauseSummary) => r.sla_breach_count },
            { key: 'actionable_share_pct', header: 'Actionable %', render: (r: CauseSummary) => r.actionable_share_pct },
            { key: 'top_prevention_lever', header: 'Top Lever', render: (r: CauseSummary) => r.top_prevention_lever },
            { key: 'est_monthly_minutes_savable', header: 'Minutes Savable', render: (r: CauseSummary) => r.est_monthly_minutes_savable },
          ]}
          emptyMessage="No data"
          rowKey={(r: CauseSummary, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Engineer Leaderboard (worst buffer first)">
        <DataTable
          rows={leaderboard}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => r.engineer_name },
            { key: 'jobs', header: 'Jobs', render: (r: EngineerRow) => r.jobs },
            { key: 'avg_buffer_minutes', header: 'Avg Buffer (min)', render: (r: EngineerRow) => r.avg_buffer_minutes },
            { key: 'breaches', header: 'Breaches', render: (r: EngineerRow) => r.breaches },
            { key: 'csat_avg', header: 'CSAT avg', render: (r: EngineerRow) => r.csat_avg },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
        />
      </Section>

      <Section title="Actionability Breakdown">
        <DataTable
          rows={actionability}
          columns={[
            { key: 'actionability', header: 'Actionability', render: (r: ActionabilityRow) => r.actionability },
            { key: 'jobs', header: 'Jobs', render: (r: ActionabilityRow) => r.jobs },
            { key: 'avg_buffer_minutes', header: 'Avg Buffer (min)', render: (r: ActionabilityRow) => r.avg_buffer_minutes },
            { key: 'share_pct', header: 'Share %', render: (r: ActionabilityRow) => r.share_pct },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionabilityRow, i: number) => String(r.actionability ?? i)}
        />
      </Section>

      <Section title="Outcome Distribution">
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
            { key: 'jobs', header: 'Jobs', render: (r: OutcomeRow) => r.jobs },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: OutcomeRow) => r.avg_csat },
            { key: 'share_pct', header: 'Share %', render: (r: OutcomeRow) => r.share_pct },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
        />
      </Section>

      <Section title="Top Prevention Levers (by minutes savable)">
        <DataTable
          rows={levers}
          columns={[
            { key: 'prevention_lever', header: 'Lever', render: (r: LeverRow) => r.prevention_lever },
            { key: 'occurrence_count', header: 'Occurrences', render: (r: LeverRow) => r.occurrence_count },
            { key: 'minutes_savable', header: 'Minutes Savable', render: (r: LeverRow) => r.minutes_savable },
          ]}
          emptyMessage="No data"
          rowKey={(r: LeverRow, i: number) => String(r.prevention_lever ?? i)}
        />
      </Section>

      <Section title="SLA Breach & Rescheduled Jobs">
        <DataTable
          rows={breaches}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: BreachRow) => r.job_code },
            { key: 'customer_org', header: 'Customer', render: (r: BreachRow) => r.customer_org },
            { key: 'engineer_name', header: 'Engineer', render: (r: BreachRow) => r.engineer_name },
            { key: 'buffer_minutes', header: 'Buffer (min)', render: (r: BreachRow) => r.buffer_minutes },
            { key: 'delay_cause', header: 'Cause', render: (r: BreachRow) => r.delay_cause },
            { key: 'prevention_lever', header: 'Lever', render: (r: BreachRow) => r.prevention_lever },
          ]}
          emptyMessage="No data"
          rowKey={(r: BreachRow, i: number) => String(r.job_code ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </section>
  );
}