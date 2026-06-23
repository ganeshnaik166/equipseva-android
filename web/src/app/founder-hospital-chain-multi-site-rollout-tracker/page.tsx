import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function rupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: '2-digit' });
  } catch {
    return s;
  }
}

function pct(n: number | null | undefined): string {
  if (n == null) return '-';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [sitesRes, snapshotsRes, delayedRes, summaryRes, blockerRes, upcomingRes, topChainsRes] = await Promise.all([
    supabase.rpc('list_rollout_sites_r2419'),
    supabase.rpc('list_arr_snapshots_r2419'),
    supabase.rpc('top_delayed_sites_r2419'),
    supabase.rpc('chain_realization_summary_r2419'),
    supabase.rpc('blocker_breakdown_r2419'),
    supabase.rpc('upcoming_go_lives_r2419'),
    supabase.rpc('top_chains_by_realization_r2419'),
  ]);

  const sites = (sitesRes.data ?? []) as any[];
  const snapshots = (snapshotsRes.data ?? []) as any[];
  const delayed = (delayedRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];
  const blockers = (blockerRes.data ?? []) as any[];
  const upcoming = (upcomingRes.data ?? []) as any[];
  const topChains = (topChainsRes.data ?? []) as any[];

  const sitesCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'site_label', header: 'Site', render: (r: any) => r.site_label },
    { key: 'site_city', header: 'City', render: (r: any) => r.site_city },
    { key: 'deployment_status', header: 'Status', render: (r: any) => r.deployment_status },
    { key: 'planned_go_live_at', header: 'Planned', render: (r: any) => fmtDate(r.planned_go_live_at) },
    { key: 'actual_go_live_at', header: 'Actual', render: (r: any) => fmtDate(r.actual_go_live_at) },
    { key: 'days_delta', header: 'Delta (d)', render: (r: any) => r.days_delta ?? '-' },
    { key: 'arr_per_site_rupees', header: 'ARR / site', render: (r: any) => rupees(r.arr_per_site_rupees) },
    { key: 'blocker_kind', header: 'Blocker', render: (r: any) => r.blocker_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const snapshotsCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'snapshot_date', header: 'Date', render: (r: any) => fmtDate(r.snapshot_date) },
    { key: 'total_sites', header: 'Sites', render: (r: any) => r.total_sites },
    { key: 'deployed_sites', header: 'Deployed', render: (r: any) => r.deployed_sites },
    { key: 'in_progress_sites', header: 'In progress', render: (r: any) => r.in_progress_sites },
    { key: 'delayed_sites', header: 'Delayed', render: (r: any) => r.delayed_sites },
    { key: 'total_arr_target_rupees', header: 'ARR target', render: (r: any) => rupees(r.total_arr_target_rupees) },
    { key: 'total_arr_realized_rupees', header: 'ARR realized', render: (r: any) => rupees(r.total_arr_realized_rupees) },
    { key: 'realized_pct', header: 'Realized %', render: (r: any) => pct(r.realized_pct) },
  ];

  const delayedCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'site_label', header: 'Site', render: (r: any) => r.site_label },
    { key: 'site_city', header: 'City', render: (r: any) => r.site_city },
    { key: 'days_delta', header: 'Days late', render: (r: any) => r.days_delta },
    { key: 'arr_per_site_rupees', header: 'ARR at risk', render: (r: any) => rupees(r.arr_per_site_rupees) },
    { key: 'blocker_kind', header: 'Blocker', render: (r: any) => r.blocker_kind },
    { key: 'blocker_notes', header: 'Notes', render: (r: any) => r.blocker_notes ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'total_sites', header: 'Total', render: (r: any) => r.total_sites },
    { key: 'deployed_sites', header: 'Deployed', render: (r: any) => r.deployed_sites },
    { key: 'in_progress_sites', header: 'In progress', render: (r: any) => r.in_progress_sites },
    { key: 'delayed_sites', header: 'Delayed', render: (r: any) => r.delayed_sites },
    { key: 'planned_sites', header: 'Planned', render: (r: any) => r.planned_sites },
    { key: 'arr_target_rupees', header: 'ARR target', render: (r: any) => rupees(r.arr_target_rupees) },
    { key: 'arr_realized_rupees', header: 'ARR realized', render: (r: any) => rupees(r.arr_realized_rupees) },
    { key: 'realized_pct', header: 'Realized %', render: (r: any) => pct(r.realized_pct) },
  ];

  const blockerCols: Column<any>[] = [
    { key: 'blocker_kind', header: 'Blocker', render: (r: any) => r.blocker_kind },
    { key: 'blocked_sites', header: 'Sites blocked', render: (r: any) => r.blocked_sites },
    { key: 'arr_at_risk_rupees', header: 'ARR at risk', render: (r: any) => rupees(r.arr_at_risk_rupees) },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'site_label', header: 'Site', render: (r: any) => r.site_label },
    { key: 'site_city', header: 'City', render: (r: any) => r.site_city },
    { key: 'deployment_status', header: 'Status', render: (r: any) => r.deployment_status },
    { key: 'planned_go_live_at', header: 'Planned', render: (r: any) => fmtDate(r.planned_go_live_at) },
    { key: 'days_to_go', header: 'Days to go', render: (r: any) => r.days_to_go },
    { key: 'arr_per_site_rupees', header: 'ARR / site', render: (r: any) => rupees(r.arr_per_site_rupees) },
    { key: 'blocker_kind', header: 'Blocker', render: (r: any) => r.blocker_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const topChainsCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'snapshot_date', header: 'Latest snapshot', render: (r: any) => fmtDate(r.snapshot_date) },
    { key: 'total_sites', header: 'Sites', render: (r: any) => r.total_sites },
    { key: 'deployed_sites', header: 'Deployed', render: (r: any) => r.deployed_sites },
    { key: 'total_arr_target_rupees', header: 'ARR target', render: (r: any) => rupees(r.total_arr_target_rupees) },
    { key: 'total_arr_realized_rupees', header: 'ARR realized', render: (r: any) => rupees(r.total_arr_realized_rupees) },
    { key: 'realized_pct', header: 'Realized %', render: (r: any) => pct(r.realized_pct) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Multi-Site Rollout Tracker</h1>
        <p className="text-sm text-gray-600">
          Chain & site progress, ARR realization, blockers, and go-live timeline across hospital chains.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain realization summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No chains tracked yet."
          rowKey={(r: any, i: number) => String(r.id ?? r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top chains by realization (latest snapshot)</h2>
        <DataTable
          rows={topChains}
          columns={topChainsCols}
          emptyMessage="No snapshots recorded."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top delayed sites</h2>
        <DataTable
          rows={delayed}
          columns={delayedCols}
          emptyMessage="No delayed sites."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Blocker breakdown (active sites)</h2>
        <DataTable
          rows={blockers}
          columns={blockerCols}
          emptyMessage="No active blockers."
          rowKey={(r: any, i: number) => String(r.blocker_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming go-lives (next 60 days)</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          emptyMessage="No upcoming go-lives."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All rollout sites</h2>
        <DataTable
          rows={sites}
          columns={sitesCols}
          emptyMessage="No rollout sites."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">ARR snapshot history</h2>
        <DataTable
          rows={snapshots}
          columns={snapshotsCols}
          emptyMessage="No ARR snapshots."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
