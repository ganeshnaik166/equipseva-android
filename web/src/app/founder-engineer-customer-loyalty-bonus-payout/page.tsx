import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [bonusesRes, payoutLogRes, topValueRes, kindDistRes, statusFunnelRes, monthlyTrendRes, ownerLoadRes] = await Promise.all([
    supabase.rpc('list_bonuses_r2650'),
    supabase.rpc('list_payout_log_r2650'),
    supabase.rpc('top_value_focus_r2650'),
    supabase.rpc('bonus_kind_distribution_r2650'),
    supabase.rpc('status_funnel_r2650'),
    supabase.rpc('monthly_bonus_trend_r2650'),
    supabase.rpc('owner_load_r2650'),
  ]);

  const bonuses = (bonusesRes.data ?? []) as any[];
  const payoutLog = (payoutLogRes.data ?? []) as any[];
  const topValue = (topValueRes.data ?? []) as any[];
  const kindDist = (kindDistRes.data ?? []) as any[];
  const statusFunnel = (statusFunnelRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];

  const bonusCols: Column<any>[] = [
    { key: 'awarded_at', header: 'Awarded', render: (r: any) => new Date(r.awarded_at).toLocaleDateString() },
    { key: 'bonus_kind', header: 'Kind', render: (r: any) => r.bonus_kind },
    { key: 'bonus_rupees', header: 'Rupees', render: (r: any) => `₹${Number(r.bonus_rupees).toLocaleString()}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const payoutCols: Column<any>[] = [
    { key: 'paid_at', header: 'Paid', render: (r: any) => new Date(r.paid_at).toLocaleDateString() },
    { key: 'payout_method', header: 'Method', render: (r: any) => r.payout_method },
    { key: 'payout_proof_ref', header: 'Proof Ref', render: (r: any) => r.payout_proof_ref ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const topValueCols: Column<any>[] = [
    { key: 'awarded_at', header: 'Awarded', render: (r: any) => new Date(r.awarded_at).toLocaleDateString() },
    { key: 'bonus_kind', header: 'Kind', render: (r: any) => r.bonus_kind },
    { key: 'bonus_rupees', header: 'Rupees', render: (r: any) => `₹${Number(r.bonus_rupees).toLocaleString()}` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindDistCols: Column<any>[] = [
    { key: 'bonus_kind', header: 'Kind', render: (r: any) => r.bonus_kind },
    { key: 'bonus_count', header: 'Count', render: (r: any) => r.bonus_count },
    { key: 'total_rupees', header: 'Total Rupees', render: (r: any) => `₹${Number(r.total_rupees).toLocaleString()}` },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'bonus_count', header: 'Count', render: (r: any) => r.bonus_count },
    { key: 'total_rupees', header: 'Total Rupees', render: (r: any) => `₹${Number(r.total_rupees).toLocaleString()}` },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'bonus_count', header: 'Count', render: (r: any) => r.bonus_count },
    { key: 'total_rupees', header: 'Total Rupees', render: (r: any) => `₹${Number(r.total_rupees).toLocaleString()}` },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'bonus_count', header: 'Count', render: (r: any) => r.bonus_count },
    { key: 'total_rupees', header: 'Total Rupees', render: (r: any) => `₹${Number(r.total_rupees).toLocaleString()}` },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Customer Loyalty Bonus Payout</h1>
        <p className="text-sm text-gray-600">Reward engineers who save churn, upsell & keep CSAT at 5 stars.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Loyalty Bonuses</h2>
        <DataTable
          rows={bonuses}
          columns={bonusCols}
          emptyMessage="No bonuses recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Payout Log</h2>
        <DataTable
          rows={payoutLog}
          columns={payoutCols}
          emptyMessage="No payouts logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Value Focus</h2>
        <DataTable
          rows={topValue}
          columns={topValueCols}
          emptyMessage="No high-value bonuses yet."
          rowKey={(r: any, i: number) => String(r.bonus_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Bonus Kind Distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindDistCols}
          emptyMessage="No distribution data."
          rowKey={(r: any, i: number) => String(r.bonus_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Funnel</h2>
        <DataTable
          rows={statusFunnel}
          columns={statusCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Bonus Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owner load data."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}
