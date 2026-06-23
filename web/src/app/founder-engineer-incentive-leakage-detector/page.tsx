import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [payoutsRes, auditsRes, topEngRes, byKindRes, byReasonRes, trendRes, actionsRes] = await Promise.all([
    supabase.rpc('list_payouts_r2422'),
    supabase.rpc('list_audits_r2422'),
    supabase.rpc('top_leakage_engineers_r2422'),
    supabase.rpc('leakage_by_kind_r2422'),
    supabase.rpc('leakage_by_reason_r2422'),
    supabase.rpc('monthly_leakage_trend_r2422'),
    supabase.rpc('action_items_r2422'),
  ]);

  const payouts = payoutsRes.data ?? [];
  const audits = auditsRes.data ?? [];
  const topEng = topEngRes.data ?? [];
  const byKind = byKindRes.data ?? [];
  const byReason = byReasonRes.data ?? [];
  const trend = trendRes.data ?? [];
  const actions = actionsRes.data ?? [];

  const payoutCols: Column<any>[] = [
    { key: 'pay_cycle_start', header: 'Cycle Start', render: (r: any) => String(r.pay_cycle_start ?? '') },
    { key: 'pay_cycle_end', header: 'Cycle End', render: (r: any) => String(r.pay_cycle_end ?? '') },
    { key: 'incentive_kind', header: 'Kind', render: (r: any) => String(r.incentive_kind ?? '') },
    { key: 'earned_rupees', header: 'Earned (Rs)', render: (r: any) => String(r.earned_rupees ?? 0) },
    { key: 'paid_rupees', header: 'Paid (Rs)', render: (r: any) => String(r.paid_rupees ?? 0) },
    { key: 'delta_rupees', header: 'Delta (Rs)', render: (r: any) => String(r.delta_rupees ?? 0) },
    { key: 'leakage_reason', header: 'Reason', render: (r: any) => String(r.leakage_reason ?? '') },
    { key: 'paid_by_email', header: 'Paid By', render: (r: any) => String(r.paid_by_email ?? '') },
  ];

  const auditCols: Column<any>[] = [
    { key: 'audit_period_start', header: 'Period Start', render: (r: any) => String(r.audit_period_start ?? '') },
    { key: 'audit_period_end', header: 'Period End', render: (r: any) => String(r.audit_period_end ?? '') },
    { key: 'total_earned_rupees', header: 'Earned (Rs)', render: (r: any) => String(r.total_earned_rupees ?? 0) },
    { key: 'total_paid_rupees', header: 'Paid (Rs)', render: (r: any) => String(r.total_paid_rupees ?? 0) },
    { key: 'total_leakage_rupees', header: 'Leakage (Rs)', render: (r: any) => String(r.total_leakage_rupees ?? 0) },
    { key: 'leakage_pct', header: 'Leakage %', render: (r: any) => String(r.leakage_pct ?? 0) },
    { key: 'top_leakage_kind', header: 'Top Kind', render: (r: any) => String(r.top_leakage_kind ?? '') },
    { key: 'top_leakage_reason', header: 'Top Reason', render: (r: any) => String(r.top_leakage_reason ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const topEngCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer ID', render: (r: any) => String(r.engineer_user_id ?? '') },
    { key: 'payout_count', header: 'Payouts', render: (r: any) => String(r.payout_count ?? 0) },
    { key: 'total_earned_rupees', header: 'Earned (Rs)', render: (r: any) => String(r.total_earned_rupees ?? 0) },
    { key: 'total_paid_rupees', header: 'Paid (Rs)', render: (r: any) => String(r.total_paid_rupees ?? 0) },
    { key: 'total_leakage_rupees', header: 'Leakage (Rs)', render: (r: any) => String(r.total_leakage_rupees ?? 0) },
    { key: 'leakage_pct', header: 'Leakage %', render: (r: any) => String(r.leakage_pct ?? 0) },
  ];

  const byKindCols: Column<any>[] = [
    { key: 'incentive_kind', header: 'Kind', render: (r: any) => String(r.incentive_kind ?? '') },
    { key: 'payout_count', header: 'Payouts', render: (r: any) => String(r.payout_count ?? 0) },
    { key: 'total_earned_rupees', header: 'Earned (Rs)', render: (r: any) => String(r.total_earned_rupees ?? 0) },
    { key: 'total_paid_rupees', header: 'Paid (Rs)', render: (r: any) => String(r.total_paid_rupees ?? 0) },
    { key: 'total_leakage_rupees', header: 'Leakage (Rs)', render: (r: any) => String(r.total_leakage_rupees ?? 0) },
    { key: 'leakage_pct', header: 'Leakage %', render: (r: any) => String(r.leakage_pct ?? 0) },
  ];

  const byReasonCols: Column<any>[] = [
    { key: 'leakage_reason', header: 'Reason', render: (r: any) => String(r.leakage_reason ?? '') },
    { key: 'payout_count', header: 'Payouts', render: (r: any) => String(r.payout_count ?? 0) },
    { key: 'total_leakage_rupees', header: 'Leakage (Rs)', render: (r: any) => String(r.total_leakage_rupees ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start ?? '') },
    { key: 'payout_count', header: 'Payouts', render: (r: any) => String(r.payout_count ?? 0) },
    { key: 'total_earned_rupees', header: 'Earned (Rs)', render: (r: any) => String(r.total_earned_rupees ?? 0) },
    { key: 'total_paid_rupees', header: 'Paid (Rs)', render: (r: any) => String(r.total_paid_rupees ?? 0) },
    { key: 'total_leakage_rupees', header: 'Leakage (Rs)', render: (r: any) => String(r.total_leakage_rupees ?? 0) },
    { key: 'leakage_pct', header: 'Leakage %', render: (r: any) => String(r.leakage_pct ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'audit_period_start', header: 'Period Start', render: (r: any) => String(r.audit_period_start ?? '') },
    { key: 'audit_period_end', header: 'Period End', render: (r: any) => String(r.audit_period_end ?? '') },
    { key: 'total_leakage_rupees', header: 'Leakage (Rs)', render: (r: any) => String(r.total_leakage_rupees ?? 0) },
    { key: 'leakage_pct', header: 'Leakage %', render: (r: any) => String(r.leakage_pct ?? 0) },
    { key: 'top_leakage_kind', header: 'Top Kind', render: (r: any) => String(r.top_leakage_kind ?? '') },
    { key: 'top_leakage_reason', header: 'Top Reason', render: (r: any) => String(r.top_leakage_reason ?? '') },
    { key: 'action_taken', header: 'Action', render: (r: any) => String(r.action_taken ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  return (
    <main style={{ padding: '24px', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '6px' }}>
        Engineer Incentive Leakage Detector
      </h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Track earned vs paid incentive per cycle & kind. Surface leakage reasons, drive audit closure.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Open Action Items</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No open leakage audits."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Top Leakage Engineers</h2>
        <DataTable
          rows={topEng}
          columns={topEngCols}
          emptyMessage="No engineer leakage data."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Leakage by Kind</h2>
        <DataTable
          rows={byKind}
          columns={byKindCols}
          emptyMessage="No kind breakdown."
          rowKey={(r: any, i: number) => String(r.incentive_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Leakage by Reason</h2>
        <DataTable
          rows={byReason}
          columns={byReasonCols}
          emptyMessage="No reason breakdown."
          rowKey={(r: any, i: number) => String(r.leakage_reason ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>Monthly Leakage Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>All Payouts</h2>
        <DataTable
          rows={payouts}
          columns={payoutCols}
          emptyMessage="No payouts recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '8px' }}>All Audits</h2>
        <DataTable
          rows={audits}
          columns={auditCols}
          emptyMessage="No audits recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
