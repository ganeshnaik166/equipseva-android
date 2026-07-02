import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorLoyaltyProgramPage() {
  const sb = await getSupabaseServerClient();

  const [tiersRes, perksRes, distRes, unusedRes] = await Promise.all([
    sb.rpc('r1721_list_tiers'),
    sb.rpc('r1721_list_perks'),
    sb.rpc('r1721_tier_distribution'),
    sb.rpc('r1721_unused_perks_per_investor'),
  ]);

  const tiers = (tiersRes.data ?? []) as any[];
  const perks = (perksRes.data ?? []) as any[];
  const dist = (distRes.data ?? []) as any[];
  const unused = (unusedRes.data ?? []) as any[];

  const tierColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) ?? '—' },
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => <span className="uppercase font-semibold">{r.loyalty_tier}</span> },
    { key: 'total_invested_rupees', header: 'Total Invested (₹)', render: (r: any) => Number(r.total_invested_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'years_since_first_check', header: 'Years', render: (r: any) => String(r.years_since_first_check ?? 0) },
    { key: 'last_recomputed_at', header: 'Last Recomputed', render: (r: any) => r.last_recomputed_at ? new Date(r.last_recomputed_at).toLocaleString() : '—' },
  ];

  const perkColumns: Column<any>[] = [
    { key: 'perk_type', header: 'Perk', render: (r: any) => r.perk_type },
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => <span className="uppercase">{r.loyalty_tier}</span> },
    { key: 'activated_at', header: 'Activated', render: (r: any) => r.activated_at ? new Date(r.activated_at).toLocaleDateString() : '—' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—' },
    { key: 'used', header: 'Used', render: (r: any) => r.used ? 'Yes' : 'No' },
    { key: 'used_at', header: 'Used At', render: (r: any) => r.used_at ? new Date(r.used_at).toLocaleDateString() : '—' },
  ];

  const distColumns: Column<any>[] = [
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => <span className="uppercase font-semibold">{r.loyalty_tier}</span> },
    { key: 'investor_count', header: 'Investors', render: (r: any) => String(r.investor_count ?? 0) },
    { key: 'total_invested_rupees', header: 'Total Invested (₹)', render: (r: any) => Number(r.total_invested_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const unusedColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) ?? '—' },
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => <span className="uppercase">{r.loyalty_tier}</span> },
    { key: 'unused_perks', header: 'Unused', render: (r: any) => String(r.unused_perks ?? 0) },
    { key: 'total_perks', header: 'Total', render: (r: any) => String(r.total_perks ?? 0) },
  ];

  return (
    <div className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Investor Loyalty Program</h1>
        <p className="text-sm text-gray-600 mt-1">
          Reward repeat and loyal investors with tiered perks — bronze, silver, gold, platinum.
          Tier promotion requires both invested amount &gt;= threshold and tenure &gt;= minimum years.
        </p>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier Distribution</h2>
        <DataTable rows={dist} columns={distColumns} rowKey={(r: any, i: number) => String(r.loyalty_tier ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Investor Tiers</h2>
        <DataTable rows={tiers} columns={tierColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Perk Activations</h2>
        <DataTable rows={perks} columns={perkColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Unused Perks Per Investor</h2>
        <p className="text-xs text-gray-500 mb-2">
          Investors with unused perks &gt; 0 are good candidates for outreach before perks expire.
        </p>
        <DataTable rows={unused} columns={unusedColumns} rowKey={(r: any, i: number) => String(r.investor_id ?? i)} />
      </section>
    </div>
  );
}
