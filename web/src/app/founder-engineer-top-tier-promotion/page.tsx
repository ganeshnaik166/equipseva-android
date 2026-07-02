import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type Candidate = {
  id: string;
  engineer_user_id: string;
  engineer_name: string;
  current_tier: string;
  proposed_tier: string;
  candidate_score: number;
  jobs_completed: number;
  avg_hospital_rating: number | null;
  total_revenue_rupees: number;
  months_in_tier: number;
  computed_at: string;
};

type Decision = {
  decision_id: string;
  engineer_user_id: string;
  engineer_name: string;
  decision: string;
  from_tier: string | null;
  to_tier: string | null;
  note: string | null;
  decided_at: string;
};

type TierRollup = {
  tier: string;
  engineers_in_tier: number;
  pending_candidates: number;
  approved_awaiting_promotion: number;
};

type Summary = {
  pending_count: number;
  approved_count: number;
  promoted_last_30d: number;
  rejected_last_30d: number;
  avg_candidate_score: number | null;
  top_score: number | null;
};

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '—';
  return '₹' + Math.round(n).toLocaleString('en-IN');
}

function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export default async function FounderEngineerTopTierPromotionPage() {
  const sb = await getSupabaseServerClient();

  const summaryRes = await sb.rpc('r1651_summary');
  const tierRes = await sb.rpc('r1651_tier_rollup');
  const pendingRes = await sb.rpc('r1651_list_pending_candidates');
  const decisionsRes = await sb.rpc('r1651_list_decisions', { p_limit: 100 });

  const summary: Summary | null = (summaryRes.data?.[0] as Summary) ?? null;
  const tiers: TierRollup[] = (tierRes.data as TierRollup[]) ?? [];
  const pending: Candidate[] = (pendingRes.data as Candidate[]) ?? [];
  const decisions: Decision[] = (decisionsRes.data as Decision[]) ?? [];

  const anyErr =
    summaryRes.error?.message ||
    tierRes.error?.message ||
    pendingRes.error?.message ||
    decisionsRes.error?.message ||
    null;

  const candidateCols: Column<Candidate>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name ?? '—' },
    {
      key: 'tier_move',
      header: 'Tier move',
      render: (r) => (
        <span>
          {(r.current_tier ?? '—') + ' '}
          {'→'}
          {' ' + (r.proposed_tier ?? '—')}
        </span>
      ),
    },
    {
      key: 'candidate_score',
      header: 'Score',
      render: (r) => (r.candidate_score != null ? Number(r.candidate_score).toFixed(2) : '—'),
    },
    { key: 'jobs_completed', header: 'Jobs', render: (r) => r.jobs_completed ?? '—' },
    {
      key: 'avg_hospital_rating',
      header: 'Avg rating',
      render: (r) => (r.avg_hospital_rating != null ? Number(r.avg_hospital_rating).toFixed(2) : '—'),
    },
    {
      key: 'total_revenue_rupees',
      header: 'Revenue',
      render: (r) => fmtRupees(r.total_revenue_rupees),
    },
    { key: 'computed_at', header: 'Computed', render: (r) => fmtDate(r.computed_at) },
  ];

  const decisionCols: Column<Decision>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name ?? '—' },
    { key: 'decision', header: 'Decision', render: (r) => r.decision ?? '—' },
    {
      key: 'tier_move',
      header: 'Tier move',
      render: (r) => (
        <span>
          {(r.from_tier ?? '—') + ' '}
          {'→'}
          {' ' + (r.to_tier ?? '—')}
        </span>
      ),
    },
    { key: 'note', header: 'Note', render: (r) => r.note ?? '—' },
    { key: 'decided_at', header: 'When', render: (r) => fmtDate(r.decided_at) },
  ];

  const tierCols: Column<TierRollup>[] = [
    { key: 'tier', header: 'Tier', render: (r) => r.tier ?? '—' },
    { key: 'engineers_in_tier', header: 'Engineers', render: (r) => r.engineers_in_tier ?? '—' },
    {
      key: 'pending_candidates',
      header: 'Pending candidates',
      render: (r) => r.pending_candidates ?? '—',
    },
    {
      key: 'approved_awaiting_promotion',
      header: 'Approved waiting',
      render: (r) => r.approved_awaiting_promotion ?? '—',
    },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
          Engineer Top-of-Tier Promotion Log
        </h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Engineers maxed in their current tier, scored as candidates for the next tier. Founder
          approves or rejects; promoted records commit the tier change.
        </p>
      </header>

      {anyErr ? (
        <div
          style={{
            padding: 12,
            background: '#fff3f3',
            border: '1px solid #f0caca',
            borderRadius: 6,
            marginBottom: 16,
            color: '#900',
            fontSize: 13,
          }}
        >
          {anyErr}
        </div>
      ) : null}

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
          gap: 12,
          marginBottom: 24,
        }}
      >
        <SummaryCard label="Pending" value={summary?.pending_count ?? 0} />
        <SummaryCard label="Approved" value={summary?.approved_count ?? 0} />
        <SummaryCard label="Promoted (30d)" value={summary?.promoted_last_30d ?? 0} />
        <SummaryCard label="Rejected (30d)" value={summary?.rejected_last_30d ?? 0} />
        <SummaryCard
          label="Avg score"
          value={
            summary?.avg_candidate_score != null
              ? Number(summary.avg_candidate_score).toFixed(2)
              : '—'
          }
        />
        <SummaryCard
          label="Top score"
          value={summary?.top_score != null ? Number(summary.top_score).toFixed(2) : '—'}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Tier rollup</h2>
        <DataTable
          columns={tierCols}
          rows={tiers}
          rowKey={(r: any, i: number) => String(r.tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Pending candidates ({pending.length})
        </h2>
        <DataTable
          columns={candidateCols}
          rows={pending}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent decisions</h2>
        <DataTable
          columns={decisionCols}
          rows={decisions}
          rowKey={(r: any, i: number) => String(r.decision_id ?? i)}
        />
      </section>
    </main>
  );
}

function SummaryCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div
      style={{
        padding: 12,
        border: '1px solid #e3e3e3',
        borderRadius: 6,
        background: '#fafafa',
      }}
    >
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
