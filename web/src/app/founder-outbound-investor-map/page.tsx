import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TargetRow = {
  id: string;
  target_investor_name: string;
  target_firm: string | null;
  expected_check_rupees: number | null;
  intro_path_md: string | null;
  priority: string;
  status: string;
  last_action_at: string | null;
  attempts_count: number;
  created_at: string;
};

type AttemptRow = {
  id: string;
  target_id: string;
  target_investor_name: string;
  attempt_via: string;
  attempted_at: string;
  by_email: string | null;
  response: string | null;
};

type PrioritySummaryRow = {
  priority: string;
  target_count: number;
  expected_check_total_rupees: number;
  unconnected_count: number;
  in_dialog_count: number;
  closed_count: number;
};

type FunnelRow = {
  stage: string;
  stage_order: number;
  target_count: number;
  pct_of_total: number;
};

function formatRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + Math.round(n).toLocaleString('en-IN');
}

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: 'numeric' });
}

export default async function FounderOutboundInvestorMapPage() {
  const sb = await getSupabaseServerClient();

  const [targetsRes, attemptsRes, summaryRes, funnelRes] = await Promise.all([
    sb.rpc('r1758_list_targets'),
    sb.rpc('r1758_list_attempts', { p_target_id: null }),
    sb.rpc('r1758_priority_summary'),
    sb.rpc('r1758_conversion_funnel'),
  ]);

  const targets: TargetRow[] = (targetsRes.data as TargetRow[] | null) ?? [];
  const attempts: AttemptRow[] = (attemptsRes.data as AttemptRow[] | null) ?? [];
  const summary: PrioritySummaryRow[] = (summaryRes.data as PrioritySummaryRow[] | null) ?? [];
  const funnel: FunnelRow[] = (funnelRes.data as FunnelRow[] | null) ?? [];

  const anyError =
    targetsRes.error || attemptsRes.error || summaryRes.error || funnelRes.error;

  const totalTargets = targets.length;
  const totalExpectedCheck = targets.reduce(
    (acc, t) => acc + (t.expected_check_rupees ?? 0),
    0,
  );
  const tier1Count = targets.filter((t) => t.priority === 'tier_1').length;
  const inDialogCount = targets.filter((t) => t.status === 'in_dialog').length;

  const targetColumns: Column<TargetRow>[] = [
    {
      key: 'investor',
      header: 'Investor',
      render: (r: TargetRow) => (
        <div>
          <div className="font-medium">{r.target_investor_name}</div>
          <div className="text-xs text-[var(--color-muted)]">{r.target_firm ?? '—'}</div>
        </div>
      ),
    },
    {
      key: 'priority',
      header: 'Priority',
      render: (r: TargetRow) => {
        const cls =
          r.priority === 'tier_1'
            ? 'bg-red-100 text-red-700'
            : r.priority === 'tier_2'
              ? 'bg-amber-100 text-amber-700'
              : 'bg-gray-100 text-gray-700';
        return (
          <span className={'inline-block rounded px-2 py-0.5 text-xs ' + cls}>
            {r.priority}
          </span>
        );
      },
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: TargetRow) => <span className="text-xs">{r.status}</span>,
    },
    {
      key: 'check',
      header: 'Expected check',
      render: (r: TargetRow) => <span>{formatRupees(r.expected_check_rupees)}</span>,
    },
    {
      key: 'attempts',
      header: 'Attempts',
      render: (r: TargetRow) => <span>{r.attempts_count}</span>,
    },
    {
      key: 'last_action',
      header: 'Last action',
      render: (r: TargetRow) => <span className="text-xs">{formatDate(r.last_action_at)}</span>,
    },
    {
      key: 'intro_path',
      header: 'Intro path',
      render: (r: TargetRow) => (
        <span className="text-xs text-[var(--color-muted)]">
          {r.intro_path_md ?? '—'}
        </span>
      ),
    },
  ];

  const attemptColumns: Column<AttemptRow>[] = [
    {
      key: 'when',
      header: 'When',
      render: (r: AttemptRow) => <span className="text-xs">{formatDate(r.attempted_at)}</span>,
    },
    {
      key: 'target',
      header: 'Target',
      render: (r: AttemptRow) => <span>{r.target_investor_name}</span>,
    },
    {
      key: 'via',
      header: 'Via',
      render: (r: AttemptRow) => <span className="text-xs">{r.attempt_via}</span>,
    },
    {
      key: 'by',
      header: 'By',
      render: (r: AttemptRow) => (
        <span className="text-xs text-[var(--color-muted)]">{r.by_email ?? '—'}</span>
      ),
    },
    {
      key: 'response',
      header: 'Response',
      render: (r: AttemptRow) => (
        <span className="text-xs">{r.response ?? '—'}</span>
      ),
    },
  ];

  const summaryColumns: Column<PrioritySummaryRow>[] = [
    {
      key: 'priority',
      header: 'Priority',
      render: (r: PrioritySummaryRow) => <span className="font-medium">{r.priority}</span>,
    },
    {
      key: 'targets',
      header: 'Targets',
      render: (r: PrioritySummaryRow) => <span>{r.target_count}</span>,
    },
    {
      key: 'expected',
      header: 'Expected check total',
      render: (r: PrioritySummaryRow) => (
        <span>{formatRupees(r.expected_check_total_rupees)}</span>
      ),
    },
    {
      key: 'unconnected',
      header: 'Unconnected',
      render: (r: PrioritySummaryRow) => <span>{r.unconnected_count}</span>,
    },
    {
      key: 'in_dialog',
      header: 'In dialog',
      render: (r: PrioritySummaryRow) => <span>{r.in_dialog_count}</span>,
    },
    {
      key: 'closed',
      header: 'Closed',
      render: (r: PrioritySummaryRow) => <span>{r.closed_count}</span>,
    },
  ];

  const funnelColumns: Column<FunnelRow>[] = [
    {
      key: 'order',
      header: 'Step',
      render: (r: FunnelRow) => <span className="text-xs">{r.stage_order}</span>,
    },
    {
      key: 'stage',
      header: 'Stage',
      render: (r: FunnelRow) => <span className="font-medium">{r.stage}</span>,
    },
    {
      key: 'count',
      header: 'Targets',
      render: (r: FunnelRow) => <span>{r.target_count}</span>,
    },
    {
      key: 'pct',
      header: 'Share of pipeline',
      render: (r: FunnelRow) => <span>{Number(r.pct_of_total).toFixed(1)}%</span>,
    },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Outbound Investor Map</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Investors the founder wants to reach, the intro path planned, and the
          outbound attempts logged against each target.
        </p>
      </header>

      {anyError ? (
        <div className="rounded border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          Failed to load outbound investor map. Founder access only.
        </div>
      ) : null}

      <section className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
            Total targets
          </div>
          <div className="mt-1 text-2xl font-semibold">{totalTargets}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
            Tier-1 targets
          </div>
          <div className="mt-1 text-2xl font-semibold">{tier1Count}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
            Currently in dialog
          </div>
          <div className="mt-1 text-2xl font-semibold">{inDialogCount}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
            Expected check total
          </div>
          <div className="mt-1 text-2xl font-semibold">
            {formatRupees(totalExpectedCheck)}
          </div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Pipeline by priority</h2>
        <p className="text-sm text-[var(--color-muted)]">
          Tier-1 names are the highest-conviction prospects: target a small,
          deliberate list rather than spraying intros.
        </p>
        <DataTable
          rows={summary}
          columns={summaryColumns}
          rowKey={(r, i) => String(r.priority ?? i)}
          emptyMessage="No outbound targets yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Conversion funnel</h2>
        <p className="text-sm text-[var(--color-muted)]">
          Step-by-step view from cold target to closed outcome.
        </p>
        <DataTable
          rows={funnel}
          columns={funnelColumns}
          rowKey={(r, i) => String(r.stage ?? i)}
          emptyMessage="No funnel data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Target list</h2>
        <p className="text-sm text-[var(--color-muted)]">
          Tier-1 first, then Tier-2 and Tier-3. Intro path notes the warmest known
          path to each name.
        </p>
        <DataTable
          rows={targets}
          columns={targetColumns}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No investor targets added yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent intro attempts</h2>
        <p className="text-sm text-[var(--color-muted)]">
          Most recent 200 outbound attempts across all targets.
        </p>
        <DataTable
          rows={attempts}
          columns={attemptColumns}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No intro attempts logged yet."
        />
      </section>
    </main>
  );
}
