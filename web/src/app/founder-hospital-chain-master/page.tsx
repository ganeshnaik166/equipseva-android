import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_chains: number;
  active_chains: number;
  suspended_chains: number;
  draft_chains: number;
  total_included_locations: number;
  total_excluded_locations: number;
  platinum_chains: number;
  gold_chains: number;
};

type ChainRow = {
  id: string;
  chain_name: string | null;
  parent_org_name: string | null;
  contract_code: string | null;
  master_tier: string | null;
  status: string | null;
  effective_from: string | null;
  effective_to: string | null;
  included_count: number | null;
  excluded_count: number | null;
  created_at: string | null;
};

type MembershipRow = {
  id: string;
  chain_name: string | null;
  hospital_name: string | null;
  hospital_state: string | null;
  membership_kind: string | null;
  has_override: boolean | null;
  added_at: string | null;
  removed_at: string | null;
};

type TierRow = {
  master_tier: string | null;
  chain_count: number | null;
  included_locations: number | null;
  repair_jobs_30d: number | null;
  revenue_30d_rupees: number | null;
};

export default async function FounderHospitalChainMasterPage() {
  const sb = await getSupabaseServerClient();

  const [overviewRes, chainsRes, membershipsRes, tierRes] = await Promise.all([
    sb.rpc('get_chain_master_overview'),
    sb.rpc('list_chain_master_contracts'),
    sb.rpc('list_chain_memberships'),
    sb.rpc('get_chain_revenue_by_tier'),
  ]);

  const overview = (overviewRes.data?.[0] ?? null) as Overview | null;
  const chains = (chainsRes.data ?? []) as ChainRow[];
  const memberships = (membershipsRes.data ?? []) as MembershipRow[];
  const tierBreakdown = (tierRes.data ?? []) as TierRow[];

  const chainCols: Column<ChainRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: ChainRow) => r.chain_name ?? '—' },
    { key: 'parent_org_name', header: 'Parent Org', render: (r: ChainRow) => r.parent_org_name ?? '—' },
    { key: 'contract_code', header: 'Code', render: (r: ChainRow) => r.contract_code ?? '—' },
    { key: 'master_tier', header: 'Tier', render: (r: ChainRow) => (r.master_tier ?? '—').toUpperCase() },
    { key: 'status', header: 'Status', render: (r: ChainRow) => r.status ?? '—' },
    { key: 'effective_from', header: 'From', render: (r: ChainRow) => r.effective_from ?? '—' },
    { key: 'effective_to', header: 'To', render: (r: ChainRow) => r.effective_to ?? '—' },
    { key: 'included_count', header: 'Included', render: (r: ChainRow) => String(r.included_count ?? 0) },
    { key: 'excluded_count', header: 'Excluded', render: (r: ChainRow) => String(r.excluded_count ?? 0) },
  ];

  const memberCols: Column<MembershipRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: MembershipRow) => r.chain_name ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: MembershipRow) => r.hospital_name ?? '—' },
    { key: 'hospital_state', header: 'State', render: (r: MembershipRow) => r.hospital_state ?? '—' },
    { key: 'membership_kind', header: 'Kind', render: (r: MembershipRow) => r.membership_kind ?? '—' },
    { key: 'has_override', header: 'Rate Override', render: (r: MembershipRow) => (r.has_override ? 'yes' : 'no') },
    { key: 'added_at', header: 'Added', render: (r: MembershipRow) => (r.added_at ? new Date(r.added_at).toLocaleString() : '—') },
    { key: 'removed_at', header: 'Removed', render: (r: MembershipRow) => (r.removed_at ? new Date(r.removed_at).toLocaleString() : '—') },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'master_tier', header: 'Tier', render: (r: TierRow) => (r.master_tier ?? '—').toUpperCase() },
    { key: 'chain_count', header: 'Chains', render: (r: TierRow) => String(r.chain_count ?? 0) },
    { key: 'included_locations', header: 'Locations', render: (r: TierRow) => String(r.included_locations ?? 0) },
    { key: 'repair_jobs_30d', header: 'Jobs 30d', render: (r: TierRow) => String(r.repair_jobs_30d ?? 0) },
    { key: 'revenue_30d_rupees', header: 'Revenue 30d (Rs)', render: (r: TierRow) => `Rs ${(r.revenue_30d_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Hospital Chain Master Contracts</h1>
        <p style={{ color: '#666', marginTop: 8 }}>
          Parent-chain agreements covering multiple hospital locations. Per-chain inclusion/exclusion lists with rate-card binding.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <KPI label="Total Chains" value={overview?.total_chains ?? 0} />
        <KPI label="Active" value={overview?.active_chains ?? 0} />
        <KPI label="Suspended" value={overview?.suspended_chains ?? 0} />
        <KPI label="Draft" value={overview?.draft_chains ?? 0} />
        <KPI label="Included Locations" value={overview?.total_included_locations ?? 0} />
        <KPI label="Excluded Locations" value={overview?.total_excluded_locations ?? 0} />
        <KPI label="Platinum Chains" value={overview?.platinum_chains ?? 0} />
        <KPI label="Gold Chains" value={overview?.gold_chains ?? 0} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Revenue by Tier (last 30 days)</h2>
        <DataTable
          columns={tierCols}
          rows={tierBreakdown}
          rowKey={(r: any, i: number) => String(r.id ?? r.master_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Chain Master Contracts</h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 12 }}>
          {"<contract_code> binds chain-wide rate card. Per-location override via membership table."}
        </p>
        <DataTable
          columns={chainCols}
          rows={chains}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Membership Changes</h2>
        <DataTable
          columns={memberCols}
          rows={memberships}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

function KPI({ label, value }: { label: string; value: number | string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
