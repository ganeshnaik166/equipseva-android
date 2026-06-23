import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [ledgerRes, actionsRes, topChainsRes, kindRes, pendingRes, trendRes, complianceRes] = await Promise.all([
    supabase.rpc('list_rebate_ledger_r2527'),
    supabase.rpc('list_redemption_actions_r2527'),
    supabase.rpc('top_earning_chains_r2527'),
    supabase.rpc('rebate_kind_breakdown_r2527'),
    supabase.rpc('pending_redeem_focus_r2527'),
    supabase.rpc('monthly_earn_trend_r2527'),
    supabase.rpc('compliance_summary_r2527'),
  ]);

  const ledger = (ledgerRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const topChains = (topChainsRes.data ?? []) as any[];
  const kinds = (kindRes.data ?? []) as any[];
  const pending = (pendingRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const compliance = (complianceRes.data ?? []) as any[];

  const ledgerCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'earned_at', header: 'Earned', render: (r: any) => r.earned_at ? new Date(r.earned_at).toLocaleDateString() : '-' },
    { key: 'earned_rupees', header: 'Earned (Rs)', render: (r: any) => `Rs ${Number(r.earned_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'rebate_kind', header: 'Kind', render: (r: any) => r.rebate_kind },
    { key: 'policy_compliance', header: 'Compliance', render: (r: any) => r.policy_compliance },
    { key: 'redeemed_rupees', header: 'Redeemed (Rs)', render: (r: any) => `Rs ${Number(r.redeemed_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'action_at', header: 'Action At', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleString() : '-' },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'action_summary', header: 'Summary', render: (r: any) => r.action_summary ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topChainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'rebate_count', header: 'Rebates', render: (r: any) => String(r.rebate_count ?? 0) },
    { key: 'total_earned_rupees', header: 'Earned (Rs)', render: (r: any) => `Rs ${Number(r.total_earned_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_redeemed_rupees', header: 'Redeemed (Rs)', render: (r: any) => `Rs ${Number(r.total_redeemed_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'pending_rupees', header: 'Pending (Rs)', render: (r: any) => `Rs ${Number(r.pending_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const kindCols: Column<any>[] = [
    { key: 'rebate_kind', header: 'Kind', render: (r: any) => r.rebate_kind },
    { key: 'ledger_count', header: 'Count', render: (r: any) => String(r.ledger_count ?? 0) },
    { key: 'earned_rupees', header: 'Earned (Rs)', render: (r: any) => `Rs ${Number(r.earned_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'redeemed_rupees', header: 'Redeemed (Rs)', render: (r: any) => `Rs ${Number(r.redeemed_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'earned_at', header: 'Earned', render: (r: any) => r.earned_at ? new Date(r.earned_at).toLocaleDateString() : '-' },
    { key: 'earned_rupees', header: 'Earned (Rs)', render: (r: any) => `Rs ${Number(r.earned_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'rebate_kind', header: 'Kind', render: (r: any) => r.rebate_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'days_outstanding', header: 'Days', render: (r: any) => String(r.days_outstanding ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'ledger_count', header: 'Count', render: (r: any) => String(r.ledger_count ?? 0) },
    { key: 'earned_rupees', header: 'Earned (Rs)', render: (r: any) => `Rs ${Number(r.earned_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'redeemed_rupees', header: 'Redeemed (Rs)', render: (r: any) => `Rs ${Number(r.redeemed_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const complianceCols: Column<any>[] = [
    { key: 'policy_compliance', header: 'Compliance', render: (r: any) => r.policy_compliance },
    { key: 'ledger_count', header: 'Count', render: (r: any) => String(r.ledger_count ?? 0) },
    { key: 'earned_rupees', header: 'Earned (Rs)', render: (r: any) => `Rs ${Number(r.earned_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'redeemed_rupees', header: 'Redeemed (Rs)', render: (r: any) => `Rs ${Number(r.redeemed_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const totalEarned = ledger.reduce((s, r) => s + Number(r.earned_rupees ?? 0), 0);
  const totalRedeemed = ledger.reduce((s, r) => s + Number(r.redeemed_rupees ?? 0), 0);
  const pendingCount = pending.length;

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>Hospital Chain Rebate & Loyalty Credit Ledger</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>Chain rebates earned vs redeemed — kind, compliance, pending focus.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <div style={{ padding: '12px', border: '1px solid #ddd', borderRadius: '6px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total Earned</div>
          <div style={{ fontSize: '20px', fontWeight: 700 }}>Rs {totalEarned.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: '12px', border: '1px solid #ddd', borderRadius: '6px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total Redeemed</div>
          <div style={{ fontSize: '20px', fontWeight: 700 }}>Rs {totalRedeemed.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: '12px', border: '1px solid #ddd', borderRadius: '6px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Pending Redeem</div>
          <div style={{ fontSize: '20px', fontWeight: 700 }}>{pendingCount}</div>
        </div>
        <div style={{ padding: '12px', border: '1px solid #ddd', borderRadius: '6px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Chains</div>
          <div style={{ fontSize: '20px', fontWeight: 700 }}>{topChains.length}</div>
        </div>
      </div>

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '16px 0 8px' }}>Top Earning Chains</h2>
      <DataTable rows={topChains} columns={topChainCols} emptyMessage="No chains" rowKey={(r: any, i: number) => String(r.id ?? i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>Rebate Kind Breakdown</h2>
      <DataTable rows={kinds} columns={kindCols} emptyMessage="No kinds" rowKey={(r: any, i: number) => String(r.id ?? i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>Pending Redeem Focus</h2>
      <DataTable rows={pending} columns={pendingCols} emptyMessage="No pending rebates" rowKey={(r: any, i: number) => String(r.id ?? i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>Monthly Earn Trend</h2>
      <DataTable rows={trend} columns={trendCols} emptyMessage="No trend data" rowKey={(r: any, i: number) => String(r.id ?? i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>Compliance Summary</h2>
      <DataTable rows={compliance} columns={complianceCols} emptyMessage="No compliance data" rowKey={(r: any, i: number) => String(r.id ?? i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>Rebate Ledger</h2>
      <DataTable rows={ledger} columns={ledgerCols} emptyMessage="No rebates" rowKey={(r: any, i: number) => String(r.id ?? i)} />

      <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '24px 0 8px' }}>Redemption Actions</h2>
      <DataTable rows={actions} columns={actionCols} emptyMessage="No actions" rowKey={(r: any, i: number) => String(r.id ?? i)} />
    </div>
  );
}
