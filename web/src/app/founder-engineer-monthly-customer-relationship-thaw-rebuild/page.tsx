import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Attempt = {
  id: string;
  engineer_handle: string;
  engineer_city: string;
  customer_handle: string;
  customer_segment: string;
  cold_since_days: number;
  thaw_step: string;
  outcome: string;
  revenue_recovered_rupees: number;
  tier_verdict: string;
  attempted_at: string;
};

type Verdict = {
  id: string;
  engineer_handle: string;
  month_label: string;
  customers_targeted: number;
  customers_thawed: number;
  revenue_recovered_rupees: number;
  founder_verdict: string;
  coaching_focus: string;
};

type StepRow = {
  thaw_step: string;
  attempts: number;
  bookings: number;
  revenue_rupees: number;
  conversion_pct: number;
};

type SegmentRow = {
  customer_segment: string;
  attempts: number;
  saves: number;
  revenue_rupees: number;
};

type LeaderRow = {
  engineer_handle: string;
  engineer_city: string;
  attempts: number;
  bookings: number;
  revenue_rupees: number;
};

type TierRow = {
  tier_verdict: string;
  count_attempts: number;
  revenue_rupees: number;
};

type VerdictDistRow = {
  founder_verdict: string;
  engineers: number;
  total_thawed: number;
  total_revenue_rupees: number;
};

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, attemptsRes, verdictsRes, byStepRes, bySegmentRes, leaderRes, tierRes, verdictDistRes] = await Promise.all([
    supabase.rpc('founder_r2822_thaw_summary'),
    supabase.rpc('founder_r2822_attempts_list'),
    supabase.rpc('founder_r2822_verdicts_list'),
    supabase.rpc('founder_r2822_by_step'),
    supabase.rpc('founder_r2822_by_segment'),
    supabase.rpc('founder_r2822_engineer_leaderboard'),
    supabase.rpc('founder_r2822_tier_breakdown'),
    supabase.rpc('founder_r2822_verdict_distribution'),
  ]);

  const summary = (summaryRes.data?.[0] ?? {
    total_attempts: 0,
    booked_jobs: 0,
    warm_leads: 0,
    no_response: 0,
    total_revenue_recovered_rupees: 0,
    platinum_saves: 0,
  }) as {
    total_attempts: number;
    booked_jobs: number;
    warm_leads: number;
    no_response: number;
    total_revenue_recovered_rupees: number;
    platinum_saves: number;
  };

  const attempts = (attemptsRes.data ?? []) as Attempt[];
  const verdicts = (verdictsRes.data ?? []) as Verdict[];
  const byStep = (byStepRes.data ?? []) as StepRow[];
  const bySegment = (bySegmentRes.data ?? []) as SegmentRow[];
  const leaderboard = (leaderRes.data ?? []) as LeaderRow[];
  const tierBreakdown = (tierRes.data ?? []) as TierRow[];
  const verdictDist = (verdictDistRes.data ?? []) as VerdictDistRow[];

  return (
    <div style={{ padding: '24px', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '4px' }}>
        Engineer Monthly Customer Relationship Thaw & Rebuild
      </h1>
      <p style={{ color: '#666', marginBottom: '20px' }}>
        Round r2822 · cold customer reactivation playbook · engineer × customer × thaw step × outcome × tier verdict
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <KpiCard label="Total Attempts" value={String(summary.total_attempts)} />
        <KpiCard label="Booked Jobs" value={String(summary.booked_jobs)} />
        <KpiCard label="Warm Leads" value={String(summary.warm_leads)} />
        <KpiCard label="No Response" value={String(summary.no_response)} />
        <KpiCard label="Revenue Recovered" value={rupees(summary.total_revenue_recovered_rupees)} />
        <KpiCard label="Platinum Saves" value={String(summary.platinum_saves)} />
      </div>

      <Section title="Engineer Leaderboard (revenue recovered)">
        <DataTable
          rows={leaderboard}
          columns={[
            { key: 'engineer_handle', header: 'Engineer', render: (r: LeaderRow) => r.engineer_handle },
            { key: 'engineer_city', header: 'City', render: (r: LeaderRow) => r.engineer_city },
            { key: 'attempts', header: 'Attempts', render: (r: LeaderRow) => r.attempts },
            { key: 'bookings', header: 'Bookings', render: (r: LeaderRow) => r.bookings },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: LeaderRow) => rupees(r.revenue_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: LeaderRow, i: number) => String(r.engineer_handle ?? i)}
        />
      </Section>

      <Section title="By Thaw Step (conversion funnel)">
        <DataTable
          rows={byStep}
          columns={[
            { key: 'thaw_step', header: 'Thaw Step', render: (r: StepRow) => r.thaw_step },
            { key: 'attempts', header: 'Attempts', render: (r: StepRow) => r.attempts },
            { key: 'bookings', header: 'Bookings', render: (r: StepRow) => r.bookings },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: StepRow) => rupees(r.revenue_rupees) },
            { key: 'conversion_pct', header: 'Conv %', render: (r: StepRow) => `${r.conversion_pct}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: StepRow, i: number) => String(r.thaw_step ?? i)}
        />
      </Section>

      <Section title="By Customer Segment">
        <DataTable
          rows={bySegment}
          columns={[
            { key: 'customer_segment', header: 'Segment', render: (r: SegmentRow) => r.customer_segment },
            { key: 'attempts', header: 'Attempts', render: (r: SegmentRow) => r.attempts },
            { key: 'saves', header: 'Saves', render: (r: SegmentRow) => r.saves },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: SegmentRow) => rupees(r.revenue_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SegmentRow, i: number) => String(r.customer_segment ?? i)}
        />
      </Section>

      <Section title="Tier Verdict Breakdown (platinum vs lost cause)">
        <DataTable
          rows={tierBreakdown}
          columns={[
            { key: 'tier_verdict', header: 'Tier', render: (r: TierRow) => r.tier_verdict },
            { key: 'count_attempts', header: 'Attempts', render: (r: TierRow) => r.count_attempts },
            { key: 'revenue_rupees', header: 'Revenue', render: (r: TierRow) => rupees(r.revenue_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRow, i: number) => String(r.tier_verdict ?? i)}
        />
      </Section>

      <Section title="Founder Verdict Distribution">
        <DataTable
          rows={verdictDist}
          columns={[
            { key: 'founder_verdict', header: 'Verdict', render: (r: VerdictDistRow) => r.founder_verdict },
            { key: 'engineers', header: 'Engineers', render: (r: VerdictDistRow) => r.engineers },
            { key: 'total_thawed', header: 'Thawed', render: (r: VerdictDistRow) => r.total_thawed },
            { key: 'total_revenue_rupees', header: 'Revenue', render: (r: VerdictDistRow) => rupees(r.total_revenue_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictDistRow, i: number) => String(r.founder_verdict ?? i)}
        />
      </Section>

      <Section title="Monthly Engineer Verdicts (coaching focus)">
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'engineer_handle', header: 'Engineer', render: (r: Verdict) => r.engineer_handle },
            { key: 'month_label', header: 'Month', render: (r: Verdict) => r.month_label },
            { key: 'customers_targeted', header: 'Targeted', render: (r: Verdict) => r.customers_targeted },
            { key: 'customers_thawed', header: 'Thawed', render: (r: Verdict) => r.customers_thawed },
            { key: 'revenue_recovered_rupees', header: 'Revenue', render: (r: Verdict) => rupees(r.revenue_recovered_rupees) },
            { key: 'founder_verdict', header: 'Verdict', render: (r: Verdict) => r.founder_verdict },
            { key: 'coaching_focus', header: 'Coaching Focus', render: (r: Verdict) => r.coaching_focus },
          ]}
          emptyMessage="No data"
          rowKey={(r: Verdict, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="All Thaw Attempts (latest first)">
        <DataTable
          rows={attempts}
          columns={[
            { key: 'engineer_handle', header: 'Engineer', render: (r: Attempt) => r.engineer_handle },
            { key: 'engineer_city', header: 'City', render: (r: Attempt) => r.engineer_city },
            { key: 'customer_handle', header: 'Customer', render: (r: Attempt) => r.customer_handle },
            { key: 'customer_segment', header: 'Segment', render: (r: Attempt) => r.customer_segment },
            { key: 'cold_since_days', header: 'Cold Days', render: (r: Attempt) => r.cold_since_days },
            { key: 'thaw_step', header: 'Step', render: (r: Attempt) => r.thaw_step },
            { key: 'outcome', header: 'Outcome', render: (r: Attempt) => r.outcome },
            { key: 'revenue_recovered_rupees', header: 'Revenue', render: (r: Attempt) => rupees(r.revenue_recovered_rupees) },
            { key: 'tier_verdict', header: 'Tier', render: (r: Attempt) => r.tier_verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: Attempt, i: number) => String(r.id ?? i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: '8px', padding: '14px' }}>
      <div style={{ color: '#6b7280', fontSize: '12px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</div>
      <div style={{ marginTop: '4px', fontSize: '20px', fontWeight: 700, color: '#111827' }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginTop: '24px' }}>
      <h2 style={{ fontSize: '16px', fontWeight: 700, marginBottom: '10px', color: '#111827' }}>{title}</h2>
      {children}
    </section>
  );
}
