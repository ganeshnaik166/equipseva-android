import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function pct(n: number | null | undefined) {
  return Number(n ?? 0).toFixed(2) + '%';
}

function dt(s: string | null | undefined) {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return String(s);
  }
}

function commitmentBadge(level: string) {
  const map: Record<string, string> = {
    signed: 'bg-green-100 text-green-800',
    loi: 'bg-blue-100 text-blue-800',
    verbal: 'bg-amber-100 text-amber-800',
    none: 'bg-gray-100 text-gray-700',
    dropped: 'bg-red-100 text-red-800',
  };
  const cls = map[level] || 'bg-gray-100 text-gray-700';
  return <span className={`rounded px-2 py-0.5 text-xs font-medium ${cls}`}>{level}</span>;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    conversations,
    funnel,
    blockers,
    expiring,
    atRisk,
    health,
    weekly,
  ] = await Promise.all([
    sb.rpc('list_renewal_conversations_r2411'),
    sb.rpc('commitment_funnel_r2411'),
    sb.rpc('top_blockers_r2411'),
    sb.rpc('expiring_soon_r2411'),
    sb.rpc('top_arr_at_risk_r2411'),
    sb.rpc('chain_renewal_health_r2411'),
    sb.rpc('weekly_progress_r2411'),
  ]);

  const conversationsRows = (conversations.data ?? []) as any[];
  const funnelRows = (funnel.data ?? []) as any[];
  const blockerRows = (blockers.data ?? []) as any[];
  const expiringRows = (expiring.data ?? []) as any[];
  const atRiskRows = (atRisk.data ?? []) as any[];
  const healthRows = (health.data ?? []) as any[];
  const weeklyRows = (weekly.data ?? []) as any[];

  const totalSigned = funnelRows
    .filter((r) => r.commitment_level === 'signed')
    .reduce((s, r) => s + Number(r.total_arr_rupees ?? 0), 0);
  const totalLoi = funnelRows
    .filter((r) => r.commitment_level === 'loi')
    .reduce((s, r) => s + Number(r.total_arr_rupees ?? 0), 0);
  const totalAtRisk = atRiskRows.reduce((s, r) => s + Number(r.at_risk_rupees ?? 0), 0);
  const totalUncommitted = expiringRows.reduce(
    (s, r) => s + Number(r.uncommitted_gap_rupees ?? 0),
    0
  );

  const conversationCols: Column<any>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'when', header: 'When', render: (r: any) => dt(r.conversation_at) },
    { key: 'commit', header: 'Commit', render: (r: any) => commitmentBadge(r.commitment_level) },
    { key: 'term', header: 'Term (yrs)', render: (r: any) => String(r.term_years) },
    { key: 'val', header: 'Per Year', render: (r: any) => rupees(r.value_per_year_rupees) },
    { key: 'total', header: 'Total Deal', render: (r: any) => <span className="font-semibold">{rupees(r.total_deal_value_rupees)}</span> },
    { key: 'blocker', header: 'Blocker', render: (r: any) => (
        <div>
          <div className="text-xs font-medium">{r.blocker_kind}</div>
          {r.blocker_notes ? <div className="text-xs text-gray-600">{r.blocker_notes}</div> : null}
        </div>
    ) },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'next', header: 'Next Step', render: (r: any) => (
        <div>
          <div>{dt(r.next_step_due_at)}</div>
          {r.days_until_next_step !== null && r.days_until_next_step !== undefined ? (
            <div className={`text-xs ${Number(r.days_until_next_step) < 0 ? 'text-red-700' : 'text-gray-600'}`}>
              {Number(r.days_until_next_step) >= 0 ? `in ${r.days_until_next_step}d` : `${Math.abs(Number(r.days_until_next_step))}d overdue`}
            </div>
          ) : null}
        </div>
    ) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'level', header: 'Commitment', render: (r: any) => commitmentBadge(r.commitment_level) },
    { key: 'count', header: 'Convos', render: (r: any) => String(r.conversation_count) },
    { key: 'arr', header: 'Total ARR', render: (r: any) => <span className="font-semibold">{rupees(r.total_arr_rupees)}</span> },
    { key: 'term', header: 'Avg Term (yrs)', render: (r: any) => String(r.avg_term_years ?? '—') },
  ];

  const blockerCols: Column<any>[] = [
    { key: 'kind', header: 'Blocker Kind', render: (r: any) => <span className="font-medium">{r.blocker_kind}</span> },
    { key: 'count', header: 'Count', render: (r: any) => String(r.blocker_count) },
    { key: 'arr', header: 'ARR Blocked', render: (r: any) => <span className="font-semibold text-red-700">{rupees(r.arr_blocked_rupees)}</span> },
    { key: 'chains', header: 'Chains Impacted', render: (r: any) => String(r.chains_impacted) },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'snap', header: 'Snapshot', render: (r: any) => String(r.snapshot_date) },
    { key: '90', header: 'Expiring 90d', render: (r: any) => rupees(r.expiring_in_90d_rupees) },
    { key: '180', header: 'Expiring 180d', render: (r: any) => rupees(r.expiring_in_180d_rupees) },
    { key: 'commit', header: 'Committed', render: (r: any) => <span className="text-green-700">{rupees(r.committed_renewal_rupees)}</span> },
    { key: 'gap', header: 'Uncommitted Gap', render: (r: any) => <span className="font-semibold text-amber-700">{rupees(r.uncommitted_gap_rupees)}</span> },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'hosp', header: 'Hospitals', render: (r: any) => String(r.hospital_count) },
    { key: 'total', header: 'Total ARR', render: (r: any) => rupees(r.total_arr_rupees) },
    { key: 'risk', header: 'At-Risk ARR', render: (r: any) => <span className="font-semibold text-red-700">{rupees(r.at_risk_rupees)}</span> },
    { key: 'pct', header: '% At Risk', render: (r: any) => pct(r.at_risk_pct) },
  ];

  const healthCols: Column<any>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span className="font-medium">{r.chain_name}</span> },
    { key: 'commit', header: 'Latest Commit', render: (r: any) => commitmentBadge(r.latest_commitment) },
    { key: 'convos', header: 'Conversations', render: (r: any) => String(r.conversation_count) },
    { key: 'total', header: 'Deal Value', render: (r: any) => <span className="font-semibold">{rupees(r.total_deal_value_rupees)}</span> },
    { key: 'last', header: 'Last Touch', render: (r: any) => dt(r.last_conversation_at) },
    { key: 'block', header: 'Open Blocker?', render: (r: any) => (
        r.has_open_blocker
          ? <span className="rounded bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800">yes</span>
          : <span className="rounded bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800">no</span>
    ) },
    { key: 'due', header: 'Next Due', render: (r: any) => dt(r.next_due_at) },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week', header: 'Week Of', render: (r: any) => String(r.week_start) },
    { key: 'convos', header: 'Convos', render: (r: any) => String(r.conversation_count) },
    { key: 'signed', header: 'Signed', render: (r: any) => <span className="text-green-700 font-medium">{r.signed_count}</span> },
    { key: 'loi', header: 'LOI', render: (r: any) => <span className="text-blue-700 font-medium">{r.loi_count}</span> },
    { key: 'verbal', header: 'Verbal', render: (r: any) => <span className="text-amber-700 font-medium">{r.verbal_count}</span> },
    { key: 'arr', header: 'ARR Progressed', render: (r: any) => <span className="font-semibold">{rupees(r.arr_progressed_rupees)}</span> },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Renewal Commitment Desk</h1>
        <p className="text-sm text-gray-600">
          Multi-year renewal conversations &amp; ARR exposure across hospital chains.
          Track commitment funnel (verbal =&gt; LOI =&gt; signed), blockers blocking ARR,
          and uncommitted gap on contracts expiring &lt;= 180 days.
        </p>
      </header>

      <section className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-gray-500">Signed ARR</div>
          <div className="mt-1 text-xl font-bold text-green-700">{rupees(totalSigned)}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-gray-500">LOI ARR</div>
          <div className="mt-1 text-xl font-bold text-blue-700">{rupees(totalLoi)}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-gray-500">At-Risk ARR</div>
          <div className="mt-1 text-xl font-bold text-red-700">{rupees(totalAtRisk)}</div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-gray-500">Uncommitted Gap (180d)</div>
          <div className="mt-1 text-xl font-bold text-amber-700">{rupees(totalUncommitted)}</div>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Commitment Funnel</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No commitment data yet."
          rowKey={(r: any, i: number) => String(r.commitment_level ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Top Blockers (ARR Blocked)</h2>
        <DataTable
          rows={blockerRows}
          columns={blockerCols}
          emptyMessage="No open blockers. Clean pipeline."
          rowKey={(r: any, i: number) => String(r.blocker_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Expiring Soon & Uncommitted Gap</h2>
        <DataTable
          rows={expiringRows}
          columns={expiringCols}
          emptyMessage="No ARR snapshots loaded."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Top ARR At Risk</h2>
        <DataTable
          rows={atRiskRows}
          columns={atRiskCols}
          emptyMessage="No at-risk chains identified."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Per-Chain Renewal Health</h2>
        <DataTable
          rows={healthRows}
          columns={healthCols}
          emptyMessage="No chains tracked yet."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Weekly Progress (Last 12 Weeks)</h2>
        <DataTable
          rows={weeklyRows}
          columns={weeklyCols}
          emptyMessage="No conversations logged yet."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">All Conversations</h2>
        <DataTable
          rows={conversationsRows}
          columns={conversationCols}
          emptyMessage="No renewal conversations logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
