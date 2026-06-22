import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalLoyaltyProgramPage() {
  const sb = await getSupabaseServerClient();

  const [tiersRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_tiers_r1951'),
    sb.rpc('top_tier_hospitals_r1951'),
    sb.rpc('recent_actions_r1951'),
  ]);

  const tiers: any[] = Array.isArray(tiersRes.data) ? tiersRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const tierCols: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'tier', header: 'Tier', render: (r: any) => String(r.tier ?? '') },
    { key: 'lifetime_value_rupees', header: 'LTV (Rs)', render: (r: any) => String(r.lifetime_value_rupees ?? 0) },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => String(r.jobs_completed ?? 0) },
    { key: 'current_streak_days', header: 'Streak (d)', render: (r: any) => String(r.current_streak_days ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_activity_at', header: 'Last Activity', render: (r: any) => r.last_activity_at ? new Date(r.last_activity_at).toLocaleString() : '-' },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'tier', header: 'Tier', render: (r: any) => String(r.tier ?? '') },
    { key: 'lifetime_value_rupees', header: 'LTV (Rs)', render: (r: any) => String(r.lifetime_value_rupees ?? 0) },
    { key: 'jobs_completed', header: 'Jobs', render: (r: any) => String(r.jobs_completed ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'tier_id', header: 'Tier', render: (r: any) => String(r.tier_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Loyalty Program</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Loyalty tiers for top hospitals. Tracks lifetime value, jobs completed, and active streaks across bronze, silver, gold, platinum, and founder circle tiers.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Loyalty Tiers</h2>
        <p style={{ color: '#777', marginBottom: 12 }}>
          Hospitals ranked by lifetime value. Showing up to 200 records.
        </p>
        <DataTable rows={tiers} columns={tierCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Tier Hospitals</h2>
        <p style={{ color: '#777', marginBottom: 12 }}>
          Active platinum and founder circle hospitals. Top 50 by lifetime value.
        </p>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Loyalty Actions</h2>
        <p style={{ color: '#777', marginBottom: 12 }}>
          Last 100 tier actions taken. Includes upgrades, rewards, and communications sent.
        </p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
