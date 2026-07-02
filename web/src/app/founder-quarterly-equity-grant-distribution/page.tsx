import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, byRoleRes, byTierRes, listRes, vestingRes, milestoneRes, statusRes, topRes] = await Promise.all([
    supabase.rpc('founder_equity_grant_kpis_r2741'),
    supabase.rpc('founder_equity_grants_by_role_r2741'),
    supabase.rpc('founder_equity_grants_by_tier_r2741'),
    supabase.rpc('founder_equity_grants_list_r2741'),
    supabase.rpc('founder_vesting_schedule_r2741'),
    supabase.rpc('founder_grants_by_milestone_r2741'),
    supabase.rpc('founder_vesting_status_summary_r2741'),
    supabase.rpc('founder_top_strategic_grants_r2741'),
  ]);

  const kpis = (kpisRes.data ?? [])[0] ?? { total_grants: 0, total_shares: 0, total_strategic_value: 0, avg_vesting_months: 0 };
  const byRole = byRoleRes.data ?? [];
  const byTier = byTierRes.data ?? [];
  const list = listRes.data ?? [];
  const vesting = vestingRes.data ?? [];
  const milestones = milestoneRes.data ?? [];
  const statuses = statusRes.data ?? [];
  const top = topRes.data ?? [];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Equity Grant Distribution</h1>
        <p className="text-sm text-gray-600">Founder console · grantee × role × tier × vesting × milestone × strategic value</p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Total Grants</div>
          <div className="text-2xl font-bold">{String(kpis.total_grants ?? 0)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Total Shares</div>
          <div className="text-2xl font-bold">{String(kpis.total_shares ?? 0)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Strategic Value (Rs)</div>
          <div className="text-2xl font-bold">{Number(kpis.total_strategic_value ?? 0).toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Avg Vesting (months)</div>
          <div className="text-2xl font-bold">{Number(kpis.avg_vesting_months ?? 0).toFixed(1)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Grants by Role</h2>
        <DataTable
          rows={byRole}
          columns={[
            { key: 'grantee_role', header: 'Role', render: (r: any) => r.grantee_role },
            { key: 'grant_count', header: 'Grants', render: (r: any) => String(r.grant_count) },
            { key: 'total_shares', header: 'Shares', render: (r: any) => String(r.total_shares) },
            { key: 'total_value', header: 'Value (Rs)', render: (r: any) => Number(r.total_value).toLocaleString('en-IN') },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.grantee_role ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Grants by Tier</h2>
        <DataTable
          rows={byTier}
          columns={[
            { key: 'tier', header: 'Tier', render: (r: any) => r.tier },
            { key: 'grant_count', header: 'Grants', render: (r: any) => String(r.grant_count) },
            { key: 'total_shares', header: 'Shares', render: (r: any) => String(r.total_shares) },
            { key: 'avg_strike', header: 'Avg Strike (Rs)', render: (r: any) => Number(r.avg_strike).toFixed(2) },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Grants</h2>
        <DataTable
          rows={list}
          columns={[
            { key: 'grantee_name', header: 'Grantee', render: (r: any) => r.grantee_name },
            { key: 'grantee_role', header: 'Role', render: (r: any) => r.grantee_role },
            { key: 'tier', header: 'Tier', render: (r: any) => r.tier },
            { key: 'grant_quarter', header: 'Quarter', render: (r: any) => r.grant_quarter },
            { key: 'shares_granted', header: 'Shares', render: (r: any) => String(r.shares_granted) },
            { key: 'strike_price_rupees', header: 'Strike (Rs)', render: (r: any) => Number(r.strike_price_rupees).toFixed(2) },
            { key: 'vesting_months', header: 'Vesting (mo)', render: (r: any) => String(r.vesting_months) },
            { key: 'cliff_months', header: 'Cliff (mo)', render: (r: any) => String(r.cliff_months) },
            { key: 'milestone_tag', header: 'Milestone', render: (r: any) => r.milestone_tag },
            { key: 'strategic_value_rupees', header: 'Strategic Value (Rs)', render: (r: any) => Number(r.strategic_value_rupees).toLocaleString('en-IN') },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Vesting Schedule</h2>
        <DataTable
          rows={vesting}
          columns={[
            { key: 'grantee_name', header: 'Grantee', render: (r: any) => r.grantee_name },
            { key: 'vesting_date', header: 'Date', render: (r: any) => r.vesting_date },
            { key: 'shares_vested', header: 'Shares', render: (r: any) => String(r.shares_vested) },
            { key: 'event_type', header: 'Event', render: (r: any) => r.event_type },
            { key: 'value_at_vesting_rupees', header: 'Value (Rs)', render: (r: any) => Number(r.value_at_vesting_rupees).toLocaleString('en-IN') },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Grants by Milestone</h2>
        <DataTable
          rows={milestones}
          columns={[
            { key: 'milestone_tag', header: 'Milestone', render: (r: any) => r.milestone_tag },
            { key: 'grant_count', header: 'Grants', render: (r: any) => String(r.grant_count) },
            { key: 'total_shares', header: 'Shares', render: (r: any) => String(r.total_shares) },
            { key: 'total_value', header: 'Value (Rs)', render: (r: any) => Number(r.total_value).toLocaleString('en-IN') },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.milestone_tag ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Vesting Status Summary</h2>
        <DataTable
          rows={statuses}
          columns={[
            { key: 'status', header: 'Status', render: (r: any) => r.status },
            { key: 'event_count', header: 'Events', render: (r: any) => String(r.event_count) },
            { key: 'total_shares', header: 'Shares', render: (r: any) => String(r.total_shares) },
            { key: 'total_value', header: 'Value (Rs)', render: (r: any) => Number(r.total_value).toLocaleString('en-IN') },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Strategic Grants</h2>
        <DataTable
          rows={top}
          columns={[
            { key: 'grantee_name', header: 'Grantee', render: (r: any) => r.grantee_name },
            { key: 'grantee_role', header: 'Role', render: (r: any) => r.grantee_role },
            { key: 'tier', header: 'Tier', render: (r: any) => r.tier },
            { key: 'strategic_value_rupees', header: 'Value (Rs)', render: (r: any) => Number(r.strategic_value_rupees).toLocaleString('en-IN') },
            { key: 'milestone_tag', header: 'Milestone', render: (r: any) => r.milestone_tag },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>
    </main>
  );
}
