import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainFinanceCounterpartMapPage() {
  const supabase = await getSupabaseServerClient();

  const [
    counterpartsRes,
    touchpointsRes,
    weakRes,
    topSpeedRes,
    roleRes,
    cycleRes,
    calendarRes,
  ] = await Promise.all([
    supabase.rpc('list_counterparts_r2491'),
    supabase.rpc('list_touchpoints_r2491'),
    supabase.rpc('weak_relationship_focus_r2491'),
    supabase.rpc('top_resolution_speed_r2491'),
    supabase.rpc('role_breakdown_r2491'),
    supabase.rpc('cycle_preference_summary_r2491'),
    supabase.rpc('recent_touchpoint_calendar_r2491'),
  ]);

  const counterparts = (counterpartsRes.data ?? []) as any[];
  const touchpoints = (touchpointsRes.data ?? []) as any[];
  const weak = (weakRes.data ?? []) as any[];
  const topSpeed = (topSpeedRes.data ?? []) as any[];
  const roleBreakdown = (roleRes.data ?? []) as any[];
  const cycleSummary = (cycleRes.data ?? []) as any[];
  const calendar = (calendarRes.data ?? []) as any[];

  const counterpartCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'counterpart_role', header: 'Role', render: (r: any) => r.counterpart_role },
    { key: 'counterpart_name', header: 'Name', render: (r: any) => r.counterpart_name },
    { key: 'counterpart_email', header: 'Email', render: (r: any) => r.counterpart_email },
    { key: 'cycle_preference', header: 'Cycle', render: (r: any) => r.cycle_preference },
    { key: 'dispute_resolution_speed_hours', header: 'Resolve (hrs)', render: (r: any) => Number(r.dispute_resolution_speed_hours).toFixed(1) },
    { key: 'payment_terms_days', header: 'Terms (days)', render: (r: any) => r.payment_terms_days },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => r.last_touch_at ? new Date(r.last_touch_at).toLocaleDateString() : '—' },
  ];

  const touchpointCols: Column<any>[] = [
    { key: 'touch_at', header: 'When', render: (r: any) => new Date(r.touch_at).toLocaleString() },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'counterpart_name', header: 'Counterpart', render: (r: any) => r.counterpart_name },
    { key: 'touch_kind', header: 'Kind', render: (r: any) => r.touch_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => r.follow_up_at ? new Date(r.follow_up_at).toLocaleDateString() : '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const weakCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'counterpart_role', header: 'Role', render: (r: any) => r.counterpart_role },
    { key: 'counterpart_name', header: 'Name', render: (r: any) => r.counterpart_name },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    { key: 'days_since_last_touch', header: 'Days silent', render: (r: any) => Number(r.days_since_last_touch).toFixed(1) },
    { key: 'payment_terms_days', header: 'Terms (days)', render: (r: any) => r.payment_terms_days },
    { key: 'recommended_action', header: 'Recommended action', render: (r: any) => r.recommended_action },
  ];

  const topSpeedCols: Column<any>[] = [
    { key: 'rank_position', header: '#', render: (r: any) => r.rank_position },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'counterpart_role', header: 'Role', render: (r: any) => r.counterpart_role },
    { key: 'counterpart_name', header: 'Name', render: (r: any) => r.counterpart_name },
    { key: 'dispute_resolution_speed_hours', header: 'Resolve (hrs)', render: (r: any) => Number(r.dispute_resolution_speed_hours).toFixed(1) },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
  ];

  const roleCols: Column<any>[] = [
    { key: 'counterpart_role', header: 'Role', render: (r: any) => r.counterpart_role },
    { key: 'counterpart_count', header: 'Count', render: (r: any) => r.counterpart_count },
    { key: 'avg_resolution_hours', header: 'Avg resolve (hrs)', render: (r: any) => Number(r.avg_resolution_hours).toFixed(1) },
    { key: 'avg_payment_terms_days', header: 'Avg terms (days)', render: (r: any) => Number(r.avg_payment_terms_days).toFixed(1) },
    { key: 'champion_count', header: 'Champions', render: (r: any) => r.champion_count },
    { key: 'weak_count', header: 'Weak', render: (r: any) => r.weak_count },
  ];

  const cycleCols: Column<any>[] = [
    { key: 'cycle_preference', header: 'Cycle', render: (r: any) => r.cycle_preference },
    { key: 'counterpart_count', header: 'Count', render: (r: any) => r.counterpart_count },
    { key: 'avg_payment_terms_days', header: 'Avg terms (days)', render: (r: any) => Number(r.avg_payment_terms_days).toFixed(1) },
    { key: 'avg_resolution_hours', header: 'Avg resolve (hrs)', render: (r: any) => Number(r.avg_resolution_hours).toFixed(1) },
    { key: 'share_pct', header: 'Share %', render: (r: any) => `${Number(r.share_pct).toFixed(1)}%` },
  ];

  const calendarCols: Column<any>[] = [
    { key: 'touch_day', header: 'Day', render: (r: any) => r.touch_day ? new Date(r.touch_day).toLocaleDateString() : '—' },
    { key: 'touch_count', header: 'Touches', render: (r: any) => r.touch_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'negative_count', header: 'Negative', render: (r: any) => r.negative_count },
    { key: 'dispute_resolve_count', header: 'Dispute resolves', render: (r: any) => r.dispute_resolve_count },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.25rem' }}>
        Hospital Chain Finance Team — Counterpart Map
      </h1>
      <p style={{ color: '#666', marginBottom: '1.5rem' }}>
        CFO / AR / AP / treasury & controller relationships across chains. Track cycle preference, dispute resolution speed & relationship strength.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Counterpart roster</h2>
        <DataTable
          rows={counterparts}
          columns={counterpartCols}
          emptyMessage="No counterparts mapped yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Weak / developing relationships — focus list</h2>
        <DataTable
          rows={weak}
          columns={weakCols}
          emptyMessage="No weak relationships — all champions / strong"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Top dispute resolution speed</h2>
        <DataTable
          rows={topSpeed}
          columns={topSpeedCols}
          emptyMessage="No resolution data"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Role breakdown</h2>
        <DataTable
          rows={roleBreakdown}
          columns={roleCols}
          emptyMessage="No role data"
          rowKey={(r: any, i: number) => String(r.counterpart_role ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Cycle preference summary</h2>
        <DataTable
          rows={cycleSummary}
          columns={cycleCols}
          emptyMessage="No cycle data"
          rowKey={(r: any, i: number) => String(r.cycle_preference ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>Recent touchpoint calendar (60 days)</h2>
        <DataTable
          rows={calendar}
          columns={calendarCols}
          emptyMessage="No touchpoints in last 60 days"
          rowKey={(r: any, i: number) => String(r.touch_day ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: '0.5rem' }}>All touchpoints</h2>
        <DataTable
          rows={touchpoints}
          columns={touchpointCols}
          emptyMessage="No touchpoints logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
