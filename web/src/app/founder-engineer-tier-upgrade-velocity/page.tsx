import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerTierUpgradeVelocityPage() {
  const sb = await getSupabaseServerClient();

  const { data: velocitiesData } = await sb.rpc('list_tier_velocities_r2136');
  const { data: acceleratingData } = await sb.rpc('accelerating_tier_velocities_r2136');
  const { data: recentActionsData } = await sb.rpc('recent_tier_upgrade_actions_r2136');

  const velocities = (velocitiesData ?? []) as any[];
  const accelerating = (acceleratingData ?? []) as any[];
  const recentActions = (recentActionsData ?? []) as any[];

  const velocityColumns: Column<any>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => String(r.region_label ?? '') },
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'upgrades_to_bronze', header: 'Bronze', render: (r: any) => String(r.upgrades_to_bronze ?? 0) },
    { key: 'upgrades_to_silver', header: 'Silver', render: (r: any) => String(r.upgrades_to_silver ?? 0) },
    { key: 'upgrades_to_gold', header: 'Gold', render: (r: any) => String(r.upgrades_to_gold ?? 0) },
    { key: 'upgrades_to_platinum', header: 'Platinum', render: (r: any) => String(r.upgrades_to_platinum ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Tier Upgrade Velocity</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track tier upgrade velocity per region. Spot accelerating cohorts, coach decelerating ones, escalate blocked reviews.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Velocity Snapshots</h2>
        <DataTable
          rows={velocities}
          columns={velocityColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Accelerating Regions</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>
          Regions currently showing accelerating upgrade momentum. Celebrate and replicate.
        </p>
        <DataTable
          rows={accelerating}
          columns={velocityColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>
          Last 50 actions logged across all velocity snapshots.
        </p>
        <DataTable
          rows={recentActions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
