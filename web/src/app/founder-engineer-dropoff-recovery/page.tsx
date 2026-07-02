import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

async function safeRpc(sb: any, fn: string, args?: Record<string, any>) {
  try {
    const { data, error } = args ? await sb.rpc(fn, args) : await sb.rpc(fn);
    if (error) return null;
    return data;
  } catch {
    return null;
  }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const kpisRaw = await safeRpc(sb, 'founder_dropoff_kpis');
  const queue = (await safeRpc(sb, 'founder_dropoff_queue')) ?? [];
  const touches = (await safeRpc(sb, 'founder_dropoff_recent_touches')) ?? [];
  const stageBreakdown = (await safeRpc(sb, 'founder_dropoff_stage_breakdown')) ?? [];
  const overdue = (await safeRpc(sb, 'founder_dropoff_overdue')) ?? [];
  const recovered = (await safeRpc(sb, 'founder_dropoff_recovered')) ?? [];

  const k = (kpisRaw ?? {}) as Record<string, any>;

  const kpis: Kpi[] = [
    { label: 'Total engineers', value: k.total_engineers ?? '—' },
    { label: 'Onboarded 7d+', value: k.onboarded_7d_plus ?? '—' },
    { label: 'Drop-off count', value: k.dropoff_count ?? '—' },
    { label: 'Queued', value: k.queued ?? '—' },
    { label: 'Contacted', value: k.contacted ?? '—' },
    { label: 'Responded', value: k.responded ?? '—' },
    { label: 'First bid made', value: k.first_bid_made ?? '—' },
    { label: 'Recovered', value: k.recovered ?? '—' },
    { label: 'Lost', value: k.lost ?? '—' },
    { label: 'Avg days drop-off', value: k.avg_days_dropoff ?? '—' },
    { label: 'Due today', value: k.due_today ?? '—' },
    { label: 'Due 7d', value: k.due_7d ?? '—' },
    { label: 'Total touches', value: k.total_touches ?? '—' },
    { label: 'Recovery rate %', value: k.recovery_rate_pct ?? '—' },
    { label: 'Bucket 7-14d', value: k.bucket_7_14d ?? '—' },
    { label: 'Bucket 30d+', value: k.bucket_30d_plus ?? '—' },
  ];

  const queueCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'engineer_phone', header: 'Phone', render: (r: any) => r.engineer_phone ?? '—' },
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? '—' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'days_since_onboarding', header: 'Days', render: (r: any) => r.days_since_onboarding ?? '—' },
    { key: 'next_action', header: 'Next action', render: (r: any) => r.next_action ?? '—' },
    { key: 'next_action_due_at', header: 'Due', render: (r: any) => r.next_action_due_at ? new Date(r.next_action_due_at).toLocaleDateString() : '—' },
    { key: 'touch_count', header: 'Touches', render: (r: any) => r.touch_count ?? '—' },
  ];

  const touchCols: Column<any>[] = [
    { key: 'touched_at', header: 'When', render: (r: any) => r.touched_at ? new Date(r.touched_at).toLocaleString() : '—' },
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
    { key: 'actor_email', header: 'By', render: (r: any) => r.actor_email ?? '—' },
  ];

  const stageCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt ?? '—' },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'next_action', header: 'Action', render: (r: any) => r.next_action ?? '—' },
    { key: 'next_action_due_at', header: 'Due', render: (r: any) => r.next_action_due_at ? new Date(r.next_action_due_at).toLocaleDateString() : '—' },
    { key: 'overdue_days', header: 'Overdue (d)', render: (r: any) => r.overdue_days ?? '—' },
  ];

  const recoveredCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'recovered_at', header: 'Recovered', render: (r: any) => r.recovered_at ? new Date(r.recovered_at).toLocaleDateString() : '—' },
    { key: 'days_to_recover', header: 'Days to recover', render: (r: any) => r.days_to_recover ?? '—' },
    { key: 'touch_count', header: 'Touches', render: (r: any) => r.touch_count ?? '—' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Drop-off Recovery</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Engineers who completed onboarding but never did first paid job. Reach-out queue and per-engineer recovery state.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((kp) => (
          <div key={kp.label} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{kp.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{String(kp.value)}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Active recovery queue</h2>
        <DataTable rows={queue} columns={queueCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Overdue actions</h2>
        <DataTable rows={overdue} columns={overdueCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent touches</h2>
        <DataTable rows={touches} columns={touchCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Stage breakdown</h2>
        <DataTable rows={stageBreakdown} columns={stageCols} rowKey={(r: any) => r.stage} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recovered engineers</h2>
        <DataTable rows={recovered} columns={recoveredCols} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
