import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type VersionRollup = {
  id?: string;
  deck_version: string;
  total_assigned: number;
  total_signed: number;
  total_pending: number;
  total_overdue: number;
  total_declined: number;
  total_waived: number;
  pct_signed: number | null;
  earliest_deadline: string | null;
  latest_signed_at: string | null;
};

type MemberStatus = {
  id: string;
  assignee_user_id: string;
  assignee_email: string | null;
  assignee_name: string | null;
  status: string;
  assigned_at: string;
  deadline_at: string;
  signed_at: string | null;
  followup_count: number;
  last_followup_at: string | null;
  days_overdue: number;
  declined_reason: string | null;
};

type DeadlineAlert = {
  id: string;
  deck_version: string;
  assignee_email: string | null;
  assignee_name: string | null;
  status: string;
  deadline_at: string;
  hours_to_deadline: number | null;
  followup_count: number;
  bucket: string;
};

type VersionComparison = {
  id?: string;
  metric: string;
  version_a_value: number | null;
  version_b_value: number | null;
  delta: number | null;
};

export default async function FounderCultureDeckSignaturesPage({
  searchParams,
}: {
  searchParams?: Promise<{ version?: string; va?: string; vb?: string }>;
}) {
  const sp = (await searchParams) ?? {};
  const sb = await getSupabaseServerClient();

  const rollupRes = await sb.rpc('rpc_r1646_signature_version_rollup');
  const rollups: VersionRollup[] = (rollupRes.data ?? []) as VersionRollup[];

  const focusVersion = sp.version ?? rollups[0]?.deck_version ?? '';
  const memberRes = focusVersion
    ? await sb.rpc('rpc_r1646_member_status', { p_deck_version: focusVersion })
    : { data: [] as MemberStatus[] };
  const members: MemberStatus[] = (memberRes.data ?? []) as MemberStatus[];

  const alertRes = await sb.rpc('rpc_r1646_deadline_alerts');
  const alerts: DeadlineAlert[] = (alertRes.data ?? []) as DeadlineAlert[];

  const versionA = sp.va ?? rollups[0]?.deck_version ?? '';
  const versionB = sp.vb ?? rollups[1]?.deck_version ?? '';
  const cmpRes = versionA && versionB
    ? await sb.rpc('rpc_r1646_version_comparison', { p_version_a: versionA, p_version_b: versionB })
    : { data: [] as VersionComparison[] };
  const comparison: VersionComparison[] = (cmpRes.data ?? []) as VersionComparison[];

  const totalSigned = rollups.reduce((a, r) => a + (r.total_signed ?? 0), 0);
  const totalAssigned = rollups.reduce((a, r) => a + (r.total_assigned ?? 0), 0);
  const totalOverdue = rollups.reduce((a, r) => a + (r.total_overdue ?? 0), 0);
  const overallPct = totalAssigned > 0 ? Math.round((totalSigned * 1000) / totalAssigned) / 10 : 0;

  const rollupCols: Column<VersionRollup>[] = [
    { key: 'deck_version', header: 'Version', render: (r) => r.deck_version ?? '—' },
    { key: 'total_assigned', header: 'Assigned', render: (r) => String(r.total_assigned ?? 0) },
    { key: 'total_signed', header: 'Signed', render: (r) => String(r.total_signed ?? 0) },
    { key: 'total_pending', header: 'Pending', render: (r) => String(r.total_pending ?? 0) },
    { key: 'total_overdue', header: 'Overdue', render: (r) => String(r.total_overdue ?? 0) },
    { key: 'total_declined', header: 'Declined', render: (r) => String(r.total_declined ?? 0) },
    { key: 'pct_signed', header: '% Signed', render: (r) => (r.pct_signed != null ? `${r.pct_signed}%` : '—') },
    {
      key: 'earliest_deadline',
      header: 'Earliest Deadline',
      render: (r) => (r.earliest_deadline ? new Date(r.earliest_deadline).toLocaleDateString() : '—'),
    },
  ];

  const memberCols: Column<MemberStatus>[] = [
    { key: 'assignee_name', header: 'Member', render: (r) => r.assignee_name ?? r.assignee_email ?? '—' },
    { key: 'assignee_email', header: 'Email', render: (r) => r.assignee_email ?? '—' },
    { key: 'status', header: 'Status', render: (r) => (r.status ?? '—').toUpperCase() },
    {
      key: 'deadline_at',
      header: 'Deadline',
      render: (r) => (r.deadline_at ? new Date(r.deadline_at).toLocaleDateString() : '—'),
    },
    {
      key: 'signed_at',
      header: 'Signed',
      render: (r) => (r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '—'),
    },
    { key: 'days_overdue', header: 'Days Overdue', render: (r) => String(r.days_overdue ?? 0) },
    { key: 'followup_count', header: 'Follow-ups', render: (r) => String(r.followup_count ?? 0) },
    {
      key: 'last_followup_at',
      header: 'Last Follow-up',
      render: (r) => (r.last_followup_at ? new Date(r.last_followup_at).toLocaleDateString() : '—'),
    },
  ];

  const alertCols: Column<DeadlineAlert>[] = [
    { key: 'deck_version', header: 'Version', render: (r) => r.deck_version ?? '—' },
    { key: 'assignee_name', header: 'Member', render: (r) => r.assignee_name ?? r.assignee_email ?? '—' },
    { key: 'bucket', header: 'Bucket', render: (r) => (r.bucket ?? '—').toUpperCase() },
    { key: 'status', header: 'Status', render: (r) => (r.status ?? '—').toUpperCase() },
    {
      key: 'deadline_at',
      header: 'Deadline',
      render: (r) => (r.deadline_at ? new Date(r.deadline_at).toLocaleString() : '—'),
    },
    {
      key: 'hours_to_deadline',
      header: 'Hours Left',
      render: (r) => (r.hours_to_deadline != null ? r.hours_to_deadline.toFixed(1) : '—'),
    },
    { key: 'followup_count', header: 'Follow-ups', render: (r) => String(r.followup_count ?? 0) },
  ];

  const cmpCols: Column<VersionComparison>[] = [
    { key: 'metric', header: 'Metric', render: (r) => r.metric ?? '—' },
    {
      key: 'version_a_value',
      header: `A: ${versionA || '—'}`,
      render: (r) => (r.version_a_value != null ? String(r.version_a_value) : '—'),
    },
    {
      key: 'version_b_value',
      header: `B: ${versionB || '—'}`,
      render: (r) => (r.version_b_value != null ? String(r.version_b_value) : '—'),
    },
    { key: 'delta', header: 'Δ (B − A)', render: (r) => (r.delta != null ? String(r.delta) : '—') },
  ];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Culture-Deck Signature Tracker</h1>
        <p className="text-sm text-gray-600">
          r1646 — extends r1496. Per-member status, deadline alerts, founder follow-up log, and per-version comparison.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total Assigned</div>
          <div className="text-2xl font-semibold">{totalAssigned}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total Signed</div>
          <div className="text-2xl font-semibold">{totalSigned}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Overdue</div>
          <div className="text-2xl font-semibold">{totalOverdue}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Overall % Signed</div>
          <div className="text-2xl font-semibold">{overallPct}%</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Per-Version Rollup</h2>
        <DataTable
          columns={rollupCols}
          rows={rollups}
          rowKey={(r: any, i: number) => String(r.id ?? r.deck_version ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">
          Member Status {focusVersion ? `· ${focusVersion}` : ''}
        </h2>
        <p className="text-xs text-gray-500">
          Append {"?version=<deck_version>"} in the URL to focus a different deck.
        </p>
        <DataTable
          columns={memberCols}
          rows={members}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Deadline Alerts (next 7 days)</h2>
        <DataTable
          columns={alertCols}
          rows={alerts}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">
          Version Comparison {versionA && versionB ? `· ${versionA} vs ${versionB}` : ''}
        </h2>
        <p className="text-xs text-gray-500">
          Append {"?va=<A>&vb=<B>"} to compare two specific versions.
        </p>
        <DataTable
          columns={cmpCols}
          rows={comparison}
          rowKey={(r: any, i: number) => String(r.id ?? r.metric ?? i)}
        />
      </section>
    </main>
  );
}
