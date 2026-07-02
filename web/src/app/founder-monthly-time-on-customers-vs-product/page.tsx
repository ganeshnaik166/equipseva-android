import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [allocationRes, correctionsRes, focusRes, trendRes, distributionRes, funnelRes, pulseRes] = await Promise.all([
    supabase.rpc('list_allocation_r2633'),
    supabase.rpc('list_corrections_r2633'),
    supabase.rpc('top_balance_focus_r2633'),
    supabase.rpc('monthly_allocation_trend_r2633'),
    supabase.rpc('balance_kind_distribution_r2633'),
    supabase.rpc('correction_status_funnel_r2633'),
    supabase.rpc('founder_pulse_summary_r2633'),
  ]);

  const allocation = (allocationRes.data ?? []) as any[];
  const corrections = (correctionsRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const distribution = (distributionRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const pulse = (pulseRes.data ?? [])[0] as any | undefined;

  const allocationColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'customer_hours', header: 'Customer hrs', render: (r: any) => Number(r.customer_hours).toFixed(0) },
    { key: 'product_hours', header: 'Product hrs', render: (r: any) => Number(r.product_hours).toFixed(0) },
    { key: 'team_hours', header: 'Team hrs', render: (r: any) => Number(r.team_hours).toFixed(0) },
    { key: 'fundraise_hours', header: 'Fundraise hrs', render: (r: any) => Number(r.fundraise_hours).toFixed(0) },
    { key: 'total_hours', header: 'Total', render: (r: any) => Number(r.total_hours).toFixed(0) },
    { key: 'balance_kind', header: 'Balance', render: (r: any) => r.balance_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const correctionsColumns: Column<any>[] = [
    { key: 'correction_at', header: 'When', render: (r: any) => new Date(r.correction_at).toLocaleString() },
    { key: 'correction_kind', header: 'Kind', render: (r: any) => r.correction_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const focusColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'balance_kind', header: 'Balance', render: (r: any) => r.balance_kind },
    { key: 'total_hours', header: 'Total hrs', render: (r: any) => Number(r.total_hours).toFixed(0) },
    { key: 'customer_hours', header: 'Customer', render: (r: any) => Number(r.customer_hours).toFixed(0) },
    { key: 'product_hours', header: 'Product', render: (r: any) => Number(r.product_hours).toFixed(0) },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'customer_hours', header: 'Customer', render: (r: any) => Number(r.customer_hours).toFixed(0) },
    { key: 'product_hours', header: 'Product', render: (r: any) => Number(r.product_hours).toFixed(0) },
    { key: 'team_hours', header: 'Team', render: (r: any) => Number(r.team_hours).toFixed(0) },
    { key: 'fundraise_hours', header: 'Fundraise', render: (r: any) => Number(r.fundraise_hours).toFixed(0) },
  ];

  const distributionColumns: Column<any>[] = [
    { key: 'balance_kind', header: 'Balance', render: (r: any) => r.balance_kind },
    { key: 'month_count', header: 'Months', render: (r: any) => String(r.month_count) },
    { key: 'total_hours', header: 'Total hrs', render: (r: any) => Number(r.total_hours).toFixed(0) },
  ];

  const funnelColumns: Column<any>[] = [
    { key: 'status', header: 'Correction status', render: (r: any) => r.status },
    { key: 'correction_count', header: 'Count', render: (r: any) => String(r.correction_count) },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder monthly time: customers vs product</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Track where founder hours land each month & the corrections taken to rebalance.
        </p>
      </header>

      {pulse ? (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <Card label="Months tracked" value={String(pulse.months_tracked ?? 0)} />
          <Card label="Total logged hrs" value={Number(pulse.total_logged_hours ?? 0).toFixed(0)} />
          <Card label="Customer hrs" value={Number(pulse.total_customer_hours ?? 0).toFixed(0)} />
          <Card label="Product hrs" value={Number(pulse.total_product_hours ?? 0).toFixed(0)} />
          <Card label="Open corrections" value={String(pulse.open_corrections ?? 0)} />
          <Card label="Positive outcomes" value={String(pulse.positive_outcomes ?? 0)} />
        </section>
      ) : null}

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top balance focus months</h2>
        <DataTable
          rows={focus}
          columns={focusColumns}
          emptyMessage="No focus months yet"
          rowKey={(r: any, i: number) => String(r.id ?? `${r.month_label}-${i}`)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly allocation trend</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.id ?? `${r.month_label}-${i}`)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Balance kind distribution</h2>
        <DataTable
          rows={distribution}
          columns={distributionColumns}
          emptyMessage="No distribution yet"
          rowKey={(r: any, i: number) => String(r.id ?? `${r.balance_kind}-${i}`)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Correction status funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelColumns}
          emptyMessage="No corrections yet"
          rowKey={(r: any, i: number) => String(r.id ?? `${r.status}-${i}`)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All monthly allocations</h2>
        <DataTable
          rows={allocation}
          columns={allocationColumns}
          emptyMessage="No months logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Corrections log</h2>
        <DataTable
          rows={corrections}
          columns={correctionsColumns}
          emptyMessage="No corrections logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
