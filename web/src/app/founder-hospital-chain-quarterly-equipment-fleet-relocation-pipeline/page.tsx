import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function fmtINR(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toLocaleString('en-IN');
}

function fmtDate(d: string | null | undefined): string {
  if (!d) return '-';
  return new Date(d).toISOString().slice(0, 10);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, listRes, byChainRes, byReasonRes, byOutcomeRes, costRes, milestonesRes, topRes] = await Promise.all([
    supabase.rpc('fn_r2867_relocation_pipeline_kpis'),
    supabase.rpc('fn_r2867_relocation_list'),
    supabase.rpc('fn_r2867_relocation_by_chain'),
    supabase.rpc('fn_r2867_relocation_by_reason'),
    supabase.rpc('fn_r2867_relocation_by_outcome'),
    supabase.rpc('fn_r2867_relocation_cost_summary'),
    supabase.rpc('fn_r2867_relocation_milestones'),
    supabase.rpc('fn_r2867_relocation_top_assets'),
  ]);

  const kpis = (kpisRes.data && kpisRes.data[0]) || {
    total_relocations: 0,
    completed: 0,
    in_transit: 0,
    blocked: 0,
    total_cost_rupees: 0,
    avg_cost_rupees: 0,
    chains_active: 0,
    this_quarter: 0,
  };
  const rows = listRes.data || [];
  const byChain = byChainRes.data || [];
  const byReason = byReasonRes.data || [];
  const byOutcome = byOutcomeRes.data || [];
  const costSummary = costRes.data || [];
  const milestones = milestonesRes.data || [];
  const topAssets = topRes.data || [];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Hospital Chain Quarterly Equipment Fleet Relocation Pipeline
        </h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Round r2867 · chain × asset × from-site × to-site × reason × cost × outcome
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 28 }}>
        {[
          { label: 'Total Relocations', value: fmtNum(kpis.total_relocations) },
          { label: 'Commissioned', value: fmtNum(kpis.completed) },
          { label: 'In Transit', value: fmtNum(kpis.in_transit) },
          { label: 'Blocked', value: fmtNum(kpis.blocked) },
          { label: 'Active Chains', value: fmtNum(kpis.chains_active) },
          { label: 'This Quarter', value: fmtNum(kpis.this_quarter) },
          { label: 'Total Cost', value: fmtINR(kpis.total_cost_rupees) },
          { label: 'Avg Cost / Move', value: fmtINR(kpis.avg_cost_rupees) },
        ].map((kpi) => (
          <div key={kpi.label} style={{ border: '1px solid #e3e3e3', borderRadius: 10, padding: 14, background: '#fafafa' }}>
            <div style={{ fontSize: 11, color: '#888', textTransform: 'uppercase', letterSpacing: 0.6 }}>{kpi.label}</div>
            <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{kpi.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Pipeline — All Relocations</h2>
        <DataTable
          rows={rows}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'asset_tag', header: 'Asset', render: (r: any) => r.asset_tag },
            { key: 'asset_category', header: 'Category', render: (r: any) => r.asset_category },
            { key: 'from_site', header: 'From', render: (r: any) => r.from_site },
            { key: 'to_site', header: 'To', render: (r: any) => r.to_site },
            { key: 'reason', header: 'Reason', render: (r: any) => r.reason },
            { key: 'planned_quarter', header: 'Quarter', render: (r: any) => r.planned_quarter },
            { key: 'scheduled_date', header: 'Scheduled', render: (r: any) => fmtDate(r.scheduled_date) },
            { key: 'completed_date', header: 'Completed', render: (r: any) => fmtDate(r.completed_date) },
            { key: 'cost_rupees', header: 'Cost', render: (r: any) => fmtINR(r.cost_rupees) },
            { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
          ]}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18, marginBottom: 28 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Rollup by Chain</h2>
          <DataTable
            rows={byChain}
            rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
              { key: 'relocations', header: 'Moves', render: (r: any) => fmtNum(r.relocations) },
              { key: 'completed', header: 'Done', render: (r: any) => fmtNum(r.completed) },
              { key: 'blocked', header: 'Blocked', render: (r: any) => fmtNum(r.blocked) },
              { key: 'total_cost_rupees', header: 'Total Cost', render: (r: any) => fmtINR(r.total_cost_rupees) },
              { key: 'avg_cost_rupees', header: 'Avg Cost', render: (r: any) => fmtINR(r.avg_cost_rupees) },
            ]}
          />
        </div>

        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Rollup by Reason</h2>
          <DataTable
            rows={byReason}
            rowKey={(r: any, i: number) => String(r.reason ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'reason', header: 'Reason', render: (r: any) => r.reason },
              { key: 'cnt', header: 'Count', render: (r: any) => fmtNum(r.cnt) },
              { key: 'total_cost_rupees', header: 'Total Cost', render: (r: any) => fmtINR(r.total_cost_rupees) },
              { key: 'avg_cost_rupees', header: 'Avg Cost', render: (r: any) => fmtINR(r.avg_cost_rupees) },
            ]}
          />
        </div>
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18, marginBottom: 28 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Outcome Breakdown</h2>
          <DataTable
            rows={byOutcome}
            rowKey={(r: any, i: number) => String(r.outcome ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
              { key: 'cnt', header: 'Count', render: (r: any) => fmtNum(r.cnt) },
              { key: 'pct', header: 'Share %', render: (r: any) => String(r.pct ?? '-') },
            ]}
          />
        </div>

        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Cost by Asset Category</h2>
          <DataTable
            rows={costSummary}
            rowKey={(r: any, i: number) => String(r.asset_category ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'asset_category', header: 'Category', render: (r: any) => r.asset_category },
              { key: 'units', header: 'Units', render: (r: any) => fmtNum(r.units) },
              { key: 'total_cost_rupees', header: 'Total Cost', render: (r: any) => fmtINR(r.total_cost_rupees) },
              { key: 'avg_cost_rupees', header: 'Avg Cost', render: (r: any) => fmtINR(r.avg_cost_rupees) },
            ]}
          />
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Top 10 Assets by Move Cost</h2>
        <DataTable
          rows={topAssets}
          rowKey={(r: any, i: number) => String(r.asset_tag ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'asset_tag', header: 'Asset', render: (r: any) => r.asset_tag },
            { key: 'asset_category', header: 'Category', render: (r: any) => r.asset_category },
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'from_site', header: 'From', render: (r: any) => r.from_site },
            { key: 'to_site', header: 'To', render: (r: any) => r.to_site },
            { key: 'cost_rupees', header: 'Cost', render: (r: any) => fmtINR(r.cost_rupees) },
            { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
          ]}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Milestone Log</h2>
        <DataTable
          rows={milestones}
          rowKey={(r: any, i: number) => String(i)}
          emptyMessage="No data"
          columns={[
            { key: 'asset_tag', header: 'Asset', render: (r: any) => r.asset_tag },
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'milestone', header: 'Milestone', render: (r: any) => r.milestone },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
            { key: 'occurred_on', header: 'Date', render: (r: any) => fmtDate(r.occurred_on) },
            { key: 'cost_delta_rupees', header: 'Cost Delta', render: (r: any) => fmtINR(r.cost_delta_rupees) },
            { key: 'owner_name', header: 'Owner', render: (r: any) => r.owner_name ?? '-' },
            { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
          ]}
        />
      </section>

      <footer style={{ marginTop: 32, color: '#888', fontSize: 12 }}>
        Founder console · r2867 · data via SECURITY DEFINER RPCs gated by is_founder()
      </footer>
    </div>
  );
}
