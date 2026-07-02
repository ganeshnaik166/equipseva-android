import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainEquipmentUptimeSlaBoardPage() {
  const supabase = await getSupabaseServerClient();

  const [
    uptimeRes,
    creditsRes,
    statusRes,
    chainsRes,
    balanceRes,
    kindRes,
    trendRes,
  ] = await Promise.all([
    supabase.rpc('list_uptime_r2431'),
    supabase.rpc('list_credits_r2431'),
    supabase.rpc('sla_status_breakdown_r2431'),
    supabase.rpc('top_at_risk_chains_r2431'),
    supabase.rpc('credit_balance_summary_r2431'),
    supabase.rpc('equipment_kind_summary_r2431'),
    supabase.rpc('weekly_uptime_trend_r2431'),
  ]);

  const uptimeRows = (uptimeRes.data ?? []) as any[];
  const creditRows = (creditsRes.data ?? []) as any[];
  const statusRows = (statusRes.data ?? []) as any[];
  const chainRows = (chainsRes.data ?? []) as any[];
  const balanceRows = (balanceRes.data ?? []) as any[];
  const kindRows = (kindRes.data ?? []) as any[];
  const trendRows = (trendRes.data ?? []) as any[];

  const inr = (n: number | null | undefined) =>
    typeof n === 'number' ? `₹${n.toLocaleString('en-IN')}` : '₹0';

  const uptimeColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    {
      key: 'uptime_target_pct',
      header: 'Target %',
      render: (r: any) => `${Number(r.uptime_target_pct).toFixed(2)}%`,
    },
    {
      key: 'actual_uptime_pct',
      header: 'Actual %',
      render: (r: any) => `${Number(r.actual_uptime_pct).toFixed(2)}%`,
    },
    { key: 'sla_status', header: 'SLA Status', render: (r: any) => r.sla_status },
    {
      key: 'downtime_minutes',
      header: 'Downtime (min)',
      render: (r: any) => Number(r.downtime_minutes ?? 0).toLocaleString('en-IN'),
    },
    { key: 'slo_breaches', header: 'Breaches', render: (r: any) => r.slo_breaches },
    {
      key: 'penalty_rupees',
      header: 'Penalty',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.penalty_rupees ?? 0)) }} />
      ),
    },
    {
      key: 'credit_owed_rupees',
      header: 'Credit Owed',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.credit_owed_rupees ?? 0)) }} />
      ),
    },
    {
      key: 'uptime_window',
      header: 'Window',
      render: (r: any) => `${r.uptime_window_start} to ${r.uptime_window_end}`,
    },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const creditColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    {
      key: 'credit_period',
      header: 'Period',
      render: (r: any) => `${r.credit_period_start} to ${r.credit_period_end}`,
    },
    {
      key: 'total_credit_owed_rupees',
      header: 'Owed',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_credit_owed_rupees ?? 0)) }} />
      ),
    },
    {
      key: 'total_credit_paid_rupees',
      header: 'Paid',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_credit_paid_rupees ?? 0)) }} />
      ),
    },
    {
      key: 'balance_rupees',
      header: 'Balance',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.balance_rupees ?? 0)) }} />
      ),
    },
    { key: 'payment_status', header: 'Status', render: (r: any) => r.payment_status },
    {
      key: 'payment_due_at',
      header: 'Due',
      render: (r: any) => (r.payment_due_at ? new Date(r.payment_due_at).toLocaleString('en-IN') : ''),
    },
    { key: 'payment_owner_email', header: 'Owner', render: (r: any) => r.payment_owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const statusColumns: Column<any>[] = [
    { key: 'sla_status', header: 'SLA Status', render: (r: any) => r.sla_status },
    { key: 'equipment_count', header: 'Equipment', render: (r: any) => r.equipment_count },
    {
      key: 'total_downtime_minutes',
      header: 'Downtime (min)',
      render: (r: any) => Number(r.total_downtime_minutes ?? 0).toLocaleString('en-IN'),
    },
    {
      key: 'total_penalty_rupees',
      header: 'Penalty',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_penalty_rupees ?? 0)) }} />
      ),
    },
    {
      key: 'total_credit_owed_rupees',
      header: 'Credit Owed',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_credit_owed_rupees ?? 0)) }} />
      ),
    },
    {
      key: 'avg_actual_uptime_pct',
      header: 'Avg Actual %',
      render: (r: any) => `${Number(r.avg_actual_uptime_pct ?? 0).toFixed(2)}%`,
    },
  ];

  const chainColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_count', header: 'Equipment', render: (r: any) => r.equipment_count },
    { key: 'breach_count', header: 'Breaches', render: (r: any) => r.breach_count },
    { key: 'severe_breach_count', header: 'Severe', render: (r: any) => r.severe_breach_count },
    {
      key: 'total_downtime_minutes',
      header: 'Downtime (min)',
      render: (r: any) => Number(r.total_downtime_minutes ?? 0).toLocaleString('en-IN'),
    },
    {
      key: 'total_penalty_rupees',
      header: 'Penalty',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_penalty_rupees ?? 0)) }} />
      ),
    },
    {
      key: 'total_credit_owed_rupees',
      header: 'Credit Owed',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_credit_owed_rupees ?? 0)) }} />
      ),
    },
    {
      key: 'avg_actual_uptime_pct',
      header: 'Avg Actual %',
      render: (r: any) => `${Number(r.avg_actual_uptime_pct ?? 0).toFixed(2)}%`,
    },
  ];

  const balanceColumns: Column<any>[] = [
    { key: 'payment_status', header: 'Status', render: (r: any) => r.payment_status },
    { key: 'credit_count', header: 'Count', render: (r: any) => r.credit_count },
    {
      key: 'total_owed_rupees',
      header: 'Owed',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_owed_rupees ?? 0)) }} />
      ),
    },
    {
      key: 'total_paid_rupees',
      header: 'Paid',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_paid_rupees ?? 0)) }} />
      ),
    },
    {
      key: 'total_balance_rupees',
      header: 'Balance',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_balance_rupees ?? 0)) }} />
      ),
    },
  ];

  const kindColumns: Column<any>[] = [
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'equipment_count', header: 'Equipment', render: (r: any) => r.equipment_count },
    {
      key: 'avg_actual_uptime_pct',
      header: 'Avg Actual %',
      render: (r: any) => `${Number(r.avg_actual_uptime_pct ?? 0).toFixed(2)}%`,
    },
    {
      key: 'total_downtime_minutes',
      header: 'Downtime (min)',
      render: (r: any) => Number(r.total_downtime_minutes ?? 0).toLocaleString('en-IN'),
    },
    {
      key: 'total_penalty_rupees',
      header: 'Penalty',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_penalty_rupees ?? 0)) }} />
      ),
    },
    {
      key: 'total_credit_owed_rupees',
      header: 'Credit Owed',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_credit_owed_rupees ?? 0)) }} />
      ),
    },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start },
    { key: 'equipment_count', header: 'Equipment', render: (r: any) => r.equipment_count },
    {
      key: 'avg_actual_uptime_pct',
      header: 'Avg Actual %',
      render: (r: any) => `${Number(r.avg_actual_uptime_pct ?? 0).toFixed(2)}%`,
    },
    {
      key: 'total_downtime_minutes',
      header: 'Downtime (min)',
      render: (r: any) => Number(r.total_downtime_minutes ?? 0).toLocaleString('en-IN'),
    },
    { key: 'total_breaches', header: 'Breaches', render: (r: any) => r.total_breaches },
    {
      key: 'total_credit_owed_rupees',
      header: 'Credit Owed',
      render: (r: any) => (
        <span dangerouslySetInnerHTML={{ __html: inr(Number(r.total_credit_owed_rupees ?? 0)) }} />
      ),
    },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
          Hospital Chain Equipment Uptime & SLA Board
        </h1>
        <p style={{ color: '#555' }}>
          Chain > equipment > uptime % > SLA target > penalty earned > credits owed.
        </p>
      </header>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          SLA Status Breakdown
        </h2>
        <DataTable
          rows={statusRows}
          columns={statusColumns}
          emptyMessage="No SLA status rows."
          rowKey={(r: any, i: number) => String(r.id ?? r.sla_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          Top At-Risk Chains
        </h2>
        <DataTable
          rows={chainRows}
          columns={chainColumns}
          emptyMessage="No at-risk chains yet."
          rowKey={(r: any, i: number) => String(r.id ?? r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          Credit Balance Summary
        </h2>
        <DataTable
          rows={balanceRows}
          columns={balanceColumns}
          emptyMessage="No credit balances."
          rowKey={(r: any, i: number) => String(r.id ?? r.payment_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          Equipment Kind Summary
        </h2>
        <DataTable
          rows={kindRows}
          columns={kindColumns}
          emptyMessage="No equipment kinds."
          rowKey={(r: any, i: number) => String(r.id ?? r.equipment_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          Weekly Uptime Trend
        </h2>
        <DataTable
          rows={trendRows}
          columns={trendColumns}
          emptyMessage="No weekly trend rows."
          rowKey={(r: any, i: number) => String(r.id ?? r.week_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          Equipment Uptime Log
        </h2>
        <DataTable
          rows={uptimeRows}
          columns={uptimeColumns}
          emptyMessage="No uptime rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>
          SLA Credits Owed
        </h2>
        <DataTable
          rows={creditRows}
          columns={creditColumns}
          emptyMessage="No SLA credits logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
