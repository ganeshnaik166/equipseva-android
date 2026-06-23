import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    bulkRes,
    decisionsRes,
    topSavingsRes,
    tierDistRes,
    statusFunnelRes,
    monthlyTrendRes,
    summaryRes,
  ] = await Promise.all([
    supabase.rpc('list_bulk_pricing_r2588'),
    supabase.rpc('list_decision_log_r2588'),
    supabase.rpc('top_savings_focus_r2588'),
    supabase.rpc('spend_tier_distribution_r2588'),
    supabase.rpc('status_funnel_r2588'),
    supabase.rpc('monthly_decision_trend_r2588'),
    supabase.rpc('total_annual_savings_summary_r2588'),
  ]);

  const bulkRows: any[] = bulkRes.data ?? [];
  const decisionRows: any[] = decisionsRes.data ?? [];
  const topSavingsRows: any[] = topSavingsRes.data ?? [];
  const tierDistRows: any[] = tierDistRes.data ?? [];
  const statusFunnelRows: any[] = statusFunnelRes.data ?? [];
  const monthlyTrendRows: any[] = monthlyTrendRes.data ?? [];
  const summary: any = summaryRes.data?.[0] ?? null;

  const fmtMoney = (v: any) => {
    const n = Number(v ?? 0);
    return '₹' + n.toLocaleString('en-IN');
  };

  const bulkCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'equipment_count', header: 'Equip #', render: (r: any) => String(r.equipment_count ?? 0) },
    { key: 'spend_tier', header: 'Tier', render: (r: any) => r.spend_tier },
    { key: 'spend_rupees', header: 'Spend', render: (r: any) => fmtMoney(r.spend_rupees) },
    { key: 'discount_pct', header: 'Disc %', render: (r: any) => `${r.discount_pct}%` },
    { key: 'annual_savings_rupees', header: 'Annual savings', render: (r: any) => fmtMoney(r.annual_savings_rupees) },
    { key: 'loyalty_lock_in_months', header: 'Lock-in mo', render: (r: any) => String(r.loyalty_lock_in_months ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'decision_at', header: 'When', render: (r: any) => r.decision_at ? new Date(r.decision_at).toLocaleString() : '-' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'decision_kind', header: 'Kind', render: (r: any) => r.decision_kind },
    { key: 'summary_md', header: 'Summary', render: (r: any) => (r.summary_md ?? '').slice(0, 80) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const topSavingsCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'spend_tier', header: 'Tier', render: (r: any) => r.spend_tier },
    { key: 'equipment_count', header: 'Equip #', render: (r: any) => String(r.equipment_count ?? 0) },
    { key: 'spend_rupees', header: 'Spend', render: (r: any) => fmtMoney(r.spend_rupees) },
    { key: 'annual_savings_rupees', header: 'Annual savings', render: (r: any) => fmtMoney(r.annual_savings_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const tierDistCols: Column<any>[] = [
    { key: 'spend_tier', header: 'Tier', render: (r: any) => r.spend_tier },
    { key: 'account_count', header: 'Accounts', render: (r: any) => String(r.account_count ?? 0) },
    { key: 'total_spend_rupees', header: 'Total spend', render: (r: any) => fmtMoney(r.total_spend_rupees) },
    { key: 'total_annual_savings_rupees', header: 'Total savings', render: (r: any) => fmtMoney(r.total_annual_savings_rupees) },
  ];

  const statusFunnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'account_count', header: 'Accounts', render: (r: any) => String(r.account_count ?? 0) },
    { key: 'total_annual_savings_rupees', header: 'Annual savings', render: (r: any) => fmtMoney(r.total_annual_savings_rupees) },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'decisions_count', header: 'Decisions', render: (r: any) => String(r.decisions_count ?? 0) },
    { key: 'approved_count', header: 'Approved', render: (r: any) => String(r.approved_count ?? 0) },
    { key: 'rejected_count', header: 'Rejected', render: (r: any) => String(r.rejected_count ?? 0) },
    { key: 'counter_offer_count', header: 'Counter', render: (r: any) => String(r.counter_offer_count ?? 0) },
    { key: 'escalated_count', header: 'Escalated', render: (r: any) => String(r.escalated_count ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Customer Multi-Equipment Bulk Pricing & Discount
      </h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Hospital bulk equipment spend tiers, discount applied, annual savings & loyalty lock-in.
      </p>

      {summary && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
          <div style={{ background: '#f5f5f5', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Total accounts</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{String(summary.total_accounts ?? 0)}</div>
          </div>
          <div style={{ background: '#f5f5f5', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Total equipment</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{String(summary.total_equipment_count ?? 0)}</div>
          </div>
          <div style={{ background: '#f5f5f5', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Total spend</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{fmtMoney(summary.total_spend_rupees)}</div>
          </div>
          <div style={{ background: '#f5f5f5', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Total annual savings</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{fmtMoney(summary.total_annual_savings_rupees)}</div>
          </div>
          <div style={{ background: '#eef7ee', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Accepted accounts</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{String(summary.accepted_accounts ?? 0)}</div>
          </div>
          <div style={{ background: '#eef7ee', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Accepted annual savings</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{fmtMoney(summary.accepted_annual_savings_rupees)}</div>
          </div>
          <div style={{ background: '#f5f5f5', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Avg discount %</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{String(summary.avg_discount_pct ?? 0)}%</div>
          </div>
          <div style={{ background: '#f5f5f5', padding: 12, borderRadius: 6 }}>
            <div style={{ fontSize: 11, color: '#666' }}>Avg lock-in mo</div>
            <div style={{ fontSize: 20, fontWeight: 700 }}>{String(summary.avg_loyalty_lock_in_months ?? 0)}</div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top savings focus</h2>
        <DataTable
          rows={topSavingsRows}
          columns={topSavingsCols}
          emptyMessage="No bulk pricing deals yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Spend tier distribution</h2>
        <DataTable
          rows={tierDistRows}
          columns={tierDistCols}
          emptyMessage="No tier data."
          rowKey={(r: any, i: number) => String(r.spend_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status funnel</h2>
        <DataTable
          rows={statusFunnelRows}
          columns={statusFunnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly decision trend</h2>
        <DataTable
          rows={monthlyTrendRows}
          columns={monthlyTrendCols}
          emptyMessage="No decisions logged."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All bulk pricing accounts</h2>
        <DataTable
          rows={bulkRows}
          columns={bulkCols}
          emptyMessage="No bulk pricing accounts yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Decision log</h2>
        <DataTable
          rows={decisionRows}
          columns={decisionCols}
          emptyMessage="No decisions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
