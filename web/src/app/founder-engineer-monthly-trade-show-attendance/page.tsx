import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_shows: number;
  total_leads: number;
  total_qualified: number;
  total_pipeline_rupees: number;
  total_spend_rupees: number;
  roi_multiple: number;
};

type Attendance = {
  id: string;
  engineer_name: string;
  show_name: string;
  show_city: string;
  attended_on: string;
  booth_hours: number;
  goal_leads: number;
  actual_leads: number;
  demos_given: number;
  qualified_leads: number;
  learning_score: number;
  travel_cost_rupees: number;
  booth_cost_rupees: number;
  pipeline_value_rupees: number;
  roi_verdict: string;
};

type VerdictRow = { verdict: string; show_count: number; pipeline_rupees: number; spend_rupees: number };
type Leader = { engineer_name: string; shows_attended: number; total_leads: number; qualified_leads: number; pipeline_rupees: number; avg_learning_score: number };
type GapRow = { show_name: string; engineer_name: string; goal_leads: number; actual_leads: number; gap: number; hit_pct: number };
type Followup = { lead_hospital: string; lead_contact: string; followup_stage: string; expected_value_rupees: number; followup_due: string; engineer_name: string; show_name: string };
type FunnelRow = { followup_stage: string; lead_count: number; expected_rupees: number };
type Insight = { show_name: string; engineer_name: string; learning_score: number; booth_hours: number; cost_per_qualified_lead: number | null };

const inr = (n: number | null | undefined) => {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, attRes, verdictRes, leaderRes, gapRes, followRes, funnelRes, insightRes] = await Promise.all([
    supabase.rpc('r2778_trade_show_kpis'),
    supabase.rpc('r2778_trade_show_attendance_list'),
    supabase.rpc('r2778_trade_show_verdict_breakdown'),
    supabase.rpc('r2778_trade_show_engineer_leaderboard'),
    supabase.rpc('r2778_trade_show_goal_gap'),
    supabase.rpc('r2778_trade_show_open_followups'),
    supabase.rpc('r2778_trade_show_funnel'),
    supabase.rpc('r2778_trade_show_learning_insights'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_shows: 0, total_leads: 0, total_qualified: 0,
    total_pipeline_rupees: 0, total_spend_rupees: 0, roi_multiple: 0,
  };
  const attendance: Attendance[] = (attRes.data as Attendance[]) ?? [];
  const verdicts: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const leaders: Leader[] = (leaderRes.data as Leader[]) ?? [];
  const gaps: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const followups: Followup[] = (followRes.data as Followup[]) ?? [];
  const funnel: FunnelRow[] = (funnelRes.data as FunnelRow[]) ?? [];
  const insights: Insight[] = (insightRes.data as Insight[]) ?? [];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-3xl font-bold tracking-tight">Engineer Monthly Trade Show Attendance</h1>
        <p className="mt-2 text-sm text-neutral-600">
          Engineer & show & goals & leads & demos & learning & ROI verdict — full month attendance ledger.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-6">
        <KpiCard label="Shows" value={String(kpi.total_shows)} />
        <KpiCard label="Leads" value={String(kpi.total_leads)} />
        <KpiCard label="Qualified" value={String(kpi.total_qualified)} />
        <KpiCard label="Pipeline" value={inr(kpi.total_pipeline_rupees)} />
        <KpiCard label="Spend" value={inr(kpi.total_spend_rupees)} />
        <KpiCard label="ROI x" value={String(kpi.roi_multiple ?? 0) + 'x'} />
      </section>

      <section>
        <h2 className="mb-3 text-xl font-semibold">Attendance ledger</h2>
        <DataTable
          rows={attendance}
          columns={[
            { key: 'attended_on', header: 'Date', render: (r: Attendance) => r.attended_on },
            { key: 'engineer_name', header: 'Engineer', render: (r: Attendance) => r.engineer_name },
            { key: 'show_name', header: 'Show', render: (r: Attendance) => r.show_name + ' — ' + r.show_city },
            { key: 'goal_leads', header: 'Goal', render: (r: Attendance) => String(r.goal_leads) },
            { key: 'actual_leads', header: 'Actual', render: (r: Attendance) => String(r.actual_leads) },
            { key: 'demos_given', header: 'Demos', render: (r: Attendance) => String(r.demos_given) },
            { key: 'qualified_leads', header: 'Qualified', render: (r: Attendance) => String(r.qualified_leads) },
            { key: 'learning_score', header: 'Learn /10', render: (r: Attendance) => String(r.learning_score) },
            { key: 'pipeline_value_rupees', header: 'Pipeline', render: (r: Attendance) => inr(r.pipeline_value_rupees) },
            { key: 'roi_verdict', header: 'Verdict', render: (r: Attendance) => r.roi_verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: Attendance, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid gap-6 lg:grid-cols-2">
        <div>
          <h2 className="mb-3 text-xl font-semibold">ROI verdict breakdown</h2>
          <DataTable
            rows={verdicts}
            columns={[
              { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
              { key: 'show_count', header: 'Shows', render: (r: VerdictRow) => String(r.show_count) },
              { key: 'pipeline_rupees', header: 'Pipeline', render: (r: VerdictRow) => inr(r.pipeline_rupees) },
              { key: 'spend_rupees', header: 'Spend', render: (r: VerdictRow) => inr(r.spend_rupees) },
            ]}
            emptyMessage="No data"
            rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
          />
        </div>
        <div>
          <h2 className="mb-3 text-xl font-semibold">Engineer leaderboard</h2>
          <DataTable
            rows={leaders}
            columns={[
              { key: 'engineer_name', header: 'Engineer', render: (r: Leader) => r.engineer_name },
              { key: 'shows_attended', header: 'Shows', render: (r: Leader) => String(r.shows_attended) },
              { key: 'total_leads', header: 'Leads', render: (r: Leader) => String(r.total_leads) },
              { key: 'qualified_leads', header: 'Qualified', render: (r: Leader) => String(r.qualified_leads) },
              { key: 'pipeline_rupees', header: 'Pipeline', render: (r: Leader) => inr(r.pipeline_rupees) },
              { key: 'avg_learning_score', header: 'Avg learn', render: (r: Leader) => String(r.avg_learning_score) },
            ]}
            emptyMessage="No data"
            rowKey={(r: Leader, i: number) => String(r.engineer_name ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-xl font-semibold">Goal vs actual lead gap</h2>
        <DataTable
          rows={gaps}
          columns={[
            { key: 'show_name', header: 'Show', render: (r: GapRow) => r.show_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: GapRow) => r.engineer_name },
            { key: 'goal_leads', header: 'Goal', render: (r: GapRow) => String(r.goal_leads) },
            { key: 'actual_leads', header: 'Actual', render: (r: GapRow) => String(r.actual_leads) },
            { key: 'gap', header: 'Gap', render: (r: GapRow) => String(r.gap) },
            { key: 'hit_pct', header: 'Hit %', render: (r: GapRow) => String(r.hit_pct) + '%' },
          ]}
          emptyMessage="No data"
          rowKey={(r: GapRow, i: number) => r.show_name + '-' + i}
        />
      </section>

      <section className="grid gap-6 lg:grid-cols-2">
        <div>
          <h2 className="mb-3 text-xl font-semibold">Open followups</h2>
          <DataTable
            rows={followups}
            columns={[
              { key: 'followup_due', header: 'Due', render: (r: Followup) => r.followup_due },
              { key: 'lead_hospital', header: 'Hospital', render: (r: Followup) => r.lead_hospital },
              { key: 'lead_contact', header: 'Contact', render: (r: Followup) => r.lead_contact },
              { key: 'followup_stage', header: 'Stage', render: (r: Followup) => r.followup_stage },
              { key: 'expected_value_rupees', header: 'Value', render: (r: Followup) => inr(r.expected_value_rupees) },
              { key: 'engineer_name', header: 'Engineer', render: (r: Followup) => r.engineer_name },
            ]}
            emptyMessage="No data"
            rowKey={(r: Followup, i: number) => r.lead_hospital + '-' + i}
          />
        </div>
        <div>
          <h2 className="mb-3 text-xl font-semibold">Funnel by stage</h2>
          <DataTable
            rows={funnel}
            columns={[
              { key: 'followup_stage', header: 'Stage', render: (r: FunnelRow) => r.followup_stage },
              { key: 'lead_count', header: 'Leads', render: (r: FunnelRow) => String(r.lead_count) },
              { key: 'expected_rupees', header: 'Expected', render: (r: FunnelRow) => inr(r.expected_rupees) },
            ]}
            emptyMessage="No data"
            rowKey={(r: FunnelRow, i: number) => String(r.followup_stage ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-xl font-semibold">Learning insights & cost per qualified lead</h2>
        <DataTable
          rows={insights}
          columns={[
            { key: 'show_name', header: 'Show', render: (r: Insight) => r.show_name },
            { key: 'engineer_name', header: 'Engineer', render: (r: Insight) => r.engineer_name },
            { key: 'learning_score', header: 'Learn', render: (r: Insight) => String(r.learning_score) },
            { key: 'booth_hours', header: 'Booth hrs', render: (r: Insight) => String(r.booth_hours) },
            { key: 'cost_per_qualified_lead', header: 'Cost / qualified', render: (r: Insight) => inr(r.cost_per_qualified_lead) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Insight, i: number) => r.show_name + '-' + i}
        />
      </section>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-neutral-900">{value}</div>
    </div>
  );
}
