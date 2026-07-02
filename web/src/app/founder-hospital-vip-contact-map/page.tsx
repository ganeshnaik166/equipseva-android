import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalVipContactMapPage() {
  const sb = await getSupabaseServerClient();

  const rosterRes = await sb.rpc('founder_hospital_vip_tier_a_roster');
  const treeRes = await sb.rpc('founder_hospital_vip_contact_tree');
  const distRes = await sb.rpc('founder_hospital_vip_relationship_distribution');
  const staleRes = await sb.rpc('founder_hospital_vip_stale_contacts');
  const revRes = await sb.rpc('founder_hospital_vip_revenue_link');
  const touchRes = await sb.rpc('founder_hospital_vip_recent_touchpoints');

  const roster: any[] = (rosterRes.data as any[]) ?? [];
  const tree: any[] = (treeRes.data as any[]) ?? [];
  const dist: any[] = (distRes.data as any[]) ?? [];
  const stale: any[] = (staleRes.data as any[]) ?? [];
  const rev: any[] = (revRes.data as any[]) ?? [];
  const touch: any[] = (touchRes.data as any[]) ?? [];

  const rosterCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'state', header: 'State', render: (r) => r.state ?? '—' },
    { key: 'vip_count', header: 'VIPs', render: (r) => r.vip_count ?? 0 },
    { key: 'champion_count', header: 'Champions', render: (r) => r.champion_count ?? 0 },
    { key: 'warm_count', header: 'Warm', render: (r) => r.warm_count ?? 0 },
    { key: 'cold_count', header: 'Cold', render: (r) => r.cold_count ?? 0 },
    { key: 'hostile_count', header: 'Hostile', render: (r) => r.hostile_count ?? 0 },
    { key: 'last_touch_at', header: 'Last touch', render: (r) => r.last_touch_at ? new Date(r.last_touch_at).toLocaleDateString() : '—' },
  ];

  const treeCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name ?? '—' },
    { key: 'contact_role', header: 'Role', render: (r) => r.contact_role ?? '—' },
    { key: 'relationship_tier', header: 'Relationship', render: (r) => r.relationship_tier ?? '—' },
    { key: 'owned_by', header: 'Owner', render: (r) => r.owned_by ?? '—' },
    { key: 'seniority_rank', header: 'Rank', render: (r) => r.seniority_rank ?? '—' },
    { key: 'last_contacted_at', header: 'Last contact', render: (r) => r.last_contacted_at ? new Date(r.last_contacted_at).toLocaleDateString() : '—' },
  ];

  const distCols: Column<any>[] = [
    { key: 'relationship_tier', header: 'Tier', render: (r) => r.relationship_tier ?? '—' },
    { key: 'contact_count', header: 'Contacts', render: (r) => r.contact_count ?? 0 },
    { key: 'tier_a_count', header: 'In Tier-A', render: (r) => r.tier_a_count ?? 0 },
    { key: 'pct_of_total', header: '% of total', render: (r) => r.pct_of_total != null ? `${r.pct_of_total}%` : '—' },
  ];

  const staleCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name ?? '—' },
    { key: 'contact_role', header: 'Role', render: (r) => r.contact_role ?? '—' },
    { key: 'relationship_tier', header: 'Relationship', render: (r) => r.relationship_tier ?? '—' },
    { key: 'days_since_touch', header: 'Days stale', render: (r) => r.days_since_touch ?? '—' },
    { key: 'owned_by', header: 'Owner', render: (r) => r.owned_by ?? '—' },
  ];

  const revCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'champion_count', header: 'Champions', render: (r) => r.champion_count ?? 0 },
    { key: 'jobs_90d', header: 'Jobs 90d', render: (r) => r.jobs_90d ?? 0 },
    { key: 'revenue_90d_rupees', header: 'Revenue 90d', render: (r) => r.revenue_90d_rupees != null ? `₹${Number(r.revenue_90d_rupees).toLocaleString('en-IN')}` : '—' },
    { key: 'avg_rating', header: 'Avg rating', render: (r) => r.avg_rating ?? '—' },
  ];

  const touchCols: Column<any>[] = [
    { key: 'touched_at', header: 'When', render: (r) => r.touched_at ? new Date(r.touched_at).toLocaleString() : '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'contact_name', header: 'Contact', render: (r) => r.contact_name ?? '—' },
    { key: 'touchpoint_kind', header: 'Kind', render: (r) => r.touchpoint_kind ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome ?? '—' },
    { key: 'summary', header: 'Summary', render: (r) => r.summary ?? '—' },
    { key: 'recorded_by_email', header: 'By', render: (r) => r.recorded_by_email ?? '—' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital VIP contact map</h1>
        <p className="text-sm text-gray-600">Per Tier-A hospital decision-maker tree (CEO, biomedical, procurement) with relationship-tier vs founder/CSM.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier-A hospital roster</h2>
        <DataTable<any>
          rows={roster}
          columns={rosterCols}
          rowKey={(r: any, i: number) => String(r.hospital_org_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Relationship distribution</h2>
        <DataTable<any>
          rows={dist}
          columns={distCols}
          rowKey={(r: any, i: number) => String(r.relationship_tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Full contact tree</h2>
        <DataTable<any>
          rows={tree}
          columns={treeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stale champions/warm (30d+)</h2>
        <DataTable<any>
          rows={stale}
          columns={staleCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Revenue link (90d)</h2>
        <DataTable<any>
          rows={rev}
          columns={revCols}
          rowKey={(r: any, i: number) => String(r.hospital_org_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent touchpoints</h2>
        <DataTable<any>
          rows={touch}
          columns={touchCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
