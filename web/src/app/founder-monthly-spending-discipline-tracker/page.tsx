import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlySpendingDisciplineTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    spendingRes,
    actionsRes,
    trendRes,
    breachDistRes,
    savingsRateRes,
    topCorrectionsRes,
    pulseRes,
  ] = await Promise.all([
    supabase.rpc('list_spending_r2585'),
    supabase.rpc('list_correction_actions_r2585'),
    supabase.rpc('monthly_breach_trend_r2585'),
    supabase.rpc('breach_kind_distribution_r2585'),
    supabase.rpc('savings_rate_summary_r2585'),
    supabase.rpc('top_correction_kinds_r2585'),
    supabase.rpc('founder_pulse_summary_r2585'),
  ]);

  const spending = (spendingRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const breachDist = (breachDistRes.data ?? []) as any[];
  const savingsRate = (savingsRateRes.data ?? []) as any[];
  const topCorrections = (topCorrectionsRes.data ?? []) as any[];
  const pulse = (pulseRes.data ?? [])[0] as any;

  const inr = (v: any) =>
    v === null || v === undefined ? '-' : `Rs ${Number(v).toLocaleString('en-IN')}`;

  const spendingCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'discretionary', header: 'Discretionary', render: (r: any) => inr(r.discretionary_rupees) },
    { key: 'required', header: 'Required', render: (r: any) => inr(r.required_rupees) },
    { key: 'debt', header: 'Debt Pay', render: (r: any) => inr(r.debt_payment_rupees) },
    { key: 'savings', header: 'Savings', render: (r: any) => inr(r.savings_rupees) },
    { key: 'breach', header: 'Breach', render: (r: any) => (r.budget_breach ? r.breach_kind : 'none') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'month', header: 'Month', render: (r: any) => r.month_label },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'breach_kind', header: 'Breach Kind', render: (r: any) => r.breach_kind },
    { key: 'discretionary', header: 'Discretionary', render: (r: any) => inr(r.discretionary_rupees) },
    { key: 'required', header: 'Required', render: (r: any) => inr(r.required_rupees) },
    { key: 'debt', header: 'Debt Pay', render: (r: any) => inr(r.debt_payment_rupees) },
    { key: 'savings', header: 'Savings', render: (r: any) => inr(r.savings_rupees) },
  ];

  const breachDistCols: Column<any>[] = [
    { key: 'breach_kind', header: 'Breach Kind', render: (r: any) => r.breach_kind },
    { key: 'months_count', header: 'Months', render: (r: any) => String(r.months_count) },
    { key: 'total_discretionary', header: 'Total Discretionary', render: (r: any) => inr(r.total_discretionary) },
    { key: 'total_savings', header: 'Total Savings', render: (r: any) => inr(r.total_savings) },
  ];

  const savingsRateCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'total_inflow', header: 'Total Inflow', render: (r: any) => inr(r.total_inflow_rupees) },
    { key: 'savings', header: 'Savings', render: (r: any) => inr(r.savings_rupees) },
    { key: 'rate', header: 'Savings Rate %', render: (r: any) => `${r.savings_rate_pct}%` },
  ];

  const topCorrectionsCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => r.action_kind },
    { key: 'count', header: 'Total', render: (r: any) => String(r.actions_count) },
    { key: 'positive', header: 'Positive', render: (r: any) => String(r.positive_count) },
    { key: 'pending', header: 'Pending', render: (r: any) => String(r.pending_count) },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Founder Monthly Spending Discipline Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '1.5rem' }}>
        Month &gt; discretionary &gt; required &gt; debt-pay &gt; savings &gt; budget breach &gt; correction action.
      </p>

      {pulse && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '1rem', marginBottom: '2rem' }}>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#6b7280' }}>Months Tracked</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{String(pulse.months_tracked ?? 0)}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#6b7280' }}>Breach Months</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{String(pulse.breach_months ?? 0)}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#6b7280' }}>Total Savings</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{inr(pulse.total_savings_rupees)}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: 8 }}>
            <div style={{ fontSize: '0.75rem', color: '#6b7280' }}>Open Corrections</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{String(pulse.open_corrections ?? 0)}</div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Monthly Spending</h2>
        <DataTable
          rows={spending}
          columns={spendingCols}
          emptyMessage="No spending months tracked yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Correction Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No correction actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Monthly Breach Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Breach Kind Distribution</h2>
        <DataTable
          rows={breachDist}
          columns={breachDistCols}
          emptyMessage="No breaches recorded."
          rowKey={(r: any, i: number) => String(r.breach_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Savings Rate Summary</h2>
        <DataTable
          rows={savingsRate}
          columns={savingsRateCols}
          emptyMessage="No savings data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Top Correction Kinds</h2>
        <DataTable
          rows={topCorrections}
          columns={topCorrectionsCols}
          emptyMessage="No corrections yet."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>
    </main>
  );
}
