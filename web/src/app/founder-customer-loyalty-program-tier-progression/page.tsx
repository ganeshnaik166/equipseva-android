import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function CustomerLoyaltyProgramTierProgressionPage() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    historyRes,
    eligibleRes,
    topRes,
    distRes,
    trendRes,
    churnRes,
  ] = await Promise.all([
    supabase.rpc('list_loyalty_status_r2492'),
    supabase.rpc('list_tier_progression_history_r2492'),
    supabase.rpc('eligible_for_upgrade_r2492'),
    supabase.rpc('top_points_hospitals_r2492'),
    supabase.rpc('tier_distribution_r2492'),
    supabase.rpc('monthly_progression_trend_r2492'),
    supabase.rpc('churn_risk_focus_r2492'),
  ]);

  const status = statusRes.data ?? [];
  const history = historyRes.data ?? [];
  const eligible = eligibleRes.data ?? [];
  const top = topRes.data ?? [];
  const dist = distRes.data ?? [];
  const trend = trendRes.data ?? [];
  const churn = churnRes.data ?? [];

  const statusCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => r.loyalty_tier },
    { key: 'points_total', header: 'Points', render: (r: any) => r.points_total },
    { key: 'points_this_month', header: 'This month', render: (r: any) => r.points_this_month },
    { key: 'renewals_count', header: 'Renewals', render: (r: any) => r.renewals_count },
    { key: 'next_tier_threshold_points', header: 'Next threshold', render: (r: any) => r.next_tier_threshold_points },
    { key: 'points_to_next_tier', header: 'To next', render: (r: any) => r.points_to_next_tier },
    { key: 'tier_up_alert_kind', header: 'Alert', render: (r: any) => r.tier_up_alert_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const historyCols: Column<any>[] = [
    { key: 'change_at', header: 'When', render: (r: any) => r.change_at ? new Date(r.change_at).toLocaleString() : '—' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'prior_tier', header: 'Prior', render: (r: any) => r.prior_tier ?? '—' },
    { key: 'new_tier', header: 'New', render: (r: any) => r.new_tier ?? '—' },
    { key: 'reason_kind', header: 'Reason', render: (r: any) => r.reason_kind },
    { key: 'points_at_change', header: 'Points', render: (r: any) => r.points_at_change },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const eligibleCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'loyalty_tier', header: 'Current tier', render: (r: any) => r.loyalty_tier },
    { key: 'points_total', header: 'Points', render: (r: any) => r.points_total },
    { key: 'next_tier_threshold_points', header: 'Threshold', render: (r: any) => r.next_tier_threshold_points },
    { key: 'points_to_next_tier', header: 'To next', render: (r: any) => r.points_to_next_tier },
    { key: 'tier_up_alert_kind', header: 'Alert', render: (r: any) => r.tier_up_alert_kind },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => r.loyalty_tier },
    { key: 'points_total', header: 'Points', render: (r: any) => r.points_total },
    { key: 'renewals_count', header: 'Renewals', render: (r: any) => r.renewals_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const distCols: Column<any>[] = [
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => r.loyalty_tier },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => r.hospital_count },
    { key: 'total_points', header: 'Total points', render: (r: any) => r.total_points },
    { key: 'avg_renewals', header: 'Avg renewals', render: (r: any) => r.avg_renewals },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'change_count', header: 'Changes', render: (r: any) => r.change_count },
    { key: 'promotions', header: 'Promotions', render: (r: any) => r.promotions },
    { key: 'downgrades', header: 'Downgrades', render: (r: any) => r.downgrades },
  ];

  const churnCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '—' },
    { key: 'loyalty_tier', header: 'Tier', render: (r: any) => r.loyalty_tier },
    { key: 'points_total', header: 'Points', render: (r: any) => r.points_total },
    { key: 'points_this_month', header: 'This month', render: (r: any) => r.points_this_month },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Customer Loyalty Program & Tier Progression</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Hospital loyalty tiers, points, renewals, benefits unlocked & tier-up alerts.</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Loyalty status</h2>
        <DataTable
          rows={status}
          columns={statusCols}
          emptyMessage="No loyalty status rows."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Eligible for upgrade</h2>
        <DataTable
          rows={eligible}
          columns={eligibleCols}
          emptyMessage="No hospitals near tier-up."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top points hospitals</h2>
        <DataTable
          rows={top}
          columns={topCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Tier distribution</h2>
        <DataTable
          rows={dist}
          columns={distCols}
          emptyMessage="No distribution."
          rowKey={(r: any, i: number) => String(r.loyalty_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly progression trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Churn risk focus</h2>
        <DataTable
          rows={churn}
          columns={churnCols}
          emptyMessage="No churn risk hospitals."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Progression history</h2>
        <DataTable
          rows={history}
          columns={historyCols}
          emptyMessage="No history yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
