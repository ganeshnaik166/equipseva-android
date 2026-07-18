import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [actionsRes, outcomesRes, focusRes, kindDistRes, funnelRes, trendRes, ownerRes] = await Promise.all([
    supabase.rpc('list_bond_actions_r2631'),
    supabase.rpc('list_outcomes_r2631'),
    supabase.rpc('top_bond_focus_r2631'),
    supabase.rpc('action_kind_distribution_r2631'),
    supabase.rpc('status_funnel_r2631'),
    supabase.rpc('quarterly_bond_trend_r2631'),
    supabase.rpc('owner_load_r2631'),
  ]);

  const actions = (actionsRes.data ?? []) as any[];
  const outcomes = (outcomesRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const kindDist = (kindDistRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const owners = (ownerRes.data ?? []) as any[];

  const fmtMoney = (n: any) => {
    const v = Number(n ?? 0);
    return '₹' + v.toLocaleString('en-IN');
  };

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'value_rupees', header: 'Value', render: (r: any) => fmtMoney(r.value_rupees) },
    { key: 'bond_strength_after', header: 'Bond', render: (r: any) => r.bond_strength_after },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'revenue_realized_rupees', header: 'Revenue', render: (r: any) => fmtMoney(r.revenue_realized_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
    { key: 'observed_at', header: 'Observed', render: (r: any) => String(r.observed_at).slice(0, 10) },
  ];

  const focusCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'total_actions', header: 'Actions', render: (r: any) => String(r.total_actions) },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtMoney(r.total_value_rupees) },
    { key: 'champion_count', header: 'Champion Wins', render: (r: any) => String(r.champion_count) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt) },
    { key: 'total_value_rupees', header: 'Value', render: (r: any) => fmtMoney(r.total_value_rupees) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'total_actions', header: 'Actions', render: (r: any) => String(r.total_actions) },
    { key: 'total_value_rupees', header: 'Planned Value', render: (r: any) => fmtMoney(r.total_value_rupees) },
    { key: 'realized_revenue_rupees', header: 'Realized Revenue', render: (r: any) => fmtMoney(r.realized_revenue_rupees) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => String(r.open_actions) },
    { key: 'open_outcomes', header: 'Open Outcomes', render: (r: any) => String(r.open_outcomes) },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtMoney(r.total_value_rupees) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>
        Hospital Chain Quarterly Loyalty Bond Cement
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Track exclusive pricing, joint marketing, co-innovation, founder gifts & strategic reviews =&gt; quarterly bond strength.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Bond Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No bond actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No outcomes yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Bond Focus (by chain)</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No focus data."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action Kind Distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindCols}
          emptyMessage="No distribution data."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String((r.bucket ?? '') + '-' + (r.status ?? '') + '-' + i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Quarterly Bond Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner Load</h2>
        <DataTable
          rows={owners}
          columns={ownerCols}
          emptyMessage="No owner load."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
