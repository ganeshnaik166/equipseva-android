import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CatalogRow = {
  quest_id: string;
  slug: string;
  title: string;
  category: string;
  difficulty: string;
  bonus_rupees: number;
  is_active: boolean;
  opted_in_count: number;
  approved_count: number;
  paid_count: number;
  total_payout_rupees: number;
  closes_at: string | null;
};

type PendingRow = {
  completion_id: string;
  quest_title: string;
  category: string;
  engineer_user_id: string;
  engineer_tier: string | null;
  bonus_rupees: number;
  submitted_at: string;
  hours_waiting: number;
  evidence_url: string | null;
};

type LeaderRow = {
  engineer_user_id: string;
  engineer_tier: string | null;
  quests_opted_in: number;
  quests_approved: number;
  quests_paid: number;
  total_bonus_rupees: number;
  latest_completion_at: string | null;
};

type CategoryRow = {
  category: string;
  quest_count: number;
  total_opt_ins: number;
  total_approved: number;
  total_bonus_paid_rupees: number;
  avg_bonus_rupees: number;
};

type StaleRow = {
  completion_id: string;
  quest_title: string;
  category: string;
  engineer_user_id: string;
  engineer_tier: string | null;
  opted_in_at: string;
  days_stale: number;
  closes_at: string | null;
};

type PayoutRow = {
  month_label: string;
  paid_count: number;
  total_bonus_rupees: number;
  unique_engineers: number;
  avg_bonus_rupees: number;
};

function inr(n: number | null | undefined): string {
  if (n == null) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function shortId(id: string | null | undefined): string {
  if (!id) return '—';
  return id.slice(0, 8);
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  return new Date(s).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

export default async function FounderEngineerSideQuestPage() {
  const sb = await getSupabaseServerClient();

  const [catalog, pending, leader, category, stale, payouts] = await Promise.all([
    sb.rpc('founder_side_quest_catalog'),
    sb.rpc('founder_side_quest_pending_review'),
    sb.rpc('founder_side_quest_engineer_leaderboard'),
    sb.rpc('founder_side_quest_category_mix'),
    sb.rpc('founder_side_quest_stale_opt_ins'),
    sb.rpc('founder_side_quest_payout_summary'),
  ]);

  const catalogRows: CatalogRow[] = (catalog.data ?? []) as CatalogRow[];
  const pendingRows: PendingRow[] = (pending.data ?? []) as PendingRow[];
  const leaderRows: LeaderRow[] = (leader.data ?? []) as LeaderRow[];
  const categoryRows: CategoryRow[] = (category.data ?? []) as CategoryRow[];
  const staleRows: StaleRow[] = (stale.data ?? []) as StaleRow[];
  const payoutRows: PayoutRow[] = (payouts.data ?? []) as PayoutRow[];

  const activeQuests = catalogRows.filter(r => r.is_active).length;
  const totalOptIns = catalogRows.reduce((acc, r) => acc + Number(r.opted_in_count ?? 0), 0);
  const totalPaid = catalogRows.reduce((acc, r) => acc + Number(r.total_payout_rupees ?? 0), 0);
  const pendingReview = pendingRows.length;

  const catalogCols: Column<CatalogRow>[] = [
    { key: 'title', header: 'Quest', render: (r) => r.title ?? '—' },
    { key: 'category', header: 'Category', render: (r) => r.category ?? '—' },
    { key: 'difficulty', header: 'Difficulty', render: (r) => r.difficulty ?? '—' },
    { key: 'bonus_rupees', header: 'Bonus', render: (r) => inr(r.bonus_rupees) },
    { key: 'is_active', header: 'Active', render: (r) => (r.is_active ? 'yes' : 'no') },
    { key: 'opted_in_count', header: 'Opted in', render: (r) => String(r.opted_in_count ?? 0) },
    { key: 'approved_count', header: 'Approved', render: (r) => String(r.approved_count ?? 0) },
    { key: 'paid_count', header: 'Paid', render: (r) => String(r.paid_count ?? 0) },
    { key: 'total_payout_rupees', header: 'Total payout', render: (r) => inr(r.total_payout_rupees) },
    { key: 'closes_at', header: 'Closes', render: (r) => fmtDate(r.closes_at) },
  ];

  const pendingCols: Column<PendingRow>[] = [
    { key: 'quest_title', header: 'Quest', render: (r) => r.quest_title ?? '—' },
    { key: 'category', header: 'Category', render: (r) => r.category ?? '—' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r) => shortId(r.engineer_user_id) },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier ?? '—' },
    { key: 'bonus_rupees', header: 'Bonus', render: (r) => inr(r.bonus_rupees) },
    { key: 'submitted_at', header: 'Submitted', render: (r) => fmtDate(r.submitted_at) },
    { key: 'hours_waiting', header: 'Hours waiting', render: (r) => String(r.hours_waiting ?? 0) },
    { key: 'evidence_url', header: 'Evidence', render: (r) => r.evidence_url ?? '—' },
  ];

  const leaderCols: Column<LeaderRow>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r) => shortId(r.engineer_user_id) },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier ?? '—' },
    { key: 'quests_opted_in', header: 'Opted in', render: (r) => String(r.quests_opted_in ?? 0) },
    { key: 'quests_approved', header: 'Approved', render: (r) => String(r.quests_approved ?? 0) },
    { key: 'quests_paid', header: 'Paid', render: (r) => String(r.quests_paid ?? 0) },
    { key: 'total_bonus_rupees', header: 'Total bonus', render: (r) => inr(r.total_bonus_rupees) },
    { key: 'latest_completion_at', header: 'Latest', render: (r) => fmtDate(r.latest_completion_at) },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category ?? '—' },
    { key: 'quest_count', header: 'Quests', render: (r) => String(r.quest_count ?? 0) },
    { key: 'total_opt_ins', header: 'Opt-ins', render: (r) => String(r.total_opt_ins ?? 0) },
    { key: 'total_approved', header: 'Approved', render: (r) => String(r.total_approved ?? 0) },
    { key: 'total_bonus_paid_rupees', header: 'Bonus paid', render: (r) => inr(r.total_bonus_paid_rupees) },
    { key: 'avg_bonus_rupees', header: 'Avg bonus', render: (r) => inr(r.avg_bonus_rupees) },
  ];

  const staleCols: Column<StaleRow>[] = [
    { key: 'quest_title', header: 'Quest', render: (r) => r.quest_title ?? '—' },
    { key: 'category', header: 'Category', render: (r) => r.category ?? '—' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r) => shortId(r.engineer_user_id) },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier ?? '—' },
    { key: 'opted_in_at', header: 'Opted in', render: (r) => fmtDate(r.opted_in_at) },
    { key: 'days_stale', header: 'Days stale', render: (r) => String(r.days_stale ?? 0) },
    { key: 'closes_at', header: 'Closes', render: (r) => fmtDate(r.closes_at) },
  ];

  const payoutCols: Column<PayoutRow>[] = [
    { key: 'month_label', header: 'Month', render: (r) => r.month_label ?? '—' },
    { key: 'paid_count', header: 'Paid count', render: (r) => String(r.paid_count ?? 0) },
    { key: 'total_bonus_rupees', header: 'Total bonus', render: (r) => inr(r.total_bonus_rupees) },
    { key: 'unique_engineers', header: 'Engineers', render: (r) => String(r.unique_engineers ?? 0) },
    { key: 'avg_bonus_rupees', header: 'Avg bonus', render: (r) => inr(r.avg_bonus_rupees) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>Engineer Side-Quest Log</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Optional skill challenges, certifications, and community demos. Per-engineer opt-in with bonus payouts.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', marginBottom: '32px' }}>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase' }}>Active quests</div>
          <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{activeQuests}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase' }}>Total opt-ins</div>
          <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{totalOptIns}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase' }}>Pending review</div>
          <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{pendingReview}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase' }}>Bonus paid total</div>
          <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{inr(totalPaid)}</div>
        </div>
      </div>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Quest catalog</h2>
        <DataTable<CatalogRow> rows={catalogRows} columns={catalogCols} rowKey={(r) => r.quest_id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Pending review</h2>
        <DataTable<PendingRow> rows={pendingRows} columns={pendingCols} rowKey={(r) => r.completion_id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Engineer leaderboard</h2>
        <DataTable<LeaderRow> rows={leaderRows} columns={leaderCols} rowKey={(r) => r.engineer_user_id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Category mix</h2>
        <DataTable<CategoryRow> rows={categoryRows} columns={categoryCols} rowKey={(r) => r.category} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Stale opt-ins (no submission 14+ days)</h2>
        <DataTable<StaleRow> rows={staleRows} columns={staleCols} rowKey={(r) => r.completion_id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Payout summary by month</h2>
        <DataTable<PayoutRow> rows={payoutRows} columns={payoutCols} rowKey={(r) => r.month_label} />
      </section>
    </div>
  );
}
