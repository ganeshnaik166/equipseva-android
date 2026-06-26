import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Milestone = {
  id: string;
  engineer_name: string;
  customer_name: string;
  milestone_type: string;
  milestone_date: string;
  gesture_type: string;
  gesture_cost_rupees: number;
  engagement_score: number;
  ltv_uplift_rupees: number;
  verdict: string;
  notes: string | null;
};

type Outcome = {
  id: string;
  engineer_name: string;
  customer_name: string;
  celebration_month: string;
  gestures_delivered: number;
  customer_response: string;
  referrals_generated: number;
  amc_renewed: boolean;
  nps_delta: number;
  next_action: string;
};

type Summary = {
  total_milestones: number;
  green_count: number;
  amber_count: number;
  red_count: number;
  total_ltv_uplift: number;
  avg_engagement: number;
};

type Leader = {
  engineer_name: string;
  milestones_celebrated: number;
  total_ltv_uplift: number;
  avg_engagement: number;
  green_share: number;
};

type GestureMix = {
  gesture_type: string;
  count: number;
  total_cost: number;
  total_ltv_uplift: number;
  roi_multiple: number | null;
};

type ResponseMix = {
  customer_response: string;
  count: number;
  total_referrals: number;
  amc_renewal_rate: number;
  avg_nps_delta: number;
};

type ProgramKpi = {
  total_outcomes: number;
  total_referrals: number;
  renewal_rate: number;
  avg_nps_delta: number;
  scale_signals: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, milestonesRes, outcomesRes, leadersRes, gesturesRes, responsesRes, redRes, kpiRes] = await Promise.all([
    supabase.rpc('founder_r2830_milestone_summary'),
    supabase.rpc('founder_r2830_milestone_list'),
    supabase.rpc('founder_r2830_outcome_list'),
    supabase.rpc('founder_r2830_engineer_leaderboard'),
    supabase.rpc('founder_r2830_gesture_mix'),
    supabase.rpc('founder_r2830_response_mix'),
    supabase.rpc('founder_r2830_red_milestones'),
    supabase.rpc('founder_r2830_program_kpis'),
  ]);

  const summary = (summaryRes.data?.[0] ?? null) as Summary | null;
  const milestones = (milestonesRes.data ?? []) as Milestone[];
  const outcomes = (outcomesRes.data ?? []) as Outcome[];
  const leaders = (leadersRes.data ?? []) as Leader[];
  const gestures = (gesturesRes.data ?? []) as GestureMix[];
  const responses = (responsesRes.data ?? []) as ResponseMix[];
  const reds = (redRes.data ?? []) as Milestone[];
  const kpi = (kpiRes.data?.[0] ?? null) as ProgramKpi | null;

  const fmt = (n: number | null | undefined) => (n == null ? '-' : new Intl.NumberFormat('en-IN').format(n));
  const rupees = (n: number | null | undefined) => (n == null ? '-' : 'Rs ' + new Intl.NumberFormat('en-IN').format(n));

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Relationship Co-Celebration</h1>
        <p className="text-sm text-gray-600">Round 2830 · engineer x customer x milestone x gesture x engagement x LTV uplift x verdict</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <KpiCard label="Milestones" value={fmt(summary?.total_milestones)} />
        <KpiCard label="Green" value={fmt(summary?.green_count)} />
        <KpiCard label="Amber" value={fmt(summary?.amber_count)} />
        <KpiCard label="Red" value={fmt(summary?.red_count)} />
        <KpiCard label="LTV Uplift" value={rupees(summary?.total_ltv_uplift)} />
        <KpiCard label="Avg Engagement" value={summary?.avg_engagement != null ? String(summary.avg_engagement) : '-'} />
      </section>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <KpiCard label="Outcomes Tracked" value={fmt(kpi?.total_outcomes)} />
        <KpiCard label="Total Referrals" value={fmt(kpi?.total_referrals)} />
        <KpiCard label="AMC Renewal Rate" value={kpi?.renewal_rate != null ? kpi.renewal_rate + '%' : '-'} />
        <KpiCard label="Avg NPS Delta" value={kpi?.avg_nps_delta != null ? String(kpi.avg_nps_delta) : '-'} />
        <KpiCard label="Scale Signals" value={fmt(kpi?.scale_signals)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Milestones</h2>
        <DataTable
          rows={milestones}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Milestone) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: Milestone) => r.customer_name },
            { key: 'milestone_type', header: 'Milestone', render: (r: Milestone) => r.milestone_type },
            { key: 'milestone_date', header: 'Date', render: (r: Milestone) => r.milestone_date },
            { key: 'gesture_type', header: 'Gesture', render: (r: Milestone) => r.gesture_type },
            { key: 'gesture_cost_rupees', header: 'Cost', render: (r: Milestone) => rupees(r.gesture_cost_rupees) },
            { key: 'engagement_score', header: 'Engagement', render: (r: Milestone) => String(r.engagement_score) },
            { key: 'ltv_uplift_rupees', header: 'LTV Uplift', render: (r: Milestone) => rupees(r.ltv_uplift_rupees) },
            { key: 'verdict', header: 'Verdict', render: (r: Milestone) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: Milestone, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable
          rows={leaders}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Leader) => r.engineer_name },
            { key: 'milestones_celebrated', header: 'Milestones', render: (r: Leader) => fmt(r.milestones_celebrated) },
            { key: 'total_ltv_uplift', header: 'LTV Uplift', render: (r: Leader) => rupees(r.total_ltv_uplift) },
            { key: 'avg_engagement', header: 'Avg Engagement', render: (r: Leader) => String(r.avg_engagement) },
            { key: 'green_share', header: 'Green %', render: (r: Leader) => (r.green_share != null ? r.green_share + '%' : '-') },
          ]}
          emptyMessage="No data"
          rowKey={(r: Leader, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Gesture ROI</h2>
        <DataTable
          rows={gestures}
          columns={[
            { key: 'gesture_type', header: 'Gesture', render: (r: GestureMix) => r.gesture_type },
            { key: 'count', header: 'Count', render: (r: GestureMix) => fmt(r.count) },
            { key: 'total_cost', header: 'Total Cost', render: (r: GestureMix) => rupees(r.total_cost) },
            { key: 'total_ltv_uplift', header: 'LTV Uplift', render: (r: GestureMix) => rupees(r.total_ltv_uplift) },
            { key: 'roi_multiple', header: 'ROI x', render: (r: GestureMix) => (r.roi_multiple != null ? String(r.roi_multiple) : '-') },
          ]}
          emptyMessage="No data"
          rowKey={(r: GestureMix, i: number) => String(r.gesture_type ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Customer Response Mix</h2>
        <DataTable
          rows={responses}
          columns={[
            { key: 'customer_response', header: 'Response', render: (r: ResponseMix) => r.customer_response },
            { key: 'count', header: 'Count', render: (r: ResponseMix) => fmt(r.count) },
            { key: 'total_referrals', header: 'Referrals', render: (r: ResponseMix) => fmt(r.total_referrals) },
            { key: 'amc_renewal_rate', header: 'Renewal %', render: (r: ResponseMix) => (r.amc_renewal_rate != null ? r.amc_renewal_rate + '%' : '-') },
            { key: 'avg_nps_delta', header: 'Avg NPS Delta', render: (r: ResponseMix) => String(r.avg_nps_delta) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ResponseMix, i: number) => String(r.customer_response ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Outcome) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: Outcome) => r.customer_name },
            { key: 'celebration_month', header: 'Month', render: (r: Outcome) => r.celebration_month },
            { key: 'gestures_delivered', header: 'Gestures', render: (r: Outcome) => fmt(r.gestures_delivered) },
            { key: 'customer_response', header: 'Response', render: (r: Outcome) => r.customer_response },
            { key: 'referrals_generated', header: 'Referrals', render: (r: Outcome) => fmt(r.referrals_generated) },
            { key: 'amc_renewed', header: 'AMC Renewed', render: (r: Outcome) => (r.amc_renewed ? 'yes' : 'no') },
            { key: 'nps_delta', header: 'NPS Delta', render: (r: Outcome) => String(r.nps_delta) },
            { key: 'next_action', header: 'Next', render: (r: Outcome) => r.next_action },
          ]}
          emptyMessage="No data"
          rowKey={(r: Outcome, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Red &amp; Low-Engagement Milestones</h2>
        <p className="text-sm text-gray-600 mb-2">Milestones flagged red or engagement score &lt; 75.</p>
        <DataTable
          rows={reds}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Milestone) => r.engineer_name },
            { key: 'customer_name', header: 'Customer', render: (r: Milestone) => r.customer_name },
            { key: 'milestone_type', header: 'Milestone', render: (r: Milestone) => r.milestone_type },
            { key: 'engagement_score', header: 'Engagement', render: (r: Milestone) => String(r.engagement_score) },
            { key: 'verdict', header: 'Verdict', render: (r: Milestone) => r.verdict },
            { key: 'notes', header: 'Notes', render: (r: Milestone) => r.notes ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Milestone, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="border rounded-lg p-3 bg-white">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-lg font-semibold">{value}</div>
    </div>
  );
}