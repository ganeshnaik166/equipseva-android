import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ConsolidationRow = {
  id: string;
  chain_name: string;
  quarter_label: string;
  current_vendors_count: number;
  consolidation_target_count: number;
  est_savings_rupees: number;
  action_kind: string;
  decision: string;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type FocusRow = {
  chain_name: string;
  est_savings_rupees: number;
  current_vendors_count: number;
  consolidation_target_count: number;
  decision: string;
  status: string;
};

type DecisionRow = {
  decision: string;
  chain_count: number;
  total_savings_rupees: number;
};

type TrendRow = {
  quarter_label: string;
  chain_count: number;
  total_savings_rupees: number;
  avg_vendor_reduction: number;
};

type OwnerRow = {
  owner_email: string;
  chain_count: number;
  open_count: number;
  total_savings_rupees: number;
};

type SummaryRow = {
  total_chains: number;
  total_current_vendors: number;
  total_target_vendors: number;
  total_savings_rupees: number;
  executed_count: number;
};

function fmtRupees(n: number): string {
  if (!n) return '0';
  return new Intl.NumberFormat('en-IN').format(n);
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [listRes, focusRes, decisionRes, trendRes, ownerRes, summaryRes] = await Promise.all([
    sb.rpc('list_consolidation_r2671'),
    sb.rpc('top_savings_focus_r2671'),
    sb.rpc('decision_funnel_r2671'),
    sb.rpc('quarterly_consolidation_trend_r2671'),
    sb.rpc('owner_load_r2671'),
    sb.rpc('consolidation_summary_r2671'),
  ]);

  const rows: ConsolidationRow[] = (listRes.data as ConsolidationRow[] | null) ?? [];
  const focus: FocusRow[] = (focusRes.data as FocusRow[] | null) ?? [];
  const decisions: DecisionRow[] = (decisionRes.data as DecisionRow[] | null) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];
  const owners: OwnerRow[] = (ownerRes.data as OwnerRow[] | null) ?? [];
  const summary: SummaryRow | null = ((summaryRes.data as SummaryRow[] | null) ?? [])[0] ?? null;

  const listCols: Column<ConsolidationRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'current_vendors_count', header: 'Now', render: (r: any) => r.current_vendors_count },
    { key: 'consolidation_target_count', header: 'Target', render: (r: any) => r.consolidation_target_count },
    { key: 'est_savings_rupees', header: 'Savings (Rs)', render: (r: any) => fmtRupees(r.est_savings_rupees) },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const focusCols: Column<FocusRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'est_savings_rupees', header: 'Savings (Rs)', render: (r: any) => fmtRupees(r.est_savings_rupees) },
    { key: 'current_vendors_count', header: 'Now', render: (r: any) => r.current_vendors_count },
    { key: 'consolidation_target_count', header: 'Target', render: (r: any) => r.consolidation_target_count },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const decisionCols: Column<DecisionRow>[] = [
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'total_savings_rupees', header: 'Savings (Rs)', render: (r: any) => fmtRupees(r.total_savings_rupees) },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'total_savings_rupees', header: 'Savings (Rs)', render: (r: any) => fmtRupees(r.total_savings_rupees) },
    { key: 'avg_vendor_reduction', header: 'Avg reduction', render: (r: any) => r.avg_vendor_reduction },
  ];

  const ownerCols: Column<OwnerRow>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'total_savings_rupees', header: 'Savings (Rs)', render: (r: any) => fmtRupees(r.total_savings_rupees) },
  ];

  const kpiCard = (label: string, value: string | number) => (
    <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff', minWidth: 160 }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Quarterly Vendor Consolidation Board</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-chain quarterly review of how many vendors a chain runs vs the consolidation target. Each row tracks
        estimated savings, the proposed action, and the decision & status. Chains with decision pending or approved
        are the focus list; executed rows count toward delivered savings.
      </p>

      <section style={{ marginBottom: 32, display: 'flex', gap: 12, flexWrap: 'wrap' }}>
        {kpiCard('Chains in board', summary?.total_chains ?? 0)}
        {kpiCard('Current vendors', summary?.total_current_vendors ?? 0)}
        {kpiCard('Target vendors', summary?.total_target_vendors ?? 0)}
        {kpiCard('Est. savings (Rs)', fmtRupees(summary?.total_savings_rupees ?? 0))}
        {kpiCard('Executed chains', summary?.executed_count ?? 0)}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top savings focus ({focus.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Chains with decision pending or approved — ordered by est. savings. These are where founder time moves the dial.
        </p>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All chain reviews ({rows.length})</h2>
        <DataTable
          rows={rows}
          columns={listCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Decision funnel</h2>
          <DataTable
            rows={decisions}
            columns={decisionCols}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.decision ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Quarterly trend</h2>
          <DataTable
            rows={trend}
            columns={trendCols}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
          />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Owner load ({owners.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Who owns how much — chains, open work, and savings on their plate.
        </p>
        <DataTable
          rows={owners}
          columns={ownerCols}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}