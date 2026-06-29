import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_wires: number;
  total_wired_inr: number;
  reconciled_count: number;
  in_transit_count: number;
  disputed_count: number;
  current_month_inflow_inr: number;
  flagged_movements: number;
  closing_reserve_inr: number;
};

type WireRow = {
  id: string;
  wire_month: string;
  investor_name: string;
  investor_class: string;
  wire_amount_inr: number;
  wire_currency: string;
  wire_status: string;
  bank_account_label: string;
  expected_at: string;
  received_at: string | null;
};

type MovementRow = {
  id: string;
  movement_month: string;
  reserve_account: string;
  movement_type: string;
  amount_inr: number;
  closing_balance_inr: number;
  movement_at: string;
  counterparty: string | null;
  approval_status: string;
  variance_flag: boolean;
};

type ClassRow = {
  investor_class: string;
  wire_count: number;
  total_inr: number;
  reconciled_inr: number;
};

type TrailRow = {
  reserve_account: string;
  movement_count: number;
  net_change_inr: number;
  latest_closing_inr: number;
  flagged_count: number;
};

type TrendRow = {
  movement_month: string;
  total_inflow_inr: number;
  total_outflow_inr: number;
  net_inr: number;
};

type VarianceRow = {
  id: string;
  reserve_account: string;
  movement_type: string;
  amount_inr: number;
  counterparty: string | null;
  approval_status: string;
  movement_at: string;
  notes: string | null;
};

type PendingRow = {
  id: string;
  investor_name: string;
  investor_class: string;
  wire_amount_inr: number;
  wire_currency: string;
  wire_status: string;
  expected_at: string;
  days_pending: number;
};

function fmtInr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  if (v >= 10000000) return '₹' + (v / 10000000).toFixed(2) + ' Cr';
  if (v >= 100000) return '₹' + (v / 100000).toFixed(2) + ' L';
  return '₹' + v.toLocaleString('en-IN');
}

function fmtDate(d: string | null | undefined): string {
  if (!d) return '-';
  return new Date(d).toLocaleDateString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, wiresRes, movementsRes, classRes, trailRes, trendRes, varianceRes, pendingRes] = await Promise.all([
    supabase.rpc('r2925_kpi_summary'),
    supabase.rpc('r2925_list_wires'),
    supabase.rpc('r2925_list_movements'),
    supabase.rpc('r2925_investor_class_breakdown'),
    supabase.rpc('r2925_account_balance_trail'),
    supabase.rpc('r2925_monthly_inflow_trend'),
    supabase.rpc('r2925_variance_alerts'),
    supabase.rpc('r2925_pending_reconciliation'),
  ]);

  const kpi: KpiRow = (kpiRes.data?.[0] ?? {
    total_wires: 0,
    total_wired_inr: 0,
    reconciled_count: 0,
    in_transit_count: 0,
    disputed_count: 0,
    current_month_inflow_inr: 0,
    flagged_movements: 0,
    closing_reserve_inr: 0,
  }) as KpiRow;

  const wires: WireRow[] = (wiresRes.data ?? []) as WireRow[];
  const movements: MovementRow[] = (movementsRes.data ?? []) as MovementRow[];
  const classes: ClassRow[] = (classRes.data ?? []) as ClassRow[];
  const trails: TrailRow[] = (trailRes.data ?? []) as TrailRow[];
  const trends: TrendRow[] = (trendRes.data ?? []) as TrendRow[];
  const variances: VarianceRow[] = (varianceRes.data ?? []) as VarianceRow[];
  const pendings: PendingRow[] = (pendingRes.data ?? []) as PendingRow[];

  const wireCols: Column<WireRow>[] = [
    { key: 'wire_month', header: 'Month', render: (r) => fmtDate(r.wire_month) },
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name },
    { key: 'investor_class', header: 'Class', render: (r) => r.investor_class },
    { key: 'wire_amount_inr', header: 'Amount', render: (r) => fmtInr(r.wire_amount_inr) },
    { key: 'wire_currency', header: 'Ccy', render: (r) => r.wire_currency },
    { key: 'wire_status', header: 'Status', render: (r) => r.wire_status },
    { key: 'bank_account_label', header: 'Account', render: (r) => r.bank_account_label },
    { key: 'expected_at', header: 'Expected', render: (r) => fmtDate(r.expected_at) },
    { key: 'received_at', header: 'Received', render: (r) => fmtDate(r.received_at) },
  ];

  const moveCols: Column<MovementRow>[] = [
    { key: 'movement_at', header: 'When', render: (r) => fmtDate(r.movement_at) },
    { key: 'reserve_account', header: 'Account', render: (r) => r.reserve_account },
    { key: 'movement_type', header: 'Type', render: (r) => r.movement_type },
    { key: 'amount_inr', header: 'Amount', render: (r) => fmtInr(r.amount_inr) },
    { key: 'closing_balance_inr', header: 'Closing', render: (r) => fmtInr(r.closing_balance_inr) },
    { key: 'counterparty', header: 'Counterparty', render: (r) => r.counterparty ?? '-' },
    { key: 'approval_status', header: 'Approval', render: (r) => r.approval_status },
    { key: 'variance_flag', header: 'Variance', render: (r) => (r.variance_flag ? 'YES' : 'no') },
  ];

  const classCols: Column<ClassRow>[] = [
    { key: 'investor_class', header: 'Class', render: (r) => r.investor_class },
    { key: 'wire_count', header: 'Wires', render: (r) => String(r.wire_count) },
    { key: 'total_inr', header: 'Total', render: (r) => fmtInr(r.total_inr) },
    { key: 'reconciled_inr', header: 'Reconciled', render: (r) => fmtInr(r.reconciled_inr) },
  ];

  const trailCols: Column<TrailRow>[] = [
    { key: 'reserve_account', header: 'Account', render: (r) => r.reserve_account },
    { key: 'movement_count', header: 'Movements', render: (r) => String(r.movement_count) },
    { key: 'net_change_inr', header: 'Net Change', render: (r) => fmtInr(r.net_change_inr) },
    { key: 'latest_closing_inr', header: 'Latest Closing', render: (r) => fmtInr(r.latest_closing_inr) },
    { key: 'flagged_count', header: 'Flagged', render: (r) => String(r.flagged_count) },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'movement_month', header: 'Month', render: (r) => fmtDate(r.movement_month) },
    { key: 'total_inflow_inr', header: 'Inflow', render: (r) => fmtInr(r.total_inflow_inr) },
    { key: 'total_outflow_inr', header: 'Outflow', render: (r) => fmtInr(r.total_outflow_inr) },
    { key: 'net_inr', header: 'Net', render: (r) => fmtInr(r.net_inr) },
  ];

  const varCols: Column<VarianceRow>[] = [
    { key: 'movement_at', header: 'When', render: (r) => fmtDate(r.movement_at) },
    { key: 'reserve_account', header: 'Account', render: (r) => r.reserve_account },
    { key: 'movement_type', header: 'Type', render: (r) => r.movement_type },
    { key: 'amount_inr', header: 'Amount', render: (r) => fmtInr(r.amount_inr) },
    { key: 'counterparty', header: 'Counterparty', render: (r) => r.counterparty ?? '-' },
    { key: 'approval_status', header: 'Approval', render: (r) => r.approval_status },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '-' },
  ];

  const pendCols: Column<PendingRow>[] = [
    { key: 'investor_name', header: 'Investor', render: (r) => r.investor_name },
    { key: 'investor_class', header: 'Class', render: (r) => r.investor_class },
    { key: 'wire_amount_inr', header: 'Amount', render: (r) => fmtInr(r.wire_amount_inr) },
    { key: 'wire_currency', header: 'Ccy', render: (r) => r.wire_currency },
    { key: 'wire_status', header: 'Status', render: (r) => r.wire_status },
    { key: 'expected_at', header: 'Expected', render: (r) => fmtDate(r.expected_at) },
    { key: 'days_pending', header: 'Days Pending', render: (r) => String(r.days_pending) },
  ];

  const kpiCard = (label: string, value: string) => (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 600, marginTop: 6 }}>{value}</div>
    </div>
  );

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700, margin: 0 }}>
          Monthly Strategic Investor Wire & Bank-Reserve Movement Audit
        </h1>
        <p style={{ color: '#6b7280', marginTop: 6 }}>
          Round r2925 — founder-gated audit of investor wires and reserve account movements (HEAVY ops).
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpiCard('Total Wires', String(kpi.total_wires))}
        {kpiCard('Total Wired', fmtInr(kpi.total_wired_inr))}
        {kpiCard('Reconciled', String(kpi.reconciled_count))}
        {kpiCard('In Transit', String(kpi.in_transit_count))}
        {kpiCard('Disputed', String(kpi.disputed_count))}
        {kpiCard('This Month Inflow', fmtInr(kpi.current_month_inflow_inr))}
        {kpiCard('Flagged Movements', String(kpi.flagged_movements))}
        {kpiCard('Closing Reserve', fmtInr(kpi.closing_reserve_inr))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Investor Wires (latest first)</h2>
        <DataTable
          rows={wires}
          columns={wireCols}
          emptyMessage="No investor wires recorded."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Bank-Reserve Movements</h2>
        <DataTable
          rows={movements}
          columns={moveCols}
          emptyMessage="No reserve movements recorded."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Investor Class Breakdown</h2>
        <DataTable
          rows={classes}
          columns={classCols}
          emptyMessage="No class data."
          rowKey={(r, i) => String(r.investor_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Account Balance Trail</h2>
        <DataTable
          rows={trails}
          columns={trailCols}
          emptyMessage="No accounts."
          rowKey={(r, i) => String(r.reserve_account ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Monthly Inflow vs Outflow Trend</h2>
        <DataTable
          rows={trends}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.movement_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Variance & Approval Alerts</h2>
        <DataTable
          rows={variances}
          columns={varCols}
          emptyMessage="No variance alerts. All clear."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Pending Wire Reconciliation</h2>
        <DataTable
          rows={pendings}
          columns={pendCols}
          emptyMessage="No pending wires."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
