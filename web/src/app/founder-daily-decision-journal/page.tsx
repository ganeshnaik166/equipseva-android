import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type DecisionRow = {
  id: string;
  decided_on: string;
  decision_title: string;
  category: string;
  reversibility: string;
  confidence_pct: number;
  status: string;
  review_due_date: string;
  days_until_review: number;
  has_retro: boolean;
};

type DueRow = {
  id: string;
  decision_title: string;
  decided_on: string;
  review_due_date: string;
  days_overdue: number;
  category: string;
  reversibility: string;
  confidence_pct: number;
};

type RetroRow = {
  id: string;
  decision_id: string;
  decision_title: string;
  decided_on: string;
  reviewed_on: string;
  outcome_rating: string;
  lessons_md: string;
  follow_up_action_md: string;
};

type CalibrationRow = {
  confidence_bucket: string;
  decisions_count: number;
  better_than_expected: number;
  on_track: number;
  worse_than_expected: number;
  too_early: number;
};

type CategoryRow = {
  category: string;
  total_decisions: number;
  pending_review: number;
  reviewed: number;
  one_way_doors: number;
  avg_confidence: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [decisionsRes, dueRes, retrosRes, calibRes, catRes] = await Promise.all([
    sb.rpc('list_decisions_r2309'),
    sb.rpc('decisions_due_for_review_r2309'),
    sb.rpc('list_retros_r2309'),
    sb.rpc('calibration_scorecard_r2309'),
    sb.rpc('decision_category_breakdown_r2309'),
  ]);

  const decisions: DecisionRow[] = (decisionsRes.data as DecisionRow[] | null) ?? [];
  const due: DueRow[] = (dueRes.data as DueRow[] | null) ?? [];
  const retros: RetroRow[] = (retrosRes.data as RetroRow[] | null) ?? [];
  const calibration: CalibrationRow[] = (calibRes.data as CalibrationRow[] | null) ?? [];
  const categories: CategoryRow[] = (catRes.data as CategoryRow[] | null) ?? [];

  const decisionCols: Column<DecisionRow>[] = [
    { key: 'decided_on', header: 'Decided', render: (r: any) => r.decided_on },
    { key: 'decision_title', header: 'Decision', render: (r: any) => r.decision_title },
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'reversibility', header: 'Reversibility', render: (r: any) => r.reversibility },
    { key: 'confidence_pct', header: 'Confidence %', render: (r: any) => r.confidence_pct },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'review_due_date', header: 'Review by', render: (r: any) => r.review_due_date },
    { key: 'days_until_review', header: 'Days to review', render: (r: any) => r.days_until_review },
    { key: 'has_retro', header: 'Retro logged', render: (r: any) => (r.has_retro ? 'yes' : 'no') },
  ];

  const dueCols: Column<DueRow>[] = [
    { key: 'decision_title', header: 'Decision', render: (r: any) => r.decision_title },
    { key: 'decided_on', header: 'Decided', render: (r: any) => r.decided_on },
    { key: 'review_due_date', header: 'Due', render: (r: any) => r.review_due_date },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => r.days_overdue },
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'reversibility', header: 'Reversibility', render: (r: any) => r.reversibility },
    { key: 'confidence_pct', header: 'Confidence %', render: (r: any) => r.confidence_pct },
  ];

  const retroCols: Column<RetroRow>[] = [
    { key: 'decision_title', header: 'Decision', render: (r: any) => r.decision_title },
    { key: 'decided_on', header: 'Decided', render: (r: any) => r.decided_on },
    { key: 'reviewed_on', header: 'Reviewed', render: (r: any) => r.reviewed_on },
    { key: 'outcome_rating', header: 'Outcome', render: (r: any) => r.outcome_rating },
    { key: 'lessons_md', header: 'Lessons', render: (r: any) => (r.lessons_md ? r.lessons_md.slice(0, 80) : '—') },
    { key: 'follow_up_action_md', header: 'Follow-up', render: (r: any) => (r.follow_up_action_md ? r.follow_up_action_md.slice(0, 80) : '—') },
  ];

  const calibCols: Column<CalibrationRow>[] = [
    { key: 'confidence_bucket', header: 'Confidence bucket', render: (r: any) => r.confidence_bucket },
    { key: 'decisions_count', header: 'Reviewed decisions', render: (r: any) => r.decisions_count },
    { key: 'better_than_expected', header: 'Better', render: (r: any) => r.better_than_expected },
    { key: 'on_track', header: 'On track', render: (r: any) => r.on_track },
    { key: 'worse_than_expected', header: 'Worse', render: (r: any) => r.worse_than_expected },
    { key: 'too_early', header: 'Too early', render: (r: any) => r.too_early },
  ];

  const catCols: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'total_decisions', header: 'Total', render: (r: any) => r.total_decisions },
    { key: 'pending_review', header: 'Pending review', render: (r: any) => r.pending_review },
    { key: 'reviewed', header: 'Reviewed', render: (r: any) => r.reviewed },
    { key: 'one_way_doors', header: 'One-way doors', render: (r: any) => r.one_way_doors },
    { key: 'avg_confidence', header: 'Avg confidence %', render: (r: any) => r.avg_confidence },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Daily Decision Journal</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Log each meaningful decision with context, options, expected outcome, and confidence. One week later the retrospective check fires — compare actual vs expected to build a calibration record. Helps separate good decisions from good outcomes.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Decisions due for review ({due.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Decisions with review_due_date &lt;= today and no retro yet. One-way doors should be reviewed promptly.
        </p>
        <DataTable
          rows={due}
          columns={dueCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All decisions ({decisions.length})</h2>
        <DataTable
          rows={decisions}
          columns={decisionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Retros logged ({retros.length})</h2>
        <DataTable
          rows={retros}
          columns={retroCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Calibration scorecard ({calibration.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Confidence bucket vs actual outcome. Well-calibrated founders score "on track" or "better" most often in the 60-100 buckets and rarely in 0-39.
        </p>
        <DataTable
          rows={calibration}
          columns={calibCols}
          rowKey={(r: any, i: number) => String(r.confidence_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Category breakdown ({categories.length})</h2>
        <DataTable
          rows={categories}
          columns={catCols}
          rowKey={(r: any, i: number) => String(r.category ?? i)}
        />
      </section>
    </div>
  );
}
