import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function Card({ k }: { k: Kpi }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
      <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
    </div>
  );
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let pending: any[] = [];
  let flagged: any[] = [];
  let scorecard: any[] = [];
  let decisions: any[] = [];
  let tierStats: any[] = [];
  let overdue: any[] = [];

  try {
    const r = await sb.rpc('founder_promotion_review_kpis');
    kpis = (r.data && r.data[0]) || null;
  } catch {}
  try {
    const r = await sb.rpc('founder_promotion_review_pending');
    pending = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_promotion_review_demote_flagged');
    flagged = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_promotion_review_scorecard');
    scorecard = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_promotion_review_recent_decisions');
    decisions = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_promotion_review_tier_stats');
    tierStats = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_promotion_review_overdue');
    overdue = r.data || [];
  } catch {}

  const cards: Kpi[] = [
    { label: 'Total reviews', value: String(kpis?.total_reviews ?? '—') },
    { label: 'Pending', value: String(kpis?.pending_reviews ?? '—') },
    { label: 'Overdue', value: String(kpis?.overdue_reviews ?? '—') },
    { label: 'Approved', value: String(kpis?.approved_reviews ?? '—') },
    { label: 'Demote flagged', value: String(kpis?.demote_flagged ?? '—') },
    { label: 'Hold flagged', value: String(kpis?.hold_flagged ?? '—') },
    { label: 'Completed', value: String(kpis?.completed_reviews ?? '—') },
    { label: 'Due next 7d', value: String(kpis?.due_next_7d ?? '—') },
    { label: 'Due next 30d', value: String(kpis?.due_next_30d ?? '—') },
    { label: 'Engineers reviewed', value: String(kpis?.total_engineers_reviewed ?? '—') },
    { label: 'Avg scorecard rating', value: String(kpis?.avg_scorecard_rating ?? '—') },
    { label: 'Total jobs', value: String(kpis?.total_jobs_completed ?? '—') },
    { label: 'Total payout (rupees)', value: String(kpis?.total_payout_rupees ?? '—') },
    { label: 'Total disputes', value: String(kpis?.total_disputes ?? '—') },
    { label: 'Demote rate %', value: String(kpis?.demote_rate_pct ?? '—') },
    { label: 'Approve rate %', value: String(kpis?.approve_rate_pct ?? '—') },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'promoted_from_tier', header: 'From', render: (r: any) => r.promoted_from_tier ?? '—' },
    { key: 'promoted_to_tier', header: 'To', render: (r: any) => r.promoted_to_tier ?? '—' },
    { key: 'review_due_at', header: 'Due', render: (r: any) => r.review_due_at ?? '—' },
    { key: 'days_until_due', header: 'Days', render: (r: any) => r.days_until_due ?? '—' },
    { key: 'scorecard_jobs_completed', header: 'Jobs', render: (r: any) => r.scorecard_jobs_completed ?? '—' },
    { key: 'scorecard_avg_rating', header: 'Rating', render: (r: any) => r.scorecard_avg_rating ?? '—' },
    { key: 'scorecard_disputes', header: 'Disputes', render: (r: any) => r.scorecard_disputes ?? '—' },
  ];

  const flaggedCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'promoted_to_tier', header: 'Tier', render: (r: any) => r.promoted_to_tier ?? '—' },
    { key: 'scorecard_avg_rating', header: 'Rating', render: (r: any) => r.scorecard_avg_rating ?? '—' },
    { key: 'scorecard_disputes', header: 'Disputes', render: (r: any) => r.scorecard_disputes ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
    { key: 'flagged_at', header: 'When', render: (r: any) => r.flagged_at ?? '—' },
  ];

  const scorecardCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'cached_highest_tier', header: 'Tier', render: (r: any) => r.cached_highest_tier ?? '—' },
    { key: 'jobs_last_90d', header: 'Jobs 90d', render: (r: any) => r.jobs_last_90d ?? '—' },
    { key: 'avg_rating_last_90d', header: 'Rating 90d', render: (r: any) => r.avg_rating_last_90d ?? '—' },
    { key: 'disputes_last_90d', header: 'Disputes 90d', render: (r: any) => r.disputes_last_90d ?? '—' },
    { key: 'payout_last_90d_rupees', header: 'Payout 90d', render: (r: any) => r.payout_last_90d_rupees ?? '—' },
    { key: 'review_status', header: 'Status', render: (r: any) => r.review_status ?? '—' },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? '—' },
    { key: 'decided_at', header: 'When', render: (r: any) => r.decided_at ?? '—' },
    { key: 'decided_by_email', header: 'By', render: (r: any) => r.decided_by_email ?? '—' },
    { key: 'rationale', header: 'Rationale', render: (r: any) => r.rationale ?? '—' },
  ];

  const tierCols: Column<any>[] = [
    { key: 'promoted_from_tier', header: 'From', render: (r: any) => r.promoted_from_tier ?? '—' },
    { key: 'promoted_to_tier', header: 'To', render: (r: any) => r.promoted_to_tier ?? '—' },
    { key: 'total_reviews', header: 'Total', render: (r: any) => r.total_reviews ?? '—' },
    { key: 'approved_count', header: 'Approved', render: (r: any) => r.approved_count ?? '—' },
    { key: 'demoted_count', header: 'Demoted', render: (r: any) => r.demoted_count ?? '—' },
    { key: 'hold_count', header: 'Hold', render: (r: any) => r.hold_count ?? '—' },
    { key: 'approve_rate_pct', header: 'Approve %', render: (r: any) => r.approve_rate_pct ?? '—' },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'promoted_to_tier', header: 'Tier', render: (r: any) => r.promoted_to_tier ?? '—' },
    { key: 'review_due_at', header: 'Due', render: (r: any) => r.review_due_at ?? '—' },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => r.days_overdue ?? '—' },
    { key: 'scorecard_avg_rating', header: 'Rating', render: (r: any) => r.scorecard_avg_rating ?? '—' },
    { key: 'scorecard_disputes', header: 'Disputes', render: (r: any) => r.scorecard_disputes ?? '—' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Post-Promotion Review</h1>
      <p style={{ fontSize: 14, color: '#6b7280', marginBottom: 16 }}>
        T+90 day audit: per-engineer scorecard, demotion-trigger flag, founder decision log.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, marginBottom: 24 }}>
        {cards.map((k, i) => <Card key={i} k={k} />)}
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '16px 0 8px' }}>Pending reviews</h2>
      <DataTable columns={pendingCols} rows={pending} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Overdue reviews</h2>
      <DataTable columns={overdueCols} rows={overdue} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Demote-flagged engineers</h2>
      <DataTable columns={flaggedCols} rows={flagged} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Per-engineer 90d scorecard</h2>
      <DataTable columns={scorecardCols} rows={scorecard} rowKey={(r: any) => r.engineer_id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Tier transition stats</h2>
      <DataTable columns={tierCols} rows={tierStats} rowKey={(r: any) => `${r.promoted_from_tier}-${r.promoted_to_tier}`} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Recent decisions</h2>
      <DataTable columns={decisionCols} rows={decisions} rowKey={(r: any) => r.id} />
    </div>
  );
}
