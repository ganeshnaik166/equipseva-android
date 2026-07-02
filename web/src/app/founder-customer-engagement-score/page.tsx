import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ScoreRow = {
  id: string;
  customer_email: string;
  scored_for_month: string;
  portal_login_count: number;
  amc_renewals_count: number;
  nps_score: number | null;
  referrals_made: number;
  composite_score: number;
  tier: string;
  computed_at: string;
};

type TierRow = {
  tier: string;
  customers: number;
  avg_score: number;
};

type ActionRow = {
  id: string;
  customer_email: string;
  action_type: string;
  action_status: string;
  due_by: string | null;
  created_at: string;
};

type AtRiskRow = {
  id: string;
  customer_email: string;
  composite_score: number;
  tier: string;
  scored_for_month: string;
};

type SummaryRow = {
  total_scored: number;
  champions: number;
  cold: number;
  avg_score: number | null;
  open_actions: number;
};

export default async function CustomerEngagementScorePage() {
  const sb = await getSupabaseServerClient();

  const [scoresRes, tiersRes, actionsRes, atRiskRes, summaryRes] = await Promise.all([
    sb.rpc('ces_r2308_latest_scores', { p_limit: 50 }),
    sb.rpc('ces_r2308_tier_distribution', { p_month: null }),
    sb.rpc('ces_r2308_open_actions', { p_limit: 50 }),
    sb.rpc('ces_r2308_top_at_risk', { p_limit: 20 }),
    sb.rpc('ces_r2308_summary'),
  ]);

  const scores: ScoreRow[] = (scoresRes.data as ScoreRow[] | null) ?? [];
  const tiers: TierRow[] = (tiersRes.data as TierRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];
  const atRisk: AtRiskRow[] = (atRiskRes.data as AtRiskRow[] | null) ?? [];
  const summary: SummaryRow | null =
    Array.isArray(summaryRes.data) && summaryRes.data.length > 0
      ? (summaryRes.data[0] as SummaryRow)
      : null;

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'email', header: 'Customer', render: (r) => r.customer_email },
    { key: 'month', header: 'Month', render: (r) => r.scored_for_month },
    { key: 'logins', header: 'Logins', render: (r) => r.portal_login_count },
    { key: 'amc', header: 'AMC renewals', render: (r) => r.amc_renewals_count },
    { key: 'nps', header: 'NPS', render: (r) => r.nps_score ?? '—' },
    { key: 'refs', header: 'Referrals', render: (r) => r.referrals_made },
    { key: 'score', header: 'Score', render: (r) => Number(r.composite_score).toFixed(2) },
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'customers', header: 'Customers', render: (r) => r.customers },
    { key: 'avg', header: 'Avg score', render: (r) => (r.avg_score == null ? '—' : Number(r.avg_score).toFixed(2)) },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'email', header: 'Customer', render: (r) => r.customer_email },
    { key: 'type', header: 'Action', render: (r) => r.action_type },
    { key: 'status', header: 'Status', render: (r) => r.action_status },
    { key: 'due', header: 'Due', render: (r) => r.due_by ?? '—' },
    { key: 'created', header: 'Created', render: (r) => new Date(r.created_at).toLocaleDateString() },
  ];

  const atRiskCols: Column<AtRiskRow>[] = [
    { key: 'email', header: 'Customer', render: (r) => r.customer_email },
    { key: 'score', header: 'Score', render: (r) => Number(r.composite_score).toFixed(2) },
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'month', header: 'Month', render: (r) => r.scored_for_month },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 px-6 py-10">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Customer engagement score</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Composite multi-signal score across portal logins, AMC renewals, NPS &amp; referrals. Score &gt;=75 marks
          champions; score &lt;25 flags cold accounts that need outreach.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-4 md:grid-cols-5">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Scored</div>
          <div className="text-xl font-semibold">{summary?.total_scored ?? 0}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Champions</div>
          <div className="text-xl font-semibold">{summary?.champions ?? 0}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Cold</div>
          <div className="text-xl font-semibold">{summary?.cold ?? 0}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Avg score</div>
          <div className="text-xl font-semibold">
            {summary?.avg_score == null ? '—' : Number(summary.avg_score).toFixed(2)}
          </div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Open actions</div>
          <div className="text-xl font-semibold">{summary?.open_actions ?? 0}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Tier distribution (latest month)</h2>
        <DataTable<TierRow>
          columns={tierCols}
          rows={tiers}
          emptyMessage="No tier data yet."
          rowKey={(r, i) => `${r.tier}-${i}`}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top at-risk customers</h2>
        <DataTable<AtRiskRow>
          columns={atRiskCols}
          rows={atRisk}
          emptyMessage="No cold or lukewarm customers."
          rowKey={(r) => r.id}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Latest scores</h2>
        <DataTable<ScoreRow>
          columns={scoreCols}
          rows={scores}
          emptyMessage="No scores recorded yet."
          rowKey={(r) => r.id}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Open engagement actions</h2>
        <DataTable<ActionRow>
          columns={actionCols}
          rows={actions}
          emptyMessage="No open actions."
          rowKey={(r) => r.id}
        />
      </section>
    </main>
  );
}
