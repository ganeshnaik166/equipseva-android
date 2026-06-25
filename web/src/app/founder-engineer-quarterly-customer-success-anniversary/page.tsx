import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_milestones: number;
  gestures_executed: number;
  avg_pulse: number;
  avg_retention_lift: number;
  total_gesture_spend: number;
  total_upsell_unlocked: number;
};

type Milestone = {
  id: string;
  engineer_name: string;
  engineer_tier: string;
  customer_org: string;
  customer_segment: string;
  tenure_quarters: number;
  anniversary_date: string;
  gesture_type: string;
  gesture_cost_rupees: number;
  customer_pulse_score: number;
  retention_lift_pct: number;
  amc_renewal_likelihood_pct: number;
};

type ImpactRow = {
  engineer_name: string;
  customer_org: string;
  pulse_check_date: string;
  pulse_score_post: number;
  pulse_delta: number;
  amc_signed_post: boolean;
  upsell_value_rupees: number;
  testimonial_received: boolean;
  referral_made: boolean;
  outcome_tag: string;
};

type TenureRow = {
  tenure_bucket: string;
  cohort_size: number;
  avg_pulse: number;
  avg_retention_lift: number;
  total_upsell: number;
};

type GestureRoi = {
  gesture_type: string;
  uses: number;
  avg_cost: number;
  avg_pulse_delta: number;
  total_upsell: number;
  roi_multiple: number;
};

type Leaderboard = {
  engineer_name: string;
  engineer_tier: string;
  milestones_handled: number;
  avg_pulse_score: number;
  avg_retention_lift: number;
  total_upsell_driven: number;
  testimonials_secured: number;
};

type AtRisk = {
  engineer_name: string;
  customer_org: string;
  customer_segment: string;
  tenure_quarters: number;
  anniversary_date: string;
  gesture_type: string;
  customer_pulse_score: number;
  amc_renewal_likelihood_pct: number;
  risk_flag: string;
};

type SegmentMatrix = {
  customer_segment: string;
  total: number;
  exceeded_count: number;
  met_count: number;
  partial_count: number;
  missed_count: number;
  exceeded_rate_pct: number;
};

function inr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0%';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, rosterRes, impactRes, tenureRes, roiRes, leadersRes, riskRes, segRes] =
    await Promise.all([
      supabase.rpc('founder_r2762_anniversary_kpis'),
      supabase.rpc('founder_r2762_milestone_roster'),
      supabase.rpc('founder_r2762_impact_ledger'),
      supabase.rpc('founder_r2762_tenure_cohort'),
      supabase.rpc('founder_r2762_gesture_roi'),
      supabase.rpc('founder_r2762_engineer_leaderboard'),
      supabase.rpc('founder_r2762_at_risk_anniversaries'),
      supabase.rpc('founder_r2762_segment_outcome_matrix'),
    ]);

  const kpis: Kpis = (kpisRes.data?.[0] ?? {
    total_milestones: 0,
    gestures_executed: 0,
    avg_pulse: 0,
    avg_retention_lift: 0,
    total_gesture_spend: 0,
    total_upsell_unlocked: 0,
  }) as Kpis;

  const roster: Milestone[] = (rosterRes.data ?? []) as Milestone[];
  const impact: ImpactRow[] = (impactRes.data ?? []) as ImpactRow[];
  const tenure: TenureRow[] = (tenureRes.data ?? []) as TenureRow[];
  const roi: GestureRoi[] = (roiRes.data ?? []) as GestureRoi[];
  const leaders: Leaderboard[] = (leadersRes.data ?? []) as Leaderboard[];
  const risk: AtRisk[] = (riskRes.data ?? []) as AtRisk[];
  const segments: SegmentMatrix[] = (segRes.data ?? []) as SegmentMatrix[];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Quarterly Customer Success Anniversary
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Engineer x customer x tenure x gesture x pulse x retention impact. Tracks the
        anniversary moments where engineers convert long-tenure customers into renewals,
        upsells, testimonials, and referrals.
      </p>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12,
          marginBottom: 24,
        }}
      >
        <KpiCard label="Milestones" value={String(kpis.total_milestones ?? 0)} />
        <KpiCard label="Gestures Executed" value={String(kpis.gestures_executed ?? 0)} />
        <KpiCard label="Avg Pulse" value={Number(kpis.avg_pulse ?? 0).toFixed(2)} />
        <KpiCard label="Avg Retention Lift" value={pct(kpis.avg_retention_lift)} />
        <KpiCard label="Gesture Spend" value={inr(kpis.total_gesture_spend)} />
        <KpiCard label="Upsell Unlocked" value={inr(kpis.total_upsell_unlocked)} />
      </div>

      <Section title="Milestone Roster">
        <DataTable
          rows={roster}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Milestone) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: Milestone) => r.engineer_tier },
            { key: 'customer_org', header: 'Customer', render: (r: Milestone) => r.customer_org },
            { key: 'customer_segment', header: 'Segment', render: (r: Milestone) => r.customer_segment },
            { key: 'tenure_quarters', header: 'Tenure (Q)', render: (r: Milestone) => String(r.tenure_quarters) },
            { key: 'anniversary_date', header: 'Date', render: (r: Milestone) => r.anniversary_date },
            { key: 'gesture_type', header: 'Gesture', render: (r: Milestone) => r.gesture_type },
            { key: 'gesture_cost_rupees', header: 'Cost', render: (r: Milestone) => inr(r.gesture_cost_rupees) },
            { key: 'customer_pulse_score', header: 'Pulse', render: (r: Milestone) => Number(r.customer_pulse_score).toFixed(1) },
            { key: 'retention_lift_pct', header: 'Lift', render: (r: Milestone) => pct(r.retention_lift_pct) },
            { key: 'amc_renewal_likelihood_pct', header: 'AMC Likelihood', render: (r: Milestone) => pct(r.amc_renewal_likelihood_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Milestone, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Gesture Impact Ledger (14-day pulse check)">
        <DataTable
          rows={impact}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: ImpactRow) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r: ImpactRow) => r.customer_org },
            { key: 'pulse_check_date', header: 'Check Date', render: (r: ImpactRow) => r.pulse_check_date },
            { key: 'pulse_score_post', header: 'Pulse Post', render: (r: ImpactRow) => Number(r.pulse_score_post).toFixed(1) },
            { key: 'pulse_delta', header: 'Delta', render: (r: ImpactRow) => Number(r.pulse_delta).toFixed(1) },
            { key: 'amc_signed_post', header: 'AMC Signed', render: (r: ImpactRow) => (r.amc_signed_post ? 'yes' : 'no') },
            { key: 'upsell_value_rupees', header: 'Upsell', render: (r: ImpactRow) => inr(r.upsell_value_rupees) },
            { key: 'testimonial_received', header: 'Testimonial', render: (r: ImpactRow) => (r.testimonial_received ? 'yes' : 'no') },
            { key: 'referral_made', header: 'Referral', render: (r: ImpactRow) => (r.referral_made ? 'yes' : 'no') },
            { key: 'outcome_tag', header: 'Outcome', render: (r: ImpactRow) => r.outcome_tag },
          ]}
          emptyMessage="No data"
          rowKey={(r: ImpactRow, i: number) => String(i)}
        />
      </Section>

      <Section title="Tenure Cohort Breakdown">
        <DataTable
          rows={tenure}
          columns={[
            { key: 'tenure_bucket', header: 'Bucket', render: (r: TenureRow) => r.tenure_bucket },
            { key: 'cohort_size', header: 'Cohort', render: (r: TenureRow) => String(r.cohort_size) },
            { key: 'avg_pulse', header: 'Avg Pulse', render: (r: TenureRow) => Number(r.avg_pulse ?? 0).toFixed(2) },
            { key: 'avg_retention_lift', header: 'Avg Lift', render: (r: TenureRow) => pct(r.avg_retention_lift) },
            { key: 'total_upsell', header: 'Upsell', render: (r: TenureRow) => inr(r.total_upsell) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TenureRow, i: number) => String(i)}
        />
      </Section>

      <Section title="Gesture-Type ROI">
        <DataTable
          rows={roi}
          columns={[
            { key: 'gesture_type', header: 'Gesture', render: (r: GestureRoi) => r.gesture_type },
            { key: 'uses', header: 'Uses', render: (r: GestureRoi) => String(r.uses) },
            { key: 'avg_cost', header: 'Avg Cost', render: (r: GestureRoi) => inr(Math.round(Number(r.avg_cost ?? 0))) },
            { key: 'avg_pulse_delta', header: 'Avg Pulse Delta', render: (r: GestureRoi) => Number(r.avg_pulse_delta ?? 0).toFixed(2) },
            { key: 'total_upsell', header: 'Upsell', render: (r: GestureRoi) => inr(r.total_upsell) },
            { key: 'roi_multiple', header: 'ROI Multiple', render: (r: GestureRoi) => Number(r.roi_multiple ?? 0).toFixed(2) + 'x' },
          ]}
          emptyMessage="No data"
          rowKey={(r: GestureRoi, i: number) => String(i)}
        />
      </Section>

      <Section title="Engineer Leaderboard">
        <DataTable
          rows={leaders}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Leaderboard) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: Leaderboard) => r.engineer_tier },
            { key: 'milestones_handled', header: 'Milestones', render: (r: Leaderboard) => String(r.milestones_handled) },
            { key: 'avg_pulse_score', header: 'Avg Pulse', render: (r: Leaderboard) => Number(r.avg_pulse_score ?? 0).toFixed(2) },
            { key: 'avg_retention_lift', header: 'Avg Lift', render: (r: Leaderboard) => pct(r.avg_retention_lift) },
            { key: 'total_upsell_driven', header: 'Upsell Driven', render: (r: Leaderboard) => inr(r.total_upsell_driven) },
            { key: 'testimonials_secured', header: 'Testimonials', render: (r: Leaderboard) => String(r.testimonials_secured) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Leaderboard, i: number) => String(i)}
        />
      </Section>

      <Section title="At-Risk Anniversaries">
        <DataTable
          rows={risk}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: AtRisk) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r: AtRisk) => r.customer_org },
            { key: 'customer_segment', header: 'Segment', render: (r: AtRisk) => r.customer_segment },
            { key: 'tenure_quarters', header: 'Tenure (Q)', render: (r: AtRisk) => String(r.tenure_quarters) },
            { key: 'anniversary_date', header: 'Date', render: (r: AtRisk) => r.anniversary_date },
            { key: 'gesture_type', header: 'Gesture', render: (r: AtRisk) => r.gesture_type },
            { key: 'customer_pulse_score', header: 'Pulse', render: (r: AtRisk) => Number(r.customer_pulse_score).toFixed(1) },
            { key: 'amc_renewal_likelihood_pct', header: 'AMC Likelihood', render: (r: AtRisk) => pct(r.amc_renewal_likelihood_pct) },
            { key: 'risk_flag', header: 'Flag', render: (r: AtRisk) => r.risk_flag },
          ]}
          emptyMessage="No data"
          rowKey={(r: AtRisk, i: number) => String(i)}
        />
      </Section>

      <Section title="Segment x Outcome Matrix">
        <DataTable
          rows={segments}
          columns={[
            { key: 'customer_segment', header: 'Segment', render: (r: SegmentMatrix) => r.customer_segment },
            { key: 'total', header: 'Total', render: (r: SegmentMatrix) => String(r.total) },
            { key: 'exceeded_count', header: 'Exceeded', render: (r: SegmentMatrix) => String(r.exceeded_count) },
            { key: 'met_count', header: 'Met', render: (r: SegmentMatrix) => String(r.met_count) },
            { key: 'partial_count', header: 'Partial', render: (r: SegmentMatrix) => String(r.partial_count) },
            { key: 'missed_count', header: 'Missed', render: (r: SegmentMatrix) => String(r.missed_count) },
            { key: 'exceeded_rate_pct', header: 'Exceeded Rate', render: (r: SegmentMatrix) => pct(r.exceeded_rate_pct) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SegmentMatrix, i: number) => String(i)}
        />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        padding: 16,
        background: '#fff',
      }}
    >
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </section>
  );
}
