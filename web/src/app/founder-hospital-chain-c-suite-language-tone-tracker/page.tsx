import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [styles, actions, highRisk, styleDist, roleBreak, monthlyTrend, ownerLoad] = await Promise.all([
    supabase.rpc('list_communication_style_r2599'),
    supabase.rpc('list_tone_adjustment_actions_r2599'),
    supabase.rpc('high_risk_misalignment_focus_r2599'),
    supabase.rpc('style_distribution_r2599'),
    supabase.rpc('role_breakdown_r2599'),
    supabase.rpc('monthly_action_trend_r2599'),
    supabase.rpc('owner_load_r2599'),
  ]);

  const styleCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role },
    { key: 'communication_style_kind', header: 'Style', render: (r: any) => r.communication_style_kind },
    { key: 'tone_preference_kind', header: 'Tone', render: (r: any) => r.tone_preference_kind },
    { key: 'misalignment_risk_kind', header: 'Risk', render: (r: any) => r.misalignment_risk_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'action_at', header: 'At', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleString() : '-' },
  ];

  const highRiskCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role },
    { key: 'misalignment_risk_kind', header: 'Risk', render: (r: any) => r.misalignment_risk_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'adjustment_md', header: 'Adjustment', render: (r: any) => r.adjustment_md ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const styleDistCols: Column<any>[] = [
    { key: 'communication_style_kind', header: 'Style', render: (r: any) => r.communication_style_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
  ];

  const roleBreakCols: Column<any>[] = [
    { key: 'c_suite_role', header: 'Role', render: (r: any) => r.c_suite_role },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'high_risk', header: 'High Risk', render: (r: any) => r.high_risk },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? new Date(r.month_start).toLocaleDateString() : '-' },
    { key: 'total', header: 'Actions', render: (r: any) => r.total },
    { key: 'positive_outcome', header: 'Positive', render: (r: any) => r.positive_outcome },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'styles_owned', header: 'Styles', render: (r: any) => r.styles_owned },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => r.open_actions },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Hospital Chain C-Suite Language & Tone Tracker</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Track how each C-suite stakeholder prefers to be spoken to > flag misalignment risk > log tone adjustment actions.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>High-Risk Misalignment Focus</h2>
        <DataTable
          rows={highRisk.data ?? []}
          columns={highRiskCols}
          emptyMessage="No high-risk stakeholders"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Communication Styles</h2>
        <DataTable
          rows={styles.data ?? []}
          columns={styleCols}
          emptyMessage="No styles logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Adjustment Actions</h2>
        <DataTable
          rows={actions.data ?? []}
          columns={actionCols}
          emptyMessage="No actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 16 }}>
        <div>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Style Distribution</h2>
          <DataTable
            rows={styleDist.data ?? []}
            columns={styleDistCols}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.communication_style_kind ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Role Breakdown</h2>
          <DataTable
            rows={roleBreak.data ?? []}
            columns={roleBreakCols}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.c_suite_role ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Action Trend</h2>
          <DataTable
            rows={monthlyTrend.data ?? []}
            columns={trendCols}
            emptyMessage="No actions yet"
            rowKey={(r: any, i: number) => String(r.month_start ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Owner Load</h2>
          <DataTable
            rows={ownerLoad.data ?? []}
            columns={ownerCols}
            emptyMessage="No owners"
            rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
          />
        </div>
      </section>
    </main>
  );
}
