import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

export const dynamic = 'force-dynamic';

async function safeRpc(sb: any, name: string, args: any = {}) {
  try {
    const { data, error } = await sb.rpc(name, args);
    if (error) return [];
    return Array.isArray(data) ? data : [];
  } catch {
    return [];
  }
}

export default async function FounderWeeklyTop3Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const current = await safeRpc(sb, 'fwt3_current_week');
  const recent = await safeRpc(sb, 'fwt3_recent_weeks', { p_limit: 12 });
  const blockers = await safeRpc(sb, 'fwt3_open_blockers');
  const owners = await safeRpc(sb, 'fwt3_owner_scoreboard');

  const totalCurrent = current.length;
  const currentPending = current.filter((r: any) => r.review_status === 'pending').length;
  const currentHit = current.filter((r: any) => r.review_status === 'hit').length;
  const currentMiss = current.filter((r: any) => r.review_status === 'miss').length;
  const openBlockerSum = current.reduce((s: number, r: any) => s + Number(r.open_blocker_count ?? 0), 0);

  const last4 = recent.slice(0, 4);
  const last4Hit = last4.reduce((s: number, r: any) => s + Number(r.hit ?? 0), 0);
  const last4Total = last4.reduce((s: number, r: any) => s + Number(r.total ?? 0), 0);
  const last4Rate = last4Total > 0 ? Math.round((100 * last4Hit) / last4Total) : 0;

  const lifetimeTotal = recent.reduce((s: number, r: any) => s + Number(r.total ?? 0), 0);
  const lifetimeHit = recent.reduce((s: number, r: any) => s + Number(r.hit ?? 0), 0);
  const lifetimeMiss = recent.reduce((s: number, r: any) => s + Number(r.miss ?? 0), 0);
  const lifetimePartial = recent.reduce((s: number, r: any) => s + Number(r.partial ?? 0), 0);
  const lifetimeDropped = recent.reduce((s: number, r: any) => s + Number(r.dropped ?? 0), 0);
  const lifetimeRate = lifetimeTotal > 0 ? Math.round((100 * lifetimeHit) / lifetimeTotal) : 0;

  const critBlockers = blockers.filter((b: any) => b.severity === 'critical').length;
  const highBlockers = blockers.filter((b: any) => b.severity === 'high').length;
  const staleBlockers = blockers.filter((b: any) => Number(b.age_days ?? 0) > 7).length;

  const ownersTracked = owners.length;
  const topOwner = owners[0]?.owner_label ?? '—';
  const weeksTracked = recent.length;

  const kpis: Kpi[] = [
    { label: 'This week priorities', value: String(totalCurrent) },
    { label: 'Pending review', value: String(currentPending) },
    { label: 'This week hits', value: String(currentHit) },
    { label: 'This week misses', value: String(currentMiss) },
    { label: 'Open blockers (this week)', value: String(openBlockerSum) },
    { label: 'Last 4-week hit rate', value: `${last4Rate}%` },
    { label: 'Lifetime hit rate', value: `${lifetimeRate}%` },
    { label: 'Lifetime priorities tracked', value: String(lifetimeTotal) },
    { label: 'Lifetime hits', value: String(lifetimeHit) },
    { label: 'Lifetime misses', value: String(lifetimeMiss) },
    { label: 'Lifetime partial', value: String(lifetimePartial) },
    { label: 'Lifetime dropped', value: String(lifetimeDropped) },
    { label: 'Open blockers total', value: String(blockers.length) },
    { label: 'Critical / High blockers', value: `${critBlockers} / ${highBlockers}` },
    { label: 'Stale blockers ({">"}7d)', value: String(staleBlockers) },
    { label: 'Owners tracked / weeks', value: `${ownersTracked} / ${weeksTracked}` },
  ];

  const currentCols: Column<any>[] = [
    { key: 'slot', header: 'Slot', render: (r: any) => `#${r.slot}` },
    { key: 'title', header: 'Priority', render: (r: any) => r.title ?? '—' },
    { key: 'measurable_outcome', header: 'Measurable outcome', render: (r: any) => r.measurable_outcome ?? '—' },
    { key: 'owner_label', header: 'Owner', render: (r: any) => r.owner_label ?? 'unassigned' },
    { key: 'review_status', header: 'Status', render: (r: any) => r.review_status ?? 'pending' },
    { key: 'open_blocker_count', header: 'Open blockers', render: (r: any) => String(r.open_blocker_count ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'week_start_date', header: 'Week', render: (r: any) => r.week_start_date ?? '—' },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? 0) },
    { key: 'hit', header: 'Hit', render: (r: any) => String(r.hit ?? 0) },
    { key: 'miss', header: 'Miss', render: (r: any) => String(r.miss ?? 0) },
    { key: 'partial', header: 'Partial', render: (r: any) => String(r.partial ?? 0) },
    { key: 'dropped', header: 'Dropped', render: (r: any) => String(r.dropped ?? 0) },
    { key: 'pending', header: 'Pending', render: (r: any) => String(r.pending ?? 0) },
    { key: 'hit_rate_pct', header: 'Hit rate %', render: (r: any) => (r.hit_rate_pct == null ? '—' : `${r.hit_rate_pct}%`) },
  ];

  const blockerCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'priority_title', header: 'Priority', render: (r: any) => r.priority_title ?? '—' },
    { key: 'week_start_date', header: 'Week', render: (r: any) => r.week_start_date ?? '—' },
    { key: 'blocker_text', header: 'Blocker', render: (r: any) => r.blocker_text ?? '—' },
    { key: 'age_days', header: 'Age (days)', render: (r: any) => String(r.age_days ?? 0) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_label', header: 'Owner', render: (r: any) => r.owner_label ?? 'unassigned' },
    { key: 'total_assigned', header: 'Assigned', render: (r: any) => String(r.total_assigned ?? 0) },
    { key: 'hit', header: 'Hit', render: (r: any) => String(r.hit ?? 0) },
    { key: 'miss', header: 'Miss', render: (r: any) => String(r.miss ?? 0) },
    { key: 'hit_rate_pct', header: 'Hit rate %', render: (r: any) => (r.hit_rate_pct == null ? '—' : `${r.hit_rate_pct}%`) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Founder Weekly Top-3</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Monday declaration {">"} Friday review. Per-priority owner + blocker tracking. Top owner this season: {topOwner}.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>This week (current priorities)</h2>
        <DataTable columns={currentCols} rows={current} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent weeks (hit/miss history)</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.week_start_date} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Open blockers</h2>
        <DataTable columns={blockerCols} rows={blockers} rowKey={(r: any) => r.blocker_id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner scoreboard</h2>
        <DataTable columns={ownerCols} rows={owners} rowKey={(r: any) => r.owner_label} />
      </section>
    </main>
  );
}
