import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [resolutionsRes, actionsRes, blockersRes, kindDistRes, funnelRes, trendRes, ownerLoadRes] = await Promise.all([
    supabase.rpc('list_resolutions_r2615'),
    supabase.rpc('list_response_actions_r2615'),
    supabase.rpc('top_blocker_focus_r2615'),
    supabase.rpc('resolution_kind_distribution_r2615'),
    supabase.rpc('status_funnel_r2615'),
    supabase.rpc('monthly_resolution_trend_r2615'),
    supabase.rpc('owner_load_r2615'),
  ]);

  const resolutions: any[] = resolutionsRes.data ?? [];
  const actions: any[] = actionsRes.data ?? [];
  const blockers: any[] = blockersRes.data ?? [];
  const kindDist: any[] = kindDistRes.data ?? [];
  const funnel: any[] = funnelRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const ownerLoad: any[] = ownerLoadRes.data ?? [];

  const fmtDate = (s: string | null) => (s ? new Date(s).toLocaleDateString('en-IN') : '-');
  const fmtDateTime = (s: string | null) => (s ? new Date(s).toLocaleString('en-IN') : '-');

  const resolutionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'resolution_label', header: 'Resolution', render: (r: any) => r.resolution_label },
    { key: 'passed_at', header: 'Passed', render: (r: any) => fmtDate(r.passed_at) },
    { key: 'resolution_kind', header: 'Kind', render: (r: any) => r.resolution_kind },
    { key: 'our_impact_kind', header: 'Impact', render: (r: any) => r.our_impact_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'resolution_label', header: 'Resolution', render: (r: any) => r.resolution_label },
    { key: 'action_at', header: 'When', render: (r: any) => fmtDateTime(r.action_at) },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const blockerCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'resolution_label', header: 'Resolution', render: (r: any) => r.resolution_label },
    { key: 'resolution_kind', header: 'Kind', render: (r: any) => r.resolution_kind },
    { key: 'passed_at', header: 'Passed', render: (r: any) => fmtDate(r.passed_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindCols: Column<any>[] = [
    { key: 'resolution_kind', header: 'Kind', render: (r: any) => r.resolution_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'blocker_count', header: 'Blockers', render: (r: any) => r.blocker_count },
    { key: 'positive_count', header: 'Positives', render: (r: any) => r.positive_count },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'total', header: 'Count', render: (r: any) => r.total },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'blocker_count', header: 'Blockers', render: (r: any) => r.blocker_count },
    { key: 'positive_count', header: 'Positives', render: (r: any) => r.positive_count },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'open_resolutions', header: 'Open Resolutions', render: (r: any) => r.open_resolutions },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => r.open_actions },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Chain Board Resolution Tracker</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Track board-level decisions at hospital chains & our counter-actions =&gt; revenue protect & expand.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top blocker focus</h2>
        <DataTable
          rows={blockers}
          columns={blockerCols}
          emptyMessage="No blockers or negative-impact resolutions open."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All board resolutions</h2>
        <DataTable
          rows={resolutions}
          columns={resolutionCols}
          emptyMessage="No resolutions logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Response actions log</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No response actions recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 16 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Resolution kind distribution</h2>
          <DataTable
            rows={kindDist}
            columns={kindCols}
            emptyMessage="No data."
            rowKey={(r: any, i: number) => String(r.resolution_kind ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status funnel</h2>
          <DataTable
            rows={funnel}
            columns={funnelCols}
            emptyMessage="No data."
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data yet."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}
