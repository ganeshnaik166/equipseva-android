import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = {
  total_checklists: number;
  avg_completion_pct: number;
  avg_prep_score: number;
  total_minutes_saved: number;
  refined_count: number;
  pending_refine: number;
};

type ChecklistRow = {
  id: string;
  job_code: string;
  customer_name: string;
  hospital_segment: string;
  visit_date: string;
  engineer_name: string;
  checklist_template: string;
  items_total: number;
  items_completed: number;
  items_missed: number;
  completion_pct: number;
  prep_score: number;
  prep_impact_minutes_saved: number;
  visit_outcome: string;
  refine_status: string;
  notes: string | null;
};

type SegmentRow = {
  hospital_segment: string;
  visits: number;
  avg_completion: number;
  avg_prep: number;
  minutes_saved: number;
};

type MissedRow = {
  job_code: string;
  customer_name: string;
  engineer_name: string;
  items_missed: number;
  completion_pct: number;
  visit_outcome: string;
};

type RefineRow = {
  action_code: string;
  job_code: string;
  action_type: string;
  proposed_by: string;
  rationale: string;
  expected_minutes_saved: number;
  approval_status: string;
  measured_lift_pct: number;
};

type TemplateRow = {
  checklist_template: string;
  runs: number;
  avg_completion: number;
  total_minutes_saved: number;
  avg_missed: number;
};

type OutcomeRow = {
  visit_outcome: string;
  visits: number;
  share_pct: number;
};

type EngineerRow = {
  engineer_name: string;
  visits: number;
  avg_prep: number;
  avg_completion: number;
  missed_total: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    checklistsRes,
    segmentRes,
    missedRes,
    refineRes,
    templateRes,
    outcomeRes,
    engineerRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2740_overview'),
    supabase.rpc('founder_r2740_checklists'),
    supabase.rpc('founder_r2740_by_segment'),
    supabase.rpc('founder_r2740_missed_leaders'),
    supabase.rpc('founder_r2740_refine_actions'),
    supabase.rpc('founder_r2740_template_impact'),
    supabase.rpc('founder_r2740_outcome_mix'),
    supabase.rpc('founder_r2740_engineer_prep'),
  ]);

  const overview: OverviewRow | null =
    Array.isArray(overviewRes.data) && overviewRes.data.length > 0
      ? (overviewRes.data[0] as OverviewRow)
      : null;
  const checklists: ChecklistRow[] = (checklistsRes.data as ChecklistRow[]) ?? [];
  const segments: SegmentRow[] = (segmentRes.data as SegmentRow[]) ?? [];
  const missed: MissedRow[] = (missedRes.data as MissedRow[]) ?? [];
  const refine: RefineRow[] = (refineRes.data as RefineRow[]) ?? [];
  const templates: TemplateRow[] = (templateRes.data as TemplateRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[]) ?? [];
  const engineers: EngineerRow[] = (engineerRes.data as EngineerRow[]) ?? [];

  const kpis = [
    { label: 'Total checklists', value: overview?.total_checklists ?? 0 },
    { label: 'Avg completion %', value: overview?.avg_completion_pct ?? 0 },
    { label: 'Avg prep score', value: overview?.avg_prep_score ?? 0 },
    { label: 'Minutes saved', value: overview?.total_minutes_saved ?? 0 },
    { label: 'Refined templates', value: overview?.refined_count ?? 0 },
    { label: 'Pending refine', value: overview?.pending_refine ?? 0 },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Customer Monthly Pre-Visit Checklist Completion
        </h1>
        <p style={{ color: '#555' }}>
          Round r2740 founder console — job × checklist × items
          completed × missed × prep impact × refine action.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12,
          marginBottom: 28,
        }}
      >
        {kpis.map((k) => (
          <div
            key={k.label}
            style={{
              padding: 16,
              border: '1px solid #e5e7eb',
              borderRadius: 10,
              background: '#fafafa',
            }}
          >
            <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 6 }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{String(k.value)}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 10 }}>
          Pre-visit checklist runs
        </h2>
        <DataTable<ChecklistRow>
          rows={checklists}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'job_code', header: 'Job', render: (r) => r.job_code },
            { key: 'customer_name', header: 'Customer', render: (r) => r.customer_name },
            { key: 'hospital_segment', header: 'Segment', render: (r) => r.hospital_segment },
            { key: 'visit_date', header: 'Visit', render: (r) => r.visit_date },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            {
              key: 'checklist_template',
              header: 'Template',
              render: (r) => r.checklist_template,
            },
            {
              key: 'items',
              header: 'Done / Total',
              render: (r) => `${r.items_completed} / ${r.items_total}`,
            },
            { key: 'items_missed', header: 'Missed', render: (r) => String(r.items_missed) },
            {
              key: 'completion_pct',
              header: 'Completion %',
              render: (r) => `${r.completion_pct}%`,
            },
            { key: 'prep_score', header: 'Prep score', render: (r) => `${r.prep_score}` },
            {
              key: 'prep_impact_minutes_saved',
              header: 'Min saved',
              render: (r) => String(r.prep_impact_minutes_saved),
            },
            { key: 'visit_outcome', header: 'Outcome', render: (r) => r.visit_outcome },
            { key: 'refine_status', header: 'Refine', render: (r) => r.refine_status },
            { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
          ]}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 10 }}>By hospital segment</h2>
        <DataTable<SegmentRow>
          rows={segments}
          rowKey={(r, i) => String(r.hospital_segment ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'hospital_segment', header: 'Segment', render: (r) => r.hospital_segment },
            { key: 'visits', header: 'Visits', render: (r) => String(r.visits) },
            {
              key: 'avg_completion',
              header: 'Avg completion %',
              render: (r) => `${r.avg_completion}%`,
            },
            { key: 'avg_prep', header: 'Avg prep', render: (r) => String(r.avg_prep) },
            {
              key: 'minutes_saved',
              header: 'Min saved',
              render: (r) => String(r.minutes_saved),
            },
          ]}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 10 }}>
          Missed-items leaderboard
        </h2>
        <DataTable<MissedRow>
          rows={missed}
          rowKey={(r, i) => String(r.job_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'job_code', header: 'Job', render: (r) => r.job_code },
            { key: 'customer_name', header: 'Customer', render: (r) => r.customer_name },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'items_missed', header: 'Missed', render: (r) => String(r.items_missed) },
            {
              key: 'completion_pct',
              header: 'Completion %',
              render: (r) => `${r.completion_pct}%`,
            },
            { key: 'visit_outcome', header: 'Outcome', render: (r) => r.visit_outcome },
          ]}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 10 }}>
          Refine actions proposed & applied
        </h2>
        <DataTable<RefineRow>
          rows={refine}
          rowKey={(r, i) => String(r.action_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'action_code', header: 'Action', render: (r) => r.action_code },
            { key: 'job_code', header: 'Job', render: (r) => r.job_code },
            { key: 'action_type', header: 'Type', render: (r) => r.action_type },
            { key: 'proposed_by', header: 'Proposed by', render: (r) => r.proposed_by },
            { key: 'rationale', header: 'Rationale', render: (r) => r.rationale },
            {
              key: 'expected_minutes_saved',
              header: 'Est. min saved',
              render: (r) => String(r.expected_minutes_saved),
            },
            {
              key: 'approval_status',
              header: 'Status',
              render: (r) => r.approval_status,
            },
            {
              key: 'measured_lift_pct',
              header: 'Lift %',
              render: (r) => `${r.measured_lift_pct}%`,
            },
          ]}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 10 }}>Template impact</h2>
        <DataTable<TemplateRow>
          rows={templates}
          rowKey={(r, i) => String(r.checklist_template ?? i)}
          emptyMessage="No data"
          columns={[
            {
              key: 'checklist_template',
              header: 'Template',
              render: (r) => r.checklist_template,
            },
            { key: 'runs', header: 'Runs', render: (r) => String(r.runs) },
            {
              key: 'avg_completion',
              header: 'Avg completion %',
              render: (r) => `${r.avg_completion}%`,
            },
            {
              key: 'total_minutes_saved',
              header: 'Total min saved',
              render: (r) => String(r.total_minutes_saved),
            },
            {
              key: 'avg_missed',
              header: 'Avg missed',
              render: (r) => String(r.avg_missed),
            },
          ]}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 10 }}>Outcome mix</h2>
        <DataTable<OutcomeRow>
          rows={outcomes}
          rowKey={(r, i) => String(r.visit_outcome ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'visit_outcome', header: 'Outcome', render: (r) => r.visit_outcome },
            { key: 'visits', header: 'Visits', render: (r) => String(r.visits) },
            { key: 'share_pct', header: 'Share %', render: (r) => `${r.share_pct}%` },
          ]}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 10 }}>
          Engineer prep leaderboard
        </h2>
        <DataTable<EngineerRow>
          rows={engineers}
          rowKey={(r, i) => String(r.engineer_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'visits', header: 'Visits', render: (r) => String(r.visits) },
            { key: 'avg_prep', header: 'Avg prep', render: (r) => String(r.avg_prep) },
            {
              key: 'avg_completion',
              header: 'Avg completion %',
              render: (r) => `${r.avg_completion}%`,
            },
            {
              key: 'missed_total',
              header: 'Missed total',
              render: (r) => String(r.missed_total),
            },
          ]}
        />
      </section>
    </main>
  );
}
