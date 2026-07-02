import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    adoptionRes,
    helpRes,
    lovedRes,
    stuckRes,
    funnelRes,
    trendRes,
    releaseRes,
  ] = await Promise.all([
    supabase.rpc('list_adoption_r2562'),
    supabase.rpc('list_stuck_help_r2562'),
    supabase.rpc('top_loved_features_r2562'),
    supabase.rpc('stuck_user_focus_r2562'),
    supabase.rpc('feature_adoption_funnel_r2562'),
    supabase.rpc('weekly_use_trend_r2562'),
    supabase.rpc('release_version_breakdown_r2562'),
  ]);

  const adoption = (adoptionRes.data ?? []) as any[];
  const help = (helpRes.data ?? []) as any[];
  const loved = (lovedRes.data ?? []) as any[];
  const stuck = (stuckRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const release = (releaseRes.data ?? []) as any[];

  const fmtDate = (s: any) => (s ? new Date(s).toLocaleDateString('en-IN') : '-');
  const fmtDateTime = (s: any) => (s ? new Date(s).toLocaleString('en-IN') : '-');
  const fmtBool = (b: any) => (b ? 'yes' : 'no');
  const short = (id: any) => (id ? String(id).slice(0, 8) : '-');

  const adoptionCols: Column<any>[] = [
    { key: 'feature_name', header: 'Feature', render: (r: any) => <span>{r.feature_name}</span> },
    { key: 'release_version', header: 'Release', render: (r: any) => <span>{r.release_version}</span> },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span>{short(r.engineer_user_id)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'first_use_at', header: 'First Use', render: (r: any) => <span>{fmtDate(r.first_use_at)}</span> },
    { key: 'last_use_at', header: 'Last Use', render: (r: any) => <span>{fmtDate(r.last_use_at)}</span> },
    { key: 'daily_active', header: 'DAU', render: (r: any) => <span>{fmtBool(r.daily_active)}</span> },
    { key: 'stuck', header: 'Stuck', render: (r: any) => <span>{fmtBool(r.stuck)}</span> },
    { key: 'love_score', header: 'Love', render: (r: any) => <span>{r.love_score}/10</span> },
    { key: 'support_ticket_count', header: 'Tickets', render: (r: any) => <span>{r.support_ticket_count}</span> },
    { key: 'owner_email', header: 'Owner', render: (r: any) => <span>{r.owner_email ?? '-'}</span> },
    { key: 'notes', header: 'Notes', render: (r: any) => <span>{r.notes ?? '-'}</span> },
  ];

  const helpCols: Column<any>[] = [
    { key: 'feature_name', header: 'Feature', render: (r: any) => <span>{r.feature_name}</span> },
    { key: 'help_kind', header: 'Help Kind', render: (r: any) => <span>{r.help_kind}</span> },
    { key: 'helped_at', header: 'Helped At', render: (r: any) => <span>{fmtDateTime(r.helped_at)}</span> },
    { key: 'outcome', header: 'Outcome', render: (r: any) => <span>{r.outcome}</span> },
    { key: 'owner_email', header: 'Owner', render: (r: any) => <span>{r.owner_email ?? '-'}</span> },
    { key: 'notes', header: 'Notes', render: (r: any) => <span>{r.notes ?? '-'}</span> },
  ];

  const lovedCols: Column<any>[] = [
    { key: 'feature_name', header: 'Feature', render: (r: any) => <span>{r.feature_name}</span> },
    { key: 'user_count', header: 'Users', render: (r: any) => <span>{r.user_count}</span> },
    { key: 'avg_love', header: 'Avg Love', render: (r: any) => <span>{r.avg_love}/10</span> },
    { key: 'daily_active_count', header: 'DAU', render: (r: any) => <span>{r.daily_active_count}</span> },
    { key: 'stuck_count', header: 'Stuck', render: (r: any) => <span>{r.stuck_count}</span> },
  ];

  const stuckCols: Column<any>[] = [
    { key: 'feature_name', header: 'Feature', render: (r: any) => <span>{r.feature_name}</span> },
    { key: 'release_version', header: 'Release', render: (r: any) => <span>{r.release_version}</span> },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span>{short(r.engineer_user_id)}</span> },
    { key: 'support_ticket_count', header: 'Tickets', render: (r: any) => <span>{r.support_ticket_count}</span> },
    { key: 'help_attempts', header: 'Helps', render: (r: any) => <span>{r.help_attempts}</span> },
    { key: 'last_helped_at', header: 'Last Helped', render: (r: any) => <span>{fmtDateTime(r.last_helped_at)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'owner_email', header: 'Owner', render: (r: any) => <span>{r.owner_email ?? '-'}</span> },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'user_count', header: 'Users', render: (r: any) => <span>{r.user_count}</span> },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => <span>{fmtDate(r.week_start)}</span> },
    { key: 'first_uses', header: 'First Uses', render: (r: any) => <span>{r.first_uses}</span> },
    { key: 'last_uses', header: 'Last Uses', render: (r: any) => <span>{r.last_uses}</span> },
  ];

  const releaseCols: Column<any>[] = [
    { key: 'release_version', header: 'Release', render: (r: any) => <span>{r.release_version}</span> },
    { key: 'user_count', header: 'Users', render: (r: any) => <span>{r.user_count}</span> },
    { key: 'active_count', header: 'Active', render: (r: any) => <span>{r.active_count}</span> },
    { key: 'stuck_count', header: 'Stuck', render: (r: any) => <span>{r.stuck_count}</span> },
    { key: 'avg_love', header: 'Avg Love', render: (r: any) => <span>{r.avg_love}/10</span> },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 28, fontWeight: 700 }}>Engineer App Feature Adoption Curve</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Feature × release × engineer — daily active, stuck, love score & help interventions
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Adoption Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No adoption records"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Loved Features</h2>
        <DataTable
          rows={loved}
          columns={lovedCols}
          emptyMessage="No features tracked"
          rowKey={(r: any, i: number) => String(r.feature_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Stuck Users — Focus List</h2>
        <DataTable
          rows={stuck}
          columns={stuckCols}
          emptyMessage="No stuck users"
          rowKey={(r: any, i: number) => String(r.adoption_id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Release Version Breakdown</h2>
        <DataTable
          rows={release}
          columns={releaseCols}
          emptyMessage="No releases"
          rowKey={(r: any, i: number) => String(r.release_version ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Weekly Use Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Adoption Records</h2>
        <DataTable
          rows={adoption}
          columns={adoptionCols}
          emptyMessage="No adoption records"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Stuck User Help Log</h2>
        <DataTable
          rows={help}
          columns={helpCols}
          emptyMessage="No help entries"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
