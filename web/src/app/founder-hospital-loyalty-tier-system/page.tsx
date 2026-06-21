import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [tiersRes, perksRes, distRes, topRes] = await Promise.all([
    sb.rpc('list_loyalty_tiers_r1739'),
    sb.rpc('list_loyalty_perks_r1739'),
    sb.rpc('loyalty_tier_distribution_r1739'),
    sb.rpc('top_loyal_hospitals_r1739'),
  ]);

  const tiers = (tiersRes.data ?? []) as any[];
  const perks = (perksRes.data ?? []) as any[];
  const dist = (distRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];

  const tierCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) ?? '-' },
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => String(r.loyalty_tier ?? '-').toUpperCase() },
    { key: 'years_active', header: 'Years', render: (r: any) => String(r.years_active ?? 0) },
    { key: 'total_spend_rupees', header: 'Spend', render: (r: any) => `₹${Number(r.total_spend_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'last_assessed_at', header: 'Assessed', render: (r: any) => r.last_assessed_at ? new Date(r.last_assessed_at).toLocaleString('en-IN') : '-' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '-' },
  ];

  const perkCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => String(r.loyalty_tier ?? '-').toUpperCase() },
    { key: 'perk_type', header: 'Perk', render: (r: any) => String(r.perk_type ?? '-').replace(/_/g, ' ') },
    { key: 'activated_at', header: 'Activated', render: (r: any) => r.activated_at ? new Date(r.activated_at).toLocaleString('en-IN') : '-' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString('en-IN') : '-' },
    { key: 'used', header: 'Used', render: (r: any) => (r.used ? 'YES' : 'NO') },
    { key: 'used_at', header: 'Used At', render: (r: any) => r.used_at ? new Date(r.used_at).toLocaleString('en-IN') : '-' },
  ];

  const distCols: Column<any>[] = [
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => String(r.loyalty_tier ?? '-').toUpperCase() },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => String(r.hospital_count ?? 0) },
    { key: 'total_spend_rupees', header: 'Total Spend', render: (r: any) => `₹${Number(r.total_spend_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) ?? '-' },
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => String(r.loyalty_tier ?? '-').toUpperCase() },
    { key: 'years_active', header: 'Years', render: (r: any) => String(r.years_active ?? 0) },
    { key: 'total_spend_rupees', header: 'Spend', render: (r: any) => `₹${Number(r.total_spend_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'perks_activated', header: 'Perks', render: (r: any) => String(r.perks_activated ?? 0) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Loyalty Tier System</h1>
        <p className="text-sm text-gray-600">
          Tiers: bronze &lt; silver &lt; gold &lt; platinum. Platinum requires &gt;=5 years &amp; &gt;=₹1Cr spend.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier Distribution</h2>
        <DataTable
          rows={dist}
          columns={distCols}
          rowKey={(r: any, i: number) => String(r.loyalty_tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Loyal Hospitals</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Tier Records ({tiers.length})</h2>
        <DataTable
          rows={tiers}
          columns={tierCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Perk Activations ({perks.length})</h2>
        <DataTable
          rows={perks}
          columns={perkCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
